"use strict";

const { RtcRole, RtcTokenBuilder } = require("agora-token");

const MAX_IDENTIFIER_LENGTH = 128;
const TOKEN_TTL_SECONDS = 60 * 60;
const CALL_V2_RTC_TOKEN_CALLABLE_NAME = "callV2RtcToken";

function createRtcTokenCallableGateV2({
  enabled = false,
  environment = "",
  createToken = createFakeRtcTokenForTestV2,
  now = () => new Date(),
} = {}) {
  return async function rtcTokenCallableGateV2(request) {
    requireExactKeys(request, ["data"]);
    if (enabled !== true || !isNonProductionEnvironment(environment)) {
      return {
        status: "disabled",
      };
    }
    const result = createToken({
      request: request.data,
      now: now(),
    });
    return {
      status: "ok",
      result,
    };
  };
}

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
    channelAlias: channelAliasForCallId(normalized.callId),
    rtcUid: stableRtcUid(normalized.participantUid),
    isVideo: normalized.isVideo,
    token: "test-token-not-for-production",
    expiresAtMillis: nowMillis + TOKEN_TTL_SECONDS * 1000,
  };
}

function createAgoraRtcTokenForDevV2({
  request,
  now,
  appId,
  appCertificate,
}) {
  const normalized = validateRtcTokenRequestV2(request);
  const nowMillis = requireStrictNow(now).getTime();
  const cleanAppId = requireAgoraAppId(appId);
  const cleanCertificate = requireAgoraCertificate(appCertificate);
  const expiresAtSeconds = Math.floor(nowMillis / 1000) + TOKEN_TTL_SECONDS;
  const channelAlias = channelAliasForCallId(normalized.callId);
  const rtcUid = stableRtcUid(normalized.participantUid);
  const token = RtcTokenBuilder.buildTokenWithUid(
    cleanAppId,
    cleanCertificate,
    channelAlias,
    rtcUid,
    RtcRole.PUBLISHER,
    expiresAtSeconds,
    expiresAtSeconds,
  );
  return {
    schemaVersion: 1,
    callSystem: "v2",
    callId: normalized.callId,
    appId: cleanAppId,
    channelAlias,
    rtcUid,
    isVideo: normalized.isVideo,
    token,
    expiresAtMillis: expiresAtSeconds * 1000,
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
    appIdReady:
      typeof result.appId === "string" && /^[0-9a-fA-F]{32}$/.test(result.appId),
    videoReady: result.isVideo,
    expiryReady: Number.isSafeInteger(result.expiresAtMillis),
  };
}

function safeRtcTokenCallableGateDebugV2({ enabled = false } = {}) {
  return {
    enabled: enabled === true,
  };
}

function isNonProductionEnvironment(value) {
  return ["dev", "demo", "staging", "test", "emulator", "local"].includes(
    `${value || ""}`.trim().toLowerCase(),
  );
}

function stableRtcUid(value) {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = (hash * 31 + value.charCodeAt(index)) % 2147483647;
  }
  return hash + 1;
}

function channelAliasForCallId(callId) {
  let hash = 5381;
  for (let index = 0; index < callId.length; index += 1) {
    hash = ((hash << 5) + hash + callId.charCodeAt(index)) >>> 0;
  }
  return `helperly-call-v2-${hash.toString(16)}`;
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
    value.includes("/") ||
    value.includes("\\")
  ) {
    throw new Error("invalid_argument");
  }
  return value;
}

function requireAgoraAppId(value) {
  const clean = `${value || ""}`.trim();
  if (!/^[0-9a-fA-F]{32}$/.test(clean)) {
    throw new Error("invalid_argument");
  }
  return clean;
}

function requireAgoraCertificate(value) {
  const clean = `${value || ""}`.trim();
  if (!/^[0-9a-fA-F]{32}$/.test(clean)) {
    throw new Error("invalid_argument");
  }
  return clean;
}

function requireStrictNow(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new Error("invalid_argument");
  }
  return value;
}

module.exports = {
  CALL_V2_RTC_TOKEN_CALLABLE_NAME,
  TOKEN_TTL_SECONDS,
  createAgoraRtcTokenForDevV2,
  createRtcTokenCallableGateV2,
  createFakeRtcTokenForTestV2,
  isNonProductionEnvironment,
  safeRtcTokenCallableGateDebugV2,
  safeRtcTokenDebugV2,
  validateRtcTokenRequestV2,
};
