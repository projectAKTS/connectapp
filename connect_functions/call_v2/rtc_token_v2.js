"use strict";

const MAX_IDENTIFIER_LENGTH = 128;
const TOKEN_TTL_SECONDS = 60 * 60;

function validateRtcTokenRequestV2(request) {
  requireExactKeys(request, ["callId", "participantUid", "isVideo"]);
  const callId = requireIdentifier(request.callId);
  const participantUid = requireIdentifier(request.participantUid);
  if (typeof request.isVideo !== "boolean") {
    throw new Error("invalid_argument");
  }
  return {
    callId,
    participantUid,
    isVideo: request.isVideo,
  };
}

function createFakeRtcTokenForTestV2({ request, now }) {
  const normalized = validateRtcTokenRequestV2(request);
  const nowMillis = requireStrictNow(now).getTime();
  return {
    schemaVersion: 1,
    callSystem: "v2",
    callId: normalized.callId,
    channelAlias: "test-call-v2-channel",
    rtcUid: stableRtcUid(normalized.participantUid),
    isVideo: normalized.isVideo,
    token: "test-token-not-for-production",
    expiresAtMillis: nowMillis + TOKEN_TTL_SECONDS * 1000,
  };
}

function safeRtcTokenDebugV2(result) {
  return {
    version: result.schemaVersion,
    accessReady: typeof result.token === "string" && result.token.length > 0,
    routingReady:
      typeof result.channelAlias === "string" && result.channelAlias.length > 0,
    numericHandleReady:
      Number.isSafeInteger(result.rtcUid) && result.rtcUid > 0,
    videoReady: result.isVideo,
    expiryReady: Number.isSafeInteger(result.expiresAtMillis),
  };
}

function stableRtcUid(value) {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) % 2147483647;
  }
  return hash + 1;
}

function requireExactKeys(value, allowedKeys) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_argument");
  }
  const keys = Object.keys(value);
  if (
    keys.length !== allowedKeys.length ||
    !keys.every((key) => allowedKeys.includes(key))
  ) {
    throw new Error("invalid_argument");
  }
}

function requireIdentifier(value) {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > MAX_IDENTIFIER_LENGTH ||
    value.trim() !== value ||
    value.includes("/")
  ) {
    throw new Error("invalid_argument");
  }
  return value;
}

function requireStrictNow(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new Error("invalid_argument");
  }
  return value;
}

module.exports = {
  TOKEN_TTL_SECONDS,
  createFakeRtcTokenForTestV2,
  safeRtcTokenDebugV2,
  validateRtcTokenRequestV2,
};
