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
 * Tokens of the callee's other installations.
 *
 * Every token value found on the answering installation is removed from the
 * merged sets, including copies in legacy user-document fields.
 *
 * @param {{
 *   installations: Array<{id: string, data: object}>,
 *   userData: object,
 *   acceptedInstallationId: string,
 *   mergeTokenSets: (input: {installationDocs: object[], userData: object}) =>
 *     {fcmAll: string[], voip: string[]},
 * }} input
 */
function answeredElsewhereTargets({
  installations = [],
  userData = {},
  acceptedInstallationId,
  mergeTokenSets,
}) {
  const answering = `${acceptedInstallationId || ""}`.trim();
  if (!answering) return { fcm: [], voip: [] };
  const answeringTokens = new Set();
  for (const { id, data } of installations) {
    const installationId = `${data?.installationId || id || ""}`.trim();
    if (installationId === answering || `${id || ""}`.trim() === answering) {
      installationTokens(data).forEach((token) => answeringTokens.add(token));
    }
  }
  const merged = mergeTokenSets({
    installationDocs: installations.map(({ data }) => data || {}),
    userData,
  });
  const others = (tokens) => tokens.filter((token) => !answeringTokens.has(token));
  return { fcm: others(merged.fcmAll), voip: others(merged.voip) };
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
  ANSWERED_ELSEWHERE_STATUS,
  answeredElsewhereFcmMessage,
  answeredElsewherePayload,
  answeredElsewhereTargets,
  isAnsweredElsewhereTransition,
};
