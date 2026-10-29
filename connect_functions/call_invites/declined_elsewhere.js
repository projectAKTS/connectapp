"use strict";

/**
 * "Declined elsewhere" for a callee signed in on several devices.
 *
 * The terminal `call_end` push for a decline goes to the caller only. The
 * callee's other devices stop ringing through their Firestore listener when
 * the app runs; a killed or backgrounded Android device has no listener and
 * kept ringing until its local ring timeout (~40 s on a physical phone).
 *
 * The callee therefore also gets the `call_end`, over FCM only. Android ends
 * the native call for any `call_end` that is not `answered_elsewhere`. No
 * VoIP push: on iOS every PushKit push must report a call, and the declining
 * iPhone has none left to report.
 */

function normalizeStatus(value) {
  return `${value || ""}`.trim().toLowerCase();
}

/** Users whose devices get the decline as FCM data only. */
function declinedElsewhereFcmRecipients(before, after, status) {
  if (normalizeStatus(status) !== "declined") return [];
  const toUid = `${after?.toUid || before?.toUid || ""}`.trim();
  return toUid ? [toUid] : [];
}

module.exports = { declinedElsewhereFcmRecipients };
