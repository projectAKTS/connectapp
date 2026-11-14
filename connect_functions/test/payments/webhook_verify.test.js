"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const Stripe = require("stripe");
const { webhookSecrets, verifyStripeEvent } = require("../../payments/webhook_verify");

const stripe = new Stripe("sk_test_unused");
const payload = JSON.stringify({ id: "evt_1", type: "account.updated", data: { object: {} } });

function signed(secret) {
  return stripe.webhooks.generateTestHeaderString({ payload, secret });
}

test("splits one or several secrets", () => {
  assert.deepEqual(webhookSecrets("whsec_a"), ["whsec_a"]);
  assert.deepEqual(webhookSecrets(" whsec_a , whsec_b ,"), ["whsec_a", "whsec_b"]);
  assert.deepEqual(webhookSecrets(""), []);
  assert.deepEqual(webhookSecrets(undefined), []);
});

test("accepts an event signed by either endpoint secret", () => {
  const both = "whsec_platform,whsec_connect";
  assert.equal(verifyStripeEvent(stripe, payload, signed("whsec_platform"), both).id, "evt_1");
  assert.equal(verifyStripeEvent(stripe, payload, signed("whsec_connect"), both).id, "evt_1");
});

test("rejects an event signed by an unknown secret", () => {
  assert.throws(() =>
    verifyStripeEvent(stripe, payload, signed("whsec_other"), "whsec_platform,whsec_connect"));
});

test("rejects when no secret is configured", () => {
  assert.throws(() => verifyStripeEvent(stripe, payload, signed("whsec_a"), ""), /No webhook secret/);
});
