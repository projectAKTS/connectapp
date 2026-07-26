"use strict";

const assert = require("node:assert");
const test = require("node:test");

const {
  CALL_V2_RTC_TOKEN_CALLABLE_NAME,
  TOKEN_TTL_SECONDS,
  createAgoraRtcTokenForDevV2,
  createRtcTokenCallableGateV2,
  createFakeRtcTokenForTestV2,
  isNonProductionEnvironment,
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
    { callId: "call\\a", participantUid: "participant_a", isVideo: true },
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
  assert.equal(result.channelAlias.startsWith("helperly-call-v2-"), true);
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

test("enabled callable gate still requires non-production environment", async () => {
  const handler = createRtcTokenCallableGateV2({
    enabled: true,
    environment: "production",
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

test("enabled dev callable gate creates emulator-safe access through injection", async () => {
  const handler = createRtcTokenCallableGateV2({
    enabled: true,
    environment: "dev",
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

test("non-production environment allowlist is explicit", () => {
  for (const value of ["dev", "demo", "staging", "test", "emulator", "local"]) {
    assert.equal(isNonProductionEnvironment(value), true, value);
  }
  for (const value of ["", "prod", "production", "live", "connectapp-278b4"]) {
    assert.equal(isNonProductionEnvironment(value), false, value);
  }
});

test("dev Agora token generator validates secrets and keeps same-call routing", () => {
  const now = new Date("2026-01-01T00:00:00.000Z");
  const appId = "a".repeat(32);
  const appCertificate = "b".repeat(32);

  const first = createAgoraRtcTokenForDevV2({
    request: {
      callId: "call_a",
      participantUid: "participant_a",
      isVideo: true,
    },
    now,
    appId,
    appCertificate,
  });
  const second = createAgoraRtcTokenForDevV2({
    request: {
      callId: "call_a",
      participantUid: "participant_b",
      isVideo: true,
    },
    now,
    appId,
    appCertificate,
  });

  assert.equal(first.channelAlias, second.channelAlias);
  assert.notEqual(first.rtcUid, second.rtcUid);
  assert.equal(first.token.length > 0, true);
  assert.equal(JSON.stringify(safeRtcTokenDebugV2(first)).includes(first.token), false);

  assert.throws(
    () =>
      createAgoraRtcTokenForDevV2({
        request: {
          callId: "call_a",
          participantUid: "participant_a",
          isVideo: true,
        },
        now,
        appId: "",
        appCertificate,
      }),
    /invalid_argument/,
  );
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
