"use strict";

/**
 * True when the callee has blocked the caller. Blocked people's calls never
 * reach the callee: no push is sent and the invite ends as missed, so the
 * caller sees no answer, like WhatsApp.
 */
function calleeBlockedCaller(calleeData, callerUid) {
  const caller = `${callerUid || ""}`.trim();
  if (!caller) return false;
  const blocked = calleeData?.blockedUids;
  return Array.isArray(blocked) && blocked.some((uid) => `${uid}`.trim() === caller);
}

module.exports = { calleeBlockedCaller };
