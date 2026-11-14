"use strict";

// Paid sessions (docs/PAID_SESSIONS_DESIGN.md): clients write only free
// consultations; prices, payments and payout states are the server's.

const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, test } = require("node:test");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, serverTimestamp, setDoc, updateDoc } = require("firebase/firestore");

let testEnv;

function firestorePort() {
  const host = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
  return Number(host.split(":").pop());
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-helperly-mvp-payments",
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
    for (const uid of ["alice", "bob"]) {
      await setDoc(doc(db, `users/${uid}`), { fullName: uid, ageDeclaration: "adult" });
    }
    await setDoc(doc(db, "consultations/paid1"), {
      userId: "alice", targetUserId: "bob", participants: ["alice", "bob"],
      amountCents: 449, status: "paid", payoutState: "held",
    });
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const as = (uid) => testEnv.authenticatedContext(uid).firestore();

// What ConsultationService.bookConsultation writes for a free session.
function freeBooking(extra = {}) {
  return {
    consultationId: "f1", userId: "alice", targetUserId: "bob", participants: ["alice", "bob"],
    roomId: "room", minutesRequested: 1, cost: 0, currency: "cad", paymentIntentId: null,
    status: "scheduled", timestamp: serverTimestamp(), scheduledAt: new Date(),
    ...extra,
  };
}

test("the app can still book a free session", async () => {
  await assertSucceeds(setDoc(doc(as("alice"), "consultations/f1"), freeBooking()));
});

test("a client cannot write a paid, priced or released consultation", async () => {
  const alice = as("alice");
  const bad = [
    { cost: 4.49 },
    { paymentIntentId: "pi_someone_else" },
    { status: "paid" },
    { status: "completed" },
    { amountCents: 449 },
    { payoutState: "held" },
    { helperShareCents: 100 },
    { releaseAfter: new Date() },
    { participants: ["alice", "bob", "carol"] },
    { participants: ["alice", "carol"] },
    { targetUserId: "alice", participants: ["alice", "alice"] },
  ];
  for (const [i, extra] of bad.entries()) {
    await assertFails(setDoc(doc(alice, `consultations/bad${i}`), freeBooking(extra)), JSON.stringify(extra));
  }
});

test("nobody can change a consultation from the app", async () => {
  await assertFails(updateDoc(doc(as("alice"), "consultations/paid1"), { status: "completed" }));
  await assertFails(updateDoc(doc(as("bob"), "consultations/paid1"), { payoutState: "released" }));
});

test("payout fields on a profile are the server's; the saved card id is not", async () => {
  const bob = as("bob");
  await assertFails(updateDoc(doc(bob, "users/bob"), { payoutsEnabled: true }));
  await assertFails(updateDoc(doc(bob, "users/bob"), { stripeAccountId: "acct_x" }));
  await assertFails(updateDoc(doc(bob, "users/bob"), { payoutsCheckedAt: new Date() }));
  await assertSucceeds(setDoc(doc(bob, "users/bob"), { defaultPaymentMethodId: "pm_1" }, { merge: true }));
});
