"use strict";

/**
 * Stripe signs platform events and connected-account events with two
 * different endpoint secrets (one endpoint each). STRIPE_WEBHOOK_SECRET
 * holds one secret or several, separated by commas; an event is accepted
 * when any of them verifies it.
 */
function webhookSecrets(value) {
  return `${value || ""}`
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

function verifyStripeEvent(stripe, rawBody, signature, secretValue) {
  const secrets = webhookSecrets(secretValue);
  if (secrets.length === 0) throw new Error("No webhook secret configured");
  let lastError;
  for (const secret of secrets) {
    try {
      return stripe.webhooks.constructEvent(rawBody, signature, secret);
    } catch (e) {
      lastError = e;
    }
  }
  throw lastError;
}

module.exports = { webhookSecrets, verifyStripeEvent };
