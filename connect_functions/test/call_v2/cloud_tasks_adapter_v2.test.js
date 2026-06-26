"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  TaskPublisherError,
} = require("../../call_v2/start_call_v2");
const {
  createCloudTasksPublisherV2,
} = require("../../call_v2/cloud_tasks_adapter_v2");

const BASE_CONFIG = Object.freeze({
  projectId: "demo-helperly",
  location: "us-central1",
  queueId: "call-v2-timeouts",
  targetUrl: "https://example.com/internal/call-v2/timeouts",
  serviceAccountEmail:
    "call-v2-timeouts@demo-helperly.iam.gserviceaccount.com",
});
const SCHEDULE_TIME = new Date("2026-06-25T12:00:45.123Z");
const PAYLOAD = Object.freeze({
  callId: "call_1",
  timeoutKind: "ringing",
  expectedCallVersion: 1,
  expectedDeadlineAt: SCHEDULE_TIME,
});

test("Cloud Tasks adapter builds the exact HTTP task request and envelope", async () => {
  const calls = [];
  const externalTaskId = "helperly-call-v2-abc123";
  const fullName =
    `projects/${BASE_CONFIG.projectId}/locations/${BASE_CONFIG.location}` +
    `/queues/${BASE_CONFIG.queueId}/tasks/${externalTaskId}`;
  const publisher = createCloudTasksPublisherV2({
    ...BASE_CONFIG,
    audience: "https://example.com/internal/audience",
    client: {
      async createTask(request) {
        calls.push(request);
        return [{ name: fullName }];
      },
    },
  });

  const result = await publisher.publishTimeoutTask({
    externalTaskId,
    callId: "call_1",
    outboxTaskId: "ringing_timeout_1",
    taskKind: "ringing_timeout",
    scheduleTime: SCHEDULE_TIME,
    payload: PAYLOAD,
  });

  assert.deepEqual(result, {
    outcome: "created",
    externalTaskName: fullName,
  });
  assert.equal(calls.length, 1);
  assert.equal(
    calls[0].parent,
    `projects/${BASE_CONFIG.projectId}/locations/${BASE_CONFIG.location}` +
      `/queues/${BASE_CONFIG.queueId}`,
  );
  assert.equal(calls[0].task.name, fullName);
  assert.equal(calls[0].task.httpRequest.httpMethod, "POST");
  assert.equal(calls[0].task.httpRequest.url, BASE_CONFIG.targetUrl);
  assert.deepEqual(calls[0].task.httpRequest.headers, {
    "Content-Type": "application/json",
    "X-Helperly-Call-System": "v2",
  });
  assert.deepEqual(calls[0].task.httpRequest.oidcToken, {
    serviceAccountEmail: BASE_CONFIG.serviceAccountEmail,
    audience: "https://example.com/internal/audience",
  });
  assert.deepEqual(calls[0].task.scheduleTime, {
    seconds: 1782388845,
    nanos: 123000000,
  });
  assert.deepEqual(
    JSON.parse(calls[0].task.httpRequest.body.toString("utf8")),
    {
      schemaVersion: 1,
      externalTaskId,
      callId: "call_1",
      outboxTaskId: "ringing_timeout_1",
      taskKind: "ringing_timeout",
      payload: {
        ...PAYLOAD,
        expectedDeadlineAt: {
          seconds: 1782388845,
          nanoseconds: 123000000,
        },
      },
    },
  );
});

test("Cloud Tasks adapter normalizes already-exists provider responses", async () => {
  const externalTaskId = "helperly-call-v2-exists";
  const publisher = createCloudTasksPublisherV2({
    ...BASE_CONFIG,
    client: {
      async createTask() {
        const error = new Error("provider text is ignored");
        error.code = 6;
        throw error;
      },
    },
  });

  const result = await publisher.publishTimeoutTask({
    externalTaskId,
    callId: "call_1",
    outboxTaskId: "ringing_timeout_1",
    taskKind: "ringing_timeout",
    scheduleTime: SCHEDULE_TIME,
    payload: PAYLOAD,
  });

  assert.deepEqual(result, {
    outcome: "already_exists",
    externalTaskName:
      `projects/${BASE_CONFIG.projectId}/locations/${BASE_CONFIG.location}` +
      `/queues/${BASE_CONFIG.queueId}/tasks/${externalTaskId}`,
  });
});

test("Cloud Tasks adapter maps provider error codes without message matching", async () => {
  await assertProviderError(14, "cloud_tasks_unavailable", true);
  await assertProviderError("RESOURCE_EXHAUSTED", "cloud_tasks_resource_exhausted", true);
  await assertProviderError(7, "cloud_tasks_permission_denied", false);
  await assertProviderError("FAILED_PRECONDITION", "cloud_tasks_failed_precondition", false);
  await assertProviderError("SOMETHING_NEW", "cloud_tasks_unknown", true);
});

test("Cloud Tasks adapter rejects malformed responses and invalid configuration", async () => {
  const publisher = createCloudTasksPublisherV2({
    ...BASE_CONFIG,
    client: {
      async createTask() {
        return [];
      },
    },
  });
  await assert.rejects(
    () => publisher.publishTimeoutTask({
      externalTaskId: "helperly-call-v2-malformed",
      callId: "call_1",
      outboxTaskId: "ringing_timeout_1",
      taskKind: "ringing_timeout",
      scheduleTime: SCHEDULE_TIME,
      payload: PAYLOAD,
    }),
    (error) =>
      error instanceof TaskPublisherError &&
      error.code === "cloud_tasks_malformed_response" &&
      error.retryable === true,
  );

  assert.throws(
    () => createCloudTasksPublisherV2({
      ...BASE_CONFIG,
      targetUrl: "http://example.com/not-https",
      client: { async createTask() {} },
    }),
    /HTTPS targetUrl/,
  );
  assert.throws(
    () => createCloudTasksPublisherV2({
      ...BASE_CONFIG,
      client: { async createTask() {} },
      accessToken: "not_allowed",
    }),
    /Unsupported configuration field/,
  );
});

async function assertProviderError(providerCode, expectedCode, retryable) {
  const publisher = createCloudTasksPublisherV2({
    ...BASE_CONFIG,
    client: {
      async createTask() {
        const error = new Error("raw provider detail");
        error.code = providerCode;
        throw error;
      },
    },
  });
  await assert.rejects(
    () => publisher.publishTimeoutTask({
      externalTaskId: `helperly-call-v2-${expectedCode}`,
      callId: "call_1",
      outboxTaskId: "ringing_timeout_1",
      taskKind: "ringing_timeout",
      scheduleTime: SCHEDULE_TIME,
      payload: PAYLOAD,
    }),
    (error) =>
      error instanceof TaskPublisherError &&
      error.code === expectedCode &&
      error.retryable === retryable,
  );
}
