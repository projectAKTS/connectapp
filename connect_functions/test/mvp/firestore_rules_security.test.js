"use strict";

// Security review 2026-11-13: one user must not be able to enter another
// pair's chat or connection, write a reply in someone else's name, or
// change other people's likes on a post.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  addDoc, arrayRemove, arrayUnion, collection, doc, getDoc, getDocs, increment, serverTimestamp, setDoc, updateDoc,
} = require("firebase/firestore");

let testEnv;

function firestorePort() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  return Number(host.split(":").pop());
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-mvp-security",
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: firestorePort(),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const uid of ["alice", "bob", "mallory"]) {
      await setDoc(doc(db, `users/${uid}`), { fullName: uid, ageDeclaration: "adult" });
    }
    await setDoc(doc(db, "chats/alice_bob"), { participants: ["alice", "bob"], users: ["alice", "bob"] });
    await setDoc(doc(db, "chats/alice_bob/messages/m1"), { authorId: "alice", type: "text", text: "private" });
    // A legacy chat that never got its participant lists.
    await setDoc(doc(db, "chats/alice_mallory"), { updatedAt: 1 });
    await setDoc(doc(db, "connections/alice_bob"), { users: ["alice", "bob"], userId: "alice", connectedUserId: "bob" });
    await setDoc(doc(db, "connections/random1"), { users: ["alice", "bob"] });
    await setDoc(doc(db, "posts/p1"), { userID: "alice", content: "hi", likes: 1, likedBy: ["bob"] });
    await setDoc(doc(db, "posts/p1/comments/c1"), { userID: "bob", text: "ok" });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();

test("a stranger cannot add themselves to someone else's chat", async () => {
  const mallory = as("mallory");
  await assertFails(updateDoc(doc(mallory, "chats/alice_bob"), { participants: arrayUnion("mallory") }));
  await assertFails(updateDoc(doc(mallory, "chats/alice_bob"), { users: ["alice", "bob", "mallory"] }));
  await assertFails(
    setDoc(doc(mallory, "chats/alice_bob"), { users: ["mallory"], participants: ["mallory"] }, { merge: true }),
  );
  await assertFails(getDoc(doc(mallory, "chats/alice_bob/messages/m1")));
  await assertFails(getDocs(collection(mallory, "chats/alice_bob/messages")));
});

test("the people in a chat can still open, refresh and mark it read", async () => {
  const alice = as("alice");
  // What the chat screen writes when it opens an existing chat.
  await assertSucceeds(
    setDoc(doc(alice, "chats/alice_bob"), { users: ["alice", "bob"], participants: ["alice", "bob"] }, { merge: true }),
  );
  await assertSucceeds(setDoc(doc(alice, "chats/alice_bob"), { unreadBy: { alice: 0 } }, { merge: true }));
  // What a missed call writes.
  await assertSucceeds(
    setDoc(
      doc(as("bob"), "chats/alice_bob"),
      { users: arrayUnion("bob", "alice"), participants: arrayUnion("bob", "alice"), lastMessageType: "missed_call" },
      { merge: true },
    ),
  );
  await assertSucceeds(getDoc(doc(alice, "chats/alice_bob/messages/m1")));
});

test("a legacy chat without participant lists can be repaired only by the people in its id", async () => {
  await assertFails(
    setDoc(doc(as("bob"), "chats/alice_mallory"), { users: ["bob"], participants: ["bob"] }, { merge: true }),
  );
  await assertSucceeds(
    setDoc(
      doc(as("mallory"), "chats/alice_mallory"),
      { users: ["alice", "mallory"], participants: ["alice", "mallory"] },
      { merge: true },
    ),
  );
});

test("a stranger cannot write into someone else's connection", async () => {
  const mallory = as("mallory");
  await assertFails(updateDoc(doc(mallory, "connections/alice_bob"), { users: ["alice", "mallory"] }));
  await assertFails(updateDoc(doc(mallory, "connections/random1"), { users: ["mallory", "bob"] }));
  await assertFails(
    setDoc(doc(mallory, "connections/alice_bob"), { userId: "mallory", connectedUserId: "bob" }, { merge: true }),
  );
});

test("connections still work for the two people in them", async () => {
  const alice = as("alice");
  // InteractionService: set-merge on the pair's document, existing or new.
  await assertSucceeds(
    setDoc(
      doc(alice, "connections/alice_bob"),
      { userId: "alice", connectedUserId: "bob", users: ["alice", "bob"], lastInteractionAt: serverTimestamp() },
      { merge: true },
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(alice, "connections/alice_mallory"),
      { userId: "alice", connectedUserId: "mallory", users: ["alice", "mallory"] },
      { merge: true },
    ),
  );
  // ConnectionService: refresh an existing one, or add a new one.
  await assertSucceeds(updateDoc(doc(as("bob"), "connections/random1"), { connectedAt: serverTimestamp() }));
  await assertSucceeds(addDoc(collection(alice, "connections"), { users: ["alice", "mallory"] }));
});

test("replies are written as yourself only", async () => {
  const replies = (db) => collection(db, "posts/p1/comments/c1/replies");
  await assertFails(addDoc(replies(as("mallory")), { userID: "alice", content: "I agree" }));
  await assertFails(addDoc(replies(as("mallory")), { content: "no author" }));
  await assertSucceeds(addDoc(replies(as("mallory")), { userID: "mallory", content: "mine" }));
});

test("a like adds or removes only your own name and moves the count by one", async () => {
  const post = (uid) => doc(as(uid), "posts/p1");
  // Wiping or faking other people's likes.
  await assertFails(updateDoc(post("mallory"), { likes: 0, likedBy: [] }));
  await assertFails(updateDoc(post("mallory"), { likes: 500, likedBy: arrayUnion("mallory") }));
  await assertFails(updateDoc(post("mallory"), { likes: increment(1), likedBy: arrayUnion("alice2") }));
  await assertFails(updateDoc(post("mallory"), { likes: increment(1), likedBy: arrayRemove("bob") }));
  await assertFails(updateDoc(post("mallory"), { likes: increment(5) }));
  // What the post card writes.
  await assertSucceeds(updateDoc(post("mallory"), { likes: increment(1), likedBy: arrayUnion("mallory") }));
  await assertSucceeds(updateDoc(post("mallory"), { likes: increment(-1), likedBy: arrayRemove("mallory") }));
  await assertSucceeds(updateDoc(post("bob"), { likes: increment(-1), likedBy: arrayRemove("bob") }));
  // Still no self-likes.
  await assertFails(updateDoc(post("alice"), { likes: increment(1), likedBy: arrayUnion("alice") }));
  const after = (await getDoc(doc(as("alice"), "posts/p1"))).data();
  assert.deepEqual(after.likedBy, []);
  assert.equal(after.likes, 0);
});

test("a post's old `reports` field cannot be written by clients", async () => {
  await assertFails(updateDoc(doc(as("mallory"), "posts/p1"), { reports: [] }));
  await assertFails(updateDoc(doc(as("alice"), "posts/p1"), { reports: 0 }));
});
