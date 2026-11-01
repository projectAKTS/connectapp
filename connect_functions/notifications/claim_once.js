"use strict";

/**
 * Firestore and scheduled triggers are delivered at least once: the same
 * event can run twice, even at the same time. Before a side effect that
 * must happen once (a push, an unread counter), the handler claims the
 * source document by setting [field] in a transaction. Only the run that
 * sets it proceeds.
 *
 * At-most-once by design: if the run that claimed fails afterwards, the
 * notification is skipped rather than risking a duplicate.
 */
async function claimOnce(db, ref, field, serverTimestamp) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const data = snap.data() || {};
    if (data[field]) return false;
    tx.update(ref, { [field]: serverTimestamp() });
    return true;
  });
}

module.exports = { claimOnce };
