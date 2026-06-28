"use strict";

const crypto = require("node:crypto");
const { HttpsError } = require("firebase-functions/v2/https");

const {
  CallV2Error,
  ERROR_CODES,
  acceptCallV2,
  cancelCallV2,
  declineCallV2,
  dispatchTaskOutboxV2,
  endCallV2,
  reportParticipantMediaV2,
  renewActiveCallLeaseV2,
  startCallV2,
  createTimeoutTaskHttpHandlerV2,
} = require("./start_call_v2");
const {
  createCloudTasksPublisherV2,
} = require("./cloud_tasks_adapter_v2");
const {
  TASK_OUTBOX_RECOVERY_DEFAULT_LIMIT,
  recoverPendingTaskOutboxV2,
} = require("./deployment_readiness_v2");
const {
  evaluateCallV2ClientEligibility,
  resolveTargetEligibilityV2,
} = require("./rollout_gate_v2");
const {
  OPERATIONAL_EVENT_NAMES,
  createCallV2OperationalRecorder,
  httpStatusClass,
  timeoutOutcomeForStatus,
} = require("./observability_v2");

const CALLABLE_SERVICE_NAMES = Object.freeze([
  "startCallV2",
  "acceptCallV2",
  "declineCallV2",
  "cancelCallV2",
  "endCallV2",
  "reportParticipantMediaV2",
  "renewActiveCallLeaseV2",
]);

const CALL_V2_ERROR_TO_HTTPS = Object.freeze({
  unauthenticated: "unauthenticated",
  forbidden: "permission-denied",
  call_not_found: "not-found",
  invalid_argument: "invalid-argument",
  user_busy: "failed-precondition",
  invalid_state: "failed-precondition",
  idempotency_conflict: "already-exists",
  call_id_conflict: "already-exists",
  lock_recovery_required: "failed-precondition",
  transaction_failed: "internal",
});

const PRIVATE_CLIENT_RESULT_KEYS = Object.freeze([
  "callOps",
  "claimExpiresAt",
  "claimToken",
  "commandId",
  "commands",
  "deterministicExternalTaskId",
  "dispatchAttempt",
  "dispatchAttempts",
  "dispatchDiagnostics",
  "externalTaskName",
  "fencingToken",
  "lockClaims",
  "lockReleaseResults",
  "outboxTaskId",
  "taskId",
]);

function createCallV2FirebaseWiring({
  db,
  cloudTasksClient,
  tokenVerifier,
  targetUserAuth,
  config,
  generateClaimToken,
  generateCallId,
  now,
  services = {},
}) {
  if (!db) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A Firestore database dependency is required.",
    );
  }
  const nowProvider = typeof now === "function" ? now : () => new Date();
  const claimTokenGenerator =
    generateClaimToken || generateStrongDispatchClaimToken;
  const callIdGenerator = generateCallId || generateStrongCallId;
  const domainServices = buildCallableServices({
    services,
    generateCallId: callIdGenerator,
  });
  const taskPublisherFactory =
    services.createCloudTasksPublisher || createConfiguredCloudTasksPublisherV2;
  const dispatchService = services.dispatchTaskOutboxV2 || dispatchTaskOutboxV2;
  const recoveryService =
    services.recoverPendingTaskOutboxV2 || recoverPendingTaskOutboxV2;
  const clientEligibilityService =
    services.evaluateCallV2ClientEligibility || evaluateCallV2ClientEligibility;
  const targetEligibilityService =
    services.resolveTargetEligibilityV2 || resolveTargetEligibilityV2;
  const timeoutHandlerFactory =
    services.createTimeoutTaskHttpHandlerV2 || createTimeoutTaskHttpHandlerV2;
  const operationalRecorder = createCallV2OperationalRecorder({
    enabled: () => resolveBooleanConfig(config, "callV2ObservabilityEnabled"),
    sink: services.operationalEventSink,
  });

  const callableHandlers = Object.fromEntries(
    CALLABLE_SERVICE_NAMES.map((name) => [
      name,
      createCallableHandler({
        serviceName: name,
        service: domainServices[name],
        db,
        config,
        nowProvider,
        clientEligibilityService,
        targetEligibilityService,
        targetUserAuth,
        operationalRecorder,
      }),
    ]),
  );

  return Object.freeze({
    callableHandlers: Object.freeze(callableHandlers),
    async handleTaskOutboxCreated(event) {
      try {
        if (!resolveBooleanConfig(config, "callV2InternalTasksEnabled")) {
          recordOperationalEvent(operationalRecorder, () => ({
            eventName: OPERATIONAL_EVENT_NAMES.outboxDispatchOutcome,
            outcome: "disabled",
            fields: { retryable: false },
          }));
          throw new CallV2Error(
            ERROR_CODES.transactionFailed,
            "Call V2 internal task dispatch is disabled.",
          );
        }
        const callId = event && event.params ? event.params.callId : undefined;
        const taskId = event && event.params ? event.params.taskId : undefined;
        const publisher = taskPublisherFactory({
          cloudTasksClient,
          config,
        });
        const result = await dispatchService({
          db,
          request: {
            callId,
            taskId,
          },
          now: nowProvider,
          generateClaimToken: claimTokenGenerator,
          publisher,
        });
        if (["dispatched", "already_dispatched", "dead_letter"].includes(
          result.status,
        )) {
          recordOperationalEvent(operationalRecorder, () => ({
            eventName: OPERATIONAL_EVENT_NAMES.outboxDispatchOutcome,
            outcome: result.status,
            fields: { retryable: false },
          }));
          return result;
        }
        recordOperationalEvent(operationalRecorder, () => ({
          eventName: OPERATIONAL_EVENT_NAMES.outboxDispatchOutcome,
          outcome: "retry_required",
          fields: { retryable: true },
        }));
        throw new CallV2Error(
          ERROR_CODES.transactionFailed,
          `Call V2 outbox dispatch requires retry: ${result.status}.`,
        );
      } catch (error) {
        if (!isExpectedOutboxBoundaryError(error)) {
          recordOperationalEvent(operationalRecorder, () => ({
            eventName: OPERATIONAL_EVENT_NAMES.outboxDispatchOutcome,
            outcome: "failed",
            fields: { retryable: true },
          }));
        }
        throw error;
      }
    },
    async handleScheduledOutboxRecovery() {
      try {
        if (!resolveBooleanConfig(config, "callV2InternalTasksEnabled")) {
          const disabledResult = Object.freeze({
            status: "disabled",
            examined: 0,
            dispatched: 0,
            alreadyDispatched: 0,
            deadLetter: 0,
            busy: 0,
            retryable: 0,
            stale: 0,
            failed: 0,
          });
          recordScheduledRecoveryOutcome(
            operationalRecorder,
            "disabled",
            disabledResult,
          );
          return disabledResult;
        }
        const publisher = taskPublisherFactory({
          cloudTasksClient,
          config,
        });
        const result = await recoveryService({
          db,
          now: nowProvider,
          limit: TASK_OUTBOX_RECOVERY_DEFAULT_LIMIT,
          dispatchTask: dispatchService,
          generateClaimToken: claimTokenGenerator,
          publisher,
        });
        const completedResult = Object.freeze({
          status: "completed",
          ...result,
        });
        recordScheduledRecoveryOutcome(
          operationalRecorder,
          "completed",
          completedResult,
        );
        return completedResult;
      } catch (error) {
        recordScheduledRecoveryOutcome(operationalRecorder, "failed", {
          status: "disabled",
          examined: 0,
          dispatched: 0,
          alreadyDispatched: 0,
          deadLetter: 0,
          busy: 0,
          retryable: 0,
          stale: 0,
          failed: 0,
        });
        throw error;
      }
    },
    createTimeoutHttpHandler() {
      return async function callV2TimeoutHttpHandler(req, res) {
        let verificationResult = "not_checked";
        const normalizedHandler = timeoutHandlerFactory({
          db,
          verifyRequest: async (request) => {
            const verified = await verifyCloudTasksOidcRequestV2({
              request,
              tokenVerifier,
              config,
            });
            verificationResult = verified ? "authorized" : "unauthorized";
            return verified;
          },
          now: nowProvider,
        });
        try {
          const response = await normalizedHandler({
            method: req && req.method,
            body: req && req.body,
            headers: req && req.headers ? req.headers : {},
          });
          recordOperationalEvent(operationalRecorder, () => ({
            eventName: OPERATIONAL_EVENT_NAMES.timeoutHttpOutcome,
            outcome: timeoutOutcomeForStatus(response.statusCode),
            fields: {
              httpStatusClass: httpStatusClass(response.statusCode),
              verificationResult,
              retryable: response.statusCode >= 500,
            },
          }));
          return res.status(response.statusCode).json(response.body);
        } catch (error) {
          recordOperationalEvent(operationalRecorder, () => ({
            eventName: OPERATIONAL_EVENT_NAMES.timeoutHttpOutcome,
            outcome: "failed",
            fields: {
              httpStatusClass: "unknown",
              verificationResult,
              retryable: true,
            },
          }));
          throw error;
        }
      };
    },
  });
}

function buildCallableServices({ services, generateCallId }) {
  return {
    startCallV2:
      services.startCallV2 ||
      ((args) => startCallV2({ ...args, generateCallId })),
    acceptCallV2: services.acceptCallV2 || acceptCallV2,
    declineCallV2: services.declineCallV2 || declineCallV2,
    cancelCallV2: services.cancelCallV2 || cancelCallV2,
    endCallV2: services.endCallV2 || endCallV2,
    reportParticipantMediaV2:
      services.reportParticipantMediaV2 || reportParticipantMediaV2,
    renewActiveCallLeaseV2:
      services.renewActiveCallLeaseV2 || renewActiveCallLeaseV2,
  };
}

function createCallableHandler({
  serviceName,
  service,
  db,
  config,
  nowProvider,
  clientEligibilityService,
  targetEligibilityService,
  targetUserAuth,
  operationalRecorder,
}) {
  return async function guardedCallV2Callable(request) {
    try {
      if (!request || !request.auth || !request.auth.uid) {
        throw mapCallV2ErrorToHttps(
          new CallV2Error(
            ERROR_CODES.unauthenticated,
            "Authentication is required.",
          ),
        );
      }
      if (!resolveBooleanConfig(config, "callV2Enabled")) {
        throw new HttpsError(
          "failed-precondition",
          "Call V2 is disabled.",
          { callV2Code: "call_v2_disabled" },
        );
      }
      if (serviceName === "startCallV2") {
        await requireStartCallRolloutEligibility({
          authUid: request.auth.uid,
          authToken: request.auth.token || {},
          requestData: request.data || {},
          config,
          clientEligibilityService,
          targetEligibilityService,
          targetUserAuth,
          operationalRecorder,
        });
      }
      const result = await service({
        db,
        authUid: request.auth.uid,
        request: request.data || {},
        now: nowProvider(),
      });
      recordCallableOutcome(operationalRecorder, {
        serviceName,
        outcome: "success",
        config,
      });
      return sanitizeClientResult(result);
    } catch (error) {
      const httpsError = mapCallV2ErrorToHttps(error, serviceName);
      recordCallableOutcome(operationalRecorder, {
        serviceName,
        outcome: callableOutcomeForHttpsError(httpsError),
        config,
      });
      throw httpsError;
    }
  };
}

async function requireStartCallRolloutEligibility({
  authUid,
  authToken,
  requestData,
  config,
  clientEligibilityService,
  targetEligibilityService,
  targetUserAuth,
  operationalRecorder,
}) {
  const rolloutPolicy = resolveRolloutPolicy(config);
  const callerEligibility = clientEligibilityService({
    uid: authUid,
    authToken,
    ...rolloutPolicy,
  });
  if (!callerEligibility || callerEligibility.eligible !== true) {
    recordStartRolloutDecision(operationalRecorder, {
      outcome: "denied",
      rolloutMode: rolloutPolicy.mode,
    });
    throw callV2NotEnabledForUserError();
  }
  const calleeUid = requestData && requestData.calleeUid;
  const targetEligibility = await targetEligibilityService({
    uid: calleeUid,
    rolloutPolicy,
    getUser: targetUserAuth && typeof targetUserAuth.getUser === "function"
      ? (uid) => targetUserAuth.getUser(uid)
      : undefined,
  });
  if (!targetEligibility || targetEligibility.eligible !== true) {
    recordStartRolloutDecision(operationalRecorder, {
      outcome: "denied",
      rolloutMode: rolloutPolicy.mode,
    });
    throw callV2NotEnabledForUserError();
  }
  recordStartRolloutDecision(operationalRecorder, {
    outcome: "eligible",
    rolloutMode: rolloutPolicy.mode,
  });
}

function callV2NotEnabledForUserError() {
  return new HttpsError(
    "failed-precondition",
    "Call V2 is not enabled for this user.",
    { callV2Code: "call_v2_not_enabled_for_user" },
  );
}

function mapCallV2ErrorToHttps(error) {
  if (error instanceof HttpsError) {
    return error;
  }
  if (error instanceof CallV2Error) {
    const httpsCode =
      CALL_V2_ERROR_TO_HTTPS[error.code] || CALL_V2_ERROR_TO_HTTPS.transaction_failed;
    return new HttpsError(
      httpsCode,
      "Call V2 request failed.",
      { callV2Code: error.code },
    );
  }
  return new HttpsError(
    "internal",
    "Call V2 request failed.",
    { callV2Code: ERROR_CODES.transactionFailed },
  );
}

function sanitizeClientResult(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => sanitizeClientResult(entry));
  }
  if (!value || typeof value !== "object") {
    return value;
  }
  if (value instanceof Date || typeof value.toDate === "function") {
    return value;
  }
  const privateKeys = new Set(PRIVATE_CLIENT_RESULT_KEYS);
  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => !privateKeys.has(key))
      .map(([key, entry]) => [key, sanitizeClientResult(entry)]),
  );
}

function createConfiguredCloudTasksPublisherV2({
  cloudTasksClient,
  config,
}) {
  const projectId = requireConfigString(config, "tasksProjectId");
  const location = requireConfigString(config, "tasksLocation");
  const queueId = requireConfigString(config, "tasksQueueId");
  const targetUrl = requireConfigString(config, "tasksTargetUrl");
  const serviceAccountEmail = requireConfigString(
    config,
    "tasksServiceAccountEmail",
  );
  const audience = optionalConfigString(config, "tasksAudience");
  return createCloudTasksPublisherV2({
    client: cloudTasksClient,
    projectId,
    location,
    queueId,
    targetUrl,
    serviceAccountEmail,
    audience,
  });
}

async function verifyCloudTasksOidcRequestV2({
  request,
  tokenVerifier,
  config,
}) {
  if (!resolveBooleanConfig(config, "callV2InternalTasksEnabled")) {
    return false;
  }
  if (!tokenVerifier || typeof tokenVerifier.verifyIdToken !== "function") {
    return false;
  }
  const serviceAccountEmail = requireConfigString(
    config,
    "tasksServiceAccountEmail",
  );
  const expectedAudience =
    optionalConfigString(config, "tasksAudience") ||
    requireConfigString(config, "tasksTargetUrl");
  const authorization = headerValue(request && request.headers, "authorization");
  if (!authorization || !authorization.startsWith("Bearer ")) {
    return false;
  }
  const idToken = authorization.slice("Bearer ".length).trim();
  if (!idToken) {
    return false;
  }

  let ticket;
  try {
    ticket = await tokenVerifier.verifyIdToken({
      idToken,
      audience: expectedAudience,
    });
  } catch {
    return false;
  }
  const payload =
    ticket && typeof ticket.getPayload === "function"
      ? ticket.getPayload()
      : ticket && ticket.payload
        ? ticket.payload
        : ticket;
  return Boolean(
    payload &&
      payload.aud === expectedAudience &&
      payload.email === serviceAccountEmail &&
      payload.email_verified === true,
  );
}

function headerValue(headers, name) {
  if (!headers || typeof headers !== "object") {
    return "";
  }
  const direct = headers[name] || headers[name.toLowerCase()] ||
    headers[name.toUpperCase()];
  if (Array.isArray(direct)) {
    return direct[0] || "";
  }
  return typeof direct === "string" ? direct : "";
}

function resolveBooleanConfig(config, key) {
  const value = resolveConfigValue(config, key);
  return value === true || value === "true";
}

function resolveRolloutPolicy(config) {
  return Object.freeze({
    globalEnabled: resolveBooleanConfig(config, "callV2Enabled"),
    mode: optionalConfigString(config, "callV2RolloutMode") || "off",
    percentage: optionalConfigString(config, "callV2RolloutPercentage") || "0",
    salt: optionalConfigString(config, "callV2RolloutSalt"),
    allowlist: optionalConfigString(config, "callV2RolloutAllowlist"),
  });
}

function recordCallableOutcome(operationalRecorder, {
  serviceName,
  outcome,
  config,
}) {
  recordOperationalEvent(operationalRecorder, () => ({
    eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
    outcome,
    fields: {
      callableName: serviceName,
      rolloutMode: serviceName === "startCallV2"
        ? optionalConfigString(config, "callV2RolloutMode") || "off"
        : undefined,
    },
  }));
}

function recordStartRolloutDecision(operationalRecorder, {
  outcome,
  rolloutMode,
}) {
  recordOperationalEvent(operationalRecorder, () => ({
    eventName: OPERATIONAL_EVENT_NAMES.startRolloutDecision,
    outcome,
    fields: {
      rolloutMode,
    },
  }));
}

function recordScheduledRecoveryOutcome(operationalRecorder, outcome, result) {
  recordOperationalEvent(operationalRecorder, () => ({
    eventName: OPERATIONAL_EVENT_NAMES.scheduledRecoveryOutcome,
    outcome,
    fields: {
      examined: result.examined,
      dispatched: result.dispatched,
      alreadyDispatched: result.alreadyDispatched,
      deadLetter: result.deadLetter,
      busy: result.busy,
      retryable: result.retryable,
      stale: result.stale,
      failed: result.failed,
    },
  }));
}

function recordOperationalEvent(operationalRecorder, event) {
  if (
    !operationalRecorder ||
    typeof operationalRecorder.recordOperationalEvent !== "function"
  ) {
    return;
  }
  if (
    typeof operationalRecorder.isEnabled === "function" &&
    !operationalRecorder.isEnabled()
  ) {
    return;
  }
  const resolvedEvent = typeof event === "function" ? event() : event;
  operationalRecorder.recordOperationalEvent(resolvedEvent);
}

function callableOutcomeForHttpsError(error) {
  const callV2Code = error && error.details && error.details.callV2Code;
  if (error && error.code === "unauthenticated") {
    return "unauthenticated";
  }
  if (callV2Code === "call_v2_disabled") {
    return "disabled";
  }
  if (callV2Code === "call_v2_not_enabled_for_user") {
    return "rollout_denied";
  }
  return "failed";
}

function isExpectedOutboxBoundaryError(error) {
  return (
    error instanceof CallV2Error &&
    error.code === ERROR_CODES.transactionFailed &&
    (
      error.message === "Call V2 internal task dispatch is disabled." ||
      error.message.startsWith("Call V2 outbox dispatch requires retry:")
    )
  );
}

function requireConfigString(config, key) {
  const value = optionalConfigString(config, key);
  if (!value) {
    throw new CallV2Error(
      ERROR_CODES.transactionFailed,
      `Missing Call V2 configuration: ${key}.`,
    );
  }
  return value;
}

function optionalConfigString(config, key) {
  const value = resolveConfigValue(config, key);
  if (value === undefined || value === null) {
    return "";
  }
  return `${value}`.trim();
}

function resolveConfigValue(config, key) {
  if (!config || typeof config !== "object") {
    return undefined;
  }
  const value = config[key];
  if (typeof value === "function") {
    return value();
  }
  if (value && typeof value.value === "function") {
    return value.value();
  }
  return value;
}

function generateStrongDispatchClaimToken() {
  return `dispatch_${crypto.randomBytes(24).toString("hex")}`;
}

function generateStrongCallId() {
  return `call_${crypto.randomBytes(20).toString("hex")}`;
}

module.exports = {
  CALLABLE_SERVICE_NAMES,
  CALL_V2_ERROR_TO_HTTPS,
  createCallV2FirebaseWiring,
  createConfiguredCloudTasksPublisherV2,
  generateStrongDispatchClaimToken,
  mapCallV2ErrorToHttps,
  resolveRolloutPolicy,
  sanitizeClientResult,
  verifyCloudTasksOidcRequestV2,
};
