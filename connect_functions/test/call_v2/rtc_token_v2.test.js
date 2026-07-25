"use strict";

const assert = require("node:assert");
const test = require("node:test");

const {
  TOKEN_TTL_SECONDS,
  createFakeRtcTokenForTestV2,
  safeRtcTokenDebugV2,
  validateRtcTokenRequestV2,
} = require("../../call_v2/rtc_token_v2");

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
    { callId: "call_a", participantUid: "participant_a", isVideo: true, extra: true },
    { callId: "calls/call_a", participantUid: "participant_a", isVideo: true },
    { callId: "call_a", participantUid: " users/a", isVideo: true },
    { callId: "call_a", participantUid: "participant_a", isVideo: "true" },
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
  assert.equal(result.expiresAtMillis, now.getTime() + TOKEN_TTL_SECONDS * 1000);
  assert.equal(result.token, "test-token-not-for-production");

  const debug = safeRtcTokenDebugV2(result);
  assert.equal(JSON.stringify(debug).includes(result.token), false);
  assert.equal(JSON.stringify(debug).includes("participant_a"), false);
});
