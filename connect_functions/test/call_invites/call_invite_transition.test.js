"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  CallInviteTransitionError,
  createCallInviteTransitionHandler,
} = require("../../call_invites/call_invite_transition");

const TS = Object.freeze({ serverTimestamp: true });
const CALLER = "caller_uid";
const CALLEE = "callee_uid";

/** Minimal in-memory stand-in for the admin Firestore transaction API. */
function createFakeDb(seed = {}) {
  const docs = new Map(
    Object.entries(seed).map(([id, data]) => [`callInvites/${id}`, { ...data }]),
  );
  const writes = [];
  return {
    docs,
    writes,
    collection(name) {
      return {
        doc(id) {
          return { path: `${name}/${id}` };
        },
      };
    },
    async runTransaction(fn) {
      const pending = [];
      const tx = {
        async get(ref) {
          const data = docs.get(ref.path);
          return { exists: data !== undefined, data: () => (data ? { ...data } : undefined) };
        },
        set(ref, data, options) {
          assert.deepEqual(options, { merge: true });
          pending.push([ref.path, data]);
        },
      };
      const result = await fn(tx);
      for (const [path, data] of pending) {
        docs.set(path, { ...(docs.get(path) || {}), ...data });
        writes.push([path, data]);
      }
      return result;
    },
  };
}

function invite(status, extra = {}) {
  return {
    fromUid: CALLER,
    toUid: CALLEE,
    fromName: "Caller",
    channel: "c_channel",
    isVideo: false,
    callSystem: "call_v2_dev",
    status,
    ...extra,
  };
}

function setup(seed) {
  const db = createFakeDb(seed);
  const handle = createCallInviteTransitionHandler({
    db,
    serverTimestamp: () => TS,
  });
  return { db, handle };
}

test("accept moves a ringing invite to accepted with exact client fields", async () => {
  const { db, handle } = setup({ inv1: invite("ringing") });
  const result = await handle({
    authUid: CALLEE,
    data: { action: "accept", inviteId: "inv1", status: "connected" },
  });
  assert.equal(result.decision, "accepted");
  assert.equal(result.invite.status, "accepted");
  assert.equal(result.invite.channel, "c_channel");
  assert.equal(result.invite.fromUid, CALLER);
  assert.deepEqual(db.writes, [[
    "callInvites/inv1",
    { status: "accepted", acceptedAt: TS, calleeStage: "accepted", calleeLastError: "" },
  ]]);

  const repeat = await handle({ authUid: CALLEE, data: { action: "accept", inviteId: "inv1" } });
  assert.equal(repeat.decision, "alreadyAccepted");
  assert.equal(db.writes.length, 1, "repeat accept must not write");
});

test("accept rejects wrong recipients and reports terminal or invalid invites", async () => {
  const { db, handle } = setup({
    ringing: invite("ringing"),
    declined: invite("declined"),
    weird: invite("bogus"),
    noChannel: invite("ringing", { channel: "" }),
  });
  const callerTry = await handle({ authUid: CALLER, data: { action: "accept", inviteId: "ringing" } });
  assert.equal(callerTry.decision, "wrongRecipient");
  assert.equal((await handle({ authUid: CALLEE, data: { action: "accept", inviteId: "declined" } })).decision, "terminal");
  assert.equal((await handle({ authUid: CALLEE, data: { action: "accept", inviteId: "weird" } })).decision, "invalidStatus");
  assert.equal((await handle({ authUid: CALLEE, data: { action: "accept", inviteId: "noChannel" } })).decision, "invalidPayload");
  assert.equal((await handle({ authUid: CALLEE, data: { action: "accept", inviteId: "absent" } })).decision, "missing");
  assert.equal(db.writes.length, 0);
});

test("unauthenticated, unknown action, and malformed ids are rejected", async () => {
  const { handle } = setup({ inv1: invite("ringing") });
  await assert.rejects(
    handle({ authUid: "", data: { action: "accept", inviteId: "inv1" } }),
    (e) => e instanceof CallInviteTransitionError && e.code === "unauthenticated",
  );
  await assert.rejects(
    handle({ authUid: CALLEE, data: { action: "delete", inviteId: "inv1" } }),
    (e) => e.code === "invalid-argument",
  );
  await assert.rejects(
    handle({ authUid: CALLEE, data: { action: "accept", inviteId: "../users/x" } }),
    (e) => e.code === "invalid-argument",
  );
});

test("decline is callee-only and applies only while ringing", async () => {
  const { db, handle } = setup({ a: invite("ringing"), b: invite("ringing"), c: invite("accepted") });
  const declined = await handle({
    authUid: CALLEE,
    data: { action: "decline", inviteId: "a", endReason: "callkit_decline" },
  });
  assert.deepEqual(declined, { action: "decline", applied: true, status: "declined" });
  assert.deepEqual(db.docs.get("callInvites/a"), {
    ...invite("declined"),
    declinedAt: TS,
    endedAt: TS,
    endedBy: CALLEE,
    endReason: "callkit_decline",
    calleeStage: "declined",
  });
  assert.equal((await handle({ authUid: CALLER, data: { action: "decline", inviteId: "b" } })).applied, false);
  assert.equal((await handle({ authUid: CALLEE, data: { action: "decline", inviteId: "c" } })).applied, false);
  assert.equal(db.writes.length, 1);
});

test("terminal mirrors the client authoritative transition rules", async () => {
  const { db, handle } = setup({
    ringing: invite("ringing"),
    accepted: invite("accepted"),
    connected: invite("connected"),
    ended: invite("ended", { endReason: "remote_left" }),
  });

  const cancel = await handle({
    authUid: CALLER,
    data: { action: "terminal", inviteId: "ringing", requestedStatus: "ended", endReason: "end_button", authoritativeLocalExit: true },
  });
  assert.deepEqual(cancel, { action: "terminal", status: "cancelled", endReason: "end_button", writeApplied: true, preservedExistingTerminal: false });
  assert.equal(db.docs.get("callInvites/ringing").cancelledAt, TS);
  assert.equal(db.docs.get("callInvites/ringing").callerStage, "cancelled");

  const promoted = await handle({
    authUid: CALLEE,
    data: { action: "terminal", inviteId: "accepted", requestedStatus: "declined", endReason: "callkit_end" },
  });
  assert.equal(promoted.status, "ended", "decline after acceptance becomes ended");
  assert.equal(db.docs.get("callInvites/accepted").calleeStage, "ended");
  assert.equal(db.docs.get("callInvites/accepted").declinedAt, undefined);

  const failed = await handle({
    authUid: CALLEE,
    data: { action: "terminal", inviteId: "connected", requestedStatus: "failed", endReason: "agora_join_timeout", error: "x".repeat(400) },
  });
  assert.equal(failed.status, "failed");
  assert.equal(db.docs.get("callInvites/connected").failedAt, TS);
  assert.equal(db.docs.get("callInvites/connected").calleeLastError.length, 300);

  const preserved = await handle({
    authUid: CALLER,
    data: { action: "terminal", inviteId: "ended", requestedStatus: "failed", endReason: "late" },
  });
  assert.deepEqual(preserved, { action: "terminal", status: "ended", endReason: "remote_left", writeApplied: false, preservedExistingTerminal: true });
  assert.equal(db.writes.length, 3);
});

test("terminal never writes for non-participants or bad input", async () => {
  const { db, handle } = setup({ inv: invite("connected") });
  const stranger = await handle({
    authUid: "stranger",
    data: { action: "terminal", inviteId: "inv", requestedStatus: "ended", endReason: "end_button" },
  });
  assert.equal(stranger.writeApplied, false);
  await assert.rejects(
    handle({ authUid: CALLER, data: { action: "terminal", inviteId: "inv", requestedStatus: "connected" } }),
    (e) => e.code === "invalid-argument",
  );
  await assert.rejects(
    handle({ authUid: CALLER, data: { action: "terminal", inviteId: "inv", requestedStatus: "ended", endReason: "has spaces!" } }),
    (e) => e.code === "invalid-argument",
  );
  assert.equal(db.writes.length, 0);
});

test("stage updates mirror joining, joined_local, and connected semantics", async () => {
  const { db, handle } = setup({ a: invite("accepted"), b: invite("accepted"), c: invite("joining"), d: invite("ended") });

  await handle({ authUid: CALLEE, data: { action: "stage", inviteId: "a", stage: "joining" } });
  assert.deepEqual(db.writes.at(-1), ["callInvites/a", { calleeStage: "joining", status: "joining", joiningAt: TS }]);

  await handle({ authUid: CALLER, data: { action: "stage", inviteId: "b", stage: "joining" } });
  assert.deepEqual(db.writes.at(-1), ["callInvites/b", { callerStage: "joining" }]);

  await handle({ authUid: CALLER, data: { action: "stage", inviteId: "c", stage: "joined_local" } });
  assert.deepEqual(db.writes.at(-1), ["callInvites/c", { callerStage: "joined_local" }]);

  await handle({ authUid: CALLEE, data: { action: "stage", inviteId: "c", stage: "connected" } });
  assert.deepEqual(db.writes.at(-1), ["callInvites/c", { calleeStage: "connected", status: "connected", connectedAt: TS }]);

  const late = await handle({ authUid: CALLEE, data: { action: "stage", inviteId: "d", stage: "connected" } });
  assert.equal(late.applied, false, "terminal invites never move back to connected");
  const stranger = await handle({ authUid: "x", data: { action: "stage", inviteId: "c", stage: "joining" } });
  assert.equal(stranger.applied, false);
  await assert.rejects(
    handle({ authUid: CALLEE, data: { action: "stage", inviteId: "c", stage: "ended" } }),
    (e) => e.code === "invalid-argument",
  );
  assert.equal(db.writes.length, 4);
});

const PHONE = "phone_installation_1";
const TABLET = "tablet_installation_2";

test("accept records the answering installation and fences other installations", async () => {
  const { db, handle } = setup({ inv1: invite("ringing") });
  const first = await handle({
    authUid: CALLEE,
    data: { action: "accept", inviteId: "inv1", installationId: PHONE },
  });
  assert.equal(first.decision, "accepted");
  assert.equal(db.writes[0][1].acceptedInstallationId, PHONE);

  const same = await handle({
    authUid: CALLEE,
    data: { action: "accept", inviteId: "inv1", installationId: PHONE },
  });
  assert.equal(same.decision, "alreadyAccepted");

  const other = await handle({
    authUid: CALLEE,
    data: { action: "accept", inviteId: "inv1", installationId: TABLET },
  });
  assert.equal(other.decision, "acceptedElsewhere");
  assert.equal(other.invite.channel, "c_channel");
  assert.equal(db.writes.length, 1, "only the first accept writes");
});

test("old clients without an installation id keep today's accept behavior", async () => {
  const { db, handle } = setup({
    legacy: invite("ringing"),
    recorded: invite("accepted", { acceptedInstallationId: PHONE }),
    unrecorded: invite("joining"),
    bogusId: invite("ringing"),
  });
  await handle({ authUid: CALLEE, data: { action: "accept", inviteId: "legacy" } });
  assert.equal("acceptedInstallationId" in db.writes[0][1], false);
  assert.equal(
    (await handle({ authUid: CALLEE, data: { action: "accept", inviteId: "recorded" } })).decision,
    "alreadyAccepted",
  );
  assert.equal(
    (await handle({
      authUid: CALLEE,
      data: { action: "accept", inviteId: "unrecorded", installationId: TABLET },
    })).decision,
    "alreadyAccepted",
  );
  await handle({
    authUid: CALLEE,
    data: { action: "accept", inviteId: "bogusId", installationId: "bad id!" },
  });
  assert.equal("acceptedInstallationId" in db.writes[1][1], false, "invalid ids are ignored");
});

test("a non-answering callee installation cannot end or stage the answered call", async () => {
  const { db, handle } = setup({
    inv1: invite("connected", { acceptedInstallationId: PHONE }),
  });
  const end = await handle({
    authUid: CALLEE,
    data: {
      action: "terminal",
      inviteId: "inv1",
      requestedStatus: "ended",
      authoritativeLocalExit: true,
      installationId: TABLET,
    },
  });
  assert.equal(end.writeApplied, false);
  assert.equal(end.reason, "answered_elsewhere");
  const stage = await handle({
    authUid: CALLEE,
    data: { action: "stage", inviteId: "inv1", stage: "joining", installationId: TABLET },
  });
  assert.equal(stage.applied, false);
  assert.equal(stage.reason, "answered_elsewhere");
  assert.equal(db.writes.length, 0);

  const answering = await handle({
    authUid: CALLEE,
    data: {
      action: "terminal",
      inviteId: "inv1",
      requestedStatus: "ended",
      authoritativeLocalExit: true,
      installationId: PHONE,
    },
  });
  assert.equal(answering.writeApplied, true);
});

test("the caller and old callee clients are never fenced", async () => {
  const { handle } = setup({
    byCaller: invite("connected", { acceptedInstallationId: PHONE }),
    byLegacy: invite("connected", { acceptedInstallationId: PHONE }),
  });
  const caller = await handle({
    authUid: CALLER,
    data: {
      action: "terminal",
      inviteId: "byCaller",
      requestedStatus: "ended",
      authoritativeLocalExit: true,
      installationId: TABLET,
    },
  });
  assert.equal(caller.writeApplied, true);
  const legacy = await handle({
    authUid: CALLEE,
    data: {
      action: "terminal",
      inviteId: "byLegacy",
      requestedStatus: "ended",
      authoritativeLocalExit: true,
    },
  });
  assert.equal(legacy.writeApplied, true);
});
