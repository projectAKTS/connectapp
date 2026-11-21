"use strict";

/**
 * Free beta switch. Paid sessions, card charges and helper payout
 * onboarding are refused on the server unless the deploy-time parameter
 * PAID_SESSIONS_ENABLED is true (default false). Older app builds cannot
 * bypass it, and turning paid sessions back on is a reviewed config change
 * (.env + redeploy), not a code change.
 */
const PAID_SESSIONS_DISABLED_MESSAGE = "Paid sessions are not available during the beta";
const MVP_PAYMENTS_DISABLED_MESSAGE = "Payments are not available during the MVP launch";

function assertMvpPaymentsEnabled(enabled, HttpsErrorClass) {
  if (enabled === true) return;
  throw new HttpsErrorClass("failed-precondition", MVP_PAYMENTS_DISABLED_MESSAGE);
}

function assertPaidSessionsEnabled(enabled, HttpsErrorClass) {
  if (enabled === true) return;
  throw new HttpsErrorClass("failed-precondition", PAID_SESSIONS_DISABLED_MESSAGE);
}

module.exports = {
  MVP_PAYMENTS_DISABLED_MESSAGE,
  PAID_SESSIONS_DISABLED_MESSAGE,
  assertMvpPaymentsEnabled,
  assertPaidSessionsEnabled,
};
