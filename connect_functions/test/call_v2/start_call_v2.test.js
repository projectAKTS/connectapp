"use strict";

const assert = require("node:assert/strict");
const { after, beforeEach, test } = require("node:test");

const admin = require("firebase-admin");

const {
  ACCEPTED_JOIN_DURATION_MS,
  ACTIVE_LEASE_DURATION_MS,
  COMMAND_TTL_MS,
  ERROR_CODES,
  LOCK_EXPIRY_SAFETY_BUFFER_MS,
  OPS_RETENTION_MS,
  PUBLIC_HISTORY_RETENTION_MS,
  RECONNECT_GRACE_DURATION_MS,
  RINGING_DURATION_MS,
  CallV2Error,
  acceptCallV2,
  cancelCallV2,
  declineCallV2,
  endCallV2,
  processActiveLeaseTimeoutV2,
  processCallTimeoutV2,
  reportParticipantMediaV2,
  renewActiveCallLeaseV2,
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
  assert.equal(callerParticipant.heartbeatVersion, 0);
  assert.equal(callerParticipant.rtcUid, result.callerRtcUid);
  assert.equal(calleeParticipant.uid, "callee");
  assert.equal(calleeParticipant.role, "callee");
  assert.equal(calleeParticipant.mediaState, "not_joined");
  assert.equal(calleeParticipant.mediaVersion, 0);
  assert.equal(calleeParticipant.heartbeatVersion, 0);
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
  assert.deepEqual(ops.lockClaims, {
    caller: {
      uid: "caller",
      fencingToken: callerLock.fencingToken,
    },
    callee: {
      uid: "callee",
      fencingToken: calleeLock.fencingToken,
    },
  });
  assert.equal(call.lockClaims, undefined);
  assert.equal(call.fencingToken, undefined);

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

test("malformed existing lock expiry requires recovery without writes", async () => {
  const cases = [
    {
      name: "iso string expiry",
      expiresAt: new Date(fixedMs() - 1000).toISOString(),
    },
    {
      name: "numeric expiry",
      expiresAt: fixedMs() - 1000,
    },
    {
      name: "plain object expiry",
      expiresAt: { timestampMillis: fixedMs() - 1000 },
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await writeLock("caller", {
      callId: "missing_call",
      expiresAt: testCase.expiresAt,
      fencingToken: 1,
    });
    const beforeLock = normalizeFirestoreData(
      await requiredData("activeCallLocks/caller"),
    );

    await assertCallError(
      ERROR_CODES.lockRecoveryRequired,
      startCall({
        request: request({ idempotencyKey: testCase.name }),
      }),
    );
    assert.deepEqual(
      normalizeFirestoreData(await requiredData("activeCallLocks/caller")),
      beforeLock,
    );
    assert.equal((await db.collection("activeCallLocks").get()).size, 1);
    await assertNoCallArtifacts();
    assert.equal(
      (await db.collection("calls/call_1/participants").get()).size,
      0,
    );
    assert.equal(
      (await db.collection("callOps/call_1/commands").get()).size,
      0,
    );
  }
});

test("nonpersistable malformed existing lock expiry requires recovery without writes", async () => {
  const cases = [
    {
      name: "invalid Date expiry",
      expiresAt: new Date(Number.NaN),
    },
    {
      name: "invalid toMillis expiry",
      expiresAt: { toMillis: () => Number.NaN },
    },
    {
      name: "throwing toMillis expiry",
      expiresAt: {
        toMillis: () => {
          throw new Error("bad timestamp");
        },
      },
    },
  ];

  for (const testCase of cases) {
    const fake = fakeDbWithData({
      "activeCallLocks/caller": {
        uid: "caller",
        callId: "missing_call",
        peerUids: ["callee"],
        state: "ringing",
        acquiredAt: FIXED_NOW,
        updatedAt: FIXED_NOW,
        expiresAt: testCase.expiresAt,
        fencingToken: 1,
        acquiredByCommandId: "existing_command",
      },
    });

    await assertCallError(
      ERROR_CODES.lockRecoveryRequired,
      () => startCallV2({
        db: fake.db,
        authUid: "caller",
        request: request({ idempotencyKey: testCase.name }),
        now: FIXED_NOW,
        generateCallId: () => "call_1",
      }),
    );
    assert.deepEqual(fake.writes, []);
  }
});

test("max-minus-one expired fencing token can be replaced, accepted, and released", async () => {
  await seedUsers("caller", "callee");
  await writeLock("caller", {
    callId: "missing_caller_call",
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: Number.MAX_SAFE_INTEGER - 1,
  });
  await writeLock("callee", {
    callId: "missing_callee_call",
    expiresAt: new Date(fixedMs() - 1000),
    fencingToken: Number.MAX_SAFE_INTEGER - 1,
  });

  await startCall();

  assert.equal(
    (await requiredData("activeCallLocks/caller")).fencingToken,
    Number.MAX_SAFE_INTEGER,
  );
  assert.equal(
    (await requiredData("activeCallLocks/callee")).fencingToken,
    Number.MAX_SAFE_INTEGER,
  );
  assert.deepEqual((await requiredData("callOps/call_1")).lockClaims, {
    caller: {
      uid: "caller",
      fencingToken: Number.MAX_SAFE_INTEGER,
    },
    callee: {
      uid: "callee",
      fencingToken: Number.MAX_SAFE_INTEGER,
    },
  });

  await acceptCall();
  const endResult = await endCall();

  assert.deepEqual(endResult.lockReleaseResults, {
    caller: "released",
    callee: "released",
  });
  assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
  assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
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

test("callee accepts ringing call and updates call, participant, locks, and ops", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  const beforeCallerLock = await requiredData("activeCallLocks/caller");
  const beforeCalleeLock = await requiredData("activeCallLocks/callee");

  const result = await acceptCall();

  assert.equal(result.callId, "call_1");
  assert.equal(result.lifecycleState, "accepted");
  assert.equal(result.version, 2);
  assert.equal(millis(result.acceptedAt), fixedMs());
  assert.equal(
    millis(result.acceptedJoinDeadlineAt),
    fixedMs() + ACCEPTED_JOIN_DURATION_MS,
  );
  assert.equal(result.idempotentReplay, false);

  const call = await requiredData("calls/call_1");
  assert.equal(call.lifecycleState, "accepted");
  assert.equal(call.terminal, false);
  assert.equal(call.version, 2);
  assert.equal(millis(call.acceptedAt), fixedMs());
  assert.equal(call.acceptedByUid, "callee");
  assert.equal(
    millis(call.acceptedJoinDeadlineAt),
    fixedMs() + ACCEPTED_JOIN_DURATION_MS,
  );
  assert.equal(millis(call.updatedAt), fixedMs());
  assert.equal(millis(call.lastPublicEventAt), fixedMs());

  const calleeParticipant = await requiredData(
    "calls/call_1/participants/callee",
  );
  assert.equal(millis(calleeParticipant.acceptedAt), fixedMs());

  const callerLock = await requiredData("activeCallLocks/caller");
  const calleeLock = await requiredData("activeCallLocks/callee");
  assert.equal(callerLock.state, "accepted");
  assert.equal(calleeLock.state, "accepted");
  assert.equal(callerLock.fencingToken, beforeCallerLock.fencingToken);
  assert.equal(calleeLock.fencingToken, beforeCalleeLock.fencingToken);
  assert.equal(
    millis(callerLock.expiresAt),
    fixedMs() + ACCEPTED_JOIN_DURATION_MS + LOCK_EXPIRY_SAFETY_BUFFER_MS,
  );
  assert.equal(
    millis(calleeLock.expiresAt),
    fixedMs() + ACCEPTED_JOIN_DURATION_MS + LOCK_EXPIRY_SAFETY_BUFFER_MS,
  );

  const ops = await requiredData("callOps/call_1");
  assert.equal(ops.latestOpsVersion, 2);
  assert.equal(ops.terminalAt, null);
  assert.equal(await commandCountForAction("call_1", "acceptCall"), 1);
});

test("caller and nonparticipant cannot accept", async () => {
  await seedUsers("caller", "callee", "intruder");
  await startCall();

  await assertCallError(
    ERROR_CODES.forbidden,
    acceptCall({ authUid: "caller", request: lifecycleRequest("call_1", "a") }),
  );
  await assertCallError(
    ERROR_CODES.forbidden,
    acceptCall({
      authUid: "intruder",
      request: lifecycleRequest("call_1", "b"),
    }),
  );
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "ringing");
  assert.equal(await commandCountForAction("call_1", "acceptCall"), 0);
});

test("already accepted and terminal calls reject a new non-replay accept", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall({ request: lifecycleRequest("call_1", "accept_once") });

  await assertCallError(
    ERROR_CODES.invalidState,
    acceptCall({ request: lifecycleRequest("call_1", "accept_twice") }),
  );

  await endCall({ request: lifecycleRequest("call_1", "end_after_accept") });
  await assertCallError(
    ERROR_CODES.invalidState,
    acceptCall({ request: lifecycleRequest("call_1", "accept_terminal") }),
  );
  assert.equal(await commandCountForAction("call_1", "acceptCall"), 1);
});

test("missing or mismatched accept lock returns lock_recovery_required without writes", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await db.doc("activeCallLocks/callee").delete();

  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    acceptCall({ request: lifecycleRequest("call_1", "accept_missing") }),
  );
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "ringing");
  assert.equal(await commandCountForAction("call_1", "acceptCall"), 0);
  assert.equal((await db.collection("callCommandKeys").get()).size, 1);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await startCall();
  await db.doc("activeCallLocks/caller").update({ fencingToken: 999 });
  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    acceptCall({ request: lifecycleRequest("call_1", "accept_mismatch") }),
  );
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "ringing");
  assert.equal(await commandCountForAction("call_1", "acceptCall"), 0);
});

test("structurally invalid accept locks reject without mutation", async () => {
  const fieldDelete = admin.firestore.FieldValue.delete();
  const cases = [
    {
      name: "wrong lock state",
      mutate: () => db.doc("activeCallLocks/caller").update({ state: "accepted" }),
    },
    {
      name: "missing expiry",
      mutate: () =>
        db.doc("activeCallLocks/caller").update({ expiresAt: fieldDelete }),
    },
    {
      name: "malformed expiry",
      mutate: () => db.doc("activeCallLocks/caller").update({ expiresAt: "bad" }),
    },
    {
      name: "already expired matching lock",
      mutate: () =>
        db
          .doc("activeCallLocks/caller")
          .update({ expiresAt: new Date(fixedMs() - 1) }),
    },
    {
      name: "exact expiry boundary",
      mutate: () =>
        db.doc("activeCallLocks/caller").update({ expiresAt: FIXED_NOW }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await testCase.mutate();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.lockRecoveryRequired,
      acceptCall({ request: lifecycleRequest("call_1", testCase.name) }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("matching accept idempotency replay returns the same result", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const first = await acceptCall();
  const replay = await acceptCall();

  assert.equal(replay.callId, first.callId);
  assert.equal(replay.version, first.version);
  assert.equal(replay.idempotentReplay, true);
  assert.equal(millis(replay.acceptedAt), millis(first.acceptedAt));
  assert.equal(await commandCountForAction("call_1", "acceptCall"), 1);
});

test("accept one millisecond before ringing deadline succeeds", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  const beforeDeadline = new Date(fixedMs() + RINGING_DURATION_MS - 1);

  const result = await acceptCall({
    now: beforeDeadline,
    request: lifecycleRequest("call_1", "accept_before_deadline"),
  });

  assert.equal(result.lifecycleState, "accepted");
  assert.equal(millis(result.acceptedAt), beforeDeadline.getTime());
});

test("ringing commands at or after deadline fail without mutation", async () => {
  const cases = [
    {
      name: "accept exact deadline",
      run: () =>
        acceptCall({
          now: new Date(fixedMs() + RINGING_DURATION_MS),
          request: lifecycleRequest("call_1", "accept_exact_deadline"),
        }),
    },
    {
      name: "decline after deadline",
      run: () =>
        declineCall({
          now: new Date(fixedMs() + RINGING_DURATION_MS + 1),
          request: lifecycleRequest("call_1", "decline_after_deadline"),
        }),
    },
    {
      name: "cancel after deadline",
      run: () =>
        cancelCall({
          now: new Date(fixedMs() + RINGING_DURATION_MS + 1),
          request: lifecycleRequest("call_1", "cancel_after_deadline"),
        }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    const before = await captureMutationState();

    await assertCallError(ERROR_CODES.invalidState, testCase.run());
    await assertMutationStateUnchanged(before);
  }
});

test("accept replay completed before deadline still replays after deadline", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  const beforeDeadline = new Date(fixedMs() + RINGING_DURATION_MS - 1);
  const afterDeadline = new Date(fixedMs() + RINGING_DURATION_MS + 1);

  const first = await acceptCall({
    now: beforeDeadline,
    request: lifecycleRequest("call_1", "accept_deadline_replay"),
  });
  const replay = await acceptCall({
    now: afterDeadline,
    request: lifecycleRequest("call_1", "accept_deadline_replay"),
  });

  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.callId, first.callId);
  assert.equal(millis(replay.acceptedAt), millis(first.acceptedAt));
  assert.equal(replay.version, first.version);
});

test("concurrent identical accepts create one transition and one replay", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const results = await Promise.all([
    acceptCall({ request: lifecycleRequest("call_1", "same_accept") }),
    acceptCall({ request: lifecycleRequest("call_1", "same_accept") }),
  ]);

  assert.equal(new Set(results.map((result) => result.version)).size, 1);
  assert.equal(results.filter((result) => result.idempotentReplay).length, 1);
  assert.equal(results.filter((result) => !result.idempotentReplay).length, 1);
  assert.equal((await requiredData("calls/call_1")).version, 2);
  assert.equal(await commandCountForAction("call_1", "acceptCall"), 1);
});

test("concurrent accept versus decline results in exactly one valid transition", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const results = await Promise.allSettled([
    acceptCall({ request: lifecycleRequest("call_1", "accept_race") }),
    declineCall({ request: lifecycleRequest("call_1", "decline_race") }),
  ]);

  assertOneSuccessAndOneInvalidState(results);
  const call = await requiredData("calls/call_1");
  assert.ok(["accepted", "declined"].includes(call.lifecycleState));
  assert.equal(call.version, 2);
});

test("callee declines ringing call with terminal fields and lock release", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const result = await declineCall();

  assertTerminalResult(result, {
    lifecycleState: "declined",
    endReason: "declined",
  });
  assert.deepEqual(result.lockReleaseResults, {
    caller: "released",
    callee: "released",
  });
  const call = await requiredData("calls/call_1");
  assert.equal(call.lifecycleState, "declined");
  assert.equal(call.terminal, true);
  assert.equal(call.version, 2);
  assert.equal(millis(call.historyExpiresAt), fixedMs() + PUBLIC_HISTORY_RETENTION_MS);
  assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
  assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
  const ops = await requiredData("callOps/call_1");
  assert.equal(ops.terminalState, "declined");
  assert.equal(ops.terminalReason, "declined");
  assert.equal(millis(ops.terminalAt), fixedMs());
  assert.deepEqual(ops.lockReleaseResults, result.lockReleaseResults);
});

test("caller cannot decline", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  await assertCallError(
    ERROR_CODES.forbidden,
    declineCall({ authUid: "caller" }),
  );
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "ringing");
});

test("decline does not delete unrelated or fencing-mismatched locks", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await db.doc("activeCallLocks/caller").update({ callId: "other_call" });
  await db.doc("activeCallLocks/callee").update({ fencingToken: 999 });

  const result = await declineCall();

  assert.deepEqual(result.lockReleaseResults, {
    caller: "call_mismatch",
    callee: "fencing_mismatch",
  });
  assert.equal((await db.doc("activeCallLocks/caller").get()).exists, true);
  assert.equal((await db.doc("activeCallLocks/callee").get()).exists, true);
});

test("caller cancels ringing call and releases only matching locks", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const result = await cancelCall();

  assertTerminalResult(result, {
    lifecycleState: "cancelled",
    endReason: "cancelled",
  });
  assert.deepEqual(result.lockReleaseResults, {
    caller: "released",
    callee: "released",
  });
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "cancelled");
  assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
  assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
});

test("callee cannot cancel", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  await assertCallError(
    ERROR_CODES.forbidden,
    cancelCall({ authUid: "callee" }),
  );
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "ringing");
});

test("concurrent cancel versus accept results in exactly one transition", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const results = await Promise.allSettled([
    cancelCall({ request: lifecycleRequest("call_1", "cancel_race") }),
    acceptCall({ request: lifecycleRequest("call_1", "accept_cancel_race") }),
  ]);

  assertOneSuccessAndOneInvalidState(results);
  const call = await requiredData("calls/call_1");
  assert.ok(["cancelled", "accepted"].includes(call.lifecycleState));
  assert.equal(call.version, 2);
});

test("either participant can end an accepted call", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  const result = await endCall({ authUid: "caller" });

  assertTerminalResult(result, {
    lifecycleState: "completed",
    endReason: "ended_by_participant",
    version: 3,
  });
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "completed");
});

test("either participant can end an active call", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  await db.doc("calls/call_1").update({
    lifecycleState: "active",
    activeAt: FIXED_NOW,
    version: 3,
  });
  await db.doc("callOps/call_1").update({ latestOpsVersion: 3 });

  const result = await endCall({
    authUid: "callee",
    request: lifecycleRequest("call_1", "end_active"),
  });

  assertTerminalResult(result, {
    lifecycleState: "completed",
    endReason: "ended_by_participant",
    version: 4,
  });
});

test("end while ringing returns invalid_state", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  await assertCallError(
    ERROR_CODES.invalidState,
    endCall(),
  );
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "ringing");
});

test("end produces completed terminal state and exact history retention", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  await endCall();

  const call = await requiredData("calls/call_1");
  assert.equal(call.lifecycleState, "completed");
  assert.equal(call.terminal, true);
  assert.equal(call.endReason, "ended_by_participant");
  assert.equal(millis(call.endedAt), fixedMs());
  assert.equal(millis(call.historyExpiresAt), fixedMs() + PUBLIC_HISTORY_RETENTION_MS);
});

test("concurrent end commands increment version only once", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  const results = await Promise.allSettled([
    endCall({
      authUid: "caller",
      request: lifecycleRequest("call_1", "end_race_caller"),
    }),
    endCall({
      authUid: "callee",
      request: lifecycleRequest("call_1", "end_race_callee"),
    }),
  ]);

  assertOneSuccessAndOneInvalidState(results);
  const call = await requiredData("calls/call_1");
  assert.equal(call.lifecycleState, "completed");
  assert.equal(call.version, 3);
});

test("same end idempotency key replays the original result", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  const first = await endCall({ request: lifecycleRequest("call_1", "end_same") });
  const replay = await endCall({ request: lifecycleRequest("call_1", "end_same") });

  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.callId, first.callId);
  assert.equal(replay.version, first.version);
  assert.equal(millis(replay.endedAt), millis(first.endedAt));
  assert.equal(await commandCountForAction("call_1", "endCall"), 1);
});

test("same lifecycle idempotency key with changed call ID conflicts", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall({ request: lifecycleRequest("call_1", "same_key") });

  await assertCallError(
    ERROR_CODES.idempotencyConflict,
    acceptCall({ request: lifecycleRequest("other_call", "same_key") }),
  );
});

test("nonexistent and legacy calls cannot be mutated", async () => {
  await assertCallError(
    ERROR_CODES.callNotFound,
    cancelCall({ request: lifecycleRequest("missing_call", "missing") }),
  );
  assert.equal((await db.collection("callCommandKeys").get()).size, 0);

  await db.doc("calls/legacy_call").set({
    callSystem: "legacy",
    lifecycleState: "ringing",
  });
  await assertCallError(
    ERROR_CODES.callNotFound,
    cancelCall({ request: lifecycleRequest("legacy_call", "legacy") }),
  );
  assert.equal((await db.collection("callCommandKeys").get()).size, 0);
});

test("malformed authoritative V2 call schema is rejected without writes", async () => {
  const fieldDelete = admin.firestore.FieldValue.delete();
  const cases = [
    {
      name: "missing schemaVersion",
      mutate: () => db.doc("calls/call_1").update({ schemaVersion: fieldDelete }),
    },
    {
      name: "wrong schemaVersion",
      mutate: () => db.doc("calls/call_1").update({ schemaVersion: 3 }),
    },
    {
      name: "duplicate participant UIDs",
      mutate: () =>
        db.doc("calls/call_1").update({ participantUids: ["caller", "caller"] }),
    },
    {
      name: "extra participant UID",
      mutate: () =>
        db
          .doc("calls/call_1")
          .update({ participantUids: ["caller", "callee", "extra"] }),
    },
    {
      name: "malformed participant UID",
      mutate: () =>
        db
          .doc("calls/call_1")
          .update({ participantUids: ["caller", "bad/uid"] }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await testCase.mutate();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.transactionFailed,
      cancelCall({ request: lifecycleRequest("call_1", testCase.name) }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("malformed actor participant document is rejected without writes", async () => {
  const cases = [
    {
      name: "malformed participant uid",
      mutate: () =>
        db.doc("calls/call_1/participants/callee").update({ uid: "other" }),
    },
    {
      name: "incorrect participant role",
      mutate: () =>
        db.doc("calls/call_1/participants/callee").update({ role: "caller" }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await testCase.mutate();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.transactionFailed,
      acceptCall({ request: lifecycleRequest("call_1", testCase.name) }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("malformed version is rejected without lifecycle writes", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await db.doc("calls/call_1").update({ version: Number.MAX_SAFE_INTEGER });
  const beforeCall = normalizeFirestoreData(await requiredData("calls/call_1"));

  await assertCallError(
    ERROR_CODES.transactionFailed,
    cancelCall(),
  );

  assert.deepEqual(
    normalizeFirestoreData(await requiredData("calls/call_1")),
    beforeCall,
  );
  assert.equal(await commandCountForAction("call_1", "cancelCall"), 0);
});

test("terminal command metadata and release results stay private", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await cancelCall();

  const call = await requiredData("calls/call_1");
  const callerParticipant = await requiredData(
    "calls/call_1/participants/caller",
  );
  const ops = await requiredData("callOps/call_1");

  assert.equal(call.lockClaims, undefined);
  assert.equal(call.lockReleaseResults, undefined);
  assert.equal(call.commands, undefined);
  assert.equal(callerParticipant.lockClaims, undefined);
  assert.equal(callerParticipant.lockReleaseResults, undefined);
  assert.equal(ops.terminalState, "cancelled");
  assert.deepEqual(ops.lockReleaseResults, {
    caller: "released",
    callee: "released",
  });
  assert.equal(await commandCountForAction("call_1", "cancelCall"), 1);
});

test("ringing media reports allow preparation but reject joining or joined", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  const result = await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "ring_prepare"),
  });

  assert.equal(result.mediaState, "preparing");
  assert.equal(result.mediaVersion, 1);
  assert.equal(result.mediaChanged, true);
  assert.equal(result.lifecycleState, "ringing");
  assert.equal(result.callVersion, 1);
  assert.equal((await requiredData("calls/call_1")).version, 1);

  for (const mediaState of ["joining", "joined"]) {
    await assertCallError(
      ERROR_CODES.invalidState,
      reportMedia({
        mediaState,
        request: mediaRequest("call_1", mediaState, `ring_${mediaState}`),
      }),
    );
  }
});

test("ringing media report after deadline rejects without writes", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  const before = await captureMutationState();

  await assertCallError(
    ERROR_CODES.invalidState,
    reportMedia({
      now: new Date(fixedMs() + RINGING_DURATION_MS),
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "ring_expired"),
    }),
  );

  await assertMutationStateUnchanged(before);
});

test("ringing media reports reject malformed temporal fields without writes", async () => {
  const cases = [
    {
      name: "ringingDeadlineAt ISO string",
      mutate: () =>
        db.doc("calls/call_1").update({
          ringingDeadlineAt: new Date(
            fixedMs() + RINGING_DURATION_MS,
          ).toISOString(),
        }),
    },
    {
      name: "ringingDeadlineAt number",
      mutate: () =>
        db
          .doc("calls/call_1")
          .update({ ringingDeadlineAt: fixedMs() + RINGING_DURATION_MS }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await testCase.mutate();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.transactionFailed,
      reportMedia({
        mediaState: "preparing",
        request: mediaRequest("call_1", "preparing", testCase.name),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("ringing media reports reject malformed participant media state", async () => {
  for (const mediaState of [
    "joining",
    "joined",
    "reconnecting",
    "disconnected",
    "left",
  ]) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await db
      .doc("calls/call_1/participants/caller")
      .update({ mediaState });
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.transactionFailed,
      reportMedia({
        mediaState,
        request: mediaRequest("call_1", mediaState, `ringing_${mediaState}`),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("ringing media reports preserve the restricted transition graph", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  await reportMedia({
    mediaState: "media_failed",
    request: mediaRequest("call_1", "media_failed", "ring_fail"),
  });
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).mediaState,
    "media_failed",
  );

  await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "ring_recover"),
  });
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).mediaState,
    "preparing",
  );

  await reportMedia({
    mediaState: "media_failed",
    request: mediaRequest("call_1", "media_failed", "ring_fail_again"),
  });
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).mediaState,
    "media_failed",
  );
});

test("accepted participant progresses preparing to joining to joined", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  const preparing = await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "media_prepare"),
  });
  const joining = await reportMedia({
    mediaState: "joining",
    request: mediaRequest("call_1", "joining", "media_joining"),
  });
  const joined = await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "media_joined"),
  });

  assert.equal(preparing.mediaVersion, 1);
  assert.equal(joining.mediaVersion, 2);
  assert.equal(joined.mediaVersion, 3);
  assert.equal(joined.lifecycleState, "accepted");
  assert.equal(joined.callVersion, 2);
  const participant = await requiredData("calls/call_1/participants/caller");
  assert.equal(participant.mediaState, "joined");
  assert.equal(participant.mediaVersion, 3);
  assert.equal(millis(participant.localJoinStartedAt), fixedMs());
  assert.equal(millis(participant.mediaJoinedAt), fixedMs());
  assert.equal(millis(participant.lastMediaStateAt), fixedMs());
});

test("same-state media report succeeds without media-version increment", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "prepare_once"),
  });
  const beforeOpsVersion = (await requiredData("callOps/call_1")).latestOpsVersion;

  const result = await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "prepare_noop"),
  });

  assert.equal(result.mediaChanged, false);
  assert.equal(result.mediaVersion, 1);
  assert.equal((await requiredData("calls/call_1/participants/caller")).mediaVersion, 1);
  assert.equal((await requiredData("callOps/call_1")).latestOpsVersion, beforeOpsVersion + 1);
});

test("accepted media reports at or after join deadline reject without writes", async () => {
  const cases = [
    {
      name: "exact deadline",
      now: new Date(fixedMs() + ACCEPTED_JOIN_DURATION_MS),
    },
    {
      name: "after deadline",
      now: new Date(fixedMs() + ACCEPTED_JOIN_DURATION_MS + 1),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await acceptCall();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.invalidState,
      reportMedia({
        now: testCase.now,
        mediaState: "preparing",
        request: mediaRequest("call_1", "preparing", testCase.name),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("accepted media reports reject malformed temporal fields without writes", async () => {
  const cases = [
    {
      name: "acceptedAt malformed",
      mutate: () => db.doc("calls/call_1").update({ acceptedAt: "bad" }),
    },
    {
      name: "acceptedJoinDeadlineAt malformed",
      mutate: () =>
        db.doc("calls/call_1").update({ acceptedJoinDeadlineAt: 12345 }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await acceptCall();
    await testCase.mutate();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.transactionFailed,
      reportMedia({
        mediaState: "preparing",
        request: mediaRequest("call_1", "preparing", testCase.name),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("media report idempotency replays and conflicts by media state", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  const first = await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "media_same_key"),
  });
  const replay = await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "media_same_key"),
  });

  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.mediaVersion, first.mediaVersion);
  await assertCallError(
    ERROR_CODES.idempotencyConflict,
    reportMedia({
      mediaState: "joining",
      request: mediaRequest("call_1", "joining", "media_same_key"),
    }),
  );
  assert.equal(await commandCountForAction("call_1", "reportParticipantMedia"), 1);
});

test("non-incrementable media version rejects state changes without writes", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  await db
    .doc("calls/call_1/participants/caller")
    .update({ mediaVersion: Number.MAX_SAFE_INTEGER });
  const before = await captureMutationState();

  await assertCallError(
    ERROR_CODES.transactionFailed,
    reportMedia({
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "max_media_version"),
    }),
  );
  await assertMutationStateUnchanged(before);
});

test("unsupported media states and unknown fields reject", async () => {
  await seedUsers("caller", "callee");
  await startCall();

  await assertCallError(
    ERROR_CODES.invalidArgument,
    () => reportParticipantMediaV2({
      db,
      authUid: "caller",
      request: mediaRequest("call_1", "unsupported", "bad_state"),
      now: FIXED_NOW,
    }),
  );
  await assertCallError(
    ERROR_CODES.invalidArgument,
    () => reportParticipantMediaV2({
      db,
      authUid: "caller",
      request: {
        ...mediaRequest("call_1", "preparing", "unknown_field"),
        mediaVersion: 1,
      },
      now: FIXED_NOW,
    }),
  );
});

test("media transition graph prevents delayed regressions and leaving recovery", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "joined_once"),
  });

  await assertCallError(
    ERROR_CODES.invalidState,
    reportMedia({
      mediaState: "joining",
      request: mediaRequest("call_1", "joining", "delayed_joining"),
    }),
  );

  await reportMedia({
    mediaState: "left",
    request: mediaRequest("call_1", "left", "left_once"),
  });
  await assertCallError(
    ERROR_CODES.invalidState,
    reportMedia({
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "left_recovery"),
    }),
  );
});

test("malformed media participant documents and nonparticipants reject", async () => {
  await seedUsers("caller", "callee", "intruder");
  await startCall();
  await acceptCall();

  await db.doc("calls/call_1/participants/callee").delete();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    reportMedia({
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "missing_participant"),
    }),
  );

  await clearFirestore();
  await seedUsers("caller", "callee", "intruder");
  await startCall();
  await acceptCall();
  await db.doc("calls/call_1/participants/caller").update({ uid: "other" });
  await assertCallError(
    ERROR_CODES.transactionFailed,
    reportMedia({
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "wrong_uid"),
    }),
  );

  await clearFirestore();
  await seedUsers("caller", "callee", "intruder");
  await startCall();
  await acceptCall();
  await db.doc("calls/call_1/participants/caller").update({ role: "callee" });
  await assertCallError(
    ERROR_CODES.transactionFailed,
    reportMedia({
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "wrong_role"),
    }),
  );

  await clearFirestore();
  await seedUsers("caller", "callee", "intruder");
  await startCall();
  await acceptCall();
  await assertCallError(
    ERROR_CODES.forbidden,
    reportMedia({
      authUid: "intruder",
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "intruder"),
    }),
  );
});

test("media report validates the reporting participant lock", async () => {
  const fieldDelete = admin.firestore.FieldValue.delete();
  const cases = [
    {
      name: "missing lock",
      mutate: () => db.doc("activeCallLocks/caller").delete(),
    },
    {
      name: "mismatched call",
      mutate: () => db.doc("activeCallLocks/caller").update({ callId: "other" }),
    },
    {
      name: "wrong state",
      mutate: () => db.doc("activeCallLocks/caller").update({ state: "ringing" }),
    },
    {
      name: "mismatched fencing",
      mutate: () => db.doc("activeCallLocks/caller").update({ fencingToken: 999 }),
    },
    {
      name: "missing expiry",
      mutate: () =>
        db.doc("activeCallLocks/caller").update({ expiresAt: fieldDelete }),
    },
    {
      name: "malformed expiry",
      mutate: () => db.doc("activeCallLocks/caller").update({ expiresAt: "bad" }),
    },
    {
      name: "expired accepted lock",
      mutate: () =>
        db
          .doc("activeCallLocks/caller")
          .update({ expiresAt: new Date(fixedMs() - 1) }),
    },
    {
      name: "exact expiry boundary",
      mutate: () =>
        db.doc("activeCallLocks/caller").update({ expiresAt: FIXED_NOW }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    await acceptCall();
    await testCase.mutate();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.lockRecoveryRequired,
      reportMedia({
        mediaState: "preparing",
        request: mediaRequest("call_1", "preparing", testCase.name),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("active report may proceed with elapsed safety expiry", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await db.doc("activeCallLocks/caller").update({
    expiresAt: new Date(fixedMs() - 1),
  });

  const result = await reportMedia({
    mediaState: "reconnecting",
    request: mediaRequest("call_1", "reconnecting", "active_elapsed_lock"),
  });

  assert.equal(result.mediaState, "reconnecting");
  assert.equal(result.lifecycleState, "active");
  assert.equal(millis(result.reconnectDeadlineAt), fixedMs() + RECONNECT_GRACE_DURATION_MS);
});

test("active media reports reject malformed temporal fields without writes", async () => {
  const fieldDelete = admin.firestore.FieldValue.delete();
  const cases = [
    {
      name: "activeAt malformed",
      mutate: () => db.doc("calls/call_1").update({ activeAt: "bad" }),
    },
    {
      name: "reconnectDeadlineAt ISO string",
      mutate: () =>
        db.doc("calls/call_1").update({
          reconnectDeadlineAt: new Date(
            fixedMs() + RECONNECT_GRACE_DURATION_MS,
          ).toISOString(),
        }),
    },
    {
      name: "reconnectDeadlineAt number",
      mutate: () =>
        db
          .doc("calls/call_1")
          .update({ reconnectDeadlineAt: fixedMs() + RECONNECT_GRACE_DURATION_MS }),
    },
    {
      name: "reconnectDeadlineAt missing",
      mutate: () =>
        db
          .doc("calls/call_1")
          .update({ reconnectDeadlineAt: fieldDelete }),
    },
    {
      name: "reconnectDeadlineAt plain object",
      mutate: () =>
        db
          .doc("calls/call_1")
          .update({ reconnectDeadlineAt: { timestampMillis: fixedMs() } }),
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    await testCase.mutate();
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.transactionFailed,
      reportMedia({
        mediaState: "reconnecting",
        request: mediaRequest("call_1", "reconnecting", testCase.name),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("nonpersistable malformed active timestamps reject without writes", async () => {
  const cases = [
    {
      name: "invalid activeAt Date",
      call: { activeAt: new Date(Number.NaN), reconnectDeadlineAt: null },
    },
    {
      name: "invalid reconnect Date",
      call: {
        activeAt: FIXED_NOW,
        reconnectDeadlineAt: new Date(Number.NaN),
      },
    },
    {
      name: "invalid reconnect toMillis",
      call: {
        activeAt: FIXED_NOW,
        reconnectDeadlineAt: { toMillis: () => Number.NaN },
      },
    },
    {
      name: "throwing reconnect toMillis",
      call: {
        activeAt: FIXED_NOW,
        reconnectDeadlineAt: {
          toMillis: () => {
            throw new Error("bad timestamp");
          },
        },
      },
    },
  ];

  for (const testCase of cases) {
    const fake = fakeDbWithData(fakeActiveMediaReportData(testCase.call));

    await assertCallError(
      ERROR_CODES.transactionFailed,
      () => reportParticipantMediaV2({
        db: fake.db,
        authUid: "caller",
        request: mediaRequest("call_1", "reconnecting", testCase.name),
        now: FIXED_NOW,
      }),
    );
    assert.deepEqual(fake.writes, []);
  }
});

test("valid existing reconnect deadline is preserved until both participants join", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const existingDeadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await db
    .doc("calls/call_1")
    .update({ reconnectDeadlineAt: existingDeadline });
  const beforeVersion = (await requiredData("calls/call_1")).version;

  const result = await reportMedia({
    mediaState: "reconnecting",
    request: mediaRequest("call_1", "reconnecting", "preserve_deadline"),
  });

  const call = await requiredData("calls/call_1");
  assert.equal(result.callVersion, beforeVersion);
  assert.equal(millis(result.reconnectDeadlineAt), existingDeadline.getTime());
  assert.equal(millis(call.reconnectDeadlineAt), existingDeadline.getTime());
  assert.equal(call.version, beforeVersion);
});

test("valid existing reconnect deadline clears when both participants join", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const existingDeadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await db.doc("calls/call_1").update({
    reconnectDeadlineAt: existingDeadline,
  });
  await db.doc("calls/call_1/participants/caller").update({
    mediaState: "reconnecting",
    mediaVersion: 2,
  });
  const beforeVersion = (await requiredData("calls/call_1")).version;

  const result = await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "clear_deadline"),
  });

  const call = await requiredData("calls/call_1");
  assert.equal(result.callVersion, beforeVersion + 1);
  assert.equal(result.reconnectDeadlineAt, null);
  assert.equal(call.reconnectDeadlineAt, null);
  assert.equal(call.version, beforeVersion + 1);
});

test("active media recovery one millisecond before reconnect deadline succeeds", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: deadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });
  const beforeVersion = (await requiredData("calls/call_1")).version;

  const result = await reportMedia({
    now: new Date(deadline.getTime() - 1),
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "recover_before_deadline"),
  });

  const call = await requiredData("calls/call_1");
  assert.equal(result.lifecycleState, "active");
  assert.equal(result.mediaState, "joined");
  assert.equal(result.reconnectDeadlineAt, null);
  assert.equal(result.callVersion, beforeVersion + 1);
  assert.equal(call.reconnectDeadlineAt, null);
  assert.equal(call.version, beforeVersion + 1);
});

test("active media recovery at or after reconnect deadline rejects without writes", async () => {
  const cases = [
    {
      name: "exact deadline",
      nowOffsetMs: 0,
    },
    {
      name: "after deadline",
      nowOffsetMs: 1,
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
    await setActiveReconnectScenario({
      reconnectDeadlineAt: deadline,
      callerMediaState: "reconnecting",
      calleeMediaState: "joined",
    });
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.invalidState,
      reportMedia({
        now: new Date(deadline.getTime() + testCase.nowOffsetMs),
        mediaState: "joined",
        request: mediaRequest("call_1", "joined", testCase.name),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("late joined reports cannot clear an expired reconnect deadline", async () => {
  const cases = [
    {
      name: "caller late join",
      authUid: "caller",
      callerMediaState: "reconnecting",
      calleeMediaState: "joined",
    },
    {
      name: "callee late join",
      authUid: "callee",
      callerMediaState: "joined",
      calleeMediaState: "reconnecting",
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
    await setActiveReconnectScenario({
      reconnectDeadlineAt: deadline,
      callerMediaState: testCase.callerMediaState,
      calleeMediaState: testCase.calleeMediaState,
    });
    const before = await captureMutationState();

    await assertCallError(
      ERROR_CODES.invalidState,
      reportMedia({
        authUid: testCase.authUid,
        now: deadline,
        mediaState: "joined",
        request: mediaRequest("call_1", "joined", testCase.name),
      }),
    );
    await assertMutationStateUnchanged(before);
  }
});

test("disconnected participant cannot change media state after reconnect deadline", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: deadline,
    callerMediaState: "disconnected",
    calleeMediaState: "joined",
  });
  const before = await captureMutationState();

  await assertCallError(
    ERROR_CODES.invalidState,
    reportMedia({
      now: new Date(deadline.getTime() + 1),
      mediaState: "reconnecting",
      request: mediaRequest(
        "call_1",
        "reconnecting",
        "reconnect_after_deadline",
      ),
    }),
  );
  await assertMutationStateUnchanged(before);
});

test("media command completed before reconnect deadline replays after deadline", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: deadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });

  const first = await reportMedia({
    now: new Date(deadline.getTime() - 1),
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "replay_recover_before_deadline"),
  });
  const replay = await reportMedia({
    now: new Date(deadline.getTime() + 1),
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "replay_recover_before_deadline"),
  });

  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.mediaVersion, first.mediaVersion);
  assert.equal(replay.callVersion, first.callVersion);
  assert.equal(replay.reconnectDeadlineAt, null);
  assert.equal(await commandCountForAction("call_1", "reportParticipantMedia"), 3);
});

test("participant can end active call after reconnect deadline", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: deadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });

  const result = await endCall({
    now: new Date(deadline.getTime() + 1),
    request: lifecycleRequest("call_1", "end_after_reconnect_deadline"),
  });

  assert.equal(result.lifecycleState, "completed");
  assert.equal(result.version, 4);
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "completed");
});

test("ringing timeout before deadline returns not_due without writes", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  const deadline = (await requiredData("calls/call_1")).ringingDeadlineAt;
  const before = await captureMutationState();

  const result = await processTimeout({
    now: new Date(millis(deadline) - 1),
    request: timeoutRequest("call_1", "ringing", 1, deadline),
  });

  assert.equal(result.status, "not_due");
  assert.equal(result.lifecycleState, "ringing");
  await assertMutationStateUnchanged(before);
  assert.equal(await commandCountForAction("call_1", "processCallTimeout"), 0);
});

test("ringing timeout at and after deadline creates missed with exact fields", async () => {
  const cases = [
    {
      name: "at deadline",
      offsetMs: 0,
    },
    {
      name: "after deadline",
      offsetMs: 1,
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    const deadline = (await requiredData("calls/call_1")).ringingDeadlineAt;
    const processedAt = new Date(millis(deadline) + testCase.offsetMs);

    const result = await processTimeout({
      now: processedAt,
      request: timeoutRequest("call_1", "ringing", 1, deadline),
    });

    assert.equal(result.status, "terminalized");
    assert.equal(result.lifecycleState, "missed");
    assert.equal(result.terminal, true);
    assert.equal(result.version, 2);
    assert.equal(millis(result.endedAt), processedAt.getTime());
    assert.equal(result.endReason, "ringing_timeout");
    assert.equal(result.failureCode, null);
    assert.deepEqual(result.lockReleaseResults, {
      caller: "released",
      callee: "released",
    });
    const call = await requiredData("calls/call_1");
    assert.equal(call.lifecycleState, "missed");
    assert.equal(call.terminal, true);
    assert.equal(call.version, 2);
    assert.equal(millis(call.endedAt), processedAt.getTime());
    assert.equal(call.endedByUid, null);
    assert.equal(call.endReason, "ringing_timeout");
    assert.equal(call.failureCode, null);
    assert.equal(call.historyVisible, true);
    assert.equal(
      millis(call.historyExpiresAt),
      processedAt.getTime() + PUBLIC_HISTORY_RETENTION_MS,
    );
    assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
    assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
  }
});

test("accepted-join timeout before deadline returns not_due", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  const call = await requiredData("calls/call_1");
  const before = await captureMutationState();

  const result = await processTimeout({
    now: new Date(millis(call.acceptedJoinDeadlineAt) - 1),
    request: timeoutRequest(
      "call_1",
      "accepted_join",
      2,
      call.acceptedJoinDeadlineAt,
    ),
  });

  assert.equal(result.status, "not_due");
  assert.equal(result.lifecycleState, "accepted");
  await assertMutationStateUnchanged(before);
});

test("accepted-join timeout at deadline creates failed with controlled fields", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  const call = await requiredData("calls/call_1");
  const processedAt = new Date(millis(call.acceptedJoinDeadlineAt));

  const result = await processTimeout({
    now: processedAt,
    request: timeoutRequest(
      "call_1",
      "accepted_join",
      2,
      call.acceptedJoinDeadlineAt,
    ),
  });

  assert.equal(result.status, "terminalized");
  assert.equal(result.lifecycleState, "failed");
  assert.equal(result.version, 3);
  assert.equal(result.endReason, "accepted_join_timeout");
  assert.equal(result.failureCode, "accepted_join_timeout");
  const updated = await requiredData("calls/call_1");
  assert.equal(updated.lifecycleState, "failed");
  assert.equal(updated.endReason, "accepted_join_timeout");
  assert.equal(updated.failureCode, "accepted_join_timeout");
  assert.equal(millis(updated.historyExpiresAt), processedAt.getTime() + PUBLIC_HISTORY_RETENTION_MS);
});

test("reconnect timeout before deadline returns not_due", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: deadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });
  const before = await captureMutationState();

  const result = await processTimeout({
    now: new Date(deadline.getTime() - 1),
    request: timeoutRequest("call_1", "reconnect", 3, deadline),
  });

  assert.equal(result.status, "not_due");
  assert.equal(result.lifecycleState, "active");
  await assertMutationStateUnchanged(before);
});

test("reconnect timeout at deadline creates failed with controlled fields", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: deadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });

  const result = await processTimeout({
    now: deadline,
    request: timeoutRequest("call_1", "reconnect", 3, deadline),
  });

  assert.equal(result.status, "terminalized");
  assert.equal(result.lifecycleState, "failed");
  assert.equal(result.version, 4);
  assert.equal(result.endReason, "reconnect_timeout");
  assert.equal(result.failureCode, "reconnect_timeout");
  const call = await requiredData("calls/call_1");
  assert.equal(call.lifecycleState, "failed");
  assert.equal(call.endReason, "reconnect_timeout");
  assert.equal(call.failureCode, "reconnect_timeout");
});

test("timeout missing, terminal, stale version, lifecycle, and deadline are no-op results", async () => {
  const missing = await processTimeout({
    request: timeoutRequest(
      "missing_call",
      "ringing",
      1,
      new Date(fixedMs() + RINGING_DURATION_MS),
    ),
  });
  assert.equal(missing.status, "missing");

  await seedUsers("caller", "callee");
  await startCall();
  await cancelCall();
  const terminalCall = await requiredData("calls/call_1");
  const terminalBefore = await captureMutationState();
  const alreadyTerminal = await processTimeout({
    request: timeoutRequest("call_1", "ringing", 1, terminalCall.ringingDeadlineAt),
  });
  assert.equal(alreadyTerminal.status, "already_terminal");
  await assertMutationStateUnchanged(terminalBefore);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await startCall();
  const ringingCall = await requiredData("calls/call_1");
  const staleCases = [
    {
      name: "version mismatch",
      request: timeoutRequest("call_1", "ringing", 999, ringingCall.ringingDeadlineAt),
    },
    {
      name: "deadline mismatch",
      request: timeoutRequest(
        "call_1",
        "ringing",
        1,
        new Date(millis(ringingCall.ringingDeadlineAt) + 1),
      ),
    },
  ];
  for (const testCase of staleCases) {
    const before = await captureMutationState();
    const result = await processTimeout({ request: testCase.request });
    assert.equal(result.status, "stale", testCase.name);
    await assertMutationStateUnchanged(before);
  }

  await acceptCall();
  const acceptedCall = await requiredData("calls/call_1");
  const lifecycleBefore = await captureMutationState();
  const lifecycleMismatch = await processTimeout({
    request: timeoutRequest("call_1", "ringing", 2, acceptedCall.ringingDeadlineAt),
  });
  assert.equal(lifecycleMismatch.status, "stale");
  await assertMutationStateUnchanged(lifecycleBefore);
});

test("timeout rejects malformed requests, deadlines, call schema, and callOps without writes", async () => {
  await assertCallError(
    ERROR_CODES.invalidArgument,
    () => processCallTimeoutV2({
      db,
      request: {
        ...timeoutRequest("call_1", "ringing", 1, FIXED_NOW),
        actorUid: "caller",
      },
      now: FIXED_NOW,
    }),
  );
  await assertCallError(
    ERROR_CODES.invalidArgument,
    () => processCallTimeoutV2({
      db,
      request: timeoutRequest("call_1", "ringing", 1, "bad"),
      now: FIXED_NOW,
    }),
  );

  const fieldDelete = admin.firestore.FieldValue.delete();
  const malformedDeadlineCases = [
    {
      name: "missing ringing deadline",
      setup: async () => {
        await startCall();
        await db.doc("calls/call_1").update({ ringingDeadlineAt: fieldDelete });
        return timeoutRequest("call_1", "ringing", 1, new Date(fixedMs()));
      },
    },
    {
      name: "malformed accepted deadline",
      setup: async () => {
        await startCall();
        await acceptCall();
        await db.doc("calls/call_1").update({ acceptedJoinDeadlineAt: "bad" });
        return timeoutRequest("call_1", "accepted_join", 2, new Date(fixedMs()));
      },
    },
    {
      name: "null reconnect deadline",
      setup: async () => {
        await promoteCallToActive();
        return timeoutRequest("call_1", "reconnect", 3, new Date(fixedMs()));
      },
    },
  ];
  for (const testCase of malformedDeadlineCases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    const request = await testCase.setup();
    const before = await captureMutationState();
    await assertCallError(
      ERROR_CODES.transactionFailed,
      processTimeout({ request }),
    );
    await assertMutationStateUnchanged(before);
  }

  await clearFirestore();
  await seedUsers("caller", "callee");
  await startCall();
  const deadline = (await requiredData("calls/call_1")).ringingDeadlineAt;
  await db.doc("calls/call_1").update({ schemaVersion: 3 });
  const badSchema = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processTimeout({ request: timeoutRequest("call_1", "ringing", 1, deadline) }),
  );
  await assertMutationStateUnchanged(badSchema);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await startCall();
  const call = await requiredData("calls/call_1");
  await db.doc("callOps/call_1").update({ latestOpsVersion: "bad" });
  const badOps = await captureMutationState();
    await assertCallError(
      ERROR_CODES.transactionFailed,
      processTimeout({
        now: new Date(millis(call.ringingDeadlineAt)),
        request: timeoutRequest("call_1", "ringing", 1, call.ringingDeadlineAt),
      }),
    );
  await assertMutationStateUnchanged(badOps);
});

test("timeout scoped lock release reports missing, mismatched, and missing-claim locks", async () => {
  const cases = [
    {
      name: "missing locks",
      mutate: async () => {
        await db.doc("activeCallLocks/caller").delete();
        await db.doc("activeCallLocks/callee").delete();
      },
      expected: {
        caller: "missing",
        callee: "missing",
      },
      assertLocks: async () => {
        assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
        assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
      },
    },
    {
      name: "unrelated locks",
      mutate: async () => {
        await db.doc("activeCallLocks/caller").update({ callId: "other_call" });
      },
      expected: {
        caller: "call_mismatch",
        callee: "released",
      },
      assertLocks: async () => {
        assert.equal((await requiredData("activeCallLocks/caller")).callId, "other_call");
        assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
      },
    },
    {
      name: "fencing mismatch",
      mutate: async () => {
        await db.doc("activeCallLocks/caller").update({ fencingToken: 999 });
      },
      expected: {
        caller: "fencing_mismatch",
        callee: "released",
      },
      assertLocks: async () => {
        assert.equal((await requiredData("activeCallLocks/caller")).fencingToken, 999);
        assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
      },
    },
    {
      name: "missing claim",
      mutate: async () => {
        await db.doc("callOps/call_1").update({
          "lockClaims.caller": admin.firestore.FieldValue.delete(),
        });
      },
      expected: {
        caller: "claim_missing",
        callee: "released",
      },
      assertLocks: async () => {
        assert.equal((await db.doc("activeCallLocks/caller").get()).exists, true);
        assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
      },
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await startCall();
    const call = await requiredData("calls/call_1");
    await testCase.mutate();

    const result = await processTimeout({
      now: new Date(millis(call.ringingDeadlineAt)),
      request: timeoutRequest("call_1", "ringing", 1, call.ringingDeadlineAt),
    });

    assert.deepEqual(result.lockReleaseResults, testCase.expected, testCase.name);
    assert.deepEqual(
      (await requiredData("callOps/call_1")).lockReleaseResults,
      testCase.expected,
    );
    await testCase.assertLocks();
  }
});

test("timeout updates callOps metadata and creates only private command record", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  const call = await requiredData("calls/call_1");
  const beforeOps = await requiredData("callOps/call_1");
  const beforeIdempotencySize = (await db.collection("callCommandKeys").get()).size;

  await processTimeout({
    now: new Date(millis(call.ringingDeadlineAt)),
    request: timeoutRequest("call_1", "ringing", 1, call.ringingDeadlineAt),
  });

  const updatedCall = await requiredData("calls/call_1");
  const ops = await requiredData("callOps/call_1");
  assert.equal(updatedCall.version, call.version + 1);
  assert.equal(ops.latestOpsVersion, beforeOps.latestOpsVersion + 1);
  assert.equal(millis(ops.terminalAt), millis(call.ringingDeadlineAt));
  assert.equal(ops.terminalState, "missed");
  assert.equal(ops.terminalReason, "ringing_timeout");
  assert.equal(ops.failureCode, null);
  assert.equal(ops.timeoutKind, "ringing");
  assert.equal(millis(ops.timeoutDeadlineAt), millis(call.ringingDeadlineAt));
  assert.equal(millis(ops.timeoutProcessedAt), millis(call.ringingDeadlineAt));
  assert.equal(
    millis(ops.opsRetentionExpiresAt),
    millis(call.ringingDeadlineAt) + OPS_RETENTION_MS,
  );
  assert.equal(await commandCountForAction("call_1", "processCallTimeout"), 1);
  assert.equal((await db.collection("callCommandKeys").get()).size, beforeIdempotencySize);
  assert.equal(updatedCall.timeoutKind, undefined);
  assert.equal(updatedCall.lockClaims, undefined);
});

test("duplicate timeout delivery replays original result and creates one command", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  const call = await requiredData("calls/call_1");
  const request = timeoutRequest("call_1", "ringing", 1, call.ringingDeadlineAt);

  const first = await processTimeout({
    now: new Date(millis(call.ringingDeadlineAt)),
    request,
  });
  const replay = await processTimeout({ now: new Date(millis(call.ringingDeadlineAt) + 1), request });

  assert.equal(first.status, "terminalized");
  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.status, "terminalized");
  assert.equal(replay.version, first.version);
  assert.equal(await commandCountForAction("call_1", "processCallTimeout"), 1);

  const command = (await db.collection("callOps/call_1/commands").get()).docs
    .find((doc) => doc.data().action === "processCallTimeout")
    .data();
  await db.doc(`callOps/call_1/commands/${command.commandId}`).update({
    status: "pending",
  });
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processTimeout({ now: new Date(millis(call.ringingDeadlineAt)), request }),
  );
});

test("timeout lifecycle races produce one authoritative outcome", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  let call = await requiredData("calls/call_1");
  let results = await Promise.allSettled([
    processTimeout({
      now: new Date(millis(call.ringingDeadlineAt)),
      request: timeoutRequest("call_1", "ringing", 1, call.ringingDeadlineAt),
    }),
    acceptCall({ request: lifecycleRequest("call_1", "accept_timeout_race") }),
  ]);
  await assertTimeoutRaceOutcome(results, ["accepted", "missed"]);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await startCall();
  call = await requiredData("calls/call_1");
  results = await Promise.allSettled([
    processTimeout({
      now: new Date(millis(call.ringingDeadlineAt)),
      request: timeoutRequest("call_1", "ringing", 1, call.ringingDeadlineAt),
    }),
    cancelCall({ request: lifecycleRequest("call_1", "cancel_timeout_race") }),
  ]);
  await assertTimeoutRaceOutcome(results, ["cancelled", "missed"]);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "caller_joined_before_timeout"),
  });
  call = await requiredData("calls/call_1");
  results = await Promise.allSettled([
    processTimeout({
      now: new Date(millis(call.acceptedJoinDeadlineAt)),
      request: timeoutRequest(
        "call_1",
        "accepted_join",
        2,
        call.acceptedJoinDeadlineAt,
      ),
    }),
    reportMedia({
      authUid: "callee",
      mediaState: "joined",
      request: mediaRequest("call_1", "joined", "callee_join_timeout_race"),
    }),
  ]);
  await assertTimeoutRaceOutcome(results, ["active", "failed"]);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const reconnectDeadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: reconnectDeadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });
  results = await Promise.allSettled([
    processTimeout({
      now: reconnectDeadline,
      request: timeoutRequest("call_1", "reconnect", 3, reconnectDeadline),
    }),
    reportMedia({
      now: new Date(reconnectDeadline.getTime() - 1),
      mediaState: "joined",
      request: mediaRequest("call_1", "joined", "recover_timeout_race"),
    }),
  ]);
  await assertTimeoutRaceOutcome(results, ["active", "failed"]);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const endDeadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: endDeadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });
  results = await Promise.allSettled([
    processTimeout({
      now: endDeadline,
      request: timeoutRequest("call_1", "reconnect", 3, endDeadline),
    }),
    endCall({
      now: endDeadline,
      request: lifecycleRequest("call_1", "end_timeout_race"),
    }),
  ]);
  await assertTimeoutRaceOutcome(results, ["completed", "failed"]);
});

test("stale old reconnect task cannot terminalize newer reconnect generation", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const oldDeadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  const newDeadline = new Date(oldDeadline.getTime() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: newDeadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });
  await db.doc("calls/call_1").update({ version: 4 });
  const before = await captureMutationState();

  const result = await processTimeout({
    now: new Date(oldDeadline.getTime() + 1),
    request: timeoutRequest("call_1", "reconnect", 3, oldDeadline),
  });

  assert.equal(result.status, "stale");
  await assertMutationStateUnchanged(before);
});

test("reconnect timeout rejects malformed participants and joined inconsistency", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  let deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await setActiveReconnectScenario({
    reconnectDeadlineAt: deadline,
    callerMediaState: "reconnecting",
    calleeMediaState: "joined",
  });
  await db.doc("calls/call_1/participants/caller").update({ role: "callee" });
  let before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processTimeout({
      now: deadline,
      request: timeoutRequest("call_1", "reconnect", 3, deadline),
    }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  deadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await db.doc("calls/call_1").update({ reconnectDeadlineAt: deadline });
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processTimeout({
      now: deadline,
      request: timeoutRequest("call_1", "reconnect", 3, deadline),
    }),
  );
  await assertMutationStateUnchanged(before);
});

test("accepted call promotes to active only after both participants joined", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  const callerLockBefore = await requiredData("activeCallLocks/caller");
  const calleeLockBefore = await requiredData("activeCallLocks/callee");

  const first = await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "caller_joined"),
  });
  assert.equal(first.promotedToActive, false);
  assert.equal(first.callVersion, 2);
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "accepted");

  const second = await reportMedia({
    authUid: "callee",
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "callee_joined"),
  });

  assert.equal(second.promotedToActive, true);
  assert.equal(second.lifecycleState, "active");
  assert.equal(second.callVersion, 3);
  assert.equal(millis(second.activeAt), fixedMs());
  const call = await requiredData("calls/call_1");
  assert.equal(call.lifecycleState, "active");
  assert.equal(call.version, 3);
  assert.equal(millis(call.activeAt), fixedMs());
  assert.equal((await requiredData("activeCallLocks/caller")).state, "active");
  assert.equal((await requiredData("activeCallLocks/callee")).state, "active");
  assert.equal(
    millis((await requiredData("activeCallLocks/caller")).expiresAt),
    fixedMs() + ACTIVE_LEASE_DURATION_MS,
  );
  assert.equal(
    millis((await requiredData("activeCallLocks/callee")).expiresAt),
    fixedMs() + ACTIVE_LEASE_DURATION_MS,
  );
  assert.equal(
    (await requiredData("activeCallLocks/caller")).fencingToken,
    callerLockBefore.fencingToken,
  );
  assert.equal(
    (await requiredData("activeCallLocks/callee")).fencingToken,
    calleeLockBefore.fencingToken,
  );
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).heartbeatVersion,
    0,
  );
  assert.equal(
    (await requiredData("calls/call_1/participants/callee")).heartbeatVersion,
    0,
  );
});

test("caller heartbeat renews only caller lock with exact versions and ops", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const heartbeatAt = new Date(fixedMs() + 10 * 1000);
  const beforeCall = await requiredData("calls/call_1");
  const beforeOps = await requiredData("callOps/call_1");
  const beforeCaller = await requiredData("calls/call_1/participants/caller");
  const beforeCallee = await requiredData("calls/call_1/participants/callee");
  const beforeCallerLock = await requiredData("activeCallLocks/caller");
  const beforeCalleeLock = await requiredData("activeCallLocks/callee");

  const result = await renewLease({
    now: heartbeatAt,
    request: heartbeatRequest("call_1", 1, "caller_heartbeat_1"),
  });

  assert.equal(result.callId, "call_1");
  assert.equal(result.participantUid, "caller");
  assert.equal(result.heartbeatVersion, 1);
  assert.equal(millis(result.lastHeartbeatAt), heartbeatAt.getTime());
  assert.equal(
    millis(result.leaseExpiresAt),
    heartbeatAt.getTime() + ACTIVE_LEASE_DURATION_MS,
  );
  assert.equal(result.lifecycleState, "active");
  assert.equal(result.callVersion, beforeCall.version);
  assert.equal(result.idempotentReplay, false);

  const caller = await requiredData("calls/call_1/participants/caller");
  const callee = await requiredData("calls/call_1/participants/callee");
  assert.equal(caller.heartbeatVersion, 1);
  assert.equal(caller.mediaVersion, beforeCaller.mediaVersion);
  assert.equal(caller.mediaState, beforeCaller.mediaState);
  assert.equal(millis(caller.lastHeartbeatAt), heartbeatAt.getTime());
  assert.deepEqual(
    normalizeFirestoreData(callee),
    normalizeFirestoreData(beforeCallee),
  );

  const callerLock = await requiredData("activeCallLocks/caller");
  const calleeLock = await requiredData("activeCallLocks/callee");
  assert.equal(callerLock.state, "active");
  assert.equal(callerLock.fencingToken, beforeCallerLock.fencingToken);
  assert.equal(millis(callerLock.updatedAt), heartbeatAt.getTime());
  assert.equal(
    millis(callerLock.expiresAt),
    heartbeatAt.getTime() + ACTIVE_LEASE_DURATION_MS,
  );
  assert.deepEqual(
    normalizeFirestoreData(calleeLock),
    normalizeFirestoreData(beforeCalleeLock),
  );

  const call = await requiredData("calls/call_1");
  const ops = await requiredData("callOps/call_1");
  assert.equal(call.version, beforeCall.version);
  assert.equal(call.lifecycleState, "active");
  assert.equal(call.reconnectDeadlineAt, null);
  assert.equal(ops.latestOpsVersion, beforeOps.latestOpsVersion + 1);
  assert.equal(
    millis(ops.opsRetentionExpiresAt),
    heartbeatAt.getTime() + OPS_RETENTION_MS,
  );
  assert.equal(await commandCountForAction("call_1", "renewActiveCallLease"), 1);
  for (const publicDoc of [call, caller]) {
    assert.equal(publicDoc.commandId, undefined);
    assert.equal(publicDoc.idempotencyKey, undefined);
    assert.equal(publicDoc.lockClaims, undefined);
    assertNoPrivatePublicFields(publicDoc);
  }
});

test("callee heartbeat renews only callee lock", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const heartbeatAt = new Date(fixedMs() + 15 * 1000);
  const beforeCallerLock = await requiredData("activeCallLocks/caller");

  const result = await renewLease({
    authUid: "callee",
    now: heartbeatAt,
    request: heartbeatRequest("call_1", 1, "callee_heartbeat_1"),
  });

  assert.equal(result.participantUid, "callee");
  assert.equal(result.heartbeatVersion, 1);
  assert.deepEqual(
    normalizeFirestoreData(await requiredData("activeCallLocks/caller")),
    normalizeFirestoreData(beforeCallerLock),
  );
  const calleeLock = await requiredData("activeCallLocks/callee");
  assert.equal(millis(calleeLock.updatedAt), heartbeatAt.getTime());
  assert.equal(
    millis(calleeLock.expiresAt),
    heartbeatAt.getTime() + ACTIVE_LEASE_DURATION_MS,
  );
  assert.equal(
    (await requiredData("calls/call_1/participants/callee")).heartbeatVersion,
    1,
  );
});

test("heartbeat idempotency replays, conflicts, and handles duplicate concurrency", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();

  const first = await renewLease({
    request: heartbeatRequest("call_1", 1, "heartbeat_replay"),
  });
  const replay = await renewLease({
    request: heartbeatRequest("call_1", 1, "heartbeat_replay"),
  });
  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.heartbeatVersion, first.heartbeatVersion);
  assert.equal(millis(replay.leaseExpiresAt), millis(first.leaseExpiresAt));
  await assertCallError(
    ERROR_CODES.idempotencyConflict,
    renewLease({
      request: heartbeatRequest("call_1", 2, "heartbeat_replay"),
    }),
  );

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const results = await Promise.all([
    renewLease({ request: heartbeatRequest("call_1", 1, "heartbeat_dupe") }),
    renewLease({ request: heartbeatRequest("call_1", 1, "heartbeat_dupe") }),
  ]);

  assert.equal(results.filter((result) => result.idempotentReplay).length, 1);
  assert.equal(
    results.filter((result) => !result.idempotentReplay).length,
    1,
  );
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).heartbeatVersion,
    1,
  );
  assert.equal(await commandCountForAction("call_1", "renewActiveCallLease"), 1);
});

test("heartbeat rejects old and skipped versions without renewing", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await renewLease({ request: heartbeatRequest("call_1", 1, "heartbeat_first") });
  let before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.invalidState,
    renewLease({ request: heartbeatRequest("call_1", 1, "heartbeat_old") }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.invalidState,
    renewLease({ request: heartbeatRequest("call_1", 2, "heartbeat_skipped") }),
  );
  await assertMutationStateUnchanged(before);
});

test("heartbeat rejects invalid actors, lifecycles, and media states", async () => {
  await seedUsers("caller", "callee", "other");
  await promoteCallToActive();
  await db.doc("calls/call_1/participants/caller").update({ role: "callee" });
  let before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    renewLease({ request: heartbeatRequest("call_1", 1, "wrong_role") }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee", "other");
  await promoteCallToActive();
  await assertCallError(
    ERROR_CODES.forbidden,
    renewLease({
      authUid: "other",
      request: heartbeatRequest("call_1", 1, "nonparticipant"),
    }),
  );

  const lifecycleCases = [
    {
      name: "ringing",
      setup: async () => startCall(),
    },
    {
      name: "accepted",
      setup: async () => {
        await startCall();
        await acceptCall();
      },
    },
    {
      name: "terminal",
      setup: async () => {
        await promoteCallToActive();
        await endCall();
      },
    },
  ];
  for (const testCase of lifecycleCases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await testCase.setup();
    before = await captureMutationState();
    await assertCallError(
      ERROR_CODES.invalidState,
      renewLease({
        request: heartbeatRequest("call_1", 1, `heartbeat_${testCase.name}`),
      }),
    );
    await assertMutationStateUnchanged(before);
  }

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await db.doc("calls/call_1/participants/caller").update({
    mediaState: "disconnected",
    mediaVersion: 2,
  });
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.invalidState,
    renewLease({ request: heartbeatRequest("call_1", 1, "bad_media_state") }),
  );
  await assertMutationStateUnchanged(before);
});

test("heartbeat lock validation and deadline boundaries are authoritative", async () => {
  const lockCases = [
    {
      name: "missing lock",
      mutate: () => db.doc("activeCallLocks/caller").delete(),
    },
    {
      name: "mismatched lock",
      mutate: () => db.doc("activeCallLocks/caller").update({ callId: "other" }),
    },
    {
      name: "missing claim",
      mutate: () =>
        db.doc("callOps/call_1").update({
          "lockClaims.caller": admin.firestore.FieldValue.delete(),
        }),
    },
    {
      name: "wrong state",
      mutate: () => db.doc("activeCallLocks/caller").update({ state: "accepted" }),
    },
  ];
  for (const testCase of lockCases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    await testCase.mutate();
    const before = await captureMutationState();
    await assertCallError(
      ERROR_CODES.lockRecoveryRequired,
      renewLease({
        request: heartbeatRequest("call_1", 1, `heartbeat_${testCase.name}`),
      }),
    );
    await assertMutationStateUnchanged(before);
  }

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  let lock = await requiredData("activeCallLocks/caller");
  const beforeExpiry = await renewLease({
    now: new Date(millis(lock.expiresAt) - 1),
    request: heartbeatRequest("call_1", 1, "heartbeat_before_expiry"),
  });
  assert.equal(beforeExpiry.heartbeatVersion, 1);

  for (const offsetMs of [0, 1]) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    lock = await requiredData("activeCallLocks/caller");
    const before = await captureMutationState();
    await assertCallError(
      ERROR_CODES.invalidState,
      renewLease({
        now: new Date(millis(lock.expiresAt) + offsetMs),
        request: heartbeatRequest(
          "call_1",
          1,
          `heartbeat_expired_${offsetMs}`,
        ),
      }),
    );
    await assertMutationStateUnchanged(before);
  }

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const reconnectDeadline = new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS);
  await db.doc("calls/call_1").update({ reconnectDeadlineAt: reconnectDeadline });
  const openReconnect = await renewLease({
    now: new Date(reconnectDeadline.getTime() - 1),
    request: heartbeatRequest("call_1", 1, "heartbeat_open_reconnect"),
  });
  assert.equal(openReconnect.heartbeatVersion, 1);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await db.doc("calls/call_1").update({ reconnectDeadlineAt: reconnectDeadline });
  const before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.invalidState,
    renewLease({
      now: reconnectDeadline,
      request: heartbeatRequest("call_1", 1, "heartbeat_expired_reconnect"),
    }),
  );
  await assertMutationStateUnchanged(before);
});

test("active lease timeout before expiry returns not_due without writes", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const request = await activeLeaseTimeoutRequestFromState("caller");
  const before = await captureMutationState();

  const result = await processActiveLeaseTimeout({
    now: new Date(millis(request.expectedLeaseExpiresAt) - 1),
    request,
  });

  assert.equal(result.status, "not_due");
  assert.equal(result.lifecycleState, "active");
  await assertMutationStateUnchanged(before);
  assert.equal(
    await commandCountForAction("call_1", "processActiveLeaseTimeout"),
    0,
  );
});

test("active lease timeout at and after expiry terminalizes exactly", async () => {
  for (const offsetMs of [0, 1]) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    const request = await activeLeaseTimeoutRequestFromState("caller");
    const processedAt = new Date(millis(request.expectedLeaseExpiresAt) + offsetMs);
    const beforeOps = await requiredData("callOps/call_1");
    const beforeIdempotencySize = (await db.collection("callCommandKeys").get()).size;

    const result = await processActiveLeaseTimeout({
      now: processedAt,
      request,
    });

    assert.equal(result.status, "terminalized");
    assert.equal(result.timeoutKind, "active_lease");
    assert.equal(result.lifecycleState, "failed");
    assert.equal(result.terminal, true);
    assert.equal(result.version, 4);
    assert.equal(millis(result.endedAt), processedAt.getTime());
    assert.equal(result.endReason, "active_lease_timeout");
    assert.equal(result.failureCode, "active_lease_timeout");
    assert.deepEqual(result.lockReleaseResults, {
      caller: "released",
      callee: "released",
    });

    const call = await requiredData("calls/call_1");
    const ops = await requiredData("callOps/call_1");
    assert.equal(call.lifecycleState, "failed");
    assert.equal(call.terminal, true);
    assert.equal(call.version, 4);
    assert.equal(call.endedByUid, null);
    assert.equal(call.endReason, "active_lease_timeout");
    assert.equal(call.failureCode, "active_lease_timeout");
    assert.equal(call.historyVisible, true);
    assert.equal(
      millis(call.historyExpiresAt),
      processedAt.getTime() + PUBLIC_HISTORY_RETENTION_MS,
    );
    assert.equal(ops.latestOpsVersion, beforeOps.latestOpsVersion + 1);
    assert.equal(millis(ops.terminalAt), processedAt.getTime());
    assert.equal(ops.terminalState, "failed");
    assert.equal(ops.terminalReason, "active_lease_timeout");
    assert.equal(ops.failureCode, "active_lease_timeout");
    assert.equal(ops.timeoutKind, "active_lease");
    assert.equal(ops.timeoutParticipantUid, "caller");
    assert.equal(
      millis(ops.timeoutDeadlineAt),
      millis(request.expectedLeaseExpiresAt),
    );
    assert.equal(millis(ops.timeoutProcessedAt), processedAt.getTime());
    assert.deepEqual(ops.lockReleaseResults, {
      caller: "released",
      callee: "released",
    });
    assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
    assert.equal((await db.doc("activeCallLocks/callee").get()).exists, false);
    assert.equal(
      await commandCountForAction("call_1", "processActiveLeaseTimeout"),
      1,
    );
    assert.equal((await db.collection("callCommandKeys").get()).size, beforeIdempotencySize);
  }
});

test("active lease timeout scoped release preserves unrelated peer locks", async () => {
  const cases = [
    {
      name: "peer call mismatch",
      mutate: () =>
        db.doc("activeCallLocks/callee").update({ callId: "other_call" }),
      expected: {
        caller: "released",
        callee: "call_mismatch",
      },
      assertLocks: async () => {
        assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
        assert.equal((await requiredData("activeCallLocks/callee")).callId, "other_call");
      },
    },
    {
      name: "peer fencing mismatch",
      mutate: () =>
        db.doc("activeCallLocks/callee").update({ fencingToken: 999 }),
      expected: {
        caller: "released",
        callee: "fencing_mismatch",
      },
      assertLocks: async () => {
        assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
        assert.equal((await requiredData("activeCallLocks/callee")).fencingToken, 999);
      },
    },
    {
      name: "peer claim missing",
      mutate: () =>
        db.doc("callOps/call_1").update({
          "lockClaims.callee": admin.firestore.FieldValue.delete(),
        }),
      expected: {
        caller: "released",
        callee: "claim_missing",
      },
      assertLocks: async () => {
        assert.equal((await db.doc("activeCallLocks/caller").get()).exists, false);
        assert.equal((await db.doc("activeCallLocks/callee").get()).exists, true);
      },
    },
  ];

  for (const testCase of cases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    const request = await activeLeaseTimeoutRequestFromState("caller");
    await testCase.mutate();

    const result = await processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    });

    assert.deepEqual(result.lockReleaseResults, testCase.expected, testCase.name);
    assert.deepEqual(
      (await requiredData("callOps/call_1")).lockReleaseResults,
      testCase.expected,
    );
    await testCase.assertLocks();
  }
});

test("active lease timeout safe no-op stale statuses create no command", async () => {
  const missing = await processActiveLeaseTimeout({
    request: activeLeaseTimeoutRequest(
      "missing_call",
      "caller",
      3,
      0,
      1,
      new Date(fixedMs() + ACTIVE_LEASE_DURATION_MS),
    ),
  });
  assert.equal(missing.status, "missing");

  await seedUsers("caller", "callee");
  await promoteCallToActive();
  let request = await activeLeaseTimeoutRequestFromState("caller");
  await endCall();
  let before = await captureMutationState();
  let result = await processActiveLeaseTimeout({
    now: new Date(millis(request.expectedLeaseExpiresAt)),
    request,
  });
  assert.equal(result.status, "already_terminal");
  await assertMutationStateUnchanged(before);

  const staleCases = [
    {
      name: "changed call version",
      mutate: async () => db.doc("calls/call_1").update({ version: 4 }),
    },
    {
      name: "renewed heartbeat",
      mutate: async () =>
        db.doc("calls/call_1/participants/caller").update({
          heartbeatVersion: 1,
          lastHeartbeatAt: FIXED_NOW,
        }),
    },
    {
      name: "renewed lock expiry",
      mutate: async () =>
        db.doc("activeCallLocks/caller").update({
          expiresAt: new Date(millis(request.expectedLeaseExpiresAt) + 1000),
        }),
    },
    {
      name: "reconnect deadline",
      mutate: async () =>
        db.doc("calls/call_1").update({
          reconnectDeadlineAt: new Date(fixedMs() + RECONNECT_GRACE_DURATION_MS),
        }),
    },
  ];

  for (const testCase of staleCases) {
    await clearFirestore();
    await seedUsers("caller", "callee");
    await promoteCallToActive();
    request = await activeLeaseTimeoutRequestFromState("caller");
    await testCase.mutate();
    before = await captureMutationState();
    result = await processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt) + 1),
      request,
    });
    assert.equal(result.status, "stale", testCase.name);
    await assertMutationStateUnchanged(before);
    assert.equal(
      await commandCountForAction("call_1", "processActiveLeaseTimeout"),
      0,
    );
  }
});

test("active lease timeout handles fencing changes and duplicate delivery", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  let request = await activeLeaseTimeoutRequestFromState("caller");
  await db.doc("activeCallLocks/caller").update({ fencingToken: 2 });
  await db.doc("callOps/call_1").update({
    "lockClaims.caller.fencingToken": 2,
  });
  let before = await captureMutationState();
  let result = await processActiveLeaseTimeout({
    now: new Date(millis(request.expectedLeaseExpiresAt)),
    request,
  });
  assert.equal(result.status, "stale");
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  request = await activeLeaseTimeoutRequestFromState("caller");
  await db.doc("activeCallLocks/caller").update({ fencingToken: 2 });
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  request = await activeLeaseTimeoutRequestFromState("caller");
  const first = await processActiveLeaseTimeout({
    now: new Date(millis(request.expectedLeaseExpiresAt)),
    request,
  });
  const replay = await processActiveLeaseTimeout({
    now: new Date(millis(request.expectedLeaseExpiresAt) + 1),
    request,
  });
  assert.equal(first.status, "terminalized");
  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.status, "terminalized");
  assert.equal(replay.version, first.version);
  assert.equal(
    await commandCountForAction("call_1", "processActiveLeaseTimeout"),
    1,
  );

  const command = (await db.collection("callOps/call_1/commands").get()).docs
    .find((doc) => doc.data().action === "processActiveLeaseTimeout")
    .data();
  await db.doc(`callOps/call_1/commands/${command.commandId}`).update({
    status: "pending",
  });
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
  );
});

test("active lease timeout rejects malformed active heartbeat state", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  let request = await activeLeaseTimeoutRequestFromState("caller");
  await db.doc("calls/call_1/participants/callee").update({
    mediaState: "reconnecting",
    mediaVersion: 2,
  });
  let before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await db.doc("calls/call_1/participants/caller").update({
    heartbeatVersion: 1,
    lastHeartbeatAt: null,
  });
  request = await activeLeaseTimeoutRequestFromState("caller");
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
  );
  await assertMutationStateUnchanged(before);
});

test("active lease services reject missing or malformed participant documents", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await db.doc("calls/call_1/participants/caller").delete();
  let before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    renewLease({ request: heartbeatRequest("call_1", 1, "missing_participant") }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  let request = await activeLeaseTimeoutRequestFromState("caller");
  await db.doc("calls/call_1/participants/callee").delete();
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await db.doc("calls/call_1/participants/caller").update({
    heartbeatVersion: "bad",
  });
  request = activeLeaseTimeoutRequest(
    "call_1",
    "caller",
    3,
    0,
    (await requiredData("activeCallLocks/caller")).fencingToken,
    (await requiredData("activeCallLocks/caller")).expiresAt,
  );
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.transactionFailed,
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
  );
  await assertMutationStateUnchanged(before);
});

test("malformed active lease lock claims do not repair or delete unrelated locks", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  await db.doc("callOps/call_1").update({
    "lockClaims.caller.fencingToken": "bad",
  });
  let before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    renewLease({ request: heartbeatRequest("call_1", 1, "bad_claim_heartbeat") }),
  );
  await assertMutationStateUnchanged(before);

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const request = await activeLeaseTimeoutRequestFromState("caller");
  await db.doc("callOps/call_1").update({
    "lockClaims.caller": admin.firestore.FieldValue.delete(),
  });
  before = await captureMutationState();
  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
  );
  await assertMutationStateUnchanged(before);
  assert.equal((await db.doc("activeCallLocks/callee").get()).exists, true);
});

test("old active lease timeout cannot terminalize after successful heartbeat", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const oldRequest = await activeLeaseTimeoutRequestFromState("caller");
  await renewLease({
    now: new Date(millis(oldRequest.expectedLeaseExpiresAt) - 1),
    request: heartbeatRequest("call_1", 1, "renew_before_old_timeout"),
  });
  const before = await captureMutationState();

  const result = await processActiveLeaseTimeout({
    now: new Date(millis(oldRequest.expectedLeaseExpiresAt) + 1),
    request: oldRequest,
  });

  assert.equal(result.status, "stale");
  await assertMutationStateUnchanged(before);
  assert.equal(
    await commandCountForAction("call_1", "processActiveLeaseTimeout"),
    0,
  );
});

test("heartbeat versus active lease timeout race produces one authoritative outcome", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  const request = await activeLeaseTimeoutRequestFromState("caller");
  const results = await Promise.allSettled([
    processActiveLeaseTimeout({
      now: new Date(millis(request.expectedLeaseExpiresAt)),
      request,
    }),
    renewLease({
      now: new Date(millis(request.expectedLeaseExpiresAt) - 1),
      request: heartbeatRequest("call_1", 1, "heartbeat_timeout_race"),
    }),
  ]);

  await assertActiveLeaseRaceOutcome(results, ["active", "failed"]);
  const call = await requiredData("calls/call_1");
  if (call.lifecycleState === "active") {
    assert.equal(
      (await requiredData("calls/call_1/participants/caller")).heartbeatVersion,
      1,
    );
    assert.equal(
      await commandCountForAction("call_1", "processActiveLeaseTimeout"),
      0,
    );
  } else {
    assert.equal(call.endReason, "active_lease_timeout");
    assert.equal(
      await commandCountForAction("call_1", "processActiveLeaseTimeout"),
      1,
    );
  }
});

test("racing active lease timeouts and participant end create one terminal transition", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  let callerRequest = await activeLeaseTimeoutRequestFromState("caller");
  let calleeRequest = await activeLeaseTimeoutRequestFromState("callee");
  let results = await Promise.allSettled([
    processActiveLeaseTimeout({
      now: new Date(millis(callerRequest.expectedLeaseExpiresAt)),
      request: callerRequest,
    }),
    processActiveLeaseTimeout({
      now: new Date(millis(calleeRequest.expectedLeaseExpiresAt)),
      request: calleeRequest,
    }),
  ]);

  await assertActiveLeaseRaceOutcome(results, ["failed"]);
  let call = await requiredData("calls/call_1");
  assert.equal(call.terminal, true);
  assert.equal(call.version, 4);
  assert.equal(
    await commandCountForAction("call_1", "processActiveLeaseTimeout"),
    1,
  );

  await clearFirestore();
  await seedUsers("caller", "callee");
  await promoteCallToActive();
  callerRequest = await activeLeaseTimeoutRequestFromState("caller");
  results = await Promise.allSettled([
    processActiveLeaseTimeout({
      now: new Date(millis(callerRequest.expectedLeaseExpiresAt)),
      request: callerRequest,
    }),
    endCall({
      now: new Date(millis(callerRequest.expectedLeaseExpiresAt)),
      request: lifecycleRequest("call_1", "end_active_lease_race"),
    }),
  ]);

  await assertActiveLeaseRaceOutcome(results, ["completed", "failed"]);
  call = await requiredData("calls/call_1");
  assert.equal(call.terminal, true);
  assert.equal(call.version, 4);
  assert.ok(["completed", "failed"].includes(call.lifecycleState));
});

test("same-state joined report still evaluates active promotion", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  await db.doc("calls/call_1/participants/caller").update({
    mediaState: "joined",
    mediaVersion: 1,
    mediaJoinedAt: FIXED_NOW,
    lastMediaStateAt: FIXED_NOW,
  });
  await db.doc("calls/call_1/participants/callee").update({
    mediaState: "joined",
    mediaVersion: 1,
    mediaJoinedAt: FIXED_NOW,
    lastMediaStateAt: FIXED_NOW,
  });

  const result = await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "noop_promotes"),
  });

  assert.equal(result.mediaChanged, false);
  assert.equal(result.promotedToActive, true);
  assert.equal(result.lifecycleState, "active");
  assert.equal((await requiredData("calls/call_1")).lifecycleState, "active");
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).mediaVersion,
    1,
  );
});

test("promotion failure rolls back the triggering participant update", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "caller_ready"),
  });
  await db.doc("activeCallLocks/callee").update({ fencingToken: 999 });
  const before = await captureMutationState();

  await assertCallError(
    ERROR_CODES.lockRecoveryRequired,
    reportMedia({
      authUid: "callee",
      mediaState: "joined",
      request: mediaRequest("call_1", "joined", "callee_bad_lock"),
    }),
  );

  await assertMutationStateUnchanged(before);
});

test("concurrent joined reports promote exactly once", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  const results = await Promise.all([
    reportMedia({
      mediaState: "joined",
      request: mediaRequest("call_1", "joined", "caller_concurrent_join"),
    }),
    reportMedia({
      authUid: "callee",
      mediaState: "joined",
      request: mediaRequest("call_1", "joined", "callee_concurrent_join"),
    }),
  ]);

  assert.equal(results.filter((result) => result.promotedToActive).length, 1);
  const call = await requiredData("calls/call_1");
  assert.equal(call.lifecycleState, "active");
  assert.equal(call.version, 3);
});

test("concurrent duplicate media report creates one transition and one replay", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  const results = await Promise.all([
    reportMedia({
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "dup_media"),
    }),
    reportMedia({
      mediaState: "preparing",
      request: mediaRequest("call_1", "preparing", "dup_media"),
    }),
  ]);

  assert.equal(results.filter((result) => result.idempotentReplay).length, 1);
  assert.equal(
    results.filter(
      (result) => !result.idempotentReplay && result.mediaChanged,
    ).length,
    1,
  );
  assert.equal((await requiredData("calls/call_1/participants/caller")).mediaVersion, 1);
  assert.equal(await commandCountForAction("call_1", "reportParticipantMedia"), 1);
});

test("active reconnect deadline set, preserved, and cleared with versions", async () => {
  await seedUsers("caller", "callee");
  await promoteCallToActive();

  const reconnecting = await reportMedia({
    mediaState: "reconnecting",
    request: mediaRequest("call_1", "reconnecting", "caller_reconnecting"),
  });
  assert.equal(reconnecting.callVersion, 4);
  assert.equal(
    millis(reconnecting.reconnectDeadlineAt),
    fixedMs() + RECONNECT_GRACE_DURATION_MS,
  );

  await reportMedia({
    mediaState: "reconnecting",
    request: mediaRequest("call_1", "reconnecting", "caller_reconnecting_noop"),
  });
  assert.equal((await requiredData("calls/call_1")).version, 4);
  assert.equal(
    millis((await requiredData("calls/call_1")).reconnectDeadlineAt),
    fixedMs() + RECONNECT_GRACE_DURATION_MS,
  );

  await reportMedia({
    authUid: "callee",
    mediaState: "disconnected",
    request: mediaRequest("call_1", "disconnected", "callee_disconnect"),
  });
  assert.equal((await requiredData("calls/call_1")).version, 4);
  assert.equal(
    millis((await requiredData("calls/call_1")).reconnectDeadlineAt),
    fixedMs() + RECONNECT_GRACE_DURATION_MS,
  );

  await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "caller_rejoined"),
  });
  assert.equal((await requiredData("calls/call_1")).version, 4);
  const cleared = await reportMedia({
    authUid: "callee",
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "callee_rejoined"),
  });
  assert.equal(cleared.callVersion, 5);
  assert.equal(cleared.reconnectDeadlineAt, null);
  assert.equal((await requiredData("calls/call_1")).reconnectDeadlineAt, null);
});

test("media failure uses controlled code and recovery clears it", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();

  await reportMedia({
    mediaState: "media_failed",
    request: mediaRequest("call_1", "media_failed", "media_failed"),
  });
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).failureCode,
    "client_reported_media_failure",
  );

  await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "media_recovered"),
  });
  assert.equal(
    (await requiredData("calls/call_1/participants/caller")).failureCode,
    null,
  );
});

test("terminal call rejects new media report but replays prior report", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  const first = await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "before_terminal"),
  });
  await endCall();

  await assertCallError(
    ERROR_CODES.invalidState,
    reportMedia({
      mediaState: "joining",
      request: mediaRequest("call_1", "joining", "after_terminal"),
    }),
  );
  const replay = await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "before_terminal"),
  });
  assert.equal(replay.idempotentReplay, true);
  assert.equal(replay.mediaVersion, first.mediaVersion);
});

test("media command records stay private and callOps increments once per command", async () => {
  await seedUsers("caller", "callee");
  await startCall();
  await acceptCall();
  const beforeOpsVersion = (await requiredData("callOps/call_1")).latestOpsVersion;

  await reportMedia({
    mediaState: "preparing",
    request: mediaRequest("call_1", "preparing", "private_media_command"),
  });

  const call = await requiredData("calls/call_1");
  const participant = await requiredData("calls/call_1/participants/caller");
  const ops = await requiredData("callOps/call_1");
  assert.equal(ops.latestOpsVersion, beforeOpsVersion + 1);
  assert.equal(await commandCountForAction("call_1", "reportParticipantMedia"), 1);
  for (const publicDoc of [call, participant]) {
    assert.equal(publicDoc.commandId, undefined);
    assert.equal(publicDoc.idempotencyKey, undefined);
    assert.equal(publicDoc.lockClaims, undefined);
    assert.equal(publicDoc.diagnostics, undefined);
  }
});

test("exports the expected stable error code vocabulary", () => {
  assert.deepEqual(Object.values(ERROR_CODES).sort(), [
    "call_id_conflict",
    "call_not_found",
    "callee_not_found",
    "forbidden",
    "idempotency_conflict",
    "invalid_argument",
    "invalid_state",
    "lock_recovery_required",
    "transaction_failed",
    "unauthenticated",
    "user_busy",
  ]);
});

function acceptCall(overrides = {}) {
  return acceptCallV2({
    db,
    authUid: overrides.authUid || "callee",
    request: overrides.request || lifecycleRequest("call_1", "accept_1"),
    now: overrides.now || FIXED_NOW,
  });
}

function declineCall(overrides = {}) {
  return declineCallV2({
    db,
    authUid: overrides.authUid || "callee",
    request: overrides.request || lifecycleRequest("call_1", "decline_1"),
    now: overrides.now || FIXED_NOW,
  });
}

function cancelCall(overrides = {}) {
  return cancelCallV2({
    db,
    authUid: overrides.authUid || "caller",
    request: overrides.request || lifecycleRequest("call_1", "cancel_1"),
    now: overrides.now || FIXED_NOW,
  });
}

function endCall(overrides = {}) {
  return endCallV2({
    db,
    authUid: overrides.authUid || "caller",
    request: overrides.request || lifecycleRequest("call_1", "end_1"),
    now: overrides.now || FIXED_NOW,
  });
}

function reportMedia(overrides = {}) {
  const mediaState = overrides.mediaState || "preparing";
  return reportParticipantMediaV2({
    db,
    authUid: overrides.authUid || "caller",
    request: overrides.request || mediaRequest("call_1", mediaState, "media_1"),
    now: overrides.now || FIXED_NOW,
  });
}

function renewLease(overrides = {}) {
  return renewActiveCallLeaseV2({
    db,
    authUid: overrides.authUid || "caller",
    request: overrides.request || heartbeatRequest(
      "call_1",
      1,
      "heartbeat_1",
    ),
    now: overrides.now || FIXED_NOW,
  });
}

function processTimeout(overrides = {}) {
  return processCallTimeoutV2({
    db,
    request: overrides.request || timeoutRequest(
      "call_1",
      "ringing",
      1,
      new Date(fixedMs() + RINGING_DURATION_MS),
    ),
    now: overrides.now || FIXED_NOW,
  });
}

function processActiveLeaseTimeout(overrides = {}) {
  return processActiveLeaseTimeoutV2({
    db,
    request: overrides.request || activeLeaseTimeoutRequest(
      "call_1",
      "caller",
      3,
      0,
      1,
      new Date(fixedMs() + ACTIVE_LEASE_DURATION_MS),
    ),
    now: overrides.now || FIXED_NOW,
  });
}

function lifecycleRequest(callId, idempotencyKey) {
  return {
    callId,
    idempotencyKey,
  };
}

function mediaRequest(callId, mediaState, idempotencyKey) {
  return {
    callId,
    mediaState,
    idempotencyKey,
  };
}

function heartbeatRequest(callId, heartbeatVersion, idempotencyKey) {
  return {
    callId,
    heartbeatVersion,
    idempotencyKey,
  };
}

function timeoutRequest(
  callId,
  timeoutKind,
  expectedCallVersion,
  expectedDeadlineAt,
) {
  return {
    callId,
    timeoutKind,
    expectedCallVersion,
    expectedDeadlineAt,
  };
}

function activeLeaseTimeoutRequest(
  callId,
  participantUid,
  expectedCallVersion,
  expectedHeartbeatVersion,
  expectedFencingToken,
  expectedLeaseExpiresAt,
) {
  return {
    callId,
    participantUid,
    expectedCallVersion,
    expectedHeartbeatVersion,
    expectedFencingToken,
    expectedLeaseExpiresAt,
  };
}

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

async function activeLeaseTimeoutRequestFromState(participantUid = "caller") {
  const call = await requiredData("calls/call_1");
  const participant = await requiredData(
    `calls/call_1/participants/${participantUid}`,
  );
  const lock = await requiredData(`activeCallLocks/${participantUid}`);
  return activeLeaseTimeoutRequest(
    "call_1",
    participantUid,
    call.version,
    participant.heartbeatVersion,
    lock.fencingToken,
    lock.expiresAt,
  );
}

async function promoteCallToActive() {
  await startCall();
  await acceptCall();
  await reportMedia({
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "promote_caller_joined"),
  });
  return reportMedia({
    authUid: "callee",
    mediaState: "joined",
    request: mediaRequest("call_1", "joined", "promote_callee_joined"),
  });
}

async function setActiveReconnectScenario({
  reconnectDeadlineAt,
  callerMediaState,
  calleeMediaState,
}) {
  await db.doc("calls/call_1").update({
    reconnectDeadlineAt,
  });
  await db.doc("calls/call_1/participants/caller").update({
    mediaState: callerMediaState,
    mediaVersion: callerMediaState === "joined" ? 1 : 2,
  });
  await db.doc("calls/call_1/participants/callee").update({
    mediaState: calleeMediaState,
    mediaVersion: calleeMediaState === "joined" ? 1 : 2,
  });
}

function assertTerminalResult(result, expected) {
  assert.equal(result.callId, "call_1");
  assert.equal(result.lifecycleState, expected.lifecycleState);
  assert.equal(result.terminal, true);
  assert.equal(result.version, expected.version || 2);
  assert.equal(millis(result.endedAt), fixedMs());
  assert.equal(result.endReason, expected.endReason);
  assert.equal(result.idempotentReplay, false);
}

function assertOneSuccessAndOneInvalidState(results) {
  const fulfilled = results.filter((result) => result.status === "fulfilled");
  const rejected = results.filter((result) => result.status === "rejected");
  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.ok(rejected[0].reason instanceof CallV2Error);
  assert.equal(rejected[0].reason.code, ERROR_CODES.invalidState);
}

async function assertTimeoutRaceOutcome(results, allowedLifecycleStates) {
  const timeoutResult = results[0];
  assert.equal(timeoutResult.status, "fulfilled");
  assert.ok(
    ["terminalized", "stale", "already_terminal"].includes(
      timeoutResult.value.status,
    ),
    timeoutResult.value.status,
  );
  if (results[1].status === "rejected") {
    assert.ok(results[1].reason instanceof CallV2Error);
    assert.ok(
      [ERROR_CODES.invalidState, ERROR_CODES.transactionFailed].includes(
        results[1].reason.code,
      ),
      results[1].reason.code,
    );
  }
  const finalCall = await requiredData("calls/call_1");
  assert.ok(allowedLifecycleStates.includes(finalCall.lifecycleState));
}

async function assertActiveLeaseRaceOutcome(results, allowedLifecycleStates) {
  const finalCall = await requiredData("calls/call_1");
  assert.ok(allowedLifecycleStates.includes(finalCall.lifecycleState));
  for (const result of results) {
    if (result.status === "rejected") {
      assert.ok(result.reason instanceof CallV2Error);
      assert.ok(
        [ERROR_CODES.invalidState, ERROR_CODES.transactionFailed].includes(
          result.reason.code,
        ),
        result.reason.code,
      );
    }
  }
  if (finalCall.terminal) {
    const terminalizedTimeouts = results.filter(
      (result) =>
        result.status === "fulfilled" &&
        result.value.status === "terminalized",
    );
    assert.ok(terminalizedTimeouts.length <= 1);
  }
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

async function commandCountForAction(callId, action) {
  const snapshot = await db.collection(`callOps/${callId}/commands`).get();
  return snapshot.docs.filter((doc) => doc.data().action === action).length;
}

async function captureMutationState(callId = "call_1") {
  return {
    call: await docState(`calls/${callId}`),
    callOps: await docState(`callOps/${callId}`),
    callerParticipant: await docState(`calls/${callId}/participants/caller`),
    calleeParticipant: await docState(`calls/${callId}/participants/callee`),
    callerLock: await docState("activeCallLocks/caller"),
    calleeLock: await docState("activeCallLocks/callee"),
    commands: await collectionState(`callOps/${callId}/commands`),
    idempotency: await collectionState("callCommandKeys"),
  };
}

async function assertMutationStateUnchanged(before, callId = "call_1") {
  assert.deepEqual(await captureMutationState(callId), before);
}

async function docState(path) {
  const snapshot = await db.doc(path).get();
  return {
    exists: snapshot.exists,
    data: snapshot.exists ? normalizeFirestoreData(snapshot.data()) : null,
  };
}

async function collectionState(path) {
  const snapshot = await db.collection(path).get();
  return snapshot.docs
    .map((doc) => ({
      id: doc.id,
      data: normalizeFirestoreData(doc.data()),
    }))
    .sort((left, right) => left.id.localeCompare(right.id));
}

function assertExactKeys(value, expectedKeys) {
  assert.deepEqual(Object.keys(value).sort(), [...expectedKeys].sort());
}

function assertParticipantSchema(participant) {
  assertExactKeys(participant, [
    "acceptedAt",
    "failureCode",
    "heartbeatVersion",
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
  assert.equal(participant.heartbeatVersion, 0);
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

function fakeActiveMediaReportData(callOverrides = {}) {
  return {
    "calls/call_1": {
      schemaVersion: 2,
      callSystem: "v2",
      lifecycleState: "active",
      terminal: false,
      version: 3,
      callerUid: "caller",
      calleeUid: "callee",
      participantUids: ["caller", "callee"],
      activeAt: FIXED_NOW,
      reconnectDeadlineAt: null,
      ...callOverrides,
    },
    "callOps/call_1": {
      callId: "call_1",
      latestOpsVersion: 3,
      lockClaims: {
        caller: {
          uid: "caller",
          fencingToken: 1,
        },
        callee: {
          uid: "callee",
          fencingToken: 1,
        },
      },
    },
    "calls/call_1/participants/caller": {
      uid: "caller",
      role: "caller",
      mediaState: "joined",
      mediaVersion: 1,
      heartbeatVersion: 0,
    },
    "calls/call_1/participants/callee": {
      uid: "callee",
      role: "callee",
      mediaState: "joined",
      mediaVersion: 1,
      heartbeatVersion: 0,
    },
    "activeCallLocks/caller": {
      uid: "caller",
      callId: "call_1",
      state: "active",
      expiresAt: FIXED_NOW,
      fencingToken: 1,
    },
    "activeCallLocks/callee": {
      uid: "callee",
      callId: "call_1",
      state: "active",
      expiresAt: FIXED_NOW,
      fencingToken: 1,
    },
  };
}

function fakeDbWithData(dataByPath) {
  const writes = [];
  const transaction = {
    async get(ref) {
      const exists = Object.prototype.hasOwnProperty.call(dataByPath, ref.path);
      return {
        id: ref.id,
        exists,
        data: () => dataByPath[ref.path],
      };
    },
    create(ref, data) {
      writes.push({ type: "create", path: ref.path, data });
    },
    set(ref, data) {
      writes.push({ type: "set", path: ref.path, data });
    },
    update(ref, data) {
      writes.push({ type: "update", path: ref.path, data });
    },
    delete(ref) {
      writes.push({ type: "delete", path: ref.path });
    },
  };

  function docRef(path) {
    const segments = path.split("/");
    return {
      path,
      id: segments[segments.length - 1],
      collection(collectionId) {
        return collectionRef(`${path}/${collectionId}`);
      },
    };
  }

  function collectionRef(path) {
    return {
      path,
      doc(id) {
        return docRef(`${path}/${id}`);
      },
    };
  }

  return {
    writes,
    db: {
      collection: collectionRef,
      runTransaction: (callback) => callback(transaction),
    },
  };
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
