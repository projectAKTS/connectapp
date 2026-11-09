"use strict";

/**
 * Missed-call note for the callee, as messaging apps do it.
 *
 * When a call ends without the callee answering (the ring timed out, or the
 * caller hung up while it rang), the server adds a system message
 * "Missed audio call" / "Missed video call" to the two users' chat. The
 * message is authored by the caller, so the normal chat push tells the
 * callee "<caller>: Missed call" and the chat shows it in its history.
 *
 * No note when the callee declined (they saw the call), when the call was
 * ever accepted, or when the callee has blocked the caller (the invite then
 * ends as missed with endReason "callee_unavailable" and must stay silent).
 */

const MISSED_STATUSES = new Set(["missed", "cancelled"]);

function normalizeStatus(value) {
  return `${value || ""}`.trim().toLowerCase();
}

function chatIdFor(a, b) {
  return [a, b].sort().join("_");
}

/** The note to write for this invite transition, or null. */
function missedCallNoteFor(before, after) {
  const status = normalizeStatus(after?.status);
  if (!MISSED_STATUSES.has(status)) return null;
  if (normalizeStatus(before?.status) === status) return null;
  if (after?.acceptedAt || before?.acceptedAt) return null;
  if (`${after?.endReason || ""}`.trim() === "callee_unavailable") return null;

  const callerUid = `${after?.fromUid || before?.fromUid || ""}`.trim();
  const calleeUid = `${after?.toUid || before?.toUid || ""}`.trim();
  if (!callerUid || !calleeUid || callerUid === calleeUid) return null;

  const isVideo = Boolean(after?.isVideo ?? before?.isVideo);
  return {
    chatId: chatIdFor(callerUid, calleeUid),
    callerUid,
    calleeUid,
    isVideo,
    text: isVideo ? "Missed video call" : "Missed audio call",
  };
}

module.exports = { missedCallNoteFor };
