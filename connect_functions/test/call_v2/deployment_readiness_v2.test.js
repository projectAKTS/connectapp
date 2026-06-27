"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const {
  CallV2Error,
  ERROR_CODES,
} = require("../../call_v2/start_call_v2");
const {
  RECOVERABLE_OUTBOX_STATUSES,
  TASK_OUTBOX_RECOVERY_MAX_LIMIT,
  recoverPendingTaskOutboxV2,
  validateCallV2DeploymentConfig,
} = require("../../call_v2/deployment_readiness_v2");

test("Firestore index configuration contains intended V2 TTL policies and recovery index", () => {
  const indexesPath = path.resolve(__dirname, "../../../firestore.indexes.json");
  const firebasePath = path.resolve(__dirname, "../../../firebase.json");
  const indexes = JSON.parse(fs.readFileSync(indexesPath, "utf8"));
  const firebaseConfig = JSON.parse(fs.readFileSync(firebasePath, "utf8"));

  assert.equal(firebaseConfig.firestore.indexes, "firestore.indexes.json");
  assert.deepEqual(ttlTargets(indexes), [
    "callCommandKeys.ttlAt",
    "callOps.opsRetentionExpiresAt",
    "calls.historyExpiresAt",
    "commands.ttlAt",
    "taskOutbox.ttlAt",
  ]);
  assert.ok(indexes.indexes.some((entry) =>
    entry.collectionGroup === "taskOutbox" &&
    entry.queryScope === "COLLECTION_GROUP" &&
    JSON.stringify(entry.fields) === JSON.stringify([
      { fieldPath: "status", order: "ASCENDING" },
      { fieldPath: "updatedAt", order: "ASCENDING" },
    ]),
  ));
});

test("outbox recovery queries only recoverable statuses with bounded deterministic queries", async () => {
  const db = fakeRecoveryDb({
    pendingDocs: [fakeTaskDoc("call_a", "task_pending")],
    dispatchingDocs: [fakeTaskDoc("call_b", "task_dispatching")],
  });
  const dispatchRequests = [];
  const result = await recoverPendingTaskOutboxV2({
    db,
    now: () => new Date("2026-06-25T12:00:00.000Z"),
    limit: 2,
    dispatchTask: async (request) => {
      dispatchRequests.push(request.request);
      return request.request.taskId === "task_pending"
        ? { status: "dispatched" }
        : { status: "busy" };
    },
    generateClaimToken: () => "claim",
    publisher: {},
  });

  assert.deepEqual(db.queryLog, [
    {
      collectionGroup: "taskOutbox",
      status: "pending",
      orderBy: ["updatedAt", "asc"],
      limit: 2,
    },
    {
      collectionGroup: "taskOutbox",
      status: "dispatching",
      orderBy: ["updatedAt", "asc"],
      limit: 1,
    },
  ]);
  assert.deepEqual(dispatchRequests, [
    { callId: "call_a", taskId: "task_pending" },
    { callId: "call_b", taskId: "task_dispatching" },
  ]);
  assert.deepEqual(result, {
    examined: 2,
    dispatched: 1,
    alreadyDispatched: 0,
    deadLetter: 0,
    busy: 1,
    retryable: 0,
    stale: 0,
    failed: 0,
  });
  assert.equal(JSON.stringify(result).includes("call_a"), false);
  assert.equal(JSON.stringify(result).includes("task_pending"), false);
});

test("outbox recovery isolates failures and aggregates dispatcher outcomes only", async () => {
  const db = fakeRecoveryDb({
    pendingDocs: [
      fakeTaskDoc("call_a", "dispatch"),
      fakeTaskDoc("call_b", "already"),
      fakeTaskDoc("call_c", "dead"),
      fakeTaskDoc("call_d", "retry"),
      fakeTaskDoc("call_e", "stale"),
      fakeTaskDoc("call_f", "throw"),
      { ref: { id: "malformed", parent: {} } },
    ],
  });
  const statusByTask = {
    dispatch: "dispatched",
    already: "already_dispatched",
    dead: "dead_letter",
    retry: "retryable",
    stale: "stale",
  };

  const result = await recoverPendingTaskOutboxV2({
    db,
    now: new Date("2026-06-25T12:00:00.000Z"),
    limit: TASK_OUTBOX_RECOVERY_MAX_LIMIT + 20,
    dispatchTask: async ({ request }) => {
      if (request.taskId === "throw") {
        throw new Error("task-specific failure");
      }
      return { status: statusByTask[request.taskId] };
    },
    generateClaimToken: () => "claim",
    publisher: {},
  });

  assert.equal(db.queryLog[0].limit, TASK_OUTBOX_RECOVERY_MAX_LIMIT);
  assert.deepEqual(result, {
    examined: 7,
    dispatched: 1,
    alreadyDispatched: 1,
    deadLetter: 1,
    busy: 0,
    retryable: 1,
    stale: 1,
    failed: 2,
  });
});

test("deployment validation accepts safe disabled deployment and rejects unsafe switch ordering", () => {
  assert.equal(
    validateCallV2DeploymentConfig({
      clientEnabled: false,
      internalTasksEnabled: false,
    }).status,
    "code_only_ready",
  );

  assert.throws(
    () => validateCallV2DeploymentConfig({
      clientEnabled: true,
      internalTasksEnabled: false,
    }),
    (error) =>
      error instanceof CallV2Error &&
      error.code === ERROR_CODES.invalidArgument,
  );
});

test("deployment validation requires complete explicit internal task configuration", () => {
  assert.throws(
    () => validateCallV2DeploymentConfig({
      clientEnabled: false,
      internalTasksEnabled: true,
      region: "us-central1",
    }),
    /projectId/,
  );

  const result = validateCallV2DeploymentConfig(completeConfig({
    clientEnabled: true,
    internalTasksEnabled: true,
  }));
  assert.equal(result.status, "client_and_internal_ready");
  assert.deepEqual(result.sanitizedConfig, {
    regionConfigured: true,
    projectIdConfigured: true,
    locationConfigured: true,
    queueIdConfigured: true,
    targetUrlConfigured: true,
    serviceAccountEmailConfigured: true,
    audienceConfigured: true,
  });
  assert.equal(JSON.stringify(result).includes("https://"), false);
  assert.equal(JSON.stringify(result).includes("@"), false);
});

test("deployment validation script is network-free and prints sanitized output", () => {
  const script = path.resolve(
    __dirname,
    "../../call_v2/validate_deployment_v2.js",
  );
  let result = spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: {
      PATH: process.env.PATH,
    },
  });
  assert.equal(result.status, 0);
  assert.equal(JSON.parse(result.stdout).status, "code_only_ready");

  result = spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: {
      PATH: process.env.PATH,
      CALL_V2_INTERNAL_TASKS_ENABLED: "true",
      CALL_V2_REGION: "us-central1",
    },
  });
  assert.notEqual(result.status, 0);
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.ok, false);
  assert.equal(JSON.stringify(parsed).includes("https://"), false);
});

function ttlTargets(indexes) {
  return indexes.fieldOverrides
    .filter((entry) => entry.ttl === true)
    .map((entry) => `${entry.collectionGroup}.${entry.fieldPath}`)
    .sort();
}

function fakeRecoveryDb({ pendingDocs = [], dispatchingDocs = [] }) {
  const docsByStatus = {
    pending: pendingDocs,
    dispatching: dispatchingDocs,
  };
  const queryLog = [];
  return {
    queryLog,
    collectionGroup(collectionGroupName) {
      const query = {
        collectionGroupName,
        status: null,
        order: null,
        requestedLimit: null,
        where(field, operator, value) {
          assert.equal(field, "status");
          assert.equal(operator, "==");
          assert.ok(RECOVERABLE_OUTBOX_STATUSES.includes(value));
          this.status = value;
          return this;
        },
        orderBy(field, direction) {
          this.order = [field, direction];
          return this;
        },
        limit(value) {
          this.requestedLimit = value;
          return this;
        },
        async get() {
          queryLog.push({
            collectionGroup: this.collectionGroupName,
            status: this.status,
            orderBy: this.order,
            limit: this.requestedLimit,
          });
          return {
            docs: (docsByStatus[this.status] || []).slice(
              0,
              this.requestedLimit,
            ),
          };
        },
      };
      return query;
    },
  };
}

function fakeTaskDoc(callId, taskId) {
  return {
    ref: {
      id: taskId,
      parent: {
        id: "taskOutbox",
        parent: {
          id: callId,
        },
      },
    },
  };
}

function completeConfig(overrides = {}) {
  return {
    clientEnabled: false,
    internalTasksEnabled: true,
    region: "us-central1",
    projectId: "project-id",
    location: "us-central1",
    queueId: "queue-id",
    targetUrl: "https://example.com/executeCallTimeoutTaskV2",
    serviceAccountEmail: "tasks@project-id.iam.gserviceaccount.com",
    audience: "https://example.com/executeCallTimeoutTaskV2",
    ...overrides,
  };
}
