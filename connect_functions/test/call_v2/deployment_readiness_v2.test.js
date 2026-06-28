"use strict";

const assert = require("node:assert/strict");
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
    pendingDocs: [fakeTaskDoc("call_a", "task_pending", 20)],
    dispatchingDocs: [fakeTaskDoc("call_b", "task_dispatching", 10)],
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
      limit: 2,
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

test("outbox recovery fairly reserves capacity for pending and dispatching work", async () => {
  let db = fakeRecoveryDb({
    pendingDocs: [
      fakeTaskDoc("call_p1", "pending_1", 20),
      fakeTaskDoc("call_p2", "pending_2", 21),
      fakeTaskDoc("call_p3", "pending_3", 22),
      fakeTaskDoc("call_p4", "pending_4", 23),
    ],
    dispatchingDocs: [
      fakeTaskDoc("call_d1", "dispatching_1", 1),
      fakeTaskDoc("call_d2", "dispatching_2", 2),
    ],
  });
  let requests = [];
  await recoverPendingTaskOutboxV2({
    db,
    limit: 4,
    dispatchTask: recordRequests(requests),
    generateClaimToken: () => "claim",
    publisher: {},
  });
  assert.deepEqual(requests.map((request) => request.taskId), [
    "pending_1",
    "pending_2",
    "dispatching_1",
    "dispatching_2",
  ]);

  db = fakeRecoveryDb({
    pendingDocs: [fakeTaskDoc("call_p1", "pending_1", 30)],
    dispatchingDocs: [
      fakeTaskDoc("call_d1", "dispatching_1", 1),
      fakeTaskDoc("call_d2", "dispatching_2", 2),
      fakeTaskDoc("call_d3", "dispatching_3", 3),
      fakeTaskDoc("call_d4", "dispatching_4", 4),
    ],
  });
  requests = [];
  await recoverPendingTaskOutboxV2({
    db,
    limit: 4,
    dispatchTask: recordRequests(requests),
    generateClaimToken: () => "claim",
    publisher: {},
  });
  assert.deepEqual(requests.map((request) => request.taskId), [
    "pending_1",
    "dispatching_1",
    "dispatching_2",
    "dispatching_3",
  ]);
});

test("outbox recovery limit one selects oldest recoverable candidate", async () => {
  const db = fakeRecoveryDb({
    pendingDocs: [fakeTaskDoc("call_p", "pending_newer", 20)],
    dispatchingDocs: [fakeTaskDoc("call_d", "dispatching_older", 10)],
  });
  const requests = [];

  const result = await recoverPendingTaskOutboxV2({
    db,
    limit: 1,
    dispatchTask: recordRequests(requests),
    generateClaimToken: () => "claim",
    publisher: {},
  });

  assert.equal(result.examined, 1);
  assert.deepEqual(requests.map((request) => request.taskId), [
    "dispatching_older",
  ]);
});

test("outbox recovery reassigns empty capacity without exceeding limit", async () => {
  const db = fakeRecoveryDb({
    pendingDocs: [
      fakeTaskDoc("call_p1", "pending_1", 1),
      fakeTaskDoc("call_p2", "pending_2", 2),
      fakeTaskDoc("call_p3", "pending_3", 3),
    ],
  });
  const requests = [];

  const result = await recoverPendingTaskOutboxV2({
    db,
    limit: 4,
    dispatchTask: recordRequests(requests),
    generateClaimToken: () => "claim",
    publisher: {},
  });

  assert.equal(result.examined, 3);
  assert.deepEqual(requests.map((request) => request.taskId), [
    "pending_1",
    "pending_2",
    "pending_3",
  ]);
});

test("outbox recovery suppresses duplicate candidates and orders stable ties", async () => {
  const duplicate = fakeTaskDoc("call_dup", "task_dup", 1);
  const db = fakeRecoveryDb({
    pendingDocs: [
      duplicate,
      duplicate,
      fakeTaskDoc("call_z", "task_z", 5),
      fakeTaskDoc("call_a", "task_a", 5),
    ],
  });
  const requests = [];

  const result = await recoverPendingTaskOutboxV2({
    db,
    limit: 4,
    dispatchTask: recordRequests(requests),
    generateClaimToken: () => "claim",
    publisher: {},
  });

  assert.equal(result.examined, 3);
  assert.deepEqual(requests.map((request) => request.taskId), [
    "task_dup",
    "task_a",
    "task_z",
  ]);
});

test("outbox recovery counts dispatcher outcomes and excludes terminal outbox statuses", async () => {
  const db = fakeRecoveryDb({
    pendingDocs: [fakeTaskDoc("call_p", "pending_retry", 1)],
    dispatchingDocs: [
      fakeTaskDoc("call_d1", "dispatching_busy", 1),
      fakeTaskDoc("call_d2", "dispatching_recovered", 2),
    ],
    dispatchedDocs: [fakeTaskDoc("call_done", "dispatched_ignored", 1)],
    deadLetterDocs: [fakeTaskDoc("call_dead", "dead_ignored", 1)],
  });
  const result = await recoverPendingTaskOutboxV2({
    db,
    limit: 4,
    dispatchTask: async ({ request }) => {
      if (request.taskId === "dispatching_busy") {
        return { status: "busy" };
      }
      if (request.taskId === "dispatching_recovered") {
        return { status: "dispatched" };
      }
      return { status: "retryable" };
    },
    generateClaimToken: () => "claim",
    publisher: {},
  });

  assert.deepEqual(db.queryLog.map((query) => query.status), [
    "pending",
    "dispatching",
  ]);
  assert.deepEqual(result, {
    examined: 3,
    dispatched: 1,
    alreadyDispatched: 0,
    deadLetter: 0,
    busy: 1,
    retryable: 1,
    stale: 0,
    failed: 0,
  });
});

test("outbox recovery isolates failures and aggregates dispatcher outcomes only", async () => {
  const db = fakeRecoveryDb({
    pendingDocs: [
      fakeTaskDoc("call_a", "dispatch", 1),
      fakeTaskDoc("call_b", "already", 2),
      fakeTaskDoc("call_c", "dead", 3),
      fakeTaskDoc("call_d", "retry", 4),
      fakeTaskDoc("call_e", "stale", 5),
      fakeTaskDoc("call_f", "throw", 6),
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
  assert.equal(db.queryLog[1].limit, TASK_OUTBOX_RECOVERY_MAX_LIMIT);
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
    distinctAudienceApproved: false,
  });
  assert.deepEqual(result.rolloutReadiness, {
    rolloutConfigRequired: true,
    rolloutMode: "staff",
    rolloutPercentage: 0,
    rolloutAllowlistCount: 0,
    staffClaimsManaged: true,
    globalClientRolloutApproved: false,
  });
  assert.deepEqual(result.canaryReadiness, {
    canaryConfigRequired: true,
    safeObservabilityConfigured: true,
    operationalOwnerAssigned: true,
    rollbackOwnerAssigned: true,
    staffClaimsManaged: true,
  });
  assert.equal(JSON.stringify(result).includes("https://"), false);
  assert.equal(JSON.stringify(result).includes("@"), false);
});

test("deployment validation requires explicit approval for distinct audience", () => {
  assert.throws(
    () => validateCallV2DeploymentConfig(completeConfig({
      audience: "https://tasks.example.com/call-v2",
    })),
    /audience/,
  );

  const result = validateCallV2DeploymentConfig(completeConfig({
    audience: "https://tasks.example.com/call-v2",
    allowDistinctAudience: true,
  }));
  assert.equal(result.sanitizedConfig.distinctAudienceApproved, true);
  assert.equal(JSON.stringify(result).includes("example.com"), false);
  assert.equal(JSON.stringify(result).includes("tasks.example.com"), false);
});

test("deployment validation allows internal-only deployment without rollout config", () => {
  const result = validateCallV2DeploymentConfig(completeConfig({
    clientEnabled: false,
    internalTasksEnabled: true,
    rolloutMode: undefined,
    staffClaimsManaged: undefined,
  }));
  assert.equal(result.status, "internal_only_ready");
  assert.equal(result.rolloutReadiness.rolloutConfigRequired, false);
});

test("deployment validation enforces client rollout configuration", () => {
  assert.throws(
    () => validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "off",
    })),
    /rollout mode/,
  );
  assert.throws(
    () => validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "staff",
      staffClaimsManaged: false,
    })),
    /Staff/,
  );
  assert.equal(
    validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "staff",
      staffClaimsManaged: true,
    })).rolloutReadiness.rolloutMode,
    "staff",
  );
  assert.throws(
    () => validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "allowlist",
      rolloutAllowlist: "",
    })),
    /allowlist/,
  );
  const allowlist = validateCallV2DeploymentConfig(completeConfig({
    clientEnabled: true,
    rolloutMode: "allowlist",
    rolloutAllowlist: "user_a,user_b,user_b",
  })).rolloutReadiness;
  assert.equal(allowlist.rolloutAllowlistCount, 2);
  assert.equal(JSON.stringify(allowlist).includes("user_a"), false);
  assert.throws(
    () => validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "percentage",
      rolloutPercentage: 25,
      rolloutSalt: "",
    })),
    /salt/,
  );
  assert.throws(
    () => validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "percentage",
      rolloutPercentage: 101,
      rolloutSalt: "salt",
    })),
    /percentage/,
  );
  const percentage = validateCallV2DeploymentConfig(completeConfig({
    clientEnabled: true,
    rolloutMode: "percentage",
    rolloutPercentage: 25,
    rolloutSalt: "secret_salt",
  })).rolloutReadiness;
  assert.equal(percentage.rolloutPercentage, 25);
  assert.equal(JSON.stringify(percentage).includes("secret_salt"), false);
  assert.throws(
    () => validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "all",
      allowGlobalClientRollout: false,
    })),
    /Global/,
  );
  assert.equal(
    validateCallV2DeploymentConfig(completeConfig({
      clientEnabled: true,
      rolloutMode: "all",
      allowGlobalClientRollout: true,
    })).rolloutReadiness.globalClientRolloutApproved,
    true,
  );
});

test("deployment validation requires safe client canary acknowledgements", () => {
  for (const [field, expected] of [
    ["safeObservabilityConfigured", /observability/],
    ["operationalOwnerAssigned", /operational owner/],
    ["rollbackOwnerAssigned", /rollback owner/],
  ]) {
    assert.throws(
      () => validateCallV2DeploymentConfig(completeConfig({
        clientEnabled: true,
        [field]: false,
      })),
      expected,
    );
  }

  const internalOnly = validateCallV2DeploymentConfig(completeConfig({
    clientEnabled: false,
    internalTasksEnabled: true,
    safeObservabilityConfigured: false,
    operationalOwnerAssigned: false,
    rollbackOwnerAssigned: false,
  }));
  assert.equal(internalOnly.status, "internal_only_ready");
  assert.deepEqual(internalOnly.canaryReadiness, {
    canaryConfigRequired: false,
    safeObservabilityConfigured: false,
    operationalOwnerAssigned: false,
    rollbackOwnerAssigned: false,
    staffClaimsManaged: false,
  });
});

test("deployment validation script is network-free and prints sanitized output", () => {
  let result = runDeploymentValidationCli({});
  assert.equal(result.status, 0);
  assert.equal(JSON.parse(result.stdout).status, "code_only_ready");

  result = runDeploymentValidationCli({
    CALL_V2_INTERNAL_TASKS_ENABLED: "true",
    CALL_V2_REGION: "us-central1",
  });
  assert.notEqual(result.status, 0);
  const parsed = JSON.parse(result.stdout);
  assert.equal(parsed.ok, false);
  assert.equal(JSON.stringify(parsed).includes("https://"), false);

  result = runDeploymentValidationCli({
    CALL_V2_INTERNAL_TASKS_ENABLED: "true",
    CALL_V2_REGION: "us-central1",
    CALL_V2_TASKS_PROJECT_ID: "project-id",
    CALL_V2_TASKS_LOCATION: "us-central1",
    CALL_V2_TASKS_QUEUE_ID: "queue-id",
    CALL_V2_TASKS_TARGET_URL: "https://target.example.com/task",
    CALL_V2_TASKS_SERVICE_ACCOUNT_EMAIL:
      "tasks@project-id.iam.gserviceaccount.com",
    CALL_V2_TASKS_AUDIENCE: "https://audience.example.com/task",
    CALL_V2_ALLOW_DISTINCT_AUDIENCE: "true",
  });
  assert.equal(result.status, 0);
  const approved = JSON.parse(result.stdout);
  assert.equal(approved.sanitizedConfig.distinctAudienceApproved, true);
  assert.equal(JSON.stringify(approved).includes("example.com"), false);

  result = runDeploymentValidationCli({
    CALL_V2_ENABLED: "true",
    CALL_V2_INTERNAL_TASKS_ENABLED: "true",
    CALL_V2_REGION: "us-central1",
    CALL_V2_TASKS_PROJECT_ID: "project-id",
    CALL_V2_TASKS_LOCATION: "us-central1",
    CALL_V2_TASKS_QUEUE_ID: "queue-id",
    CALL_V2_TASKS_TARGET_URL: "https://target.example.com/task",
    CALL_V2_TASKS_SERVICE_ACCOUNT_EMAIL:
      "tasks@project-id.iam.gserviceaccount.com",
    CALL_V2_TASKS_AUDIENCE: "https://target.example.com/task",
    CALL_V2_ROLLOUT_MODE: "percentage",
    CALL_V2_ROLLOUT_PERCENTAGE: "10",
    CALL_V2_ROLLOUT_SALT: "secret_salt",
    CALL_V2_SAFE_OBSERVABILITY_CONFIGURED: "true",
    CALL_V2_OPERATIONAL_OWNER_ASSIGNED: "true",
    CALL_V2_ROLLBACK_OWNER_ASSIGNED: "true",
  });
  assert.equal(result.status, 0);
  const rollout = JSON.parse(result.stdout);
  assert.equal(rollout.rolloutReadiness.rolloutMode, "percentage");
  assert.equal(rollout.rolloutReadiness.rolloutPercentage, 10);
  assert.equal(rollout.canaryReadiness.safeObservabilityConfigured, true);
  assert.equal(JSON.stringify(rollout).includes("secret_salt"), false);
  assert.equal(JSON.stringify(rollout).includes("target.example.com"), false);
});

function runDeploymentValidationCli(env) {
  const { main } = require("../../call_v2/validate_deployment_v2");
  const originalEnv = process.env;
  const originalWrite = process.stdout.write;
  const originalExitCode = process.exitCode;
  let stdout = "";
  process.env = {
    PATH: originalEnv.PATH,
    ...env,
  };
  process.exitCode = 0;
  process.stdout.write = (chunk) => {
    stdout += chunk;
    return true;
  };
  try {
    main();
    return {
      status: process.exitCode || 0,
      stdout,
    };
  } finally {
    process.env = originalEnv;
    process.stdout.write = originalWrite;
    process.exitCode = originalExitCode;
  }
}

function ttlTargets(indexes) {
  return indexes.fieldOverrides
    .filter((entry) => entry.ttl === true)
    .map((entry) => `${entry.collectionGroup}.${entry.fieldPath}`)
    .sort();
}

function fakeRecoveryDb({
  pendingDocs = [],
  dispatchingDocs = [],
  dispatchedDocs = [],
  deadLetterDocs = [],
}) {
  const docsByStatus = {
    pending: pendingDocs,
    dispatching: dispatchingDocs,
    dispatched: dispatchedDocs,
    dead_letter: deadLetterDocs,
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

function fakeTaskDoc(callId, taskId, updatedAt = 1) {
  return {
    data() {
      return {
        updatedAt,
      };
    },
    ref: {
      id: taskId,
      path: `callOps/${callId}/taskOutbox/${taskId}`,
      parent: {
        id: "taskOutbox",
        parent: {
          id: callId,
        },
      },
    },
  };
}

function recordRequests(requests, status = "dispatched") {
  return async ({ request }) => {
    requests.push(request);
    return { status };
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
    rolloutMode: "staff",
    rolloutPercentage: 0,
    rolloutSalt: "",
    rolloutAllowlist: "",
    staffClaimsManaged: true,
    allowGlobalClientRollout: false,
    safeObservabilityConfigured: true,
    operationalOwnerAssigned: true,
    rollbackOwnerAssigned: true,
    ...overrides,
  };
}
