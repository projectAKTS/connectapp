"use strict";

const assert = require("node:assert/strict");
const { beforeEach, test } = require("node:test");

const {
  bookPaidSession,
  cancelConsultation,
  finalizeBooking,
  markDisputed,
  payoutStatusFromAccount,
  refundPercentFor,
  releaseDue,
  reportSessionProblem,
} = require("../../payments/paid_booking");

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;
const T0 = Date.UTC(2026, 10, 14, 12, 0, 0);

// In-memory Firestore with serial transactions.
function fakeDb() {
  const docs = new Map();
  let chain = Promise.resolve();
  const ref = (path) => ({
    path,
    get: async () => ({ exists: docs.has(path), data: () => ({ ...docs.get(path) }) }),
    set: async (v) => docs.set(path, { ...v }),
    update: async (v) => docs.set(path, { ...docs.get(path), ...v }),
  });
  return {
    docs,
    collection: (name) => ({ doc: (id) => ref(`${name}/${id}`) }),
    runTransaction(fn) {
      const run = chain.then(async () => {
        const writes = [];
        const tx = {
          get: async (r) => ({ exists: docs.has(r.path), data: () => ({ ...docs.get(r.path) }) }),
          set: (r, v) => writes.push(() => docs.set(r.path, { ...v })),
          update: (r, v) => writes.push(() => docs.set(r.path, { ...docs.get(r.path), ...v })),
        };
        const res = await fn(tx);
        writes.forEach((w) => w());
        return res;
      });
      chain = run.catch(() => {});
      return run;
    },
  };
}

// Stripe with idempotency: the same key returns the same object.
function fakeStripe({ status = "succeeded", failTransfer = false } = {}) {
  const intents = new Map();
  const byKey = new Map();
  const refunds = [];
  const transfers = [];
  let n = 0;
  const once = (key, make) => {
    if (!byKey.has(key)) byKey.set(key, make());
    return byKey.get(key);
  };
  return {
    intents,
    refunds,
    transfers,
    setStatus(id, s) { intents.get(id).status = s; },
    paymentIntents: {
      async create(params, { idempotencyKey }) {
        return once(idempotencyKey, () => {
          const pi = {
            id: `pi_${++n}`,
            amount: params.amount,
            status,
            client_secret: `pi_${n}_secret`,
            latest_charge: `ch_${n}`,
            metadata: params.metadata,
            params,
          };
          intents.set(pi.id, pi);
          return pi;
        });
      },
      async retrieve(id) { return intents.get(id); },
      async search() { return { data: [] }; },
    },
    refunds: Object.assign(refunds, {
      async create(params, { idempotencyKey }) {
        return once(idempotencyKey, () => {
          const r = { id: `re_${++n}`, ...params };
          refunds.push(r);
          return r;
        });
      },
    }),
    transfers: Object.assign(transfers, {
      async create(params, { idempotencyKey }) {
        if (failTransfer) throw new Error("insufficient balance");
        return once(idempotencyKey, () => {
          const t = { id: `tr_${++n}`, ...params };
          transfers.push(t);
          return t;
        });
      },
    }),
  };
}

let db;
let clock;
function deps(stripe) {
  return {
    db,
    stripe,
    now: () => clock,
    serverTimestamp: () => "SERVER_TS",
    toTimestamp: (ms) => ms,
    newRoomId: () => "room-1",
    pricingVersion: "test",
  };
}

const OP = "op_0123456789abcdef";
function request(extra = {}) {
  return {
    operationId: OP,
    helperId: "helper",
    durationMinutes: 10,
    callType: "audio",
    scheduledAtMs: T0 + 2 * DAY,
    ...extra,
  };
}

beforeEach(() => {
  db = fakeDb();
  clock = T0;
  db.docs.set("users/seeker", {
    ageDeclaration: "adult", stripeCustomerId: "cus_1", defaultPaymentMethodId: "pm_1",
  });
  db.docs.set("users/helper", {
    ageDeclaration: "adult", role: "helper", payoutsEnabled: true, stripeAccountId: "acct_h",
  });
});

test("a booking charges once and the server writes the paid consultation", async () => {
  const stripe = fakeStripe();
  const res = await bookPaidSession(deps(stripe), "seeker", request());
  assert.equal(res.success, true);
  assert.equal(res.consultationId, OP);
  assert.equal(res.amount, 4.49);
  const c = db.docs.get(`consultations/${OP}`);
  assert.equal(c.status, "paid");
  assert.equal(c.payoutState, "held");
  assert.equal(c.amountCents, 449);
  assert.equal(c.platformFeeCents, 90);
  assert.equal(c.helperShareCents, 359);
  assert.equal(c.chargeId, "ch_1");
  assert.equal(c.helperStripeAccountId, "acct_h");
  assert.deepEqual(c.participants, ["seeker", "helper"]);
  assert.equal(c.releaseAfter, T0 + 2 * DAY + 10 * 60 * 1000 + DAY);
  const pi = stripe.intents.get("pi_1");
  assert.equal(pi.params.off_session, false);
  assert.equal(pi.params.transfer_group, `consultation_${OP}`);
  assert.equal(pi.metadata.consultationId, OP);

  // A retry returns the same booking without a second charge.
  const again = await bookPaidSession(deps(stripe), "seeker", request());
  assert.equal(again.replayed, true);
  assert.equal(stripe.intents.size, 1);
});

test("the price comes from the server, never from the client", async () => {
  const stripe = fakeStripe();
  await bookPaidSession(deps(stripe), "seeker", request({ amount: 0.01, cost: 0.01 }));
  assert.equal(stripe.intents.get("pi_1").amount, 449);
  await assert.rejects(
    bookPaidSession(deps(stripe), "seeker", request({ operationId: "op_free_0123456789", durationMinutes: 1 })),
    /Free sessions/,
  );
});

test("a helper must be set up for payouts, not blocked, and not the seeker", async () => {
  const stripe = fakeStripe();
  db.docs.set("users/helper", { ...db.docs.get("users/helper"), payoutsEnabled: false });
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request()), /cannot take paid sessions/);
  db.docs.set("users/helper", { ...db.docs.get("users/helper"), payoutsEnabled: true, blockedUids: ["seeker"] });
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request()), /cannot take paid sessions/);
  db.docs.set("users/helper", { ageDeclaration: "adult", payoutsEnabled: true, stripeAccountId: "acct_h" });
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request()), /cannot take paid sessions/);
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request({ helperId: "seeker" })), /yourself/);
  assert.equal(stripe.intents.size, 0);
});

test("the seeker must be an adult with a saved card, and the time must be sensible", async () => {
  const stripe = fakeStripe();
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request({ scheduledAtMs: T0 - DAY })), /next 60 days/);
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request({ scheduledAtMs: T0 + 90 * DAY })), /next 60 days/);
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request({ operationId: "short" })), /update the app/);
  db.docs.set("users/seeker", { ageDeclaration: "adult", stripeCustomerId: "cus_1" });
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request()), /No stored payment method/);
  db.docs.set("users/seeker", { ageDeclaration: "minor", stripeCustomerId: "cus_1", defaultPaymentMethodId: "pm_1" });
  await assert.rejects(bookPaidSession(deps(stripe), "seeker", request()), /adults/);
  assert.equal(stripe.intents.size, 0);
});

test("bank verification: the app gets the secret, then the same operation finishes the booking", async () => {
  const stripe = fakeStripe({ status: "requires_action" });
  const first = await bookPaidSession(deps(stripe), "seeker", request());
  assert.equal(first.requiresAction, true);
  assert.equal(first.clientSecret, "pi_1_secret");
  assert.equal(db.docs.has(`consultations/${OP}`), false);

  stripe.setStatus("pi_1", "succeeded"); // the seeker confirmed with the bank
  const second = await bookPaidSession(deps(stripe), "seeker", request());
  assert.equal(second.success, true);
  assert.equal(stripe.intents.size, 1);
  assert.equal(db.docs.get(`consultations/${OP}`).status, "paid");
});

test("the webhook finishes a booking the app never came back for, once", async () => {
  const stripe = fakeStripe({ status: "requires_action" });
  await bookPaidSession(deps(stripe), "seeker", request());
  stripe.setStatus("pi_1", "succeeded");
  const pi = stripe.intents.get("pi_1");
  assert.equal(await finalizeBooking(deps(stripe), OP, pi), OP);
  assert.equal(await finalizeBooking(deps(stripe), OP, pi), OP);
  assert.equal(db.docs.get(`consultations/${OP}`).status, "paid");
  // A PaymentIntent that is not this operation's does not book anything.
  const other = { ...pi, id: "pi_other", metadata: { operationId: "op_else_0123456789" } };
  stripe.intents.set("pi_other", other);
  db.docs.delete(`consultations/${OP}`);
  db.docs.set(`paymentOperations/${OP}`, { ...db.docs.get(`paymentOperations/${OP}`), paymentIntentId: "pi_other" });
  assert.equal(await finalizeBooking(deps(stripe), OP, other), null);
});

test("refund share: seeker by how early, helper always in full", () => {
  const at = T0 + 3 * DAY;
  assert.equal(refundPercentFor({ byHelper: false, scheduledAtMs: at, nowMs: at - 25 * HOUR }), 100);
  assert.equal(refundPercentFor({ byHelper: false, scheduledAtMs: at, nowMs: at - 2 * HOUR }), 50);
  assert.equal(refundPercentFor({ byHelper: false, scheduledAtMs: at, nowMs: at - 30 * 60 * 1000 }), 0);
  assert.equal(refundPercentFor({ byHelper: true, scheduledAtMs: at, nowMs: at - 1000 }), 100);
});

test("a seeker's late cancel refunds half and releases the rest to the helper later", async () => {
  const stripe = fakeStripe();
  await bookPaidSession(deps(stripe), "seeker", request());
  clock = T0 + 2 * DAY - 2 * HOUR;
  const res = await cancelConsultation(deps(stripe), "seeker", OP);
  assert.equal(res.refundPercent, 50);
  assert.equal(res.refundAmount, 2.25); // 449 * 50 % = 224.5 -> 225 cents
  const c = db.docs.get(`consultations/${OP}`);
  assert.equal(c.status, "cancelled");
  assert.equal(c.refundedCents, 225);
  assert.equal(c.platformFeeCents, 45);
  assert.equal(c.helperShareCents, 179);
  assert.equal(c.payoutState, "held");
  // Cancelling twice refunds once.
  await cancelConsultation(deps(stripe), "seeker", OP);
  assert.equal(stripe.refunds.length, 1);

  clock = c.releaseAfter + 1;
  const out = await releaseDue(deps(stripe), [OP]);
  assert.equal(out.released, 1);
  assert.equal(stripe.transfers[0].amount, 179);
  assert.equal(db.docs.get(`consultations/${OP}`).status, "cancelled");
});

test("a helper's cancel refunds in full and pays the helper nothing", async () => {
  const stripe = fakeStripe();
  await bookPaidSession(deps(stripe), "seeker", request());
  clock = T0 + 2 * DAY - 60 * 1000;
  const res = await cancelConsultation(deps(stripe), "helper", OP);
  assert.equal(res.refundPercent, 100);
  assert.equal(stripe.refunds[0].amount, 449);
  const c = db.docs.get(`consultations/${OP}`);
  assert.equal(c.payoutState, "none");
  assert.equal(c.releaseAfter, null);
  await assert.rejects(cancelConsultation(deps(stripe), "stranger", OP), /Not your consultation/);
});

test("client-written consultations are cancelled without any refund", async () => {
  const stripe = fakeStripe();
  db.docs.set("consultations/fake", {
    userId: "seeker", targetUserId: "helper", cost: 50, paymentIntentId: "pi_someone_else", status: "scheduled",
  });
  const res = await cancelConsultation(deps(stripe), "seeker", "fake");
  assert.equal(res.refundAmount, 0);
  assert.equal(stripe.refunds.length, 0);
  assert.equal(db.docs.get("consultations/fake").status, "cancelled");
});

test("after the session the helper is paid once and the consultation is completed", async () => {
  const stripe = fakeStripe();
  await bookPaidSession(deps(stripe), "seeker", request());
  const due = db.docs.get(`consultations/${OP}`).releaseAfter;
  clock = due - 1;
  assert.equal((await releaseDue(deps(stripe), [OP])).skipped, 1);
  clock = due;
  assert.equal((await releaseDue(deps(stripe), [OP])).released, 1);
  assert.equal((await releaseDue(deps(stripe), [OP])).skipped, 1);
  assert.equal(stripe.transfers.length, 1);
  const t = stripe.transfers[0];
  assert.equal(t.amount, 359);
  assert.equal(t.destination, "acct_h");
  assert.equal(t.source_transaction, "ch_1");
  const c = db.docs.get(`consultations/${OP}`);
  assert.equal(c.status, "completed");
  assert.equal(c.payoutState, "released");
  // Too late to cancel or report once released.
  await assert.rejects(cancelConsultation(deps(stripe), "seeker", OP), /no longer be cancelled/);
  await assert.rejects(reportSessionProblem(deps(stripe), "seeker", OP, "x"), /no longer be reported/);
});

test("a failed transfer stays held and is retried", async () => {
  const stripe = fakeStripe({ failTransfer: true });
  await bookPaidSession(deps(stripe), "seeker", request());
  clock = db.docs.get(`consultations/${OP}`).releaseAfter;
  assert.equal((await releaseDue(deps(stripe), [OP])).error, 1);
  const c = db.docs.get(`consultations/${OP}`);
  assert.equal(c.payoutState, "held");
  assert.match(c.lastPayoutError, /insufficient/);
});

test("a reported problem or a dispute holds the money for the founder", async () => {
  const stripe = fakeStripe();
  await bookPaidSession(deps(stripe), "seeker", request());
  await assert.rejects(reportSessionProblem(deps(stripe), "helper", OP, "x"), /Not your consultation/);
  await reportSessionProblem(deps(stripe), "seeker", OP, "The helper did not come");
  let c = db.docs.get(`consultations/${OP}`);
  assert.equal(c.status, "under_review");
  assert.equal(c.releaseAfter, null);
  clock = T0 + 10 * DAY;
  assert.equal((await releaseDue(deps(stripe), [OP])).skipped, 1);
  await assert.rejects(cancelConsultation(deps(stripe), "seeker", OP), /no longer be cancelled/);

  db.docs.set(`consultations/${OP}`, { ...c, status: "paid", payoutState: "held", releaseAfter: T0 });
  await markDisputed(deps(stripe), OP, "dp_1");
  c = db.docs.get(`consultations/${OP}`);
  assert.equal(c.status, "under_review");
  assert.equal(c.disputeId, "dp_1");
  assert.equal(stripe.transfers.length, 0);
});

test("payouts are ready only when Stripe allows transfers and payouts", () => {
  assert.equal(payoutStatusFromAccount({
    payouts_enabled: true, details_submitted: true, capabilities: { transfers: "active" },
  }).payoutsEnabled, true);
  assert.equal(payoutStatusFromAccount({
    payouts_enabled: true, capabilities: { transfers: "pending" },
  }).payoutsEnabled, false);
  assert.equal(payoutStatusFromAccount(null).payoutsEnabled, false);
});
