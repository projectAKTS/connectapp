"use strict";

/**
 * Paid sessions (docs/PAID_SESSIONS_DESIGN.md).
 *
 * The server books and charges in one place, so a paid consultation is
 * always written by the server with the amounts it charged. The money is
 * held on the platform account until a day after the session, then the
 * helper's share is transferred to their Stripe Express account. Cancels
 * refund from the held money; a reported problem or a dispute holds the
 * release for the founder.
 *
 * Every function takes its dependencies, so the logic is tested without
 * Firebase or Stripe:
 *   { db, stripe, now, serverTimestamp, toTimestamp, newRoomId,
 *     pricingVersion }
 */

const { ChargeError, OPERATION_ID, chargeOnce } = require("./charge_operation");
const {
  platformFeeCents,
  resolveChargeAmount,
} = require("../consultations/consultation_price");

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
// The seeker has a day after the session to report a problem.
const RELEASE_DELAY_MS = DAY;
const MAX_AHEAD_MS = 60 * DAY;
const LATE_GRACE_MS = 10 * MINUTE;
const MAX_REASON = 500;

const NOT_BOOKABLE = "This helper cannot take paid sessions right now";

function msOf(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") return value;
  if (value instanceof Date) return value.getTime();
  if (typeof value.toMillis === "function") return value.toMillis();
  return null;
}

function isHelperProfile(user) {
  return ["helper", "both"].includes(user.role) || user.isHelper === true;
}

/** Whether a Stripe account can receive the helper's share. */
function payoutStatusFromAccount(account) {
  const acct = account || {};
  return {
    payoutsEnabled: acct.payouts_enabled === true
      && acct.capabilities?.transfers === "active",
    detailsSubmitted: acct.details_submitted === true,
  };
}

/** Refund share for a cancel: the helper always refunds in full. */
function refundPercentFor({ byHelper, scheduledAtMs, nowMs }) {
  if (byHelper) return 100;
  const ahead = (scheduledAtMs ?? 0) - nowMs;
  if (ahead >= DAY) return 100;
  if (ahead >= HOUR) return 50;
  return 0;
}

async function readDoc(ref) {
  const snap = await ref.get();
  return snap.exists ? snap.data() : null;
}

/**
 * Books and charges a paid session. Returns
 * {success, consultationId, amount} or, when the bank wants the seeker to
 * confirm, {success: false, requiresAction, clientSecret, consultationId}.
 * The consultation id is the operation id, so a retry finds its booking.
 */
async function bookPaidSession(deps, uid, data) {
  const { db, stripe, now } = deps;
  const req = data || {};
  const operationId = `${req.operationId || ""}`;
  if (!OPERATION_ID.test(operationId)) {
    throw new ChargeError("failed-precondition", "Please update the app to book a paid session");
  }
  const helperId = `${req.helperId || ""}`.trim();
  if (!helperId || helperId === uid) {
    throw new ChargeError("invalid-argument", "You cannot book yourself");
  }
  const priced = resolveChargeAmount({
    durationMinutes: req.durationMinutes,
    callType: req.callType,
  });
  if (priced.error) throw new ChargeError("invalid-argument", priced.error);
  const nowMs = now();
  const scheduledAtMs = Number(req.scheduledAtMs);
  if (!Number.isFinite(scheduledAtMs)
    || scheduledAtMs < nowMs - LATE_GRACE_MS
    || scheduledAtMs > nowMs + MAX_AHEAD_MS) {
    throw new ChargeError("invalid-argument", "Choose a time in the next 60 days");
  }

  const consultRef = db.collection("consultations").doc(operationId);
  const already = await readDoc(consultRef);
  if (already) {
    if (already.userId !== uid) {
      throw new ChargeError("permission-denied", "Operation belongs to another user");
    }
    return { success: true, consultationId: operationId, amount: already.cost, replayed: true };
  }

  const seeker = await readDoc(db.collection("users").doc(uid));
  if (!seeker || seeker.ageDeclaration !== "adult") {
    throw new ChargeError("permission-denied", "Paid sessions are for adults");
  }
  if (!seeker.stripeCustomerId || !seeker.defaultPaymentMethodId) {
    throw new ChargeError("failed-precondition", "No stored payment method");
  }
  const helper = await readDoc(db.collection("users").doc(helperId));
  if (!helper
    || !isHelperProfile(helper)
    || helper.ageDeclaration === "minor"
    || (Array.isArray(helper.blockedUids) && helper.blockedUids.includes(uid))
    || helper.payoutsEnabled !== true
    || !helper.stripeAccountId) {
    throw new ChargeError("failed-precondition", NOT_BOOKABLE);
  }

  const charge = await chargeOnce({
    db,
    stripe,
    uid,
    operationId,
    helperId,
    priced,
    customer: seeker,
    pricingVersion: deps.pricingVersion,
    serverTimestamp: deps.serverTimestamp,
    now,
    booking: {
      helperId,
      helperStripeAccountId: helper.stripeAccountId,
      scheduledAtMs,
      durationMinutes: priced.durationMinutes,
      callType: priced.callType,
    },
    customerPresent: true,
    returnAction: true,
    transferGroup: `consultation_${operationId}`,
    extraMetadata: { consultationId: operationId },
  });
  if (charge.requiresAction) {
    return {
      success: false,
      requiresAction: true,
      clientSecret: charge.clientSecret,
      consultationId: operationId,
      amount: charge.amount,
    };
  }
  await finalizeBooking(deps, operationId);
  return { success: true, consultationId: operationId, amount: charge.amount };
}

/**
 * Writes the paid consultation for a succeeded operation, once. Called by
 * the booking itself and by the payment webhook (the app may never come
 * back after the bank's screen). Returns the consultation id, or null when
 * there is nothing to book yet.
 */
async function finalizeBooking(deps, operationId, paymentIntent = null) {
  const { db, stripe } = deps;
  const op = await readDoc(db.collection("paymentOperations").doc(operationId));
  if (!op || !op.booking) return null;
  const pi = paymentIntent && paymentIntent.id === op.paymentIntentId
    ? paymentIntent
    : (op.paymentIntentId || paymentIntent?.id
      ? await stripe.paymentIntents.retrieve(op.paymentIntentId || paymentIntent.id)
      : null);
  if (!pi || pi.status !== "succeeded") return null;
  if (pi.amount !== op.amountCents || pi.metadata?.operationId !== operationId) return null;

  const b = op.booking;
  const amountCents = op.amountCents;
  const feeCents = platformFeeCents(amountCents);
  const chargeId = typeof pi.latest_charge === "string"
    ? pi.latest_charge
    : pi.latest_charge?.id || null;
  const ref = db.collection("consultations").doc(operationId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) return;
    tx.set(ref, {
      consultationId: operationId,
      userId: op.uid,
      targetUserId: b.helperId,
      participants: [op.uid, b.helperId],
      roomId: deps.newRoomId(),
      minutesRequested: b.durationMinutes,
      callType: b.callType,
      cost: amountCents / 100,
      currency: "cad",
      amountCents,
      platformFeeCents: feeCents,
      helperShareCents: amountCents - feeCents,
      refundedCents: 0,
      paymentIntentId: pi.id,
      chargeId,
      helperStripeAccountId: b.helperStripeAccountId,
      status: "paid",
      payoutState: "held",
      scheduledAt: deps.toTimestamp(b.scheduledAtMs),
      releaseAfter: deps.toTimestamp(
        b.scheduledAtMs + b.durationMinutes * MINUTE + RELEASE_DELAY_MS,
      ),
      pricingVersion: deps.pricingVersion || null,
      timestamp: deps.serverTimestamp(),
      paidAt: deps.serverTimestamp(),
    });
  });
  return operationId;
}

/**
 * Cancels a consultation for either person in it. A paid one is refunded
 * from the held money (seeker: by how early; helper: in full); what is not
 * refunded is released to the helper as usual. Consultations the server
 * did not write (free ones, old ones) are cancelled without any refund.
 */
async function cancelConsultation(deps, uid, consultationId) {
  const { db, stripe, now } = deps;
  if (!consultationId) throw new ChargeError("invalid-argument", "consultationId required");
  const ref = db.collection("consultations").doc(`${consultationId}`);
  const c = await readDoc(ref);
  if (!c) throw new ChargeError("not-found", "Consultation not found");
  const byHelper = c.targetUserId === uid;
  if (c.userId !== uid && !byHelper) {
    throw new ChargeError("permission-denied", "Not your consultation");
  }
  if (c.status === "cancelled") {
    return {
      ok: true,
      refundAmount: (c.refundedCents || 0) / 100,
      refundPercent: c.refundPercent || 0,
      replayed: true,
    };
  }

  // Not a server-made paid booking: nothing to refund. Its `cost` and
  // `paymentIntentId`, if any, were written by a client and are not trusted.
  if (!(c.amountCents > 0) || !c.paymentIntentId) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.data().status === "cancelled") return;
      tx.update(ref, {
        status: "cancelled",
        cancelledBy: uid,
        cancelledAt: deps.serverTimestamp(),
        refundPercent: 0,
        refundedCents: 0,
      });
    });
    return { ok: true, refundAmount: 0, refundPercent: 0 };
  }

  // Claim the cancel, so a cancel and the release cannot both run.
  const claim = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const cur = snap.data();
    if (cur.status === "cancelling") {
      return { percent: cur.refundPercent, by: cur.cancelledBy };
    }
    if (cur.status !== "paid" || cur.payoutState !== "held") {
      throw new ChargeError("failed-precondition", "This session can no longer be cancelled");
    }
    const percent = refundPercentFor({
      byHelper,
      scheduledAtMs: msOf(cur.scheduledAt),
      nowMs: now(),
    });
    tx.update(ref, { status: "cancelling", refundPercent: percent, cancelledBy: uid });
    return { percent, by: uid };
  });

  const refundCents = Math.round((c.amountCents * claim.percent) / 100);
  let refundId = null;
  if (refundCents > 0) {
    try {
      const refund = await stripe.refunds.create(
        {
          payment_intent: c.paymentIntentId,
          amount: refundCents,
          metadata: { consultationId: `${consultationId}` },
        },
        { idempotencyKey: `refund_${consultationId}` },
      );
      refundId = refund.id;
    } catch (e) {
      console.error("Refund error:", e && e.message);
      throw new ChargeError("unavailable", "Refund not confirmed; try again");
    }
  }
  const remaining = c.amountCents - refundCents;
  const feeCents = platformFeeCents(remaining);
  const shareCents = remaining - feeCents;
  await ref.update({
    status: "cancelled",
    cancelledAt: deps.serverTimestamp(),
    refundedCents: refundCents,
    refundId,
    platformFeeCents: feeCents,
    helperShareCents: shareCents,
    payoutState: shareCents > 0 ? "held" : "none",
    ...(shareCents > 0 ? {} : { releaseAfter: null }),
  });
  return { ok: true, refundAmount: refundCents / 100, refundPercent: claim.percent, refundId };
}

/**
 * The seeker reports a problem (no-show, abuse) before the money is
 * released. The release waits until the founder decides.
 */
async function reportSessionProblem(deps, uid, consultationId, reason) {
  const { db } = deps;
  if (!consultationId) throw new ChargeError("invalid-argument", "consultationId required");
  const ref = db.collection("consultations").doc(`${consultationId}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new ChargeError("not-found", "Consultation not found");
    const c = snap.data();
    if (c.userId !== uid) throw new ChargeError("permission-denied", "Not your consultation");
    if (c.status === "under_review") return { ok: true, replayed: true };
    if (c.status !== "paid" || c.payoutState !== "held") {
      throw new ChargeError("failed-precondition", "This session can no longer be reported");
    }
    tx.update(ref, {
      status: "under_review",
      payoutState: "review",
      releaseAfter: null,
      problemReason: `${reason || ""}`.slice(0, MAX_REASON),
      problemReportedAt: deps.serverTimestamp(),
    });
    return { ok: true };
  });
}

/**
 * Releases one consultation's held money to the helper, once its time has
 * come. Returns "released", "skipped" or "error" (retried next run).
 */
async function releaseOne(deps, consultationId) {
  const { db, stripe, now } = deps;
  const ref = db.collection("consultations").doc(consultationId);
  const c = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const cur = snap.data();
    const due = msOf(cur.releaseAfter);
    if (cur.payoutState !== "held"
      || !["paid", "cancelled"].includes(cur.status)
      || due === null || due > now()) {
      return null;
    }
    tx.update(ref, { payoutState: "releasing" });
    return cur;
  });
  if (!c) return "skipped";

  let transferId = null;
  if (c.helperShareCents > 0) {
    try {
      const transfer = await stripe.transfers.create(
        {
          amount: c.helperShareCents,
          currency: "cad",
          destination: c.helperStripeAccountId,
          source_transaction: c.chargeId,
          transfer_group: `consultation_${consultationId}`,
          metadata: { consultationId },
        },
        { idempotencyKey: `transfer_${consultationId}` },
      );
      transferId = transfer.id;
    } catch (e) {
      await ref.update({
        payoutState: "held",
        lastPayoutError: `${e && e.message ? e.message : e}`.slice(0, 300),
      });
      return "error";
    }
  }
  await ref.update({
    payoutState: "released",
    transferId,
    releasedAt: deps.serverTimestamp(),
    releaseAfter: null,
    ...(c.status === "paid"
      ? { status: "completed", completedAt: deps.serverTimestamp() }
      : {}),
  });
  return "released";
}

/** Hourly job: releases every consultation whose time has come. */
async function releaseDue(deps, dueIds) {
  const results = { released: 0, skipped: 0, error: 0 };
  for (const id of dueIds) {
    const outcome = await releaseOne(deps, id);
    results[outcome] += 1;
  }
  return results;
}

/**
 * A card dispute holds the release for the founder. If the money was
 * already released, it is only flagged: reversing a transfer is his call.
 */
async function markDisputed(deps, consultationId, disputeId) {
  const { db } = deps;
  if (!consultationId) return false;
  const ref = db.collection("consultations").doc(`${consultationId}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const c = snap.data();
    if (c.payoutState === "held") {
      tx.update(ref, {
        status: "under_review",
        payoutState: "review",
        releaseAfter: null,
        disputeId,
      });
    } else {
      tx.update(ref, { disputeId, disputedAfterRelease: c.payoutState === "released" });
    }
    return true;
  });
}

module.exports = {
  NOT_BOOKABLE,
  RELEASE_DELAY_MS,
  bookPaidSession,
  cancelConsultation,
  finalizeBooking,
  isHelperProfile,
  markDisputed,
  payoutStatusFromAccount,
  refundPercentFor,
  releaseDue,
  releaseOne,
  reportSessionProblem,
};
