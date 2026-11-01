"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const {
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

test("every money-moving callable checks the switch before touching Stripe", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../../index.js"), "utf8");
  assert.match(src, /defineBoolean\("PAID_SESSIONS_ENABLED", \{\s*default: false,?\s*\}\)/);
  for (const name of ["chargeStoredPaymentMethod", "createExpressAccountLink", "createStripeCheckoutSession"]) {
    const start = src.indexOf(`exports.${name} = onCall(`);
    assert.ok(start >= 0, name);
    const body = src.slice(start, src.indexOf("\nexports.", start + 10));
    const gate = body.indexOf("assertPaidSessionsEnabled(PAID_SESSIONS_ENABLED.value()");
    const stripeUse = body.indexOf("getStripeClient()");
    assert.ok(gate > 0, `${name} has the gate`);
    assert.ok(stripeUse < 0 || gate < stripeUse, `${name} gates before Stripe`);
  }
});
