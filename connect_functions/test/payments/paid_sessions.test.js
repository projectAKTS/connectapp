"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const {
  MVP_PAYMENTS_DISABLED_MESSAGE,
  assertMvpPaymentsEnabled,
  PAID_SESSIONS_DISABLED_MESSAGE,
  assertPaidSessionsEnabled,
} = require("../../payments/paid_sessions");

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

test("payments are refused unless explicitly enabled", () => {
  for (const off of [false, undefined, null, "true", 1]) {
    assert.throws(
      () => assertPaidSessionsEnabled(off, FakeHttpsError),
      (e) => e.code === "failed-precondition" && e.message === PAID_SESSIONS_DISABLED_MESSAGE,
      `${off}`,
    );
  }
  assert.doesNotThrow(() => assertPaidSessionsEnabled(true, FakeHttpsError));
});

test("the MVP master payment switch fails closed by default", () => {
  for (const off of [false, undefined, null, "true", 1]) {
    assert.throws(
      () => assertMvpPaymentsEnabled(off, FakeHttpsError),
      (e) => e.code === "failed-precondition" && e.message === MVP_PAYMENTS_DISABLED_MESSAGE,
      `${off}`,
    );
  }
  assert.doesNotThrow(() => assertMvpPaymentsEnabled(true, FakeHttpsError));
});

test("every money-moving callable checks the switch before touching Stripe", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../../index.js"), "utf8");
  assert.match(src, /defineBoolean\("MVP_PAYMENTS_ENABLED", \{\s*default: false,?\s*\}\)/);
  assert.match(src, /defineBoolean\("PAID_SESSIONS_ENABLED", \{\s*default: false,?\s*\}\)/);
  for (const name of [
    "createStripeCustomer",
    "createSetupIntent",
    "listPaymentMethods",
    "setDefaultPaymentMethod",
    "removePaymentMethod",
    "bookPaidSession",
    "createExpressAccountLink",
    "getPayoutStatus",
  ]) {
    const start = src.indexOf(`exports.${name} = onCall(`);
    assert.ok(start >= 0, name);
    const body = src.slice(start, src.indexOf("\nexports.", start + 10));
    const gate = body.indexOf("assertPaidSessionsEnabled(PAID_SESSIONS_ENABLED.value()");
    const masterGate = body.indexOf("assertMvpPaymentsEnabled(MVP_PAYMENTS_ENABLED.value()");
    const stripeUse = body.indexOf("getStripeClient()");
    if (["bookPaidSession", "createExpressAccountLink", "getPayoutStatus"].includes(name)) {
      assert.ok(gate > 0, `${name} has the paid-session gate`);
    }
    assert.ok(masterGate > 0, `${name} has the MVP master gate`);
    assert.ok(stripeUse < 0 || masterGate < stripeUse, `${name} gates before Stripe`);
  }
  const cancelStart = src.indexOf("exports.cancelConsultation = onCall(");
  const cancelBody = src.slice(cancelStart, src.indexOf("\nexports.", cancelStart + 10));
  assert.match(cancelBody, /assertMvpPaymentsEnabled\(MVP_PAYMENTS_ENABLED\.value\(\), HttpsError\)/);
  const payoutsStart = src.indexOf("exports.releaseHeldPayouts = onSchedule(");
  const payoutsBody = src.slice(payoutsStart, src.indexOf("\nexports.", payoutsStart + 10));
  assert.match(payoutsBody, /!MVP_PAYMENTS_ENABLED\.value\(\) \|\| !PAID_SESSIONS_ENABLED\.value\(\)/);
});

test("the old charge and Checkout callables refuse without touching Stripe", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../../index.js"), "utf8");
  for (const name of ["chargeStoredPaymentMethod", "createStripeCheckoutSession"]) {
    const start = src.indexOf(`exports.${name} = onCall(`);
    assert.ok(start >= 0, name);
    const body = src.slice(start, src.indexOf("\nexports.", start + 10));
    assert.ok(!body.includes("getStripeClient()"), `${name} does not use Stripe`);
    assert.match(body, /Please update the app to book a paid session/);
  }
});
