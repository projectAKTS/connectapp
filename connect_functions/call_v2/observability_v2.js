"use strict";

const SCHEMA_VERSION = 1;

const OPERATIONAL_EVENT_NAMES = Object.freeze({
  clientCallableOutcome: "call_v2.client_callable_outcome.v1",
  startRolloutDecision: "call_v2.start_rollout_decision.v1",
  outboxDispatchOutcome: "call_v2.outbox_dispatch_outcome.v1",
  scheduledRecoveryOutcome: "call_v2.scheduled_recovery_outcome.v1",
  timeoutHttpOutcome: "call_v2.timeout_http_outcome.v1",
});

const EVENT_DEFINITIONS = Object.freeze({
  [OPERATIONAL_EVENT_NAMES.clientCallableOutcome]: Object.freeze({
    outcomes: new Set([
      "success",
      "unauthenticated",
      "disabled",
      "rollout_denied",
      "failed",
    ]),
    fields: Object.freeze({
      callableName: enumField([
        "startCallV2",
        "acceptCallV2",
        "declineCallV2",
        "cancelCallV2",
        "endCallV2",
        "reportParticipantMediaV2",
        "renewActiveCallLeaseV2",
      ]),
      rolloutMode: enumField(["off", "staff", "allowlist", "percentage", "all"]),
    }),
  }),
  [OPERATIONAL_EVENT_NAMES.startRolloutDecision]: Object.freeze({
    outcomes: new Set(["eligible", "denied"]),
    fields: Object.freeze({
      rolloutMode: enumField(["off", "staff", "allowlist", "percentage", "all"]),
    }),
  }),
  [OPERATIONAL_EVENT_NAMES.outboxDispatchOutcome]: Object.freeze({
    outcomes: new Set([
      "dispatched",
      "already_dispatched",
      "dead_letter",
      "retry_required",
      "disabled",
      "failed",
    ]),
    fields: Object.freeze({
      retryable: booleanField(),
    }),
  }),
  [OPERATIONAL_EVENT_NAMES.scheduledRecoveryOutcome]: Object.freeze({
    outcomes: new Set(["disabled", "completed", "failed"]),
    fields: Object.freeze({
      examined: counterField(),
      dispatched: counterField(),
      alreadyDispatched: counterField(),
      deadLetter: counterField(),
      busy: counterField(),
      retryable: counterField(),
      stale: counterField(),
      failed: counterField(),
    }),
  }),
  [OPERATIONAL_EVENT_NAMES.timeoutHttpOutcome]: Object.freeze({
    outcomes: new Set(["success", "unauthorized", "retryable", "failed"]),
    fields: Object.freeze({
      httpStatusClass: enumField(["2xx", "3xx", "4xx", "5xx", "unknown"]),
      verificationResult: enumField(["authorized", "unauthorized", "not_checked"]),
      retryable: booleanField(),
    }),
  }),
});

const PROHIBITED_FIELD_NAMES = new Set([
  "uid",
  "authUid",
  "callerUid",
  "calleeUid",
  "callId",
  "taskId",
  "commandId",
  "channelName",
  "agoraChannel",
  "chatId",
  "payload",
  "requestBody",
  "allowlist",
  "allowlistEntry",
  "salt",
  "rolloutSalt",
  "bucket",
  "rolloutBucket",
  "customClaims",
  "claims",
  "bearerToken",
  "authorization",
  "idToken",
  "oidcClaims",
  "serviceAccountEmail",
  "email",
  "targetUrl",
  "audience",
  "fencingToken",
  "lockClaims",
  "providerMessage",
  "stack",
  "stackTrace",
  "credentials",
]);

function createCallV2OperationalRecorder({ enabled = false, sink } = {}) {
  const resolvedSink = sink || createConsoleOperationalEventSink();
  return Object.freeze({
    isEnabled() {
      return resolveEnabled(enabled);
    },
    recordOperationalEvent(event) {
      if (!resolveEnabled(enabled)) {
        return false;
      }
      const normalized = normalizeOperationalEvent(event);
      if (!normalized) {
        return false;
      }
      try {
        if (
          resolvedSink &&
          typeof resolvedSink.recordOperationalEvent === "function"
        ) {
          resolvedSink.recordOperationalEvent(normalized);
        } else if (typeof resolvedSink === "function") {
          resolvedSink(normalized);
        }
        return true;
      } catch {
        return false;
      }
    },
  });
}

function createConsoleOperationalEventSink({ logger = console } = {}) {
  return Object.freeze({
    recordOperationalEvent(event) {
      const write = event.outcome === "failed" ||
          event.outcome === "unauthorized" ||
          event.outcome === "retry_required" ||
          event.outcome === "retryable"
        ? logger.warn
        : logger.info;
      if (typeof write === "function") {
        write.call(logger, event);
      }
    },
  });
}

function normalizeOperationalEvent(event) {
  if (!isPlainObject(event)) {
    return null;
  }
  const eventName = boundedString(event.eventName);
  const outcome = boundedString(event.outcome);
  const definition = EVENT_DEFINITIONS[eventName];
  if (!definition || !definition.outcomes.has(outcome)) {
    return null;
  }
  const fields = normalizeFields({
    allowedFields: definition.fields,
    fields: event.fields,
  });
  return Object.freeze({
    schemaVersion: SCHEMA_VERSION,
    eventName,
    outcome,
    fields: Object.freeze(fields),
  });
}

function normalizeFields({ allowedFields, fields }) {
  if (!isPlainObject(fields)) {
    return {};
  }
  const normalized = {};
  for (const [key, value] of Object.entries(fields)) {
    if (PROHIBITED_FIELD_NAMES.has(key)) {
      continue;
    }
    const validator = allowedFields[key];
    if (!validator) {
      continue;
    }
    const normalizedValue = validator(value);
    if (normalizedValue !== undefined) {
      normalized[key] = normalizedValue;
    }
  }
  return normalized;
}

function enumField(values) {
  const allowed = new Set(values);
  return (value) => {
    const stringValue = boundedString(value);
    return allowed.has(stringValue) ? stringValue : undefined;
  };
}

function booleanField() {
  return (value) => typeof value === "boolean" ? value : undefined;
}

function counterField() {
  return (value) =>
    Number.isSafeInteger(value) && value >= 0 && value <= 1000000
      ? value
      : undefined;
}

function boundedString(value) {
  if (typeof value !== "string") {
    return "";
  }
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > 80) {
    return "";
  }
  return trimmed;
}

function resolveEnabled(enabled) {
  try {
    if (typeof enabled === "function") {
      return enabled() === true;
    }
    return enabled === true;
  } catch {
    return false;
  }
}

function httpStatusClass(statusCode) {
  if (!Number.isInteger(statusCode) || statusCode < 100 || statusCode > 599) {
    return "unknown";
  }
  return `${Math.floor(statusCode / 100)}xx`;
}

function timeoutOutcomeForStatus(statusCode) {
  if (statusCode === 401 || statusCode === 403) {
    return "unauthorized";
  }
  if (statusCode >= 200 && statusCode < 400) {
    return "success";
  }
  if (statusCode >= 500 && statusCode < 600) {
    return "retryable";
  }
  return "failed";
}

function isPlainObject(value) {
  if (!value || typeof value !== "object") {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

module.exports = {
  OPERATIONAL_EVENT_NAMES,
  SCHEMA_VERSION,
  createCallV2OperationalRecorder,
  createConsoleOperationalEventSink,
  httpStatusClass,
  normalizeOperationalEvent,
  timeoutOutcomeForStatus,
};
