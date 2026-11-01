"use strict";

/**
 * Safe consultation charges.
 *
 * Every booking attempt carries a client-generated `operationId` that the
 * app reuses for every retry of that attempt (timeouts, token refresh,
 * double taps). The server:
 * 1. records the attempt in `paymentOperations/{operationId}` (server-only)
 *    in a transaction, so one id belongs to one user and one priced
 *    request;
 * 2. returns the stored result if the attempt already succeeded, without
 *    calling Stripe;
 * 3. otherwise calls Stripe with the idempotency key `charge_<operationId>`,
 *    so concurrent or repeated calls create at most one PaymentIntent;
 * 4. records the outcome. The webhook reconciles the same document.
 *
 * A failed charge stays failed for that id; a new attempt needs a new id.
 * Dependencies are injected so the logic is tested without Firebase or
 * Stripe.
 */

const OPERATION_ID = /^[A-Za-z0-9_-]{16,80}$/;
const COLLECTION = "paymentOperations";
// Stripe keeps idempotency keys for 24 hours; stay well inside that.
const KEY_TTL_MS = 20 * 60 * 60 * 1000;

// Order of states; updates never move backwards (webhooks can be late or
// repeated).
const RANK = { processing: 0, requires_action: 1, failed: 2, succeeded: 3 };

class ChargeError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code; // maps to an HttpsError code
  }
}

function idempotencyKey(operationId) {
  return `charge_${operationId}`;
}

function piState(status) {
  if (status === "succeeded") return "succeeded";
  if (status === "requires_action" || status === "requires_confirmation") {
    return "requires_action";
  }
  if (status === "canceled" || status === "requires_payment_method") {
    return "failed";
  }
  return "processing";
}

/**
 * Charges once per operation. [priced] is the server-side price
 * ({amount, durationMinutes, callType, legacy}); [customer] the user's
 * Stripe ids. Returns {success, id, amount, operationId, replayed}.
 */
async function chargeOnce({
  db,
  stripe,
  uid,
  operationId,
  helperId,
  priced,
  customer,
  pricingVersion,
  serverTimestamp,
  now = () => Date.now(),
}) {
  if (!OPERATION_ID.test(`${operationId || ""}`)) {
    throw new ChargeError("invalid-argument", "operationId required");
  }
  const amountCents = Math.round(priced.amount * 100);
  const ref = db.collection(COLLECTION).doc(operationId);

  const existing = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      const op = snap.data();
      if (op.uid !== uid) {
        throw new ChargeError("permission-denied", "Operation belongs to another user");
      }
      if (op.amountCents !== amountCents || (op.helperId || "") !== helperId) {
        throw new ChargeError("invalid-argument", "Operation reused for a different charge");
      }
      return op;
    }
    tx.set(ref, {
      uid,
      helperId,
      amountCents,
      currency: "cad",
      durationMinutes: priced.durationMinutes ?? null,
      callType: priced.callType || "",
      status: "processing",
      createdAtMs: now(),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    return null;
  });

  if (existing && existing.status === "succeeded" && existing.paymentIntentId) {
    return {
      success: true,
      id: existing.paymentIntentId,
      amount: existing.amountCents / 100,
      operationId,
      replayed: true,
    };
  }
  if (existing && existing.status === "failed") {
    throw new ChargeError("failed-precondition", existing.failureCode || "Payment failed");
  }
  if (existing) {
    // An earlier call may have charged without recording it (timeout,
    // crash). Look for its PaymentIntent before calling create again.
    const found = await findExistingIntent(stripe, existing, operationId);
    if (found) {
      const state = piState(found.status);
      await recordOutcome(db, operationId, {
        status: state,
        paymentIntentId: found.id,
        stripeStatus: found.status,
      }, serverTimestamp);
      if (state === "succeeded") {
        return {
          success: true,
          id: found.id,
          amount: amountCents / 100,
          operationId,
          replayed: true,
        };
      }
      if (state === "failed") {
        throw new ChargeError("failed-precondition", `payment_${found.status}`);
      }
      throw new ChargeError("aborted", "Payment still processing; retry");
    }
    if (now() - (existing.createdAtMs || 0) > KEY_TTL_MS) {
      // The idempotency key may have expired: never risk a second charge.
      throw new ChargeError("failed-precondition", "Payment attempt expired; start a new booking");
    }
  }

  let pi;
  try {
    pi = await stripe.paymentIntents.create(
      {
        amount: amountCents,
        currency: "cad",
        customer: customer.stripeCustomerId,
        payment_method: customer.defaultPaymentMethodId,
        off_session: true,
        confirm: true,
        metadata: {
          kind: "consultation",
          operationId,
          seekerUid: uid,
          helperUid: helperId,
          durationMinutes: `${priced.durationMinutes ?? ""}`,
          callType: priced.callType || "",
          pricingVersion,
          legacyAmount: priced.legacy ? "true" : "false",
        },
      },
      { idempotencyKey: idempotencyKey(operationId) },
    );
  } catch (e) {
    // Another request with this key is still running: the caller retries
    // with the same id and gets that request's result.
    if (e && (e.code === "idempotency_key_in_use" || e.statusCode === 409)) {
      throw new ChargeError("aborted", "Payment already in progress; retry");
    }
    // Declines are final for this attempt. Network or Stripe outages leave
    // the operation "processing" so a retry with the same key is safe.
    if (e && e.type === "StripeCardError") {
      await recordOutcome(db, operationId, {
        status: "failed",
        failureCode: e.code || "card_declined",
        paymentIntentId: e.raw?.payment_intent?.id || e.payment_intent?.id || null,
      }, serverTimestamp);
      throw new ChargeError("failed-precondition", e.code || "card_declined");
    }
    await recordOutcome(db, operationId, {
      status: "processing",
      lastError: `${e && e.message ? e.message : e}`.slice(0, 300),
    }, serverTimestamp);
    throw new ChargeError("unavailable", "Payment not confirmed; retry");
  }

  const state = piState(pi.status);
  await recordOutcome(db, operationId, {
    status: state,
    paymentIntentId: pi.id,
    stripeStatus: pi.status,
  }, serverTimestamp);
  if (state !== "succeeded") {
    throw new ChargeError("failed-precondition", `payment_${pi.status}`);
  }
  return { success: true, id: pi.id, amount: amountCents / 100, operationId, replayed: false };
}

async function findExistingIntent(stripe, op, operationId) {
  if (op.paymentIntentId) {
    return stripe.paymentIntents.retrieve(op.paymentIntentId);
  }
  try {
    const res = await stripe.paymentIntents.search({
      query: `metadata['operationId']:'${operationId}'`,
      limit: 1,
    });
    return res?.data?.[0] || null;
  } catch (_) {
    // Search is best effort (eventually consistent); the idempotency key
    // still protects retries within its lifetime.
    return null;
  }
}

/**
 * Applies [update] unless the stored state is already further along, so
 * late or duplicate events (webhooks, retries) never undo a success.
 */
async function recordOutcome(db, operationId, update, serverTimestamp) {
  const ref = db.collection(COLLECTION).doc(operationId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const current = snap.data().status || "processing";
    const next = update.status || current;
    if ((RANK[next] ?? 0) < (RANK[current] ?? 0)) return false;
    const clean = Object.fromEntries(
      Object.entries(update).filter(([, v]) => v !== undefined && v !== null),
    );
    tx.update(ref, { ...clean, updatedAt: serverTimestamp() });
    return true;
  });
}

/** Webhook reconciliation for PaymentIntent events. Safe to repeat. */
async function reconcilePaymentIntent(db, pi, serverTimestamp) {
  const operationId = pi?.metadata?.operationId;
  if (!operationId || !OPERATION_ID.test(operationId)) return false;
  return recordOutcome(db, operationId, {
    status: piState(pi.status),
    paymentIntentId: pi.id,
    stripeStatus: pi.status,
  }, serverTimestamp);
}

module.exports = {
  COLLECTION,
  KEY_TTL_MS,
  ChargeError,
  chargeOnce,
  idempotencyKey,
  piState,
  reconcilePaymentIntent,
  recordOutcome,
};
