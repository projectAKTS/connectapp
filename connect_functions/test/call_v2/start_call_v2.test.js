"use strict";

const assert = require("node:assert/strict");
const { after, beforeEach, test } = require("node:test");

const admin = require("firebase-admin");

const {
  ACCEPTED_JOIN_DURATION_MS,
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
  reportParticipantMediaV2,
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
    (await requiredData("activeCallLocks/caller")).fencingToken,
    callerLockBefore.fencingToken,
  );
  assert.equal(
    (await requiredData("activeCallLocks/callee")).fencingToken,
    calleeLockBefore.fencingToken,
  );
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
