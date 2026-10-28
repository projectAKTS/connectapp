"use strict";

/**
 * "Answered elsewhere" push for a callee signed in on several devices.
 *
 * When one installation of the callee accepts, the callee's other
 * installations must stop ringing. The answering installation must never
 * receive this push: on iOS the terminal PushKit path ends the displayed
 * CallKit call natively, which would end the answered call.
 */

const ANSWERED_ELSEWHERE_STATUS = "answered_elsewhere";
/** Set by builds that handle this push on their pushInstallations doc. */
const ANSWERED_ELSEWHERE_CAPABILITY = "answeredElsewhereV1";

function normalizeStatus(value) {
  return `${value || ""}`.trim().toLowerCase();
}

/** True only for ringing -> accepted with a recorded answering installation. */
function isAnsweredElsewhereTransition(before, after) {
  return (
    normalizeStatus(before?.status) === "ringing" &&
    normalizeStatus(after?.status) === "accepted" &&
    Boolean(`${after?.acceptedInstallationId || ""}`.trim())
  );
}

function installationTokens(data) {
  return [data?.fcmToken, data?.apnsToken, data?.voipToken]
    .map((token) => `${token || ""}`.trim())
    .filter(Boolean);
}

/**
 * Tokens of the callee's other installations that support this push.
 *
 * Only active installations with `answeredElsewhereV1: true` are targeted:
 * older builds end the answered call when they receive it. Legacy
 * user-document tokens are never used, because their build is unknown.
 * Every token value of the answering installation is excluded.
 *
 * @param {{
 *   installations: Array<{id: string, data: object}>,
 *   acceptedInstallationId: string,
 * }} input
 */
function answeredElsewhereTargets({ installations = [], acceptedInstallationId }) {
  const answering = `${acceptedInstallationId || ""}`.trim();
  if (!answering) return { fcm: [], voip: [] };
  const answeringTokens = new Set();
  const fcm = [];
  const voip = [];
  for (const { id, data } of installations) {
    const docId = `${id || ""}`.trim();
    const installationId = `${data?.installationId || docId}`.trim();
    if (installationId === answering || docId === answering) {
      installationTokens(data).forEach((token) => answeringTokens.add(token));
      continue;
    }
    if (data?.active !== true || data?.[ANSWERED_ELSEWHERE_CAPABILITY] !== true) {
      continue;
    }
    const fcmToken = `${data.fcmToken || ""}`.trim();
    const voipToken = `${data.voipToken || ""}`.trim();
    if (fcmToken) fcm.push(fcmToken);
    if (voipToken) voip.push(voipToken);
  }
  const others = (tokens) =>
    Array.from(new Set(tokens)).filter((token) => !answeringTokens.has(token));
  return { fcm: others(fcm), voip: others(voip) };
}

/** Data payload: the existing `call_end` shape with a non-terminal status. */
function answeredElsewherePayload(inviteId, before, after) {
  const pick = (key, fallback = "") => `${after?.[key] || before?.[key] || fallback}`;
  return {
    type: "call_end",
    action: "call_end",
    status: ANSWERED_ELSEWHERE_STATUS,
    channel: pick("channel").trim(),
    isVideo: `${Boolean(after?.isVideo ?? before?.isVideo)}`,
    fromName: pick("fromName", "Caller"),
    fromUid: pick("fromUid"),
    toUid: pick("toUid"),
    callId: `${inviteId}`,
    inviteId: `${inviteId}`,
    acceptedInstallationId: `${after?.acceptedInstallationId || ""}`.trim(),
  };
}

/** FCM message, matching the existing terminal push priorities. */
function answeredElsewhereFcmMessage(payloadData) {
  return {
    android: { priority: "high" },
    apns: {
      headers: { "apns-priority": "5" },
      payload: { aps: { contentAvailable: true } },
    },
    data: payloadData,
  };
}

module.exports = {
  ANSWERED_ELSEWHERE_CAPABILITY,
  ANSWERED_ELSEWHERE_STATUS,
  answeredElsewhereFcmMessage,
  answeredElsewherePayload,
  answeredElsewhereTargets,
  isAnsweredElsewhereTransition,
};
