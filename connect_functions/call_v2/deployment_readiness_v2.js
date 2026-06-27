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
  const candidates = await selectRecoveryCandidates({ db, limit: boundedLimit });

  for (const doc of candidates) {
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

  return Object.freeze(counts);
}

async function selectRecoveryCandidates({ db, limit }) {
  const snapshots = {};
  for (const status of RECOVERABLE_OUTBOX_STATUSES) {
    snapshots[status] = await queryRecoveryStatus({ db, status, limit });
  }

  if (limit === 1) {
    return oldestCandidates(uniqueCandidateDocs([
      ...snapshots.pending,
      ...snapshots.dispatching,
    ])).slice(0, 1);
  }

  const pendingBudget = Math.ceil(limit / 2);
  const dispatchingBudget = Math.floor(limit / 2);
  const selected = [];
  const selectedPaths = new Set();

  appendCandidateDocs({
    target: selected,
    selectedPaths,
    docs: snapshots.pending,
    count: pendingBudget,
  });
  appendCandidateDocs({
    target: selected,
    selectedPaths,
    docs: snapshots.dispatching,
    count: dispatchingBudget,
  });

  const remaining = limit - selected.length;
  if (remaining > 0) {
    appendCandidateDocs({
      target: selected,
      selectedPaths,
      docs: oldestCandidates([
        ...snapshots.pending,
        ...snapshots.dispatching,
      ]),
      count: remaining,
    });
  }

  return selected.slice(0, limit);
}

async function queryRecoveryStatus({ db, status, limit }) {
  const snapshot = await db
    .collectionGroup("taskOutbox")
    .where("status", "==", status)
    .orderBy("updatedAt", "asc")
    .limit(limit)
    .get();
  return oldestCandidates(snapshot.docs || []);
}

function appendCandidateDocs({ target, selectedPaths, docs, count }) {
  let added = 0;
  for (const doc of docs) {
    if (added >= count) {
      break;
    }
    const path = taskDocumentPath(doc);
    if (selectedPaths.has(path)) {
      continue;
    }
    selectedPaths.add(path);
    target.push(doc);
    added += 1;
  }
}

function uniqueCandidateDocs(docs) {
  const selectedPaths = new Set();
  const unique = [];
  for (const doc of docs) {
    const path = taskDocumentPath(doc);
    if (selectedPaths.has(path)) {
      continue;
    }
    selectedPaths.add(path);
    unique.push(doc);
  }
  return unique;
}

function oldestCandidates(docs) {
  return [...docs].sort((left, right) => {
    const timeComparison =
      candidateUpdatedAtMillis(left) - candidateUpdatedAtMillis(right);
    if (timeComparison !== 0) {
      return timeComparison;
    }
    return taskDocumentPath(left).localeCompare(taskDocumentPath(right));
  });
}

function candidateUpdatedAtMillis(doc) {
  const data = typeof doc.data === "function" ? doc.data() : {};
  const updatedAt = data && data.updatedAt;
  if (updatedAt && typeof updatedAt.toMillis === "function") {
    return updatedAt.toMillis();
  }
  if (updatedAt instanceof Date) {
    return updatedAt.getTime();
  }
  if (updatedAt && Number.isSafeInteger(updatedAt.seconds)) {
    const nanos = Number.isSafeInteger(updatedAt.nanoseconds)
      ? updatedAt.nanoseconds
      : 0;
    return (updatedAt.seconds * 1000) + Math.floor(nanos / 1000000);
  }
  if (typeof updatedAt === "number" && Number.isFinite(updatedAt)) {
    return updatedAt;
  }
  return Number.POSITIVE_INFINITY;
}

function taskDocumentPath(doc) {
  if (doc.ref && typeof doc.ref.path === "string") {
    return doc.ref.path;
  }
  const taskRef = doc.ref || {};
  const taskId = taskRef.id || "";
  const callRef = taskRef.parent && taskRef.parent.parent;
  const callId = callRef && callRef.id ? callRef.id : "";
  return `callOps/${callId}/taskOutbox/${taskId}`;
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
  allowDistinctAudience = false,
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
  requireAudienceConsistency({
    targetUrl,
    audience,
    allowDistinctAudience,
  });
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
      distinctAudienceApproved: allowDistinctAudience === true,
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

function requireAudienceConsistency({
  targetUrl,
  audience,
  allowDistinctAudience,
}) {
  if (allowDistinctAudience !== true && audience !== targetUrl) {
    throw readinessError(
      "OIDC audience must match targetUrl unless explicitly approved.",
    );
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
    distinctAudienceApproved: false,
  });
}

module.exports = {
  RECOVERABLE_OUTBOX_STATUSES,
  TASK_OUTBOX_RECOVERY_DEFAULT_LIMIT,
  TASK_OUTBOX_RECOVERY_MAX_LIMIT,
  recoverPendingTaskOutboxV2,
  validateCallV2DeploymentConfig,
};
