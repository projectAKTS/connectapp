"use strict";

/**
 * Deletes a user's account and personal data (App Store 5.1.1(v), Google
 * Play account deletion, PIPEDA).
 *
 * Deleted: the user doc and all its subcollections, their posts (with
 * comments), their follower lists, their profile photos and post media, and
 * the Auth user. Kept: consultations and Stripe records (payment records the
 * law requires), and messages already sent to other people, which stay in
 * those people's chats.
 *
 * Dependencies are injected so the plan can be tested without Firebase.
 */

const STORAGE_PREFIXES = ["users", "post_images", "post_videos", "post_video_thumbs"];

async function deleteUserData({ db, bucket, auth, uid, log = () => {} }) {
  const userId = `${uid || ""}`.trim();
  if (!userId) throw new Error("uid required");
  const summary = { uid: userId, posts: 0, storagePrefixes: 0, authDeleted: false };

  // Posts store the author as userID; older ones used userId.
  const seen = new Set();
  for (const field of ["userID", "userId"]) {
    const posts = await db.collection("posts").where(field, "==", userId).get();
    for (const post of posts.docs) {
      if (seen.has(post.ref.path)) continue;
      seen.add(post.ref.path);
      await db.recursiveDelete(post.ref);
      summary.posts += 1;
    }
  }

  await db.recursiveDelete(db.collection("followers").doc(userId));
  await db.recursiveDelete(db.collection("users").doc(userId));

  for (const prefix of STORAGE_PREFIXES) {
    await bucket.deleteFiles({ prefix: `${prefix}/${userId}/`, force: true });
    summary.storagePrefixes += 1;
  }

  try {
    await auth.deleteUser(userId);
    summary.authDeleted = true;
  } catch (error) {
    // Already gone is fine; anything else is reported but the data is gone.
    if (error?.code !== "auth/user-not-found") throw error;
  }
  log("account_deleted", summary);
  return summary;
}

module.exports = { deleteUserData, STORAGE_PREFIXES };
