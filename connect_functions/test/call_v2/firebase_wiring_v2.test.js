"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const { HttpsError } = require("firebase-functions/v2/https");

const {
  CallV2Error,
  ERROR_CODES,
} = require("../../call_v2/start_call_v2");
const {
  CALLABLE_SERVICE_NAMES,
  CALL_V2_ERROR_TO_HTTPS,
  createCallV2FirebaseWiring,
  createConfiguredCloudTasksPublisherV2,
  verifyCloudTasksOidcRequestV2,
} = require("../../call_v2/firebase_wiring_v2");

const FIXED_NOW = new Date("2026-06-25T12:00:00.000Z");

test("callable kill switch rejects before domain invocation", async () => {
  let invoked = false;
  const wiring = createCallV2FirebaseWiring({
    db: {},
    config: config({ callV2Enabled: false }),
    now: () => FIXED_NOW,
    services: {
      async startCallV2() {
        invoked = true;
      },
    },
  });

  await assertHttpsError(
    "failed-precondition",
    "call_v2_disabled",
    () => wiring.callableHandlers.startCallV2({
      auth: { uid: "caller" },
      data: {},
    }),
  );
  assert.equal(invoked, false);
});

test("callables require auth and use context UID instead of request UID", async () => {
  const calls = [];
  const wiring = createCallV2FirebaseWiring({
    db: { marker: "db" },
    config: config(),
    now: () => FIXED_NOW,
    services: {
      async startCallV2(args) {
        calls.push(args);
        return {
          callId: "call_1",
          callerUid: args.authUid,
          taskId: "private_task",
          lockReleaseResults: { caller: "private" },
        };
      },
    },
  });

  await assertHttpsError(
    "unauthenticated",
    ERROR_CODES.unauthenticated,
    () => wiring.callableHandlers.startCallV2({ data: {} }),
  );

  const result = await wiring.callableHandlers.startCallV2({
    auth: { uid: "auth_uid" },
    data: { callerUid: "request_uid", idempotencyKey: "idem" },
  });

  assert.equal(calls.length, 1);
  assert.deepEqual(Object.keys(calls[0]).sort(), [
    "authUid",
    "db",
    "now",
    "request",
  ]);
  assert.equal(calls[0].authUid, "auth_uid");
  assert.equal(calls[0].request.callerUid, "request_uid");
  assert.equal(calls[0].now instanceof Date, true);
  assert.equal(result.callId, "call_1");
  assert.equal(result.callerUid, "auth_uid");
  assert.equal(result.taskId, undefined);
  assert.equal(result.lockReleaseResults, undefined);
});

test("all seven callables route to the matching service", async () => {
  const routed = [];
  const services = Object.fromEntries(
    CALLABLE_SERVICE_NAMES.map((name) => [
      name,
      async (args) => {
        routed.push([name, args.authUid, args.request.marker]);
        return { route: name };
      },
    ]),
  );
  const wiring = createCallV2FirebaseWiring({
    db: {},
    config: config(),
    now: () => FIXED_NOW,
    services,
  });

  for (const name of CALLABLE_SERVICE_NAMES) {
    const result = await wiring.callableHandlers[name]({
      auth: { uid: "actor" },
      data: { marker: name },
    });
    assert.deepEqual(result, { route: name });
  }
  assert.deepEqual(
    routed,
    CALLABLE_SERVICE_NAMES.map((name) => [name, "actor", name]),
  );
});

test("callable error mapping is stable and hides raw errors", async () => {
  for (const [callV2Code, httpsCode] of Object.entries(
    CALL_V2_ERROR_TO_HTTPS,
  )) {
    const wiring = createCallV2FirebaseWiring({
      db: {},
      config: config(),
      now: () => FIXED_NOW,
      services: {
        async startCallV2() {
          throw new CallV2Error(callV2Code, "raw internal message", {
            path: "callOps/private",
          });
        },
      },
    });
    await assertHttpsError(
      httpsCode,
      callV2Code,
      () => wiring.callableHandlers.startCallV2({
        auth: { uid: "caller" },
        data: {},
      }),
    );
  }

  const wiring = createCallV2FirebaseWiring({
    db: {},
    config: config(),
    now: () => FIXED_NOW,
    services: {
      async startCallV2() {
        throw new Error("raw stack");
      },
    },
  });
  await assertHttpsError(
    "internal",
    ERROR_CODES.transactionFailed,
    () => wiring.callableHandlers.startCallV2({
      auth: { uid: "caller" },
      data: {},
    }),
  );
});

test("callable handler set excludes internal timeout and dispatch services", () => {
  const wiring = createCallV2FirebaseWiring({
    db: {},
    config: config(),
    now: () => FIXED_NOW,
    services: {},
  });
  assert.deepEqual(
    Object.keys(wiring.callableHandlers).sort(),
    [...CALLABLE_SERVICE_NAMES].sort(),
  );
  for (const forbidden of [
    "processCallTimeoutV2",
    "processActiveLeaseTimeoutV2",
    "dispatchTaskOutboxV2",
    "claimTaskOutboxDispatchV2",
    "finalizeTaskOutboxDispatchSuccessV2",
    "finalizeTaskOutboxDispatchFailureV2",
    "acknowledgeTimeoutTaskExecutionV2",
    "recordTimeoutTaskExecutionFailureV2",
    "executeTimeoutTaskEnvelopeV2",
  ]) {
    assert.equal(wiring.callableHandlers[forbidden], undefined);
  }
});

test("internal OIDC verifier rejects missing, malformed, and mismatched auth", async () => {
  assert.equal(
    await verifyCloudTasksOidcRequestV2({
      request: { headers: {} },
      tokenVerifier: verifierFor(payload()),
      config: config(),
    }),
    false,
  );
  assert.equal(
    await verifyCloudTasksOidcRequestV2({
      request: { headers: { authorization: "Basic abc" } },
      tokenVerifier: verifierFor(payload()),
      config: config(),
    }),
    false,
  );
  assert.equal(
    await verifyCloudTasksOidcRequestV2({
      request: { headers: { authorization: "Bearer token" } },
      tokenVerifier: {
        async verifyIdToken() {
          throw new Error("invalid");
        },
      },
      config: config(),
    }),
    false,
  );
  assert.equal(
    await verifyCloudTasksOidcRequestV2({
      request: { headers: { authorization: "Bearer token" } },
      tokenVerifier: verifierFor(payload({ aud: "https://wrong.example" })),
      config: config(),
    }),
    false,
  );
  assert.equal(
    await verifyCloudTasksOidcRequestV2({
      request: { headers: { authorization: "Bearer token" } },
      tokenVerifier: verifierFor(payload({ email: "wrong@example.com" })),
      config: config(),
    }),
    false,
  );
  assert.equal(
    await verifyCloudTasksOidcRequestV2({
      request: { headers: { authorization: "Bearer token" } },
      tokenVerifier: verifierFor(payload({ email_verified: false })),
      config: config(),
    }),
    false,
  );
});

test("internal OIDC verifier accepts only the configured service account audience", async () => {
  const calls = [];
  const ok = await verifyCloudTasksOidcRequestV2({
    request: { headers: { authorization: "Bearer token" } },
    tokenVerifier: {
      async verifyIdToken(request) {
        calls.push(request);
        return { getPayload: () => payload() };
      },
    },
    config: config(),
  });
  assert.equal(ok, true);
  assert.deepEqual(calls, [{
    idToken: "token",
    audience: "https://tasks.example/internal",
  }]);
});

test("dispatcher trigger is fail-closed when disabled and uses trusted params when enabled", async () => {
  let dispatchCalls = 0;
  const disabled = createCallV2FirebaseWiring({
    db: {},
    config: config({ callV2InternalTasksEnabled: false }),
    now: () => FIXED_NOW,
    services: {
      async dispatchTaskOutboxV2() {
        dispatchCalls += 1;
      },
    },
  });
  await assert.rejects(
    () => disabled.handleTaskOutboxCreated({
      params: { callId: "call_1", taskId: "task_1" },
    }),
    (error) =>
      error instanceof CallV2Error &&
      error.code === ERROR_CODES.transactionFailed,
  );
  assert.equal(dispatchCalls, 0);

  const dispatchRequests = [];
  const enabled = createCallV2FirebaseWiring({
    db: { publicState: "unchanged" },
    config: config(),
    now: () => FIXED_NOW,
    services: {
      createCloudTasksPublisher() {
        return { publishTimeoutTask: async () => ({}) };
      },
      async dispatchTaskOutboxV2(request) {
        dispatchRequests.push(request);
        const claimToken = request.generateClaimToken();
        assert.match(claimToken, /^dispatch_[a-f0-9]{48}$/);
        return { status: "dispatched" };
      },
    },
  });
  const result = await enabled.handleTaskOutboxCreated({
    params: { callId: "trusted_call", taskId: "trusted_task" },
    data: {
      callId: "untrusted_call",
      taskId: "untrusted_task",
      payload: { uid: "must_not_be_used" },
    },
  });
  assert.equal(result.status, "dispatched");
  assert.equal(dispatchRequests.length, 1);
  assert.deepEqual(dispatchRequests[0].request, {
    callId: "trusted_call",
    taskId: "trusted_task",
  });
});

test("dispatcher trigger success and retry classifications are stable", async () => {
  for (const status of ["dispatched", "already_dispatched", "dead_letter"]) {
    const wiring = triggerWiringReturning(status);
    assert.equal(
      (await wiring.handleTaskOutboxCreated(eventParams())).status,
      status,
    );
  }
  for (const status of ["retryable", "busy", "stale"]) {
    const wiring = triggerWiringReturning(status);
    await assert.rejects(
      () => wiring.handleTaskOutboxCreated(eventParams()),
      (error) =>
        error instanceof CallV2Error &&
        error.code === ERROR_CODES.transactionFailed &&
        error.message.includes(status),
    );
  }
});

test("Cloud Tasks production factory forwards controlled configuration", async () => {
  const calls = [];
  const publisher = createConfiguredCloudTasksPublisherV2({
    cloudTasksClient: {
      async createTask(request) {
        calls.push(request);
        return [{ name: request.task.name }];
      },
    },
    config: config(),
  });
  const result = await publisher.publishTimeoutTask({
    externalTaskId: "helperly-call-v2-factory",
    callId: "call_1",
    outboxTaskId: "task_1",
    taskKind: "ringing_timeout",
    scheduleTime: FIXED_NOW,
    payload: {
      callId: "call_1",
      timeoutKind: "ringing",
      expectedCallVersion: 1,
      expectedDeadlineAt: FIXED_NOW,
    },
  });
  assert.equal(result.outcome, "created");
  assert.equal(calls.length, 1);
  assert.equal(calls[0].task.httpRequest.url, "https://target.example/task");
  assert.deepEqual(calls[0].task.httpRequest.oidcToken, {
    serviceAccountEmail:
      "tasks@demo-helperly.iam.gserviceaccount.com",
    audience: "https://tasks.example/internal",
  });

  let createTaskCalled = false;
  assert.throws(
    () => createConfiguredCloudTasksPublisherV2({
      cloudTasksClient: {
        async createTask() {
          createTaskCalled = true;
        },
      },
      config: config({ tasksQueueId: "" }),
    }),
    /Missing Call V2 configuration: tasksQueueId/,
  );
  assert.equal(createTaskCalled, false);
});

test("HTTP adapter forwards normalized request and preserves retry status", async () => {
  const normalizedRequests = [];
  const wiring = createCallV2FirebaseWiring({
    db: {},
    config: config(),
    now: () => FIXED_NOW,
    tokenVerifier: verifierFor(payload()),
    services: {
      createTimeoutTaskHttpHandlerV2({ verifyRequest }) {
        return async (request) => {
          normalizedRequests.push(request);
          const verified = await verifyRequest(request);
          if (!verified) {
            return { statusCode: 401, body: { errorCode: "unauthorized" } };
          }
          return { statusCode: 503, body: { errorCode: "timeout_not_due" } };
        };
      },
    },
  });
  const response = fakeResponse();
  await wiring.createTimeoutHttpHandler()(
    {
      method: "POST",
      body: { schemaVersion: 1 },
      headers: { authorization: "Bearer token" },
    },
    response,
  );
  assert.deepEqual(normalizedRequests, [{
    method: "POST",
    body: { schemaVersion: 1 },
    headers: { authorization: "Bearer token" },
  }]);
  assert.deepEqual(response.writes, [{
    statusCode: 503,
    body: { errorCode: "timeout_not_due" },
  }]);
});

test("HTTP adapter unauthorized path verifies before execution", async () => {
  let executed = false;
  const wiring = createCallV2FirebaseWiring({
    db: {},
    config: config(),
    now: () => FIXED_NOW,
    tokenVerifier: {
      async verifyIdToken() {
        throw new Error("bad token");
      },
    },
    services: {
      createTimeoutTaskHttpHandlerV2({ verifyRequest }) {
        return async (request) => {
          if (!(await verifyRequest(request))) {
            return { statusCode: 401, body: { errorCode: "unauthorized" } };
          }
          executed = true;
          return { statusCode: 200, body: { status: "acknowledged" } };
        };
      },
    },
  });
  const response = fakeResponse();
  await wiring.createTimeoutHttpHandler()(
    {
      method: "POST",
      body: { schemaVersion: 1 },
      headers: { authorization: "Bearer token" },
    },
    response,
  );
  assert.equal(executed, false);
  assert.deepEqual(response.writes, [{
    statusCode: 401,
    body: { errorCode: "unauthorized" },
  }]);
});

test("index exports preserve legacy functions and expose no internal V2 services", () => {
  const exported = require("../../index");
  for (const legacy of [
    "createStripeCustomer",
    "createSetupIntent",
    "listPaymentMethods",
    "setDefaultPaymentMethod",
    "removePaymentMethod",
    "cancelConsultation",
    "chargeStoredPaymentMethod",
    "createExpressAccountLink",
    "createStripeCheckoutSession",
    "handleStripeWebhook",
    "onCallInviteCreated",
    "onCallInviteUpdated",
    "onChatMessageCreated",
    "onAuthUserCreated",
    "healthCheck",
    "getAgoraRtcToken",
  ]) {
    assert.notEqual(exported[legacy], undefined, legacy);
  }
  for (const name of CALLABLE_SERVICE_NAMES) {
    assert.notEqual(exported[name], undefined, name);
  }
  assert.notEqual(exported.onCallV2TaskOutboxCreated, undefined);
  assert.notEqual(exported.executeCallTimeoutTaskV2, undefined);
  for (const forbidden of [
    "processCallTimeoutV2",
    "processActiveLeaseTimeoutV2",
    "dispatchTaskOutboxV2",
    "claimTaskOutboxDispatchV2",
    "finalizeTaskOutboxDispatchSuccessV2",
    "finalizeTaskOutboxDispatchFailureV2",
    "acknowledgeTimeoutTaskExecutionV2",
    "recordTimeoutTaskExecutionFailureV2",
    "executeTimeoutTaskEnvelopeV2",
  ]) {
    assert.equal(exported[forbidden], undefined, forbidden);
  }
});

function config(overrides = {}) {
  return {
    callV2Enabled: true,
    callV2InternalTasksEnabled: true,
    tasksProjectId: "demo-helperly",
    tasksLocation: "us-central1",
    tasksQueueId: "call-v2-timeouts",
    tasksTargetUrl: "https://target.example/task",
    tasksServiceAccountEmail:
      "tasks@demo-helperly.iam.gserviceaccount.com",
    tasksAudience: "https://tasks.example/internal",
    ...overrides,
  };
}

function payload(overrides = {}) {
  return {
    aud: "https://tasks.example/internal",
    email: "tasks@demo-helperly.iam.gserviceaccount.com",
    email_verified: true,
    ...overrides,
  };
}

function verifierFor(payloadValue) {
  return {
    async verifyIdToken() {
      return { getPayload: () => payloadValue };
    },
  };
}

function triggerWiringReturning(status) {
  return createCallV2FirebaseWiring({
    db: {},
    config: config(),
    now: () => FIXED_NOW,
    services: {
      createCloudTasksPublisher() {
        return { publishTimeoutTask: async () => ({}) };
      },
      async dispatchTaskOutboxV2() {
        return { status };
      },
    },
  });
}

function eventParams() {
  return { params: { callId: "call_1", taskId: "task_1" } };
}

function fakeResponse() {
  return {
    writes: [],
    status(statusCode) {
      return {
        json: (body) => {
          this.writes.push({ statusCode, body });
          return this;
        },
      };
    },
  };
}

async function assertHttpsError(code, callV2Code, callback) {
  await assert.rejects(
    callback,
    (error) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, code);
      assert.deepEqual(error.details, { callV2Code });
      assert.equal(`${error.message}`.includes("raw"), false);
      assert.equal(`${error.message}`.includes("callOps"), false);
      return true;
    },
  );
}
