"use strict";

const {
  CallV2Error,
  ERROR_CODES,
  TaskPublisherError,
} = require("./start_call_v2");

const SUPPORTED_TASK_KINDS = Object.freeze([
  "ringing_timeout",
  "accepted_join_timeout",
  "reconnect_timeout",
  "active_lease_timeout",
]);

const RETRYABLE_PROVIDER_CODES = Object.freeze({
  4: "cloud_tasks_deadline_exceeded",
  8: "cloud_tasks_resource_exhausted",
  10: "cloud_tasks_aborted",
  13: "cloud_tasks_internal",
  14: "cloud_tasks_unavailable",
  DEADLINE_EXCEEDED: "cloud_tasks_deadline_exceeded",
  RESOURCE_EXHAUSTED: "cloud_tasks_resource_exhausted",
  ABORTED: "cloud_tasks_aborted",
  INTERNAL: "cloud_tasks_internal",
  UNAVAILABLE: "cloud_tasks_unavailable",
});

const PERMANENT_PROVIDER_CODES = Object.freeze({
  3: "cloud_tasks_invalid_argument",
  5: "cloud_tasks_not_found",
  7: "cloud_tasks_permission_denied",
  9: "cloud_tasks_failed_precondition",
  16: "cloud_tasks_unauthenticated",
  INVALID_ARGUMENT: "cloud_tasks_invalid_argument",
  NOT_FOUND: "cloud_tasks_not_found",
  PERMISSION_DENIED: "cloud_tasks_permission_denied",
  FAILED_PRECONDITION: "cloud_tasks_failed_precondition",
  UNAUTHENTICATED: "cloud_tasks_unauthenticated",
});

function createCloudTasksPublisherV2(config) {
  requireExactKeys(config, [
    "audience",
    "client",
    "location",
    "projectId",
    "queueId",
    "serviceAccountEmail",
    "targetUrl",
  ]);
  const {
    audience,
    client,
    location,
    projectId,
    queueId,
    serviceAccountEmail,
    targetUrl,
  } = config;
  if (!client || typeof client.createTask !== "function") {
    throw invalidConfig("A Cloud Tasks client-compatible dependency is required.");
  }
  requireBoundedIdentifier(projectId, "projectId");
  requireBoundedIdentifier(location, "location");
  requireBoundedIdentifier(queueId, "queueId");
  requireHttpsUrl(targetUrl, "targetUrl");
  requireServiceAccountEmail(serviceAccountEmail);
  if (audience !== undefined) {
    requireHttpsUrl(audience, "audience");
  }

  const parent = `projects/${projectId}/locations/${location}/queues/${queueId}`;

  return Object.freeze({
    async publishTimeoutTask(request) {
      const normalized = validatePublishRequest(request);
      const deterministicFullTaskName = `${parent}/tasks/${normalized.externalTaskId}`;
      const task = {
        name: deterministicFullTaskName,
        httpRequest: {
          httpMethod: "POST",
          url: targetUrl,
          headers: {
            "Content-Type": "application/json",
            "X-Helperly-Call-System": "v2",
          },
          oidcToken: {
            serviceAccountEmail,
            audience: audience || targetUrl,
          },
          body: Buffer.from(JSON.stringify({
            schemaVersion: 1,
            externalTaskId: normalized.externalTaskId,
            callId: normalized.callId,
            outboxTaskId: normalized.outboxTaskId,
            taskKind: normalized.taskKind,
            payload: serializePayloadForEnvelope(normalized.payload),
          }), "utf8"),
        },
        scheduleTime: normalized.scheduleTime,
      };

      try {
        const response = await client.createTask({
          parent,
          task,
        });
        const createdTask = normalizeCreateTaskResponse(response);
        if (createdTask.name !== deterministicFullTaskName) {
          throw new TaskPublisherError({
            code: "cloud_tasks_malformed_response",
            retryable: true,
          });
        }
        return Object.freeze({
          outcome: "created",
          externalTaskName: createdTask.name,
        });
      } catch (error) {
        if (error instanceof TaskPublisherError) {
          throw error;
        }
        if (isAlreadyExistsProviderError(error)) {
          return Object.freeze({
            outcome: "already_exists",
            externalTaskName: deterministicFullTaskName,
          });
        }
        throw normalizeProviderError(error);
      }
    },
  });
}

function validatePublishRequest(request) {
  requireExactKeys(request, [
    "callId",
    "externalTaskId",
    "outboxTaskId",
    "payload",
    "scheduleTime",
    "taskKind",
  ]);
  if (!isTaskNameSegment(request.externalTaskId)) {
    throw invalidConfig("A valid externalTaskId is required.");
  }
  if (!isBoundedIdentifier(request.callId, 160)) {
    throw invalidConfig("A valid callId is required.");
  }
  if (!isBoundedIdentifier(request.outboxTaskId, 220)) {
    throw invalidConfig("A valid outboxTaskId is required.");
  }
  if (!SUPPORTED_TASK_KINDS.includes(request.taskKind)) {
    throw invalidConfig("A supported taskKind is required.");
  }
  if (!request.payload || typeof request.payload !== "object" ||
    Array.isArray(request.payload)) {
    throw invalidConfig("A controlled timeout payload is required.");
  }
  return {
    externalTaskId: request.externalTaskId,
    callId: request.callId,
    outboxTaskId: request.outboxTaskId,
    taskKind: request.taskKind,
    scheduleTime: timestampForCloudTasks(request.scheduleTime),
    payload: request.payload,
  };
}

function timestampForCloudTasks(value) {
  let seconds;
  let nanos;
  if (value instanceof Date) {
    const millis = value.getTime();
    if (!Number.isFinite(millis)) {
      throw invalidConfig("A valid scheduleTime is required.");
    }
    seconds = Math.floor(millis / 1000);
    nanos = (millis % 1000) * 1000000;
  } else if (
    value &&
    Number.isSafeInteger(value.seconds) &&
    Number.isSafeInteger(value.nanoseconds)
  ) {
    seconds = value.seconds;
    nanos = value.nanoseconds;
  } else if (
    value &&
    Number.isSafeInteger(value._seconds) &&
    Number.isSafeInteger(value._nanoseconds)
  ) {
    seconds = value._seconds;
    nanos = value._nanoseconds;
  } else {
    throw invalidConfig("A valid scheduleTime is required.");
  }
  if (!Number.isSafeInteger(seconds) || nanos < 0 || nanos > 999999999) {
    throw invalidConfig("A valid scheduleTime is required.");
  }
  return Object.freeze({
    seconds,
    nanos,
  });
}

function serializePayloadForEnvelope(payload) {
  return Object.fromEntries(
    Object.entries(payload).map(([key, value]) => [
      key,
      serializeEnvelopeValue(value),
    ]),
  );
}

function serializeEnvelopeValue(value) {
  if (value instanceof Date) {
    const millis = value.getTime();
    return {
      seconds: Math.floor(millis / 1000),
      nanoseconds: (millis % 1000) * 1000000,
    };
  }
  if (
    value &&
    Number.isSafeInteger(value.seconds) &&
    Number.isSafeInteger(value.nanoseconds)
  ) {
    return {
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
    };
  }
  if (
    value &&
    Number.isSafeInteger(value._seconds) &&
    Number.isSafeInteger(value._nanoseconds)
  ) {
    return {
      seconds: value._seconds,
      nanoseconds: value._nanoseconds,
    };
  }
  return value;
}

function normalizeCreateTaskResponse(response) {
  if (Array.isArray(response) && response.length === 1) {
    return requireCreatedTaskObject(response[0]);
  }
  if (!Array.isArray(response)) {
    return requireCreatedTaskObject(response);
  }
  throw new TaskPublisherError({
    code: "cloud_tasks_malformed_response",
    retryable: true,
  });
}

function requireCreatedTaskObject(value) {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value) ||
    typeof value.name !== "string"
  ) {
    throw new TaskPublisherError({
      code: "cloud_tasks_malformed_response",
      retryable: true,
    });
  }
  return value;
}

function normalizeProviderError(error) {
  const code = normalizeProviderCode(error && error.code);
  if (RETRYABLE_PROVIDER_CODES[code]) {
    return new TaskPublisherError({
      code: RETRYABLE_PROVIDER_CODES[code],
      retryable: true,
    });
  }
  if (PERMANENT_PROVIDER_CODES[code]) {
    return new TaskPublisherError({
      code: PERMANENT_PROVIDER_CODES[code],
      retryable: false,
    });
  }
  return new TaskPublisherError({
    code: "cloud_tasks_unknown",
    retryable: true,
  });
}

function isAlreadyExistsProviderError(error) {
  const code = normalizeProviderCode(error && error.code);
  return code === 6 || code === "ALREADY_EXISTS";
}

function normalizeProviderCode(code) {
  if (typeof code === "number") {
    return code;
  }
  if (typeof code === "string") {
    return code.trim().replace(/-/g, "_").toUpperCase();
  }
  return null;
}

function requireExactKeys(value, expectedKeys) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw invalidConfig("A configuration object is required.");
  }
  const allowed = new Set(expectedKeys);
  for (const key of Object.keys(value)) {
    if (!allowed.has(key)) {
      throw invalidConfig(`Unsupported configuration field: ${key}.`);
    }
  }
  for (const key of expectedKeys) {
    if (key === "audience") {
      continue;
    }
    if (!Object.prototype.hasOwnProperty.call(value, key)) {
      throw invalidConfig(`Missing configuration field: ${key}.`);
    }
  }
}

function requireBoundedIdentifier(value, label) {
  if (!isBoundedIdentifier(value, 160)) {
    throw invalidConfig(`A valid ${label} is required.`);
  }
}

function isBoundedIdentifier(value, maxLength) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= maxLength &&
    value.trim() === value &&
    /^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(value)
  );
}

function isTaskNameSegment(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 500 &&
    value.trim() === value &&
    /^[A-Za-z0-9_-]+$/.test(value)
  );
}

function requireHttpsUrl(value, label) {
  try {
    const parsed = new URL(value);
    if (parsed.protocol !== "https:" || !parsed.hostname) {
      throw new Error("not https");
    }
  } catch {
    throw invalidConfig(`A valid HTTPS ${label} is required.`);
  }
}

function requireServiceAccountEmail(value) {
  if (
    typeof value !== "string" ||
    value.length > 254 ||
    !/^[A-Za-z0-9._-]+@[A-Za-z0-9-]+\.iam\.gserviceaccount\.com$/.test(value)
  ) {
    throw invalidConfig("A valid serviceAccountEmail is required.");
  }
}

function invalidConfig(message) {
  return new CallV2Error(ERROR_CODES.invalidArgument, message);
}

module.exports = {
  createCloudTasksPublisherV2,
};
