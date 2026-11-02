"use strict";

// MVP-2 rules: protected user fields, private reports, participant-only
// consultations, and no messages to someone who blocked you.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { addDoc, collection, doc, getDoc, setDoc, updateDoc } = require("firebase/firestore");

let testEnv;

function firestorePort() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  return Number(host.split(":").pop());
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-mvp-rules",
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
    await setDoc(doc(db, "users/alice"), { fullName: "Alice", stripeCustomerId: "cus_1", ageDeclaration: "adult" });
    await setDoc(doc(db, "users/bob"), { fullName: "Bob", blockedUids: ["mallory"], ageDeclaration: "adult" });
    await setDoc(doc(db, "users/mallory"), { fullName: "Mallory", ageDeclaration: "adult" });
    await setDoc(doc(db, "chats/alice_bob"), { participants: ["alice", "bob"] });
    await setDoc(doc(db, "chats/bob_mallory"), { participants: ["bob", "mallory"] });
    await setDoc(doc(db, "consultations/c1"), {
      userId: "alice",
      targetUserId: "bob",
      participants: ["alice", "bob"],
    });
    await setDoc(doc(db, "reports/r1"), { reporterUid: "alice", targetUid: "mallory" });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();

test("users can edit their profile but not verification or payment ids", async () => {
  const db = as("alice");
  await assertSucceeds(updateDoc(doc(db, "users/alice"), { bio: "Hi", blockedUids: ["x"] }));
  await assertFails(updateDoc(doc(db, "users/alice"), { isVerified: true }));
  await assertFails(updateDoc(doc(db, "users/alice"), { stripeCustomerId: "cus_other" }));
  await assertFails(updateDoc(doc(db, "users/alice"), { rating: 5 }));
  await assertFails(setDoc(doc(as("newbie"), "users/newbie"), { fullName: "N", isVerified: true }));
  await assertSucceeds(setDoc(doc(as("newbie"), "users/newbie"), { fullName: "N" }));
});

test("reports are write-only and must name the reporter", async () => {
  await assertSucceeds(
    addDoc(collection(as("bob"), "reports"), { reporterUid: "bob", targetUid: "mallory" }),
  );
  await assertFails(
    addDoc(collection(as("bob"), "reports"), { reporterUid: "alice", targetUid: "mallory" }),
  );
  await assertFails(getDoc(doc(as("alice"), "reports/r1")));
  await assertFails(getDoc(doc(as("mallory"), "reports/r1")));
});

test("consultations are visible to their two participants only", async () => {
  await assertSucceeds(getDoc(doc(as("alice"), "consultations/c1")));
  await assertSucceeds(getDoc(doc(as("bob"), "consultations/c1")));
  await assertFails(getDoc(doc(as("mallory"), "consultations/c1")));
  await assertSucceeds(
    setDoc(doc(as("alice"), "consultations/c2"), {
      userId: "alice",
      targetUserId: "bob",
      participants: ["alice", "bob"],
    }),
  );
  await assertFails(
    setDoc(doc(as("mallory"), "consultations/c3"), {
      userId: "alice",
      targetUserId: "bob",
      participants: ["alice", "bob"],
    }),
  );
});

test("you cannot message someone who blocked you", async () => {
  await assertSucceeds(
    addDoc(collection(as("alice"), "chats/alice_bob/messages"), { authorId: "alice", text: "hi" }),
  );
  await assertFails(
    addDoc(collection(as("mallory"), "chats/bob_mallory/messages"), {
      authorId: "mallory",
      text: "hi",
    }),
  );
  // Blocking is one-way: bob can still write to mallory.
  await assertSucceeds(
    addDoc(collection(as("bob"), "chats/bob_mallory/messages"), { authorId: "bob", text: "bye" }),
  );
});

test("profiles stay readable to signed-in users", async () => {
  const snap = await assertSucceeds(getDoc(doc(as("mallory"), "users/alice")));
  assert.equal(snap.data().fullName, "Alice");
});

test("senders cannot pre-set the server's notification marker", async () => {
  const alice = as("alice");
  await assertSucceeds(
    addDoc(collection(alice, "chats/alice_bob/messages"), { authorId: "alice", text: "hi" }),
  );
  await assertFails(
    addDoc(collection(alice, "chats/alice_bob/messages"), {
      authorId: "alice",
      text: "hi",
      notifiedAt: new Date(),
    }),
  );
});

test("a self-declared minor stays restricted until an operator reviews it", async () => {
  const alice = as("alice");
  await assertSucceeds(updateDoc(doc(alice, "users/alice"), { ageDeclaration: "minor" }));
  await assertFails(updateDoc(doc(alice, "users/alice"), { ageDeclaration: "adult" }));
  await assertFails(updateDoc(doc(alice, "users/alice"), { ageDeclaration: null }));
  await assertSucceeds(updateDoc(doc(alice, "users/alice"), { bio: "still editable" }));
  const bob = as("bob");
  await assertSucceeds(updateDoc(doc(bob, "users/bob"), { ageDeclaration: "adult" }));
});

test("a first conversation can check for its chat before creating it", async () => {
  const alice = as("alice");
  // Missing chat with alice in the id: readable (as missing).
  const snap = await assertSucceeds(getDoc(doc(alice, "chats/alice_zed")));
  assert.equal(snap.exists(), false);
  // Missing chat without alice: denied.
  await assertFails(getDoc(doc(alice, "chats/bob_zed")));
  // Existing chat of other people: still denied.
  await assertFails(getDoc(doc(as("mallory"), "chats/alice_bob")));
  // Then alice creates it.
  await assertSucceeds(setDoc(doc(alice, "chats/alice_zed"), { users: ["alice", "zed"], participants: ["alice", "zed"] }));
});

test("conversation lists still work (array-contains queries)", async () => {
  const { query, where, getDocs } = require("firebase/firestore");
  const alice = as("alice");
  const byParticipants = await assertSucceeds(
    getDocs(query(collection(alice, "chats"), where("participants", "array-contains", "alice"))),
  );
  assert.ok(byParticipants.size >= 1);
  await assertSucceeds(getDocs(query(collection(alice, "chats"), where("users", "array-contains", "alice"))));
  await assertSucceeds(
    getDocs(query(collection(alice, "consultations"), where("participants", "array-contains", "alice"))),
  );
  await assertSucceeds(getDocs(query(collection(alice, "connections"), where("users", "array-contains", "alice"))));
  await assertSucceeds(getDocs(query(collection(alice, "connections"), where("userId", "==", "alice"))));
  await assertSucceeds(getDocs(query(collection(alice, "connections"), where("connectedUserId", "==", "alice"))));
  // Unfiltered lists stay denied.
  await assertFails(getDocs(collection(alice, "chats")));
  await assertFails(getDocs(collection(alice, "consultations")));
  await assertFails(getDocs(collection(alice, "connections")));
});
