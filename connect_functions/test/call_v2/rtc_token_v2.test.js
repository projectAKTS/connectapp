"use strict";

const assert = require("node:assert");
const test = require("node:test");

const {
  CALL_V2_RTC_TOKEN_CALLABLE_NAME,
  TOKEN_TTL_SECONDS,
  createRtcTokenCallableGateV2,
  createFakeRtcTokenForTestV2,
  safeRtcTokenCallableGateDebugV2,
  safeRtcTokenDebugV2,
  validateRtcTokenRequestV2,
} = require("../../call_v2/rtc_token_v2");

test("exports stable callable handler name without index wiring", () => {
  assert.equal(CALL_V2_RTC_TOKEN_CALLABLE_NAME, "callV2RtcToken");
});

test("validates RTC token request without production credentials", () => {
  const result = validateRtcTokenRequestV2({
    callId: "call_a",
    participantUid: "participant_a",
    isVideo: true,
  });

  assert.deepEqual(result, {
    callId: "call_a",
    participantUid: "participant_a",
    isVideo: true,
  });
});

test("rejects malformed token requests", () => {
  for (const request of [
    null,
    {},
    {
      callId: "call_a",
      participantUid: "participant_a",
      isVideo: true,
      extra: true,
    },
    { callId: "calls/call_a", participantUid: "participant_a", isVideo: true },
    { callId: "call_a", participantUid: " users/a", isVideo: true },
    { callId: "call_a", participantUid: "participant_a", isVideo: "true" },
    { callId: "call_a/", participantUid: "participant_a", isVideo: true },
    { callId: "/call_a", participantUid: "participant_a", isVideo: true },
    { callId: " call_a", participantUid: "participant_a", isVideo: true },
    { callId: "call_a", participantUid: "", isVideo: true },
    {
      callId: "call_a",
      participantUid: "participant_a ".trimStart(),
      isVideo: true,
    },
    { callId: "a".repeat(129), participantUid: "participant_a", isVideo: true },
    { callId: "call_a", participantUid: "b".repeat(129), isVideo: true },
    { callId: 123, participantUid: "participant_a", isVideo: true },
  ]) {
    assert.throws(() => validateRtcTokenRequestV2(request), /invalid_argument/);
  }
});

test("creates emulator-safe fake token result and safe debug output", () => {
  const now = new Date("2026-01-01T00:00:00.000Z");
  const result = createFakeRtcTokenForTestV2({
    request: {
      callId: "call_a",
      participantUid: "participant_a",
      isVideo: false,
    },
    now,
  });

  assert.equal(result.schemaVersion, 1);
  assert.equal(result.callSystem, "v2");
  assert.equal(result.callId, "call_a");
  assert.equal(result.isVideo, false);
  assert.equal(
    result.expiresAtMillis,
    now.getTime() + TOKEN_TTL_SECONDS * 1000,
  );
  assert.equal(result.token, "test-token-not-for-production");

  const debug = safeRtcTokenDebugV2(result);
  const serializedDebug = JSON.stringify(debug).toLowerCase();
  assert.equal(serializedDebug.includes(result.token), false);
  assert.equal(
    serializedDebug.includes(result.channelAlias.toLowerCase()),
    false,
  );
  assert.equal(serializedDebug.includes("participant_a"), false);
  for (const forbidden of [
    "token",
    "channel",
    "uid",
    "user",
    "participant",
    "callid",
    "credential",
    "secret",
    "raw",
    "payload",
    "stack",
  ]) {
    assert.equal(serializedDebug.includes(forbidden), false, forbidden);
  }
  assert.deepEqual(
    Object.keys(debug).sort(),
    [
      "accessReady",
      "expiryReady",
      "numericHandleReady",
      "routingReady",
      "version",
      "videoReady",
    ].sort(),
  );
});

test("callable gate is disabled by default and does not create a token", async () => {
  const handler = createRtcTokenCallableGateV2({
    createToken: () => {
      throw new Error("should_not_run");
    },
  });

  const result = await handler({
    data: {
      callId: "call_a",
      participantUid: "participant_a",
      isVideo: false,
    },
  });

  assert.deepEqual(result, { status: "disabled" });
});

test("enabled callable gate creates emulator-safe access through injected dependency", async () => {
  const handler = createRtcTokenCallableGateV2({
    enabled: true,
    now: () => new Date("2026-01-01T00:00:00.000Z"),
  });

  const result = await handler({
    data: {
      callId: "call_a",
      participantUid: "participant_a",
      isVideo: true,
    },
  });

  assert.equal(result.status, "ok");
  assert.equal(result.result.callId, "call_a");
  assert.equal(result.result.isVideo, true);
});

test("callable gate rejects unknown wrapper keys", async () => {
  const handler = createRtcTokenCallableGateV2();

  await assert.rejects(
    () =>
      handler({
        data: {
          callId: "call_a",
          participantUid: "participant_a",
          isVideo: false,
        },
        extra: true,
      }),
    /invalid_argument/,
  );
});

test("callable gate safe debug contains no sensitive identifier wording", () => {
  const debug = safeRtcTokenCallableGateDebugV2({ enabled: true });
  const serializedDebug = JSON.stringify(debug).toLowerCase();

  for (const forbidden of [
    "token",
    "channel",
    "uid",
    "user",
    "participant",
    "callid",
    "device",
    "credential",
    "secret",
    "raw",
    "payload",
    "stack",
  ]) {
    assert.equal(serializedDebug.includes(forbidden), false, forbidden);
  }
});
