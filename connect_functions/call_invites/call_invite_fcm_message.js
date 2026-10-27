"use strict";

/**
 * FCM message for a new call invite.
 *
 * Android receives a data-only, high-priority message so the app's
 * background handler can present the full-screen incoming-call UI. A
 * top-level `notification` would make Android post a plain notification
 * itself. iOS keeps the same visible alert through `apns.payload.aps.alert`.
 */

// Slightly under the 45 s ringing timeout, so a late delivery never rings
// for a call that has already timed out.
const CALL_INVITE_ANDROID_TTL_MS = 40 * 1000;

function buildCallInviteFcmMessage({ isVideo, fromName, payloadData }) {
  return {
    android: {
      priority: "high",
      ttl: CALL_INVITE_ANDROID_TTL_MS,
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          alert: {
            title: isVideo ? "Incoming Video Call" : "Incoming Audio Call",
            body: `From ${fromName || "Someone"}`,
          },
          sound: "default",
          contentAvailable: true,
        },
      },
    },
    data: {
      type: "call_invite",
      ...payloadData,
    },
  };
}

module.exports = {
  CALL_INVITE_ANDROID_TTL_MS,
  buildCallInviteFcmMessage,
};
