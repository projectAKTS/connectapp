"use strict";

// Legacy pair calls use an Agora channel named
// `c_<first 12 chars of uid A>_<first 12 chars of uid B>_<time>` (see
// lib/services/call_session_manager.dart generateChannelName). A token for
// such a channel is given only to one of those two people, so a third
// signed-in user cannot join a call they were not part of.
//
// Channels in any other form (consultation rooms, Call V2 aliases) are not
// decided here.

function uidPrefix(authUid) {
  return `${authUid || ""}`.replace(/[^A-Za-z0-9_]/g, "").slice(0, 12);
}

function callerMayJoinChannel(channelName, authUid) {
  const channel = `${channelName || ""}`;
  if (!channel.startsWith("c_")) return true;
  const prefix = uidPrefix(authUid);
  if (!prefix) return false;
  if (channel.startsWith(`c_${prefix}_`)) return true;
  // Second position: `c_<other>_<prefix>_<time>`, where the time has no underscore.
  const tail = `_${prefix}_`;
  const at = channel.lastIndexOf(tail);
  return at > 2 && /^[a-z0-9]+$/.test(channel.slice(at + tail.length));
}

module.exports = { callerMayJoinChannel, uidPrefix };
