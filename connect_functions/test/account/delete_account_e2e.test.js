"use strict";

// End-to-end account deletion against the Auth, Firestore and Storage
// emulators, with two disposable users. Run:
//   firebase --project demo-helperly-delete-e2e --config ../firebase.json \
//     emulators:exec --only auth,firestore,storage \
//     "node --test test/account/delete_account_e2e.test.js"

const assert = require("node:assert/strict");
const { before, test } = require("node:test");

const emulated = process.env.FIRESTORE_EMULATOR_HOST &&
  process.env.FIREBASE_AUTH_EMULATOR_HOST &&
  process.env.FIREBASE_STORAGE_EMULATOR_HOST;

const PROJECT = process.env.GCLOUD_PROJECT || "demo-helperly-delete-e2e";
let admin;
let db;
let bucket;
let auth;

before(async () => {
  if (!emulated) return;
  admin = require("firebase-admin");
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
  }
  db = admin.firestore();
  bucket = admin.storage().bucket();
  auth = admin.auth();
});

async function seed() {
  for (const c of ["users", "posts", "chats", "callInvites", "reviews", "connections",
    "reports", "consultations", "paymentOperations", "followers", "accountDeletions"]) {
    await db.recursiveDelete(db.collection(c));
  }
  for (const uid of ["userA", "userB", "userC"]) {
    await auth.createUser({ uid, email: `${uid}@example.test`, password: "test-only-123" }).catch(() => {});
    await db.doc(`users/${uid}`).set({ fullName: uid, ageDeclaration: "adult" });
    await db.doc(`users/${uid}/pushInstallations/inst_${uid}`).set({ fcmToken: "t" });
    await db.doc(`users/${uid}/private/account`).set({ email: `${uid}@example.test` });
    await db.doc(`followers/${uid}`).set({ count: 1 });
    await db.doc(`followers/${uid}/userFollowers/x`).set({ at: 1 });
  }
  await db.doc("users/userB").update({ followers: ["userA", "userC"], following: ["userA", "userC"] });
  await db.doc("posts/postA").set({ userID: "userA", content: "A's post" });
  await db.doc("posts/postA/comments/c_byB").set({ userID: "userB", content: "B on A" });
  await db.doc("posts/postA_legacy").set({ userId: "userA", content: "legacy field" });
  await db.doc("posts/postB").set({ userID: "userB", content: "B's post", likedBy: ["userA", "userC"] });
  // A's comments on B's post: one alone (bottom-sheet schema), one with a
  // reply from B (screen schema), and A's reply under C's comment.
  await db.doc("posts/postB/comments/c_byA").set({ userId: "userA", userName: "userA", text: "A on B" });
  await db.doc("posts/postB/comments/c_byA_thread").set({ userID: "userA", userName: "userA", content: "A thread", userAvatar: "http://a" });
  await db.doc("posts/postB/comments/c_byA_thread/replies/r_byB").set({ userID: "userB", content: "B replies to A" });
  await db.doc("posts/postB/comments/c_byC").set({ userID: "userC", content: "C on B" });
  await db.doc("posts/postB/comments/c_byC/replies/r_byA").set({ userID: "userA", content: "A replies to C" });
  await db.doc("chats/userA_userB").set({ participants: ["userA", "userB"] });
  await db.doc("chats/userA_userB/messages/m1").set({ authorId: "userA", text: "hi B" });
  await db.doc("chats/userA_userB/messages/m2").set({ authorId: "userB", text: "hi A" });
  await db.doc("callInvites/inv1").set({ fromUid: "userA", fromName: "userA", toUid: "userB", toName: "userB", status: "ended" });
  await db.doc("callInvites/inv2").set({ fromUid: "userB", fromName: "userB", toUid: "userA", toName: "userA", status: "missed" });
  await db.doc("callInvites/inv3").set({ fromUid: "userB", fromName: "userB", toUid: "userC", toName: "userC", status: "ended" });
  await db.doc("reviews/consultAB").set({ reviewerUid: "userA", helperUid: "userB", stars: 5, text: "A about B" });
  await db.doc("reviews/consultBA").set({ reviewerUid: "userB", helperUid: "userA", stars: 4, text: "B about A" });
  await db.doc("reviews/consultCB").set({ reviewerUid: "userC", helperUid: "userB", stars: 3, text: "C about B" });
  await db.doc("connections/userA_userB").set({ users: ["userA", "userB"] });
  await db.doc("connections/legacyAB").set({ userId: "userA", connectedUserId: "userB" });
  await db.doc("connections/legacyCA").set({ userId: "userC", connectedUserId: "userA" });
  await db.doc("connections/userB_userC").set({ users: ["userB", "userC"] });
  await db.doc("reports/r1").set({ reporterUid: "userA", targetUid: "userB" });
  await db.doc("consultations/consultAB").set({ userId: "userA", targetUserId: "userB", participants: ["userA", "userB"] });
  await db.doc("paymentOperations/op_userA_000000001").set({ uid: "userA", status: "succeeded" });
  for (const p of [
    "users/userA/profile_1.jpg", "post_images/userA/1.jpg", "post_videos/userA/1.mp4",
    "post_video_thumbs/userA/1.jpg", "users/userB/profile_1.jpg", "post_images/userB/1.jpg",
    "chats/userA_userB/images/1.jpg",
  ]) {
    await bucket.file(p).save(Buffer.from("x"));
  }
}

const exists = async (p) => (await db.doc(p).get()).exists;
const fileExists = async (p) => (await bucket.file(p).exists())[0];

test("deleting user A removes A's data, keeps documented records, never touches B", { skip: !emulated }, async () => {
  await seed();
  const { deleteUserData } = require("../../account/delete_account");
  const summary = await deleteUserData({ db, bucket, auth, uid: "userA", FieldValue: admin.firestore.FieldValue });
  assert.equal(summary.authDeleted, true);
  assert.equal(summary.posts, 2, "both userID and legacy userId posts");

  // Deleted: A's account, profile, subcollections, posts (with comments on
  // them), followers, Storage folders.
  await assert.rejects(auth.getUser("userA"));
  for (const p of ["users/userA", "users/userA/pushInstallations/inst_userA",
    "users/userA/private/account", "followers/userA", "followers/userA/userFollowers/x",
    "posts/postA", "posts/postA/comments/c_byB", "posts/postA_legacy"]) {
    assert.equal(await exists(p), false, `deleted: ${p}`);
  }
  for (const f of ["users/userA/profile_1.jpg", "post_images/userA/1.jpg",
    "post_videos/userA/1.mp4", "post_video_thumbs/userA/1.jpg"]) {
    assert.equal(await fileExists(f), false, `deleted: ${f}`);
  }

  const data = async (p) => (await db.doc(p).get()).data();

  // Reviews: about A deleted; by A anonymous (stars kept); others intact.
  assert.equal(await exists("reviews/consultBA"), false, "review about A deleted");
  const rAB = await data("reviews/consultAB");
  assert.deepEqual([rAB.text, rAB.reviewerUid, rAB.stars, rAB.reviewerDeleted], ["", "", 5, true]);
  assert.equal((await data("reviews/consultCB")).text, "C about B");

  // Comments and replies A wrote on other people's posts.
  assert.equal(await exists("posts/postB/comments/c_byA"), false, "lone comment deleted");
  const thread = await data("posts/postB/comments/c_byA_thread");
  assert.equal(thread.content, "");
  assert.equal(thread.userName, "");
  assert.equal(thread.userID, "");
  assert.equal(thread.userAvatar, undefined);
  assert.equal(thread.authorDeleted, true);
  assert.equal((await data("posts/postB/comments/c_byA_thread/replies/r_byB")).content, "B replies to A", "B's reply survives");
  assert.equal(await exists("posts/postB/comments/c_byC/replies/r_byA"), false, "A's reply deleted");
  assert.equal((await data("posts/postB/comments/c_byC")).content, "C on B");

  // No name or uid of A left in other people's records.
  assert.equal((await data("callInvites/inv1")).fromName, "");
  assert.equal((await data("callInvites/inv1")).toName, "userB");
  assert.equal((await data("callInvites/inv2")).toName, "");
  assert.equal((await data("callInvites/inv3")).fromName, "userB", "unrelated call untouched");
  const b = await data("users/userB");
  assert.deepEqual(b.followers, ["userC"]);
  assert.deepEqual(b.following, ["userC"]);
  assert.deepEqual((await data("posts/postB")).likedBy, ["userC"]);
  for (const c of ["connections/userA_userB", "connections/legacyAB", "connections/legacyCA"]) {
    assert.equal(await exists(c), false, `connection with A deleted: ${c}`);
  }
  assert.equal(await exists("connections/userB_userC"), true);

  // A is not findable: no profile doc for search, no Auth user.
  const search = await db.collection("users").where("fullName", "==", "userA").get();
  assert.equal(search.empty, true);

  // Kept by design (documented retention).
  for (const p of ["chats/userA_userB/messages/m1", "chats/userA_userB/messages/m2",
    "callInvites/inv1", "reports/r1", "consultations/consultAB",
    "paymentOperations/op_userA_000000001"]) {
    assert.equal(await exists(p), true, `kept: ${p}`);
  }
  assert.equal(await fileExists("chats/userA_userB/images/1.jpg"), true, "chat media kept");

  // B and C are untouched otherwise.
  await auth.getUser("userB");
  await auth.getUser("userC");
  for (const p of ["users/userB", "users/userB/pushInstallations/inst_userB",
    "users/userB/private/account", "followers/userB", "posts/postB", "users/userC"]) {
    assert.equal(await exists(p), true, `kept: ${p}`);
  }
  for (const f of ["users/userB/profile_1.jpg", "post_images/userB/1.jpg"]) {
    assert.equal(await fileExists(f), true, `B kept: ${f}`);
  }

  // Running it again is harmless (daily job retries).
  const again = await deleteUserData({ db, bucket, auth, uid: "userA", FieldValue: admin.firestore.FieldValue });
  assert.equal(again.posts, 0);
  await auth.getUser("userB");
});

test("a failed cleanup leaves a durable record; the retry finishes it", { skip: !emulated }, async () => {
  await seed();
  const { deleteUserData, retryUnfinishedDeletions } = require("../../account/delete_account");
  const FieldValue = admin.firestore.FieldValue;
  // Simulate a missing collection-group index on the first run.
  const brokenDb = new Proxy(db, {
    get(target, prop) {
      if (prop === "collectionGroup") {
        return () => ({ where: () => ({ get: async () => { throw new Error("FAILED_PRECONDITION: index"); } }) });
      }
      const v = target[prop];
      return typeof v === "function" ? v.bind(target) : v;
    },
  });
  const first = await deleteUserData({ db: brokenDb, bucket, auth, uid: "userA", FieldValue });
  assert.equal(first.complete, false, "not claimed complete");
  const rec = (await db.doc("accountDeletions/userA").get()).data();
  assert.equal(rec.status, "cleanup_pending");
  assert.match(rec.lastError, /index/);
  assert.equal(await exists("users/userA"), false, "account itself is gone");
  assert.equal(await exists("posts/postB/comments/c_byA"), true, "cleanup still to do");

  const results = await retryUnfinishedDeletions({ db, bucket, auth, FieldValue });
  assert.deepEqual(results, [{ uid: "userA", complete: true }]);
  assert.equal(await exists("accountDeletions/userA"), false, "record cleared when done");
  assert.equal(await exists("posts/postB/comments/c_byA"), false);
  assert.equal(await exists("reviews/consultBA"), false);
  assert.equal(await exists("users/userB"), true);
  assert.equal((await db.doc("posts/postB/comments/c_byC").get()).data().content, "C on B");

  // Nothing left to retry; running again is harmless.
  assert.deepEqual(await retryUnfinishedDeletions({ db, bucket, auth, FieldValue }), []);
});

test("a successful deletion leaves no deletion record", { skip: !emulated }, async () => {
  await seed();
  const { deleteUserData } = require("../../account/delete_account");
  const res = await deleteUserData({ db, bucket, auth, uid: "userA", FieldValue: admin.firestore.FieldValue });
  assert.equal(res.complete, true);
  assert.equal(await exists("accountDeletions/userA"), false);
});
