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
  const timeoutHandlerFactory =
    services.createTimeoutTaskHttpHandlerV2 || createTimeoutTaskHttpHandlerV2;

  const callableHandlers = Object.fromEntries(
    CALLABLE_SERVICE_NAMES.map((name) => [
      name,
      createCallableHandler({
        serviceName: name,
        service: domainServices[name],
        db,
        config,
        nowProvider,
      }),
    ]),
  );

  return Object.freeze({
    callableHandlers: Object.freeze(callableHandlers),
    async handleTaskOutboxCreated(event) {
      if (!resolveBooleanConfig(config, "callV2InternalTasksEnabled")) {
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
        return result;
      }
      throw new CallV2Error(
        ERROR_CODES.transactionFailed,
        `Call V2 outbox dispatch requires retry: ${result.status}.`,
      );
    },
    async handleScheduledOutboxRecovery() {
      if (!resolveBooleanConfig(config, "callV2InternalTasksEnabled")) {
        return Object.freeze({
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
      return Object.freeze({
        status: "completed",
        ...result,
      });
    },
    createTimeoutHttpHandler() {
      const normalizedHandler = timeoutHandlerFactory({
        db,
        verifyRequest: (request) =>
          verifyCloudTasksOidcRequestV2({
            request,
            tokenVerifier,
            config,
          }),
        now: nowProvider,
      });
      return async function callV2TimeoutHttpHandler(req, res) {
        const response = await normalizedHandler({
          method: req && req.method,
          body: req && req.body,
          headers: req && req.headers ? req.headers : {},
        });
        return res.status(response.statusCode).json(response.body);
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

function createCallableHandler({ serviceName, service, db, config, nowProvider }) {
  return async function guardedCallV2Callable(request) {
    if (!resolveBooleanConfig(config, "callV2Enabled")) {
      throw new HttpsError(
        "failed-precondition",
        "Call V2 is disabled.",
        { callV2Code: "call_v2_disabled" },
      );
    }
    if (!request || !request.auth || !request.auth.uid) {
      throw mapCallV2ErrorToHttps(
        new CallV2Error(
          ERROR_CODES.unauthenticated,
          "Authentication is required.",
        ),
      );
    }
    try {
      const result = await service({
        db,
        authUid: request.auth.uid,
        request: request.data || {},
        now: nowProvider(),
      });
      return sanitizeClientResult(result);
    } catch (error) {
      throw mapCallV2ErrorToHttps(error, serviceName);
    }
  };
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
  sanitizeClientResult,
  verifyCloudTasksOidcRequestV2,
};
