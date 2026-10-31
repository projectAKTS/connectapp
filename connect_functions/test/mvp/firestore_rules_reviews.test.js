"use strict";

// MVP-5 rules: only the payer reviews a consultation, once, after its start
// time; helpers cannot set their own rating.

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
  Timestamp,
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

const HOUR = 60 * 60 * 1000;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-mvp-reviews",
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
    const consultation = (id, data) =>
      setDoc(doc(db, `consultations/${id}`), {
        userId: "alice",
        targetUserId: "bob",
        participants: ["alice", "bob"],
        status: "scheduled",
        ...data,
      });
    await setDoc(doc(db, "users/bob"), { fullName: "Bob", rating: 4, ratingCount: 1 });
    await consultation("past", { scheduledAt: Timestamp.fromMillis(Date.now() - HOUR) });
    await consultation("future", { scheduledAt: Timestamp.fromMillis(Date.now() + HOUR) });
    await consultation("cancelled", {
      scheduledAt: Timestamp.fromMillis(Date.now() - HOUR),
      status: "cancelled",
    });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();

const review = (id, extra = {}) => ({
  consultationId: id,
  reviewerUid: "alice",
  helperUid: "bob",
  stars: 5,
  text: "Very helpful with my resume.",
  createdAt: serverTimestamp(),
  ...extra,
});

test("the payer reviews a past consultation once", async () => {
  const alice = as("alice");
  await assertSucceeds(setDoc(doc(alice, "reviews/past"), review("past")));
  await assertFails(setDoc(doc(alice, "reviews/past"), review("past", { stars: 1 })));
  await assertFails(updateDoc(doc(alice, "reviews/past"), { stars: 1 }));
  const read = await assertSucceeds(getDoc(doc(as("carol"), "reviews/past")));
  assert.equal(read.data().stars, 5);
});

test("no review before the session, after a cancellation, or by others", async () => {
  await assertFails(setDoc(doc(as("alice"), "reviews/future"), review("future")));
  await assertFails(setDoc(doc(as("alice"), "reviews/cancelled"), review("cancelled")));
  await assertFails(
    setDoc(doc(as("bob"), "reviews/past"), review("past", { reviewerUid: "bob", helperUid: "alice" })),
  );
  await assertFails(
    setDoc(doc(as("carol"), "reviews/past"), review("past", { reviewerUid: "carol" })),
  );
  await assertFails(setDoc(doc(as("alice"), "reviews/missing"), review("missing")));
});

test("stars, text, helper and extra fields are checked", async () => {
  const alice = as("alice");
  for (const bad of [
    { stars: 0 },
    { stars: 6 },
    { stars: 4.5 },
    { text: "x".repeat(501) },
    { helperUid: "carol" },
    { countedAt: serverTimestamp() },
    { consultationId: "future" },
  ]) {
    await assertFails(setDoc(doc(alice, "reviews/past"), review("past", bad)));
  }
  const { text, ...noText } = review("past");
  assert.ok(text);
  await assertSucceeds(setDoc(doc(alice, "reviews/past"), noText));
});

test("helpers cannot set their own rating", async () => {
  const bob = as("bob");
  await assertFails(updateDoc(doc(bob, "users/bob"), { rating: 5 }));
  await assertFails(updateDoc(doc(bob, "users/bob"), { ratingSum: 50 }));
  await assertFails(updateDoc(doc(bob, "users/bob"), { ratingCount: 10 }));
  await assertSucceeds(updateDoc(doc(bob, "users/bob"), { fullName: "Bobby" }));
});
