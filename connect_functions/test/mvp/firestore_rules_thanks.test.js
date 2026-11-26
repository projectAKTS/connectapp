"use strict";

// Thank-you notes: one per person per chat, only to someone who wrote in
// that chat; no edits; sender or recipient may delete.

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
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

let testEnv;

function firestorePort() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  return Number(host.split(":").pop());
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-mvp-thanks",
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
    // Bob replied to Alice: Alice may thank Bob.
    await setDoc(doc(db, "chats/alice_bob"), {
      participants: ["alice", "bob"],
      repliedBy: ["alice", "bob"],
    });
    // Dave never wrote back: no thanks yet.
    await setDoc(doc(db, "chats/alice_dave"), {
      participants: ["alice", "dave"],
      repliedBy: ["alice"],
    });
    // Legacy chat with `users` instead of `participants`.
    await setDoc(doc(db, "chats/alice_erin"), {
      users: ["alice", "erin"],
      repliedBy: ["erin"],
    });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();

const note = (extra = {}) => ({
  chatId: "alice_bob",
  fromUid: "alice",
  toUid: "bob",
  text: "You found me a flat in two days. Thank you!",
  createdAt: serverTimestamp(),
  ...extra,
});

test("a person thanks someone who replied, once per chat; anyone signed in reads it", async () => {
  const alice = as("alice");
  await assertSucceeds(setDoc(doc(alice, "thanks/alice_bob_alice"), note()));
  await assertFails(setDoc(doc(alice, "thanks/alice_bob_alice"), note({ text: "Again" })));
  await assertFails(updateDoc(doc(alice, "thanks/alice_bob_alice"), { text: "Edited" }));
  const read = await assertSucceeds(getDoc(doc(as("carol"), "thanks/alice_bob_alice")));
  assert.equal(read.data().toUid, "bob");
  await assertFails(getDoc(doc(testEnv.unauthenticatedContext().firestore(), "thanks/alice_bob_alice")));
  await assertSucceeds(
    setDoc(doc(alice, "thanks/alice_erin_alice"), note({ chatId: "alice_erin", toUid: "erin" })),
  );
});

test("no thanks to someone who never wrote, to yourself, by outsiders, or with a wrong id", async () => {
  const alice = as("alice");
  await assertFails(
    setDoc(doc(alice, "thanks/alice_dave_alice"), note({ chatId: "alice_dave", toUid: "dave" })),
  );
  await assertFails(setDoc(doc(alice, "thanks/alice_bob_alice"), note({ toUid: "alice" })));
  await assertFails(
    setDoc(doc(as("carol"), "thanks/alice_bob_carol"), note({ fromUid: "carol" })),
  );
  await assertFails(setDoc(doc(alice, "thanks/alice_bob_x"), note()));
  await assertFails(setDoc(doc(alice, "thanks/alice_bob_alice"), note({ fromUid: "bob" })));
  await assertFails(
    setDoc(doc(alice, "thanks/missing_alice"), note({ chatId: "missing" })),
  );
});

test("text and fields are checked", async () => {
  const alice = as("alice");
  for (const bad of [
    { text: "" },
    { text: "   " },
    { text: "x".repeat(281) },
    { text: 5 },
    { stars: 5 },
    { createdAt: new Date(0) },
  ]) {
    await assertFails(setDoc(doc(alice, "thanks/alice_bob_alice"), note(bad)));
  }
  await assertSucceeds(
    setDoc(doc(alice, "thanks/alice_bob_alice"), note({ text: "x".repeat(280) })),
  );
});

test("the sender or the recipient may delete; nobody else", async () => {
  await assertSucceeds(setDoc(doc(as("alice"), "thanks/alice_bob_alice"), note()));
  await assertFails(deleteDoc(doc(as("carol"), "thanks/alice_bob_alice")));
  await assertSucceeds(deleteDoc(doc(as("bob"), "thanks/alice_bob_alice")));
  await assertSucceeds(setDoc(doc(as("alice"), "thanks/alice_bob_alice"), note()));
  await assertSucceeds(deleteDoc(doc(as("alice"), "thanks/alice_bob_alice")));
});
