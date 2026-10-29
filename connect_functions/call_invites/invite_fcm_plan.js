"use strict";

/**
 * Which FCM tokens get a new call invite, and when.
 *
 * Android rings from FCM alone, so its tokens get the invite at the start,
 * concurrently with the iOS VoIP push. Before, Android FCM waited behind the
 * VoIP push and the 4 s delayed APNS alert check, and Samsung phones showed
 * the call 6-7 s after the caller tapped.
 *
 * iOS FCM tokens stay a last resort: they get the invite only when neither
 * VoIP nor the APNS alert was delivered.
 */

function uniqueNonEmpty(values) {
  return Array.from(
    new Set((Array.isArray(values) ? values : []).map((v) => `${v || ""}`.trim()).filter(Boolean))
  );
}

/** Splits the callee's FCM tokens into `immediate` and `iosFallback`. */
function inviteFcmPlan(tokenSets) {
  const immediate = uniqueNonEmpty(tokenSets?.fcmForFallback);
  const sent = new Set(immediate);
  const iosFallback = uniqueNonEmpty(tokenSets?.fcmAll).filter((token) => !sent.has(token));
  return { immediate, iosFallback };
}

module.exports = { inviteFcmPlan };
