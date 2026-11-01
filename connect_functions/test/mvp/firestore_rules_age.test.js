"use strict";

// 18+ policy enforced by rules: legacy accounts keep working, new accounts
// need a declaration (old builds can't bypass), declared minors are
// restricted both ways, and createdAt can't be backdated.

const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  Timestamp,
  addDoc,
  collection,
  deleteField,
  doc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

let testEnv;
const port = () => Number((process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080").split(":").pop());

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-age-rules",
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: port(),
    },
  });
});

const OLD = Timestamp.fromDate(new Date("2025-06-01T00:00:00Z"));
const NEW = Timestamp.fromDate(new Date("2026-12-01T00:00:00Z"));

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const user = (uid, data) => setDoc(doc(db, `users/${uid}`), { fullName: uid, ...data });
    await user("legacy", { createdAt: OLD });
    await user("ancient", {}); // no createdAt at all
    await user("newbie", { createdAt: NEW }); // old build, no declaration
    await user("adult", { createdAt: NEW, ageDeclaration: "adult" });
    await user("minor", { createdAt: OLD, ageDeclaration: "minor" });
    await user("friend", { createdAt: OLD, ageDeclaration: "adult" });
    for (const [a, b] of [["legacy", "friend"], ["ancient", "friend"], ["newbie", "friend"],
      ["adult", "friend"], ["minor", "friend"]]) {
      await setDoc(doc(db, `chats/${a}_${b}`), { participants: [a, b] });
    }
    await setDoc(doc(db, "posts/p1"), { userID: "friend", content: "hi" });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();

function actions(uid) {
  const db = as(uid);
  return {
    post: () => setDoc(doc(db, `posts/${uid}_post`), { userID: uid, content: "x" }),
    comment: () => addDoc(collection(db, "posts/p1/comments"), { userID: uid, content: "x" }),
    message: () => addDoc(collection(db, `chats/${uid}_friend/messages`), { authorId: uid, text: "x" }),
    call: () => addDoc(collection(db, "callInvites"), { fromUid: uid, toUid: "friend", status: "ringing" }),
    connect: () => setDoc(doc(db, `connections/${uid}_friend`), { users: [uid, "friend"], userId: uid, connectedUserId: "friend" }),
  };
}

test("accounts from before the policy keep working without a declaration", async () => {
  for (const uid of ["legacy", "ancient"]) {
    const a = actions(uid);
    await assertSucceeds(a.post());
    await assertSucceeds(a.comment());
    await assertSucceeds(a.message());
    await assertSucceeds(a.call());
  }
});

test("new accounts without a declaration (old builds) are blocked", async () => {
  const a = actions("newbie");
  await assertFails(a.post());
  await assertFails(a.comment());
  await assertFails(a.message());
  await assertFails(a.call());
  await assertFails(a.connect());
});

test("declared adults can use everything", async () => {
  const a = actions("adult");
  await assertSucceeds(a.post());
  await assertSucceeds(a.comment());
  await assertSucceeds(a.message());
  await assertSucceeds(a.call());
});

test("declared minors are restricted, and cannot be called or messaged", async () => {
  const a = actions("minor");
  await assertFails(a.post());
  await assertFails(a.message());
  await assertFails(a.call());
  const friend = as("friend");
  await assertFails(addDoc(collection(friend, "callInvites"), { fromUid: "friend", toUid: "minor", status: "ringing" }));
  await assertFails(addDoc(collection(friend, "chats/minor_friend/messages"), { authorId: "friend", text: "x" }));
});

test("restricted and new accounts can still declare, edit and leave", async () => {
  await assertSucceeds(updateDoc(doc(as("newbie"), "users/newbie"), { ageDeclaration: "adult" }));
  await assertSucceeds(actions("newbie").message());
  await assertSucceeds(updateDoc(doc(as("minor"), "users/minor"), { bio: "still mine" }));
});

test("createdAt cannot be backdated or removed, only refreshed to now", async () => {
  const db = as("newbie");
  await assertFails(updateDoc(doc(db, "users/newbie"), { createdAt: OLD }));
  await assertFails(updateDoc(doc(db, "users/newbie"), { createdAt: deleteField() }));
  await assertSucceeds(updateDoc(doc(db, "users/newbie"), { createdAt: serverTimestamp() }));
  const fresh = as("fresh");
  await assertFails(setDoc(doc(fresh, "users/fresh"), { fullName: "f", createdAt: OLD }));
  await assertSucceeds(setDoc(doc(fresh, "users/fresh"), { fullName: "f", createdAt: serverTimestamp() }));
});
