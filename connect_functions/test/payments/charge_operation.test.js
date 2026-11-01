"use strict";

const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  KEY_TTL_MS,
  chargeOnce,
  reconcilePaymentIntent,
} = require("../../payments/charge_operation");

// In-memory Firestore: transactions run one at a time, like Firestore's
// serializable transactions after contention retries.
function fakeDb() {
  const docs = new Map();
  let chain = Promise.resolve();
  const ref = (path) => ({ path });
  const db = {
    docs,
    collection: (name) => ({ doc: (id) => ref(`${name}/${id}`) }),
    runTransaction(fn) {
      const run = chain.then(() => {
        const writes = [];
        const tx = {
          get: async (r) => ({
            exists: docs.has(r.path),
            data: () => ({ ...docs.get(r.path) }),
          }),
          set: (r, v) => writes.push(() => docs.set(r.path, { ...v })),
          update: (r, v) =>
            writes.push(() => docs.set(r.path, { ...docs.get(r.path), ...v })),
        };
        return fn(tx).then((res) => {
          writes.forEach((w) => w());
          return res;
        });
      });
      chain = run.catch(() => {});
      return run;
    },
  };
  return db;
}

// Stripe with idempotency semantics: same key -> same result; a key whose
// first request is still running -> 409.
function fakeStripe({ outcome = "succeeded", delayMs = 0, failNetworkTimes = 0 } = {}) {
  const byKey = new Map();
  const inFlight = new Set();
  const intents = [];
  let networkFailures = failNetworkTimes;
  const stripe = {
    intents,
    paymentIntents: {
      async create(params, { idempotencyKey }) {
        if (inFlight.has(idempotencyKey)) {
          const e = new Error("in use");
          e.code = "idempotency_key_in_use";
          e.statusCode = 409;
          throw e;
        }
        if (byKey.has(idempotencyKey)) return byKey.get(idempotencyKey);
        if (networkFailures > 0) {
          networkFailures -= 1;
          throw new Error("ETIMEDOUT");
        }
        inFlight.add(idempotencyKey);
        await new Promise((r) => setTimeout(r, delayMs));
        inFlight.delete(idempotencyKey);
        if (outcome === "declined") {
          const e = new Error("Your card was declined.");
          e.type = "StripeCardError";
          e.code = "card_declined";
          byKey.set(idempotencyKey, Promise.reject(e));
          byKey.get(idempotencyKey).catch(() => {});
          throw e;
        }
        const pi = { id: `pi_${intents.length + 1}`, status: outcome, metadata: params.metadata, amount: params.amount };
        intents.push(pi);
        byKey.set(idempotencyKey, pi);
        return pi;
      },
      async retrieve(id) {
        return intents.find((p) => p.id === id);
      },
      async search({ query }) {
        const op = /'operationId'\]:'([^']+)'/.exec(query)?.[1];
        return { data: intents.filter((p) => p.metadata.operationId === op) };
      },
    },
  };
  return stripe;
}

const OP = "op_1234567890abcdef";
const priced = { amount: 4.49, durationMinutes: 10, callType: "audio" };
const customer = { stripeCustomerId: "cus_1", defaultPaymentMethodId: "pm_1" };
const ts = () => "SERVER_TS";

function call(db, stripe, extra = {}) {
  return chargeOnce({
    db,
    stripe,
    uid: "seeker",
    operationId: OP,
    helperId: "helper",
    priced,
    customer,
    pricingVersion: "v1",
    serverTimestamp: ts,
    ...extra,
  });
}

test("retrying the same operation charges once and replays the result", async () => {
  const db = fakeDb();
  const stripe = fakeStripe();
  const first = await call(db, stripe);
  const second = await call(db, stripe);
  assert.equal(stripe.intents.length, 1);
  assert.equal(first.id, second.id);
  assert.equal(second.replayed, true);
  assert.equal(first.amount, 4.49);
  assert.equal(db.docs.get(`paymentOperations/${OP}`).status, "succeeded");
});

test("concurrent requests for one operation create one PaymentIntent", async () => {
  const db = fakeDb();
  const stripe = fakeStripe({ delayMs: 20 });
  const results = await Promise.allSettled([call(db, stripe), call(db, stripe), call(db, stripe)]);
  assert.equal(stripe.intents.length, 1);
  const ok = results.filter((r) => r.status === "fulfilled");
  assert.ok(ok.length >= 1);
  for (const r of results.filter((r) => r.status === "rejected")) {
    assert.equal(r.reason.code, "aborted", "the others are told to retry");
  }
  const retry = await call(db, stripe);
  assert.equal(retry.id, stripe.intents[0].id);
});

test("a timeout before the result is recorded is recovered without a second charge", async () => {
  const db = fakeDb();
  const stripe = fakeStripe({ failNetworkTimes: 1 });
  await assert.rejects(call(db, stripe), (e) => e.code === "unavailable");
  assert.equal(db.docs.get(`paymentOperations/${OP}`).status, "processing");
  const retry = await call(db, stripe);
  assert.equal(retry.success, true);
  assert.equal(stripe.intents.length, 1);
});

test("an earlier charge that was never recorded is found, not repeated", async () => {
  const db = fakeDb();
  const stripe = fakeStripe();
  await call(db, stripe);
  // Simulate a crash after Stripe charged but before we recorded it.
  const doc = db.docs.get(`paymentOperations/${OP}`);
  db.docs.set(`paymentOperations/${OP}`, { ...doc, status: "processing", paymentIntentId: undefined });
  const createdBefore = stripe.intents.length;
  const retry = await call(db, stripe, {
    stripe: { ...stripe, paymentIntents: { ...stripe.paymentIntents, create: async () => assert.fail("must not create") } },
  });
  assert.equal(retry.success, true);
  assert.equal(stripe.intents.length, createdBefore);
});

test("declines are final for the operation; a new operation can try again", async () => {
  const db = fakeDb();
  const declined = fakeStripe({ outcome: "declined" });
  await assert.rejects(call(db, declined), (e) => e.code === "failed-precondition");
  await assert.rejects(call(db, declined), (e) => e.code === "failed-precondition");
  assert.equal(db.docs.get(`paymentOperations/${OP}`).status, "failed");
  const ok = await call(db, fakeStripe(), { operationId: "op_new_attempt_000001" });
  assert.equal(ok.success, true);
});

test("an operation cannot be reused by another user or for another charge", async () => {
  const db = fakeDb();
  const stripe = fakeStripe();
  await call(db, stripe);
  await assert.rejects(call(db, stripe, { uid: "mallory" }), (e) => e.code === "permission-denied");
  await assert.rejects(
    call(db, stripe, { priced: { ...priced, amount: 0.5 } }),
    (e) => e.code === "invalid-argument",
  );
  await assert.rejects(call(db, stripe, { helperId: "other" }), (e) => e.code === "invalid-argument");
  assert.equal(stripe.intents.length, 1);
});

test("missing or malformed operation ids are rejected before any charge", async () => {
  const db = fakeDb();
  const stripe = fakeStripe();
  for (const bad of [undefined, "", "short", "has spaces in it!!!!"]) {
    await assert.rejects(call(db, stripe, { operationId: bad }), (e) => e.code === "invalid-argument");
  }
  assert.equal(stripe.intents.length, 0);
});

test("stale processing attempts past the key lifetime are not charged again", async () => {
  const db = fakeDb();
  const stripe = fakeStripe({ failNetworkTimes: 1 });
  let clock = 1_000_000;
  await assert.rejects(call(db, stripe, { now: () => clock }), (e) => e.code === "unavailable");
  clock += KEY_TTL_MS + 1;
  await assert.rejects(call(db, stripe, { now: () => clock }), (e) => e.code === "failed-precondition");
  assert.equal(stripe.intents.length, 0);
});

test("webhook events reconcile once and never undo a success", async () => {
  const db = fakeDb();
  const stripe = fakeStripe();
  const res = await call(db, stripe);
  const pi = { id: res.id, status: "succeeded", metadata: { operationId: OP } };
  assert.equal(await reconcilePaymentIntent(db, pi, ts), true);
  assert.equal(await reconcilePaymentIntent(db, pi, ts), true, "duplicate is harmless");
  await reconcilePaymentIntent(db, { ...pi, status: "requires_payment_method" }, ts);
  assert.equal(db.docs.get(`paymentOperations/${OP}`).status, "succeeded");
  assert.equal(await reconcilePaymentIntent(db, { id: "pi_x", status: "succeeded", metadata: {} }, ts), false);
});
