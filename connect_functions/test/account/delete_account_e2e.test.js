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
  for (const uid of ["userA", "userB"]) {
    await auth.createUser({ uid, email: `${uid}@example.test`, password: "test-only-123" }).catch(() => {});
    await db.doc(`users/${uid}`).set({ fullName: uid, ageDeclaration: "adult" });
    await db.doc(`users/${uid}/pushInstallations/inst_${uid}`).set({ fcmToken: "t" });
    await db.doc(`users/${uid}/private/account`).set({ email: `${uid}@example.test` });
    await db.doc(`followers/${uid}`).set({ count: 1 });
    await db.doc(`followers/${uid}/userFollowers/x`).set({ at: 1 });
  }
  await db.doc("posts/postA").set({ userID: "userA", content: "A's post" });
  await db.doc("posts/postA/comments/c_byB").set({ userID: "userB", content: "B on A" });
  await db.doc("posts/postA_legacy").set({ userId: "userA", content: "legacy field" });
  await db.doc("posts/postB").set({ userID: "userB", content: "B's post" });
  await db.doc("posts/postB/comments/c_byA").set({ userID: "userA", content: "A on B" });
  await db.doc("chats/userA_userB").set({ participants: ["userA", "userB"] });
  await db.doc("chats/userA_userB/messages/m1").set({ authorId: "userA", text: "hi B" });
  await db.doc("chats/userA_userB/messages/m2").set({ authorId: "userB", text: "hi A" });
  await db.doc("callInvites/inv1").set({ fromUid: "userA", toUid: "userB", status: "ended" });
  await db.doc("reviews/consultAB").set({ reviewerUid: "userA", helperUid: "userB", stars: 5, text: "A about B" });
  await db.doc("reviews/consultBA").set({ reviewerUid: "userB", helperUid: "userA", stars: 4, text: "B about A" });
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
  const summary = await deleteUserData({ db, bucket, auth, uid: "userA" });
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

  // Review A wrote: text removed, stars kept.
  const rAB = (await db.doc("reviews/consultAB").get()).data();
  assert.equal(rAB.text, "");
  assert.equal(rAB.stars, 5);
  assert.equal(rAB.reviewerDeleted, true);

  // Kept by design (documented retention).
  for (const p of ["chats/userA_userB/messages/m1", "chats/userA_userB/messages/m2",
    "callInvites/inv1", "reports/r1", "consultations/consultAB",
    "paymentOperations/op_userA_000000001"]) {
    assert.equal(await exists(p), true, `kept: ${p}`);
  }
  assert.equal(await fileExists("chats/userA_userB/images/1.jpg"), true, "chat media kept");

  // Findings recorded in docs/ACCOUNT_DELETION_E2E.md.
  assert.equal(await exists("posts/postB/comments/c_byA"), true, "A's comment on B's post remains");
  assert.equal(await exists("reviews/consultBA"), true, "reviews about A remain");

  // B is untouched.
  await auth.getUser("userB");
  for (const p of ["users/userB", "users/userB/pushInstallations/inst_userB",
    "users/userB/private/account", "followers/userB", "posts/postB"]) {
    assert.equal(await exists(p), true, `B kept: ${p}`);
  }
  for (const f of ["users/userB/profile_1.jpg", "post_images/userB/1.jpg"]) {
    assert.equal(await fileExists(f), true, `B kept: ${f}`);
  }

  // Running it again is harmless (daily job retries).
  const again = await deleteUserData({ db, bucket, auth, uid: "userA" });
  assert.equal(again.posts, 0);
  await auth.getUser("userB");
});
