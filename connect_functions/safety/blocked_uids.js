"use strict";

/**
 * Who a user has blocked. The list moved from the public profile
 * (`users/{uid}.blockedUids`, readable by every signed-in user) to the
 * owner-only `users/{uid}/private/safety.blockedUids`. Until every account
 * is migrated and old app builds are gone, both places count.
 */
function listOf(value) {
  return Array.isArray(value) ? value.map((v) => `${v}`.trim()).filter(Boolean) : [];
}

async function blockedUidsOf(db, uid, userData) {
  const legacy = listOf(userData?.blockedUids);
  if (!uid) return legacy;
  const snap = await db.collection("users").doc(`${uid}`)
    .collection("private").doc("safety").get();
  const priv = listOf(snap.exists ? snap.data()?.blockedUids : null);
  return [...new Set([...legacy, ...priv])];
}

/** The user data with `blockedUids` set to both places combined. */
async function withBlockedUids(db, uid, userData) {
  return { ...(userData || {}), blockedUids: await blockedUidsOf(db, uid, userData) };
}

module.exports = { blockedUidsOf, withBlockedUids };
