# Kindupp Payment-Disabled Report

**Intended MVP:** free calls and messaging; no paid consultations, card setup,
subscriptions, boosts, helper onboarding, charges, refunds, or payouts.

## Changes prepared

- Client production default is fail-closed. Payments require both a staging
  environment and explicit `MVP_PAYMENTS_ENABLED`; paid sessions additionally
  require `PAID_SESSIONS`. Subscriptions require their own explicit flag.
- Payment/payout/premium UI routes and service entry points are gated. A
  disabled-state screen replaces payment setup. Paid consultation pricing is
  zero in the free flow; free booking remains available.
- Functions now use `MVP_PAYMENTS_ENABLED` default false for card customer and
  setup/list/default/remove methods, booking, payout setup/status, and charging.
  Paid operations also require `PAID_SESSIONS_ENABLED`.
- Paid cancellation/refund checks both gates when a paid record exists. The
  scheduled held-payout worker returns without scanning/transferring while
  either gate is off.
- Stripe webhook handling remains for reconciliation of existing events; it
  does not create charges/transfers in the reviewed handler paths. The old
  checkout/charge compatibility callables refuse new payment actions.
- Removed the embedded publishable key value from `main.dart`; Stripe SDK
  initialization occurs only behind the payment gate and must be supplied at
  build time if deliberately enabled.

## Verification boundary

This is a source-code change only. The deployed production build, deployed
Functions version/parameters, Stripe live/test mode, App Store purchase
products, and customer/connected-account state have not been inspected or
changed. Production is therefore **not yet proven payment-disabled**. Before
launch, verify production parameters and the exact release binary, then deploy
the reviewed Functions version through a separately approved release process.

## Evidence/tests

- `connect_functions/test/payments/paid_sessions.test.js` exercises default
  fail-closed behavior and checks that money-moving paths guard before Stripe.
- `test/mvp/payment_feature_flags_test.dart` verifies production defaults.
- Build/test results are recorded in the Android and iOS QA reports and the
  release checklist. No production deploy or app publication was performed.
