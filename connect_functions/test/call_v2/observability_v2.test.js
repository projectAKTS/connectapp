"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  OPERATIONAL_EVENT_NAMES,
  createCallV2OperationalRecorder,
  httpStatusClass,
  normalizeOperationalEvent,
  timeoutOutcomeForStatus,
} = require("../../call_v2/observability_v2");

test("operational event schema allowlists event names, outcomes, and fields", () => {
  assert.deepEqual(
    normalizeOperationalEvent({
      eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
      outcome: "success",
      fields: {
        callableName: "startCallV2",
        rolloutMode: "staff",
        extra: "dropped",
      },
    }),
    {
      schemaVersion: 1,
      eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
      outcome: "success",
      fields: {
        callableName: "startCallV2",
        rolloutMode: "staff",
      },
    },
  );
  assert.equal(
    normalizeOperationalEvent({
      eventName: "call_v2.unknown.v1",
      outcome: "success",
      fields: {},
    }),
    null,
  );
  assert.equal(
    normalizeOperationalEvent({
      eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
      outcome: "unexpected",
      fields: {},
    }),
    null,
  );
});

test("operational event schema drops protected identifiers and sensitive values", () => {
  const normalized = normalizeOperationalEvent({
    eventName: OPERATIONAL_EVENT_NAMES.outboxDispatchOutcome,
    outcome: "dispatched",
    fields: {
      retryable: false,
      uid: "user_1",
      callId: "call_1",
      taskId: "task_1",
      commandId: "command_1",
      channelName: "call_v2_private",
      chatId: "chat_1",
      payload: { secret: true },
      requestBody: { private: true },
      allowlist: "user_1",
      salt: "secret_salt",
      bucket: 1234,
      customClaims: { callV2Staff: true },
      bearerToken: "Bearer abc",
      oidcClaims: { aud: "https://target.example/task" },
      serviceAccountEmail: "tasks@example.iam.gserviceaccount.com",
      targetUrl: "https://target.example/task",
      audience: "https://target.example/task",
      fencingToken: "fence",
      lockClaims: { owner: "private" },
      providerMessage: "provider details",
      stack: "Error: private",
      credentials: "private",
    },
  });

  assert.deepEqual(normalized, {
    schemaVersion: 1,
    eventName: OPERATIONAL_EVENT_NAMES.outboxDispatchOutcome,
    outcome: "dispatched",
    fields: { retryable: false },
  });
  const serialized = JSON.stringify(normalized);
  for (const forbidden of [
    "user_1",
    "call_1",
    "task_1",
    "secret_salt",
    "Bearer",
    "target.example",
    "gserviceaccount",
    "fence",
    "provider details",
  ]) {
    assert.equal(serialized.includes(forbidden), false, forbidden);
  }
});

test("operational event schema rejects oversized, negative, and non-plain values", () => {
  assert.deepEqual(
    normalizeOperationalEvent({
      eventName: OPERATIONAL_EVENT_NAMES.scheduledRecoveryOutcome,
      outcome: "completed",
      fields: {
        examined: 2,
        dispatched: -1,
        alreadyDispatched: 1000001,
        deadLetter: 0,
        busy: 0,
        retryable: "1",
        stale: 0,
        failed: 0,
      },
    }),
    {
      schemaVersion: 1,
      eventName: OPERATIONAL_EVENT_NAMES.scheduledRecoveryOutcome,
      outcome: "completed",
      fields: {
        examined: 2,
        deadLetter: 0,
        busy: 0,
        stale: 0,
        failed: 0,
      },
    },
  );
  assert.deepEqual(
    normalizeOperationalEvent({
      eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
      outcome: "success",
      fields: {
        callableName: "startCallV2".repeat(20),
        rolloutMode: { mode: "staff" },
      },
    }).fields,
    {},
  );
  assert.deepEqual(
    normalizeOperationalEvent({
      eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
      outcome: "success",
      fields: new Date(),
    }).fields,
    {},
  );
});

test("operational recorder is disabled by default and swallows sink failures", () => {
  const disabledEvents = [];
  const disabled = createCallV2OperationalRecorder({
    enabled: false,
    sink: (event) => disabledEvents.push(event),
  });
  assert.equal(disabled.recordOperationalEvent({
    eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
    outcome: "success",
    fields: { callableName: "acceptCallV2" },
  }), false);
  assert.deepEqual(disabledEvents, []);

  const enabled = createCallV2OperationalRecorder({
    enabled: true,
    sink: () => {
      throw new Error("logger unavailable");
    },
  });
  assert.equal(enabled.recordOperationalEvent({
    eventName: OPERATIONAL_EVENT_NAMES.clientCallableOutcome,
    outcome: "success",
    fields: { callableName: "acceptCallV2" },
  }), false);
});

test("HTTP status helpers expose only status class and retry category", () => {
  assert.equal(httpStatusClass(200), "2xx");
  assert.equal(httpStatusClass(401), "4xx");
  assert.equal(httpStatusClass(503), "5xx");
  assert.equal(httpStatusClass(99), "unknown");
  assert.equal(timeoutOutcomeForStatus(200), "success");
  assert.equal(timeoutOutcomeForStatus(401), "unauthorized");
  assert.equal(timeoutOutcomeForStatus(503), "retryable");
  assert.equal(timeoutOutcomeForStatus(404), "failed");
});
