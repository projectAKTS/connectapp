"use strict";

const {
  CallV2Error,
  ERROR_CODES,
  dispatchTaskOutboxV2,
} = require("./start_call_v2");

const RECOVERABLE_OUTBOX_STATUSES = Object.freeze([
  "pending",
  "dispatching",
]);
const TASK_OUTBOX_RECOVERY_MAX_LIMIT = 100;
const TASK_OUTBOX_RECOVERY_DEFAULT_LIMIT = 25;

async function recoverPendingTaskOutboxV2({
  db,
  now,
  limit = TASK_OUTBOX_RECOVERY_DEFAULT_LIMIT,
  dispatchTask = dispatchTaskOutboxV2,
  generateClaimToken,
  publisher,
}) {
  if (!db || typeof db.collectionGroup !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A Firestore database dependency is required.",
    );
  }
  if (typeof dispatchTask !== "function") {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A task dispatcher dependency is required.",
    );
  }
  const boundedLimit = validateRecoveryLimit(limit);
  const counts = emptyRecoveryCounts();

  for (const status of RECOVERABLE_OUTBOX_STATUSES) {
    const remaining = boundedLimit - counts.examined;
    if (remaining <= 0) {
      break;
    }
    const snapshot = await db
      .collectionGroup("taskOutbox")
      .where("status", "==", status)
      .orderBy("updatedAt", "asc")
      .limit(remaining)
      .get();
    for (const doc of snapshot.docs) {
      counts.examined += 1;
      try {
        const taskRef = doc.ref;
        const callRef = taskRef.parent && taskRef.parent.parent;
        const callId = callRef && callRef.id;
        const taskId = taskRef.id;
        if (!callId || !taskId) {
          counts.failed += 1;
          continue;
        }
        const result = await dispatchTask({
          db,
          request: {
            callId,
            taskId,
          },
          now,
          generateClaimToken,
          publisher,
        });
        incrementRecoveryCount(counts, result && result.status);
      } catch {
        counts.failed += 1;
      }
    }
  }

  return Object.freeze(counts);
}

function validateCallV2DeploymentConfig({
  clientEnabled,
  internalTasksEnabled,
  region,
  projectId,
  location,
  queueId,
  targetUrl,
  serviceAccountEmail,
  audience,
}) {
  const client = clientEnabled === true;
  const internal = internalTasksEnabled === true;
  if (client && !internal) {
    throw readinessError(
      "Client Call V2 cannot be enabled while internal task processing is disabled.",
    );
  }

  if (!client && !internal) {
    return Object.freeze({
      status: "code_only_ready",
      clientEnabled: false,
      internalTasksEnabled: false,
      taskConfigRequired: false,
      sanitizedConfig: emptySanitizedConfig(),
    });
  }

  requireBoundedIdentifier(region, "region");
  requireBoundedIdentifier(projectId, "projectId");
  requireBoundedIdentifier(location, "location");
  requireBoundedIdentifier(queueId, "queueId");
  requireHttpsUrl(targetUrl, "targetUrl");
  requireHttpsUrl(audience, "audience");
  requireServiceAccountEmail(serviceAccountEmail);

  return Object.freeze({
    status: client ? "client_and_internal_ready" : "internal_only_ready",
    clientEnabled: client,
    internalTasksEnabled: internal,
    taskConfigRequired: true,
    sanitizedConfig: Object.freeze({
      regionConfigured: true,
      projectIdConfigured: true,
      locationConfigured: true,
      queueIdConfigured: true,
      targetUrlConfigured: true,
      serviceAccountEmailConfigured: true,
      audienceConfigured: true,
    }),
  });
}

function emptyRecoveryCounts() {
  return {
    examined: 0,
    dispatched: 0,
    alreadyDispatched: 0,
    deadLetter: 0,
    busy: 0,
    retryable: 0,
    stale: 0,
    failed: 0,
  };
}

function incrementRecoveryCount(counts, status) {
  if (status === "dispatched") {
    counts.dispatched += 1;
  } else if (status === "already_dispatched") {
    counts.alreadyDispatched += 1;
  } else if (status === "dead_letter") {
    counts.deadLetter += 1;
  } else if (status === "busy") {
    counts.busy += 1;
  } else if (status === "retryable") {
    counts.retryable += 1;
  } else if (status === "stale") {
    counts.stale += 1;
  } else {
    counts.failed += 1;
  }
}

function validateRecoveryLimit(limit) {
  if (!Number.isSafeInteger(limit) || limit <= 0) {
    throw new CallV2Error(
      ERROR_CODES.invalidArgument,
      "A positive recovery limit is required.",
    );
  }
  return Math.min(limit, TASK_OUTBOX_RECOVERY_MAX_LIMIT);
}

function requireBoundedIdentifier(value, label) {
  if (!isBoundedIdentifier(value)) {
    throw readinessError(`A valid ${label} is required.`);
  }
}

function requireHttpsUrl(value, label) {
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== "https:" || !parsed.hostname) {
      throw new Error("not https");
    }
  } catch {
    throw readinessError(`A valid HTTPS ${label} is required.`);
  }
}

function requireServiceAccountEmail(value) {
  if (
    typeof value !== "string" ||
    value.length > 254 ||
    !/^[A-Za-z0-9._-]+@[A-Za-z0-9-]+\.iam\.gserviceaccount\.com$/.test(value)
  ) {
    throw readinessError("A valid serviceAccountEmail is required.");
  }
}

function isBoundedIdentifier(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 160 &&
    value.trim() === value &&
    /^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(value)
  );
}

function readinessError(message) {
  return new CallV2Error(ERROR_CODES.invalidArgument, message);
}

function emptySanitizedConfig() {
  return Object.freeze({
    regionConfigured: false,
    projectIdConfigured: false,
    locationConfigured: false,
    queueIdConfigured: false,
    targetUrlConfigured: false,
    serviceAccountEmailConfigured: false,
    audienceConfigured: false,
  });
}

module.exports = {
  RECOVERABLE_OUTBOX_STATUSES,
  TASK_OUTBOX_RECOVERY_DEFAULT_LIMIT,
  TASK_OUTBOX_RECOVERY_MAX_LIMIT,
  recoverPendingTaskOutboxV2,
  validateCallV2DeploymentConfig,
};
