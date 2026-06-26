"use strict";

const assert = require("node:assert/strict");
const { after, beforeEach, test } = require("node:test");

const admin = require("firebase-admin");

const {
  COMMAND_TTL_MS,
  ERROR_CODES,
  LOCK_EXPIRY_SAFETY_BUFFER_MS,
  OPS_RETENTION_MS,
  RINGING_DURATION_MS,
  CallV2Error,
  startCallV2,
} = require("../../call_v2/start_call_v2");

const PROJECT_ID = process.env.GCLOUD_PROJECT || "demo-helperly-call-v2";
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const FIXED_NOW = new Date("2026-06-25T12:00:00.000Z");

if (!EMULATOR_HOST) {
  throw new Error(
    "FIRESTORE_EMULATOR_HOST must be set. Run npm run test:call-v2:emulator.",
  );
}

process.env.GCLOUD_PROJECT = PROJECT_ID;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}

const db = admin.firestore();

beforeEach(async () => {
  await clearFirestore();
});

after(async () => {
  await admin.app().delete();
});

test("creates ringing call, participants, locks, ops, and idempotency atomically", async () => {
  await seedUsers("caller", "callee");

  const result = await startCall();

  assert.equal(result.callId, "call_1");
  assert.equal(result.lifecycleState, "ringing");
  assert.equal(result.version, 1);
  assert.equal(result.idempotentReplay, false);
  assert.equal(result.ringingDeadlineAt.getTime(), fixedMs() + RINGING_DURATION_MS);
  assert.ok(Number.isInteger(result.callerRtcUid));
  assert.ok(Number.isInteger(result.calleeRtcUid));

  const call = await requiredData("calls/call_1");
  assertExactKeys(call, [
    "acceptedAt",
    "acceptedByUid",
    "acceptedJoinDeadlineAt",
    "activeAt",
    "agoraChannel",
    "callSystem",
    "calleeUid",
    "callerUid",
    "createdAt",
    "endedAt",
    "endedByUid",
    "endReason",
    "failureCode",
    "historyExpiresAt",
    "historyVisible",
    "isVideo",
    "lastPublicEventAt",
    "lifecycleState",
    "mediaProvider",
    "participantUids",
    "reconnectDeadlineAt",
    "ringingDeadlineAt",
    "schemaVersion",
    "terminal",
    "updatedAt",
    "version",
  ]);
  assert.equal(call.schemaVersion, 2);
  assert.equal(call.callSystem, "v2");
  assert.equal(call.lifecycleState, "ringing");
  assert.equal(call.terminal, false);
  assert.equal(call.callerUid, "caller");
  assert.equal(call.calleeUid, "callee");
  assert.deepEqual(call.participantUids, ["caller", "callee"]);
  assert.equal(call.mediaProvider, "agora");
  assert.match(call.agoraChannel, /^call_v2_[a-f0-9]{32}$/);
  assert.equal(call.isVideo, true);
  assert.equal(millis(call.createdAt), fixedMs());
  assert.equal(millis(call.updatedAt), fixedMs());
  assert.equal(millis(call.ringingDeadlineAt), fixedMs() + RINGING_DURATION_MS);
  assert.equal(call.acceptedAt, null);
  assert.equal(call.acceptedByUid, null);
  assert.equal(call.acceptedJoinDeadlineAt, null);
  assert.equal(call.activeAt, null);
  assert.equal(call.reconnectDeadlineAt, null);
  assert.equal(call.historyVisible, true);
  assert.equal(call.historyExpiresAt, null);
  assert.equal(millis(call.lastPublicEventAt), fixedMs());

  const callerParticipant = await requiredData(
    "calls/call_1/participants/caller",
  );
  const calleeParticipant = await requiredData(
    "calls/call_1/participants/callee",
  );
  assertParticipantSchema(callerParticipant);
  assertParticipantSchema(calleeParticipant);
  assert.equal(callerParticipant.uid, "caller");
  assert.equal(callerParticipant.role, "caller");
  assert.equal(callerParticipant.mediaState, "not_joined");
  assert.equal(callerParticipant.mediaVersion, 0);
  assert.equal(callerParticipant.rtcUid, result.callerRtcUid);
  assert.equal(calleeParticipant.uid, "callee");
  assert.equal(calleeParticipant.role, "callee");
  assert.equal(calleeParticipant.mediaState, "not_joined");
  assert.equal(calleeParticipant.mediaVersion, 0);
  assert.equal(calleeParticipant.rtcUid, result.calleeRtcUid);

  const callerLock = await requiredData("activeCallLocks/caller");
  const calleeLock = await requiredData("activeCallLocks/callee");
  assertLock(callerLock, {
    uid: "caller",
    callId: "call_1",
    peerUids: ["callee"],
    fencingToken: 1,
  });
  assertLock(calleeLock, {
    uid: "callee",
    callId: "call_1",
    peerUids: ["caller"],
    fencingToken: 1,
  });

  const ops = await requiredData("callOps/call_1");
  assert.equal(ops.callId, "call_1");
  assert.equal(millis(ops.createdAt), fixedMs());
  assert.equal(ops.terminalAt, null);
  assert.equal(ops.latestOpsVersion, 1);
  assert.equal(millis(ops.opsRetentionExpiresAt), fixedMs() + OPS_RETENTION_MS);

  const commandDocs = await db.collection("callOps/call_1/commands").get();
  assert.equal(commandDocs.size, 1);
  const command = commandDocs.docs[0].data();
  assert.equal(command.actorUid, "caller");
  assert.equal(command.action, "startCall");
  assert.equal(command.callId, "call_1");
  assert.equal(command.status, "completed");
  assert.equal(millis(command.createdAt), fixedMs());
  assert.equal(millis(command.completedAt), fixedMs());
  assert.equal(millis(command.ttlAt), fixedMs() + COMMAND_TTL_MS);

  const idempotencyDocs = await db.collection("callCommandKeys").get();
  assert.equal(idempotencyDocs.size, 1);
  const idempotency = idempotencyDocs.docs[0].data();
  assert.equal(idempotency.actorUid, "caller");
  assert.equal(idempotency.action, "startCall");
  assert.equal(idempotency.callId, "call_1");
  assert.equal(idempotency.result.callId, "call_1");
  assert.equal(millis(idempotency.ttlAt), fixedMs() + COMMAND_TTL_MS);
});

test("assigns deterministic distinct rtc uids for the two participants", async () => {
  await seedUsers("caller", "callee");

  const result = await startCall();
  const callerParticipant = await requiredData(
    "calls/call_1/participants/caller",
  );
  const calleeParticipant = await requiredData(
    "calls/call_1/participants/callee",
  );

  assert.equal(callerParticipant.rtcUid, result.callerRtcUid);
  assert.equal(calleeParticipant.rtcUid, result.calleeRtcUid);
  assert.notEqual(callerParticipant.rtcUid, calleeParticipant.rtcUid);
});

test("rejects unauthenticated callers with a stable error code", async () => {
  await assertCallError(
    ERROR_CODES.unauthenticated,
    () => startCallV2({
      db,
      authUid: "",
      request: request(),
      now: FIXED_NOW,
      generateCallId: () => "call_1",
    }),
  );
  await assertNoCallArtifacts();
});

test("rejects self-calls as invalid arguments", async () => {
  await seedUsers("caller");

  await assertCallError(
    ERROR_CODES.invalidArgument,
    () => startCallV2({
      db,
      authUid: "caller",
      request: request({ calleeUid: "caller" }),
      now: FIXED_NOW,
      generateCallId: () => "call_1",
    }),
  );
  await assertNoCallArtifacts();
});

test("rejects malformed requests and unknown fields", async () => {
  const invalidRequests = [
    null,
    [],
    {},
    request({ calleeUid: "" }),
    request({ isVideo: "true" }),
    request({ idempotencyKey: "" }),
    { ...request(), unexpected: true },
  ];

  for (const invalidRequest of invalidRequests) {
    await assertCallError(
      ERROR_CODES.invalidArgument,
      () => startCallV2({
        db,
        authUid: "caller",
        request: invalidRequest,
        now: FIXED_NOW,
        generateCallId: () => "call_1",
      }),
    );
  }
  await assertNoCallArtifacts();
});

test("returns callee_not_found and writes no partial documents", async () => {
  await seedUsers("caller");

  await assertCallError(
    ERROR_CODES.calleeNotFound,
    startCall(),
  );
  await assertNoCallArtifacts();
});

test("returns user_busy for an existing caller lock without partial writes", async () => {
  await seedUsers("caller", "callee");
  await writeLock("caller", {
    callId: "existing_call",
    peerUids: ["other"],
    expiresAt: new Date(fixedMs() + 60 * 1000),
  });

  await assertCallError(
    ERROR_CODES.userBusy,
    startCall(),
  );
  await assertNoCallArtifacts();
  assert.equal((await db.collection("activeCallLocks").get()).size, 1);
});

test("returns user_busy for an existing callee lock without partial writes", async () => {
  await seedUsers("caller", "callee");
  await writeLock("callee", {
    callId: "existing_call",
    peerUids: ["other"],
    expiresAt: new Date(fixedMs() + 60 * 1000),
  });

  await assertCallError(
    ERROR_CODES.userBusy,
    startCall(),
  );
  await assertNoCallArtifacts();
  assert.equal((await db.collection("activeCallLocks").get()).size, 1);
});

test("replays a matching idempotency result without creating a second call", async () => {
  await seedUsers("caller", "callee");
  const ids = sequencedCallIds("call");

  const first = await startCall({ generateCallId: ids });
  const replay = await startCall({ generateCallId: ids });

  assert.equal(first.callId, "call_1");
  assert.equal(replay.callId, "call_1");
  assert.equal(replay.idempotentReplay, true);
  assert.equal(millis(replay.ringingDeadlineAt), fixedMs() + RINGING_DURATION_MS);
  assert.equal((await db.collection("calls").get()).size, 1);
  assert.equal((await db.collection("callCommandKeys").get()).size, 1);
});

test("rejects idempotency conflicts for changed canonical requests", async () => {
  await seedUsers("caller", "callee", "other_callee");
  await startCall();

  await assertCallError(
    ERROR_CODES.idempotencyConflict,
    startCall({
      generateCallId: () => "call_2",
      request: request({ calleeUid: "other_callee" }),
    }),
  );
  assert.equal((await db.collection("calls").get()).size, 1);
});

test("existing call with generated call ID is never overwritten", async () => {
  await seedUsers("caller", "callee");
  const existingCall = {
    marker: "existing-call",
    schemaVersion: 1,
    terminal: false,
    participantUids: ["someone_else"],
  };
  await db.doc("calls/call_1").set(existingCall);

  await assertCallError(
    ERROR_CODES.callIdConflict,
    startCall(),
  );

  assert.deepEqual(await requiredData("calls/call_1"), existingCall);
  await assertNoCollisionPartials("call_1");
  assert.equal((await db.collection("callOps").get()).size, 0);
});

test("existing callOps with generated call ID is never overwritten", async () => {
  await seedUsers("caller", "callee");
  const existingOps = {
    callId: "call_1",
    marker: "existing-ops",
    latestOpsVersion: 41,
  };
  await db.doc("callOps/call_1").set(existingOps);

  await assertCallError(
    ERROR_CODES.callIdConflict,
    startCall(),
  );

  assert.deepEqual(await requiredData("callOps/call_1"), existingOps);
  assert.equal((await db.collection("calls").get()).size, 0);
  await assertNoCollisionPartials("call_1");
});

test("existing participant with generated call ID is never overwritten", async () => {
  await seedUsers("caller", "callee");
  const existingParticipant = {
    uid: "caller",
    marker: "existing-participant",
  };
  await db.doc("calls/call_1/participants/caller").set(existingParticipant);

  await assertCallError(
    ERROR_CODES.callIdConflict,
    startCall(),
  );

  assert.deepEqual(
    await requiredData("calls/call_1/participants/caller"),
    existingParticipant,
  );
  assert.equal((await db.collection("calls").get()).size, 0);
  assert.equal((await db.collection("callOps").get()).size, 0);
  assert.equal((await db.collection("activeCallLocks").get()).size, 0);
  assert.equal((await db.collection("callCommandKeys").get()).size, 0);
});

test("allows only one concurrent start sharing the same caller", async () => {
  await seedUsers("caller", "callee_a", "callee_b");
  const ids = sequencedCallIds("call");

  const results = await Promise.allSettled([
    startCall({
      generateCallId: ids,
      request: request({ calleeUid: "callee_a", idempotencyKey: "key_a" }),
    }),
    startCall({
      generateCallId: ids,
      request: request({ calleeUid: "callee_b", idempotencyKey: "key_b" }),
    }),
  ]);

  assertOneSuccessAndOneBusy(results);
  assert.equal((await db.collection("calls").get()).size, 1);
});

test("concurrent matching idempotency requests both return the same call", async () => {
  await seedUsers("caller", "callee");

  const results = await Promise.all([
    startCall({ generateCallId: () => "call_candidate_a" }),
    startCall({ generateCallId: () => "call_candidate_b" }),
  ]);

  assert.equal(new Set(results.map((result) => result.callId)).size, 1);
  assert.equal(results.filter((result) => result.idempotentReplay).length, 1);
  assert.equal(results.filter((result) => !result.idempotentReplay).length, 1);

  const finalCallId = results[0].callId;
  assert.equal((await db.collection("calls").get()).size, 1);
  assert.equal((await db.collection("activeCallLocks").get()).size, 2);
  assert.equal((await db.collection("callCommandKeys").get()).size, 1);
  assert.equal(
    (await db.collection(`callOps/${finalCallId}/commands`).get()).size,
    1,
  );
});

test("concurrent idempotency payload conflict creates only one call", async () => {
  await seedUsers("caller", "callee");

  const results = await Promise.allSettled([
    startCall({
      generateCallId: () => "call_candidate_a",
      request: request({ isVideo: true }),
    }),
    startCall({
      generateCallId: () => "call_candidate_b",
      request: request({ isVideo: false }),
    }),
  ]);

  const fulfilled = results.filter((result) => result.status === "fulfilled");
  const rejected = results.filter((result) => result.status === "rejected");
  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.ok(rejected[0].reason instanceof CallV2Error);
  assert.equal(rejected[0].reason.code, ERROR_CODES.idempotencyConflict);

  const finalCallId = fulfilled[0].value.callId;
  assert.equal((await db.collection("calls").get()).size, 1);
  assert.equal((await db.collection("activeCallLocks").get()).size, 2);
  assert.equal((await db.collection("callCommandKeys").get()).size, 1);
  assert.equal(
    (await db.collection(`callOps/${finalCallId}/commands`).get()).size,
    1,
  );
});

test("allows only one concurrent start sharing the same callee", async () => {
  await seedUsers("caller_a", "caller_b", "callee");
  const ids = sequencedCallIds("call");

  const results = await Promise.allSettled([
    startCall({
      authUid: "caller_a",
      generateCallId: ids,
      request: request({ idempotencyKey: "key_a" }),
    }),
    startCall({
      authUid: "caller_b",
      generateCallId: ids,
      request: request({ idempotencyKey: "key_b" }),
    }),
  ]);

  assertOneSuccessAndOneBusy(results);
  assert.equal((await db.collection("calls").get()).size, 1);
});

test("replaces an expired lock when the referenced call is terminal", async () => {
  await seedUsers("caller", "callee");
  await db.doc("calls/old_call").set({ terminal: true });
  await writeLock("caller", {
    callId: "old_call",
    peerUids: ["other"],
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: 7,
  });

  await startCall();

  const lock = await requiredData("activeCallLocks/caller");
  assert.equal(lock.callId, "call_1");
  assert.equal(lock.fencingToken, 8);
});

test("replaces an expired lock when the referenced call is missing", async () => {
  await seedUsers("caller", "callee");
  await writeLock("caller", {
    callId: "missing_call",
    peerUids: ["other"],
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: 4,
  });

  await startCall();

  const lock = await requiredData("activeCallLocks/caller");
  assert.equal(lock.callId, "call_1");
  assert.equal(lock.fencingToken, 5);
});

test("requires lock recovery when an expired lock references a non-terminal call", async () => {
  await seedUsers("caller", "callee");
  await db.doc("calls/old_call").set({ terminal: false });
  await writeLock("caller", {
    callId: "old_call",
    peerUids: ["other"],
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: 4,
  });

  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    startCall(),
  );
  assert.equal((await db.collection("calls").get()).size, 1);
  assert.equal((await db.collection("callOps").get()).size, 0);
  assert.equal((await db.collection("callCommandKeys").get()).size, 0);
});

test("increments fencing tokens independently for each replaced expired lock", async () => {
  await seedUsers("caller", "callee");
  await db.doc("calls/old_caller").set({ terminal: true });
  await db.doc("calls/old_callee").set({ terminal: true });
  await writeLock("caller", {
    callId: "old_caller",
    peerUids: ["other"],
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: 2,
  });
  await writeLock("callee", {
    callId: "old_callee",
    peerUids: ["other"],
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: 9,
  });

  await startCall();

  assert.equal((await requiredData("activeCallLocks/caller")).fencingToken, 3);
  assert.equal((await requiredData("activeCallLocks/callee")).fencingToken, 10);
});

test("malformed expired-lock fencing token requires recovery without writes", async () => {
  await seedUsers("caller", "callee");
  await writeLock("caller", {
    callId: "missing_call",
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: "bad-token",
  });
  const beforeLock = normalizeFirestoreData(
    await requiredData("activeCallLocks/caller"),
  );

  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    startCall(),
  );
  assert.deepEqual(
    normalizeFirestoreData(await requiredData("activeCallLocks/caller")),
    beforeLock,
  );
  await assertNoCallArtifacts();
  assert.equal((await db.collection("callCommandKeys").get()).size, 0);
});

test("zero expired-lock fencing token requires recovery without writes", async () => {
  await seedUsers("caller", "callee");
  await writeLock("caller", {
    callId: "missing_call",
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: 0,
  });
  const beforeLock = normalizeFirestoreData(
    await requiredData("activeCallLocks/caller"),
  );

  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    startCall(),
  );
  assert.deepEqual(
    normalizeFirestoreData(await requiredData("activeCallLocks/caller")),
    beforeLock,
  );
  await assertNoCallArtifacts();
});

test("negative and non-integer fencing tokens require recovery", async () => {
  for (const fencingToken of [-1, 1.5]) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await writeLock("caller", {
      callId: "missing_call",
      expiresAt: new Date(fixedMs() - 1000),
      fencingToken,
    });
    const beforeLock = normalizeFirestoreData(
      await requiredData("activeCallLocks/caller"),
    );

    await assertCallError(
      ERROR_CODES.lockRecoveryRequired,
      startCall(),
    );
    assert.deepEqual(
      normalizeFirestoreData(await requiredData("activeCallLocks/caller")),
      beforeLock,
    );
    await assertNoCallArtifacts();
  }
});

test("overflow expired-lock fencing token requires recovery without writes", async () => {
  await seedUsers("caller", "callee");
  await writeLock("caller", {
    callId: "missing_call",
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: Number.MAX_SAFE_INTEGER,
  });
  const beforeLock = normalizeFirestoreData(
    await requiredData("activeCallLocks/caller"),
  );

  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    startCall(),
  );
  assert.deepEqual(
    normalizeFirestoreData(await requiredData("activeCallLocks/caller")),
    beforeLock,
  );
  await assertNoCallArtifacts();
});

test("public call and participant documents do not contain private operational fields", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const call = await requiredData("calls/call_1");
  const callerParticipant = await requiredData(
    "calls/call_1/participants/caller",
  );
  const calleeParticipant = await requiredData(
    "calls/call_1/participants/callee",
  );

  assertNoPrivatePublicFields(call);
  assertNoPrivatePublicFields(callerParticipant);
  assertNoPrivatePublicFields(calleeParticipant);
});

test("server-controlled deadlines, lock expiry, ttl, and retention are exact", async () => {
  await seedUsers("caller", "callee");

  await startCall();

  const call = await requiredData("calls/call_1");
  const lock = await requiredData("activeCallLocks/caller");
  const ops = await requiredData("callOps/call_1");
  const command = (await db.collection("callOps/call_1/commands").get()).docs[0]
    .data();
  const idempotency = (await db.collection("callCommandKeys").get()).docs[0]
    .data();

  assert.equal(millis(call.createdAt), fixedMs());
  assert.equal(millis(call.ringingDeadlineAt), fixedMs() + RINGING_DURATION_MS);
  assert.equal(
    millis(lock.expiresAt),
    fixedMs() + RINGING_DURATION_MS + LOCK_EXPIRY_SAFETY_BUFFER_MS,
  );
  assert.equal(millis(command.ttlAt), fixedMs() + COMMAND_TTL_MS);
  assert.equal(millis(idempotency.ttlAt), fixedMs() + COMMAND_TTL_MS);
  assert.equal(millis(ops.opsRetentionExpiresAt), fixedMs() + OPS_RETENTION_MS);
});

test("idempotency lookup hides the raw idempotency key", async () => {
  await seedUsers("caller", "callee");
  await startCall({ request: request({ idempotencyKey: "raw-secret-key" }) });

  const docs = await db.collection("callCommandKeys").get();
  assert.equal(docs.size, 1);
  assert.notEqual(docs.docs[0].id, "raw-secret-key");
  assert.equal(docs.docs[0].id.length, 64);
});

test("private command records are stored only under callOps", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const call = await requiredData("calls/call_1");
  assert.equal(call.commands, undefined);
  assert.equal(call.commandId, undefined);
  assert.equal((await db.collection("callOps/call_1/commands").get()).size, 1);
});

test("exports the expected stable error code vocabulary", () => {
  assert.deepEqual(Object.values(ERROR_CODES).sort(), [
    "call_id_conflict",
    "callee_not_found",
    "idempotency_conflict",
    "invalid_argument",
    "lock_recovery_required",
    "transaction_failed",
    "unauthenticated",
    "user_busy",
  ]);
});

function startCall(overrides = {}) {
  return startCallV2({
    db,
    authUid: overrides.authUid || "caller",
    request: overrides.request || request(),
    now: overrides.now || FIXED_NOW,
    generateCallId: overrides.generateCallId || (() => "call_1"),
  });
}

function request(overrides = {}) {
  return {
    calleeUid: "callee",
    isVideo: true,
    idempotencyKey: "idem_1",
    ...overrides,
  };
}

async function seedUsers(...uids) {
  await Promise.all(
    uids.map((uid) =>
      db.collection("users").doc(uid).set({
        uid,
        displayName: `User ${uid}`,
      }),
    ),
  );
}

async function writeLock(uid, overrides = {}) {
  await db.collection("activeCallLocks").doc(uid).set({
    uid,
    callId: overrides.callId || "existing_call",
    peerUids: overrides.peerUids || ["peer"],
    state: "ringing",
    acquiredAt: FIXED_NOW,
    updatedAt: FIXED_NOW,
    expiresAt: overrides.expiresAt || new Date(fixedMs() + 60 * 1000),
    fencingToken: overrides.fencingToken ?? 1,
    acquiredByCommandId: "existing_command",
  });
}

async function requiredData(path) {
  const snapshot = await db.doc(path).get();
  assert.equal(snapshot.exists, true, `${path} should exist`);
  return snapshot.data();
}

async function assertCallError(code, promise) {
  const assertionTarget =
    typeof promise === "function" ? Promise.resolve().then(promise) : promise;
  await assert.rejects(
    assertionTarget,
    (error) => error instanceof CallV2Error && error.code === code,
  );
}

async function assertNoCallArtifacts() {
  assert.equal((await db.collection("calls").get()).size, 0);
  assert.equal((await db.collection("callOps").get()).size, 0);
  assert.equal((await db.collection("callCommandKeys").get()).size, 0);
}

async function assertNoCollisionPartials(callId) {
  assert.equal((await db.collection("activeCallLocks").get()).size, 0);
  assert.equal((await db.collection("callCommandKeys").get()).size, 0);
  assert.equal((await db.collection(`calls/${callId}/participants`).get()).size, 0);
  assert.equal((await db.collection(`callOps/${callId}/commands`).get()).size, 0);
}

function assertExactKeys(value, expectedKeys) {
  assert.deepEqual(Object.keys(value).sort(), [...expectedKeys].sort());
}

function assertParticipantSchema(participant) {
  assertExactKeys(participant, [
    "acceptedAt",
    "failureCode",
    "lastHeartbeatAt",
    "lastMediaStateAt",
    "localJoinStartedAt",
    "mediaJoinedAt",
    "mediaLeftAt",
    "mediaState",
    "mediaVersion",
    "role",
    "rtcUid",
    "uid",
  ]);
  assert.equal(participant.acceptedAt, null);
  assert.equal(participant.localJoinStartedAt, null);
  assert.equal(participant.mediaJoinedAt, null);
  assert.equal(participant.mediaLeftAt, null);
  assert.equal(participant.lastMediaStateAt, null);
  assert.equal(participant.lastHeartbeatAt, null);
  assert.equal(participant.failureCode, null);
}

function assertLock(lock, expected) {
  assert.equal(lock.uid, expected.uid);
  assert.equal(lock.callId, expected.callId);
  assert.deepEqual(lock.peerUids, expected.peerUids);
  assert.equal(lock.state, "ringing");
  assert.equal(millis(lock.acquiredAt), fixedMs());
  assert.equal(millis(lock.updatedAt), fixedMs());
  assert.equal(
    millis(lock.expiresAt),
    fixedMs() + RINGING_DURATION_MS + LOCK_EXPIRY_SAFETY_BUFFER_MS,
  );
  assert.equal(lock.fencingToken, expected.fencingToken);
  assert.match(lock.acquiredByCommandId, /^start_[a-f0-9]{48}$/);
}

function assertOneSuccessAndOneBusy(results) {
  const fulfilled = results.filter((result) => result.status === "fulfilled");
  const rejected = results.filter((result) => result.status === "rejected");
  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.ok(rejected[0].reason instanceof CallV2Error);
  assert.equal(rejected[0].reason.code, ERROR_CODES.userBusy);
}

function assertNoPrivatePublicFields(value) {
  for (const key of Object.keys(value)) {
    const normalizedKey = key.toLowerCase();
    assert.equal(normalizedKey.includes("token"), false, key);
    assert.equal(normalizedKey.includes("device"), false, key);
    assert.equal(normalizedKey.includes("diagnostic"), false, key);
    assert.equal(normalizedKey.includes("secret"), false, key);
    assert.equal(normalizedKey.includes("notification"), false, key);
  }
}

function sequencedCallIds(prefix) {
  let count = 0;
  return () => `${prefix}_${++count}`;
}

function normalizeFirestoreData(value) {
  if (Array.isArray(value)) {
    return value.map((entry) => normalizeFirestoreData(entry));
  }
  if (value && typeof value.toMillis === "function") {
    return { timestampMillis: value.toMillis() };
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [
        key,
        normalizeFirestoreData(entry),
      ]),
    );
  }
  return value;
}

function fixedMs() {
  return FIXED_NOW.getTime();
}

function millis(value) {
  if (value instanceof Date) {
    return value.getTime();
  }
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value && typeof value.toDate === "function") {
    return value.toDate().getTime();
  }
  return new Date(value).getTime();
}

async function clearFirestore() {
  const response = await fetch(
    `http://${EMULATOR_HOST}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" },
  );
  if (!response.ok) {
    throw new Error(`Failed to clear Firestore emulator: ${response.status}`);
  }
}
