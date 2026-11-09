"use strict";

/**
 * A new comment notifies the post's author, unless they wrote it or have
 * blocked the commenter. Returns null when nobody is notified.
 */
function commentNotificationFor({ post, comment, authorBlockedUids }) {
  const authorUid = `${post?.userID || post?.userId || ""}`.trim();
  const commenterUid = `${comment?.userID || ""}`.trim();
  if (!authorUid || !commenterUid || authorUid === commenterUid) return null;
  if (Array.isArray(authorBlockedUids) && authorBlockedUids.includes(commenterUid)) {
    return null;
  }
  const text = `${comment?.text || ""}`.replace(/\s+/g, " ").trim();
  return {
    toUid: authorUid,
    commenterName: `${comment?.authorName || ""}`.trim(),
    snippet: text.length > 100 ? `${text.slice(0, 99)}…` : text,
  };
}

module.exports = { commentNotificationFor };
