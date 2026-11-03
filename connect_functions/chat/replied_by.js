"use strict";

// First-contact safety (docs/SAFETY_ROADMAP.md #3): `repliedBy` lists the
// participants who have written in a chat. The rules allow media, links and
// calls to non-helpers only once the other person is in it. Only the server
// writes it. System messages such as "Missed call" do not count.

/**
 * The `repliedBy` value to merge into the chat for a new message, or null
 * when nothing changes.
 */
async function repliedByUpdate({ chatRef, chat, users, authorId, isSystem, FieldValue }) {
  if (Array.isArray(chat.repliedBy)) {
    if (isSystem || chat.repliedBy.includes(authorId)) return null;
    return FieldValue.arrayUnion(authorId);
  }
  // A chat from before the field: rebuild it from its history once.
  return writersFromHistory(chatRef, users, isSystem ? [] : [authorId]);
}

async function writersFromHistory(chatRef, users, known = []) {
  const writers = new Set(known);
  await Promise.all(
    users.map(async (uid) => {
      if (writers.has(uid)) return;
      const snap = await chatRef.collection("messages").where("authorId", "==", uid).limit(10).get();
      if (snap.docs.some((d) => d.get("system") !== true)) writers.add(uid);
    }),
  );
  return users.filter((uid) => writers.has(uid));
}

module.exports = { repliedByUpdate, writersFromHistory };
