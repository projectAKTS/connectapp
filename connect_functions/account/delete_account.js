"use strict";

/**
 * Deletes a user's account and personal data (App Store 5.1.1(v), Google
 * Play account deletion, PIPEDA).
 *
 * Deleted: the user doc and all its subcollections, their posts (with
 * comments), their follower lists, their profile photos and post media, the
 * text of reviews they wrote, and the Auth user. Kept: consultations and
 * Stripe records (payment records the law requires), review stars (they are
 * part of the helper's average), and messages already sent to other people,
 * which stay in those people's chats.
 *
 * Dependencies are injected so the plan can be tested without Firebase.
 */

const STORAGE_PREFIXES = ["users", "post_images", "post_videos", "post_video_thumbs"];

/**
 * Removes references that would keep a deleted person identifiable in
 * other people's data, without deleting those people's content:
 * - comments and replies they wrote: deleted, or, when other people
 *   replied under the comment, emptied into an anonymous placeholder so
 *   the replies survive;
 * - reviews about them (helper): deleted (their only purpose was that
 *   profile's reputation); reviews they wrote: stars kept for the helper's
 *   average, text and reviewer id removed;
 * - their name on call records (the records themselves are retained);
 * - their uid in other users' followers/following and in post likes;
 * - connection records with them.
 * Needs [FieldValue] (Admin SDK). Safe to run again.
 */
async function scrubReferences({ db, FieldValue, uid }) {
  const counts = {
    commentsDeleted: 0,
    commentsAnonymized: 0,
    replies: 0,
    reviewsAbout: 0,
    reviewsBy: 0,
    callNames: 0,
    follows: 0,
    likes: 0,
    connections: 0,
  };
  const seen = new Set();
  const byAuthor = async (group) => {
    const out = [];
    for (const field of ["userID", "userId"]) {
      const snap = await db.collectionGroup(group).where(field, "==", uid).get();
      for (const d of snap.docs) {
        if (seen.has(d.ref.path)) continue;
        seen.add(d.ref.path);
        out.push(d);
      }
    }
    return out;
  };

  for (const reply of await byAuthor("replies")) {
    await reply.ref.delete();
    counts.replies += 1;
  }
  for (const comment of await byAuthor("comments")) {
    const replies = await comment.ref.collection("replies").limit(1).get();
    if (replies.empty) {
      await comment.ref.delete();
      counts.commentsDeleted += 1;
    } else {
      await comment.ref.update({
        text: "",
        content: "",
        userName: "",
        userAvatar: FieldValue.delete(),
        userID: "",
        userId: "",
        authorDeleted: true,
        likedBy: [],
      });
      counts.commentsAnonymized += 1;
    }
  }

  const about = await db.collection("reviews").where("helperUid", "==", uid).get();
  for (const r of about.docs) {
    await r.ref.delete();
    counts.reviewsAbout += 1;
  }
  const by = await db.collection("reviews").where("reviewerUid", "==", uid).get();
  for (const r of by.docs) {
    await r.ref.update({ text: "", reviewerUid: "", reviewerDeleted: true });
    counts.reviewsBy += 1;
  }

  for (const [field, nameField] of [["fromUid", "fromName"], ["toUid", "toName"]]) {
    const calls = await db.collection("callInvites").where(field, "==", uid).get();
    for (const c of calls.docs) {
      await c.ref.update({ [nameField]: "" });
      counts.callNames += 1;
    }
  }

  for (const field of ["followers", "following"]) {
    const users = await db.collection("users").where(field, "array-contains", uid).get();
    for (const u of users.docs) {
      await u.ref.update({ [field]: FieldValue.arrayRemove(uid) });
      counts.follows += 1;
    }
  }
  const liked = await db.collection("posts").where("likedBy", "array-contains", uid).get();
  for (const p of liked.docs) {
    await p.ref.update({ likedBy: FieldValue.arrayRemove(uid) });
    counts.likes += 1;
  }

  const links = new Set();
  for (const [field, op] of [["users", "array-contains"], ["userId", "=="], ["connectedUserId", "=="]]) {
    const snap = await db.collection("connections").where(field, op, uid).get();
    for (const c of snap.docs) {
      if (links.has(c.ref.path)) continue;
      links.add(c.ref.path);
      await c.ref.delete();
      counts.connections += 1;
    }
  }
  return counts;
}

/**
 * Runs [scrubReferences] but never lets a cleanup failure (for example a
 * missing collection-group index) stop the account deletion itself; the
 * error is returned in the summary and logged.
 */
async function scrubReferencesSafely(args) {
  try {
    return await scrubReferences(args);
  } catch (error) {
    return { error: `${error && error.message ? error.message : error}`.slice(0, 300) };
  }
}

async function deleteUserData({ db, bucket, auth, uid, FieldValue, log = () => {} }) {
  const userId = `${uid || ""}`.trim();
  if (!userId) throw new Error("uid required");
  const summary = {
    uid: userId,
    posts: 0,
    reviews: 0,
    storagePrefixes: 0,
    authDeleted: false,
  };

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

  if (FieldValue) {
    // Full reference cleanup (production path).
    summary.references = await scrubReferencesSafely({ db, FieldValue, uid: userId });
    if (summary.references.error) log("account_delete_scrub_failed", summary.references);
    summary.reviews = summary.references.reviewsBy || 0;
  } else {
    // Minimal path for callers without the Admin FieldValue (unit tests).
    const reviews = await db.collection("reviews").where("reviewerUid", "==", userId).get();
    for (const review of reviews.docs) {
      await review.ref.update({ text: "", reviewerDeleted: true });
      summary.reviews += 1;
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

module.exports = { deleteUserData, scrubReferences, STORAGE_PREFIXES };
