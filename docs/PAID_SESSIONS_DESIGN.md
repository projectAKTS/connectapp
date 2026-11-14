# Paid Sessions: Design (2026-11-14)

Paid sessions stay off (`PAID_SESSIONS_ENABLED=false`) until this is built,
tested end to end in Stripe test mode on staging, and the founder turns
them on. This file records how money moves and why.

## What Was Wrong

1. Helpers were never paid: the stored-card charge kept the money on the
   platform account, and the app had no screen to connect a payout account.
2. The webhook could not work: `STRIPE_WEBHOOK_SECRET` was never set.
3. The app charged first and wrote the booking itself, so a crash in
   between left a charge without a booking, and the client chose the
   `cost` and `paymentIntentId` that refunds later trusted.
4. A card that needs bank verification (3D Secure) stayed "pending"
   forever.
5. Nothing recorded that a session happened; a helper could not cancel;
   a no-show could not be refunded.
6. Reviews could be written for invented consultations.

## Money Flow (Stripe Connect Express, separate charges and transfers)

1. **Helper setup.** A helper opens *Get paid*, completes Stripe's hosted
   Express onboarding (`createExpressAccountLink`), and comes back. The
   server reads the account (`getPayoutStatus`, and the `account.updated`
   webhook) and stores `payoutsEnabled` on the user. Only the server writes
   it.
2. **Booking.** The app calls `bookPaidSession` with the helper, duration,
   call type, time and a per-attempt `operationId`. The server:
   - checks paid sessions are on, the seeker is an adult, the helper is a
     helper with `payoutsEnabled`, has not blocked the seeker, and is not
     the seeker;
   - prices the session itself (`consultation_price.js`);
   - charges the seeker's default card once per `operationId` (the
     existing idempotent `chargeOnce`), with the customer present;
   - writes `consultations/{operationId}` itself, with the amounts and the
     PaymentIntent. The client never writes a paid consultation.
3. **Bank verification.** If Stripe asks for it, the server returns the
   PaymentIntent's client secret, the app shows the bank's screen
   (`Stripe.instance.handleNextAction`), and calls `bookPaidSession` again
   with the same `operationId`; the server finds the PaymentIntent and
   finishes the booking. The `payment_intent.succeeded` webhook finishes
   it too, so a closed app cannot lose a paid booking.
4. **Money is held.** The charge stays on the platform account until the
   session is over.
5. **Release.** One day after the session's end, an hourly job marks the
   consultation `completed` and transfers the helper's share (price minus
   the 20 % platform fee, `PricingConfig.platformFee`) to the helper's
   account, tied to the original charge (`source_transaction`). One
   transfer per consultation (idempotency key).
6. **Cancel.**
   - Seeker: 100 % back 24 h or more before, 50 % back 1 h or more
     before, nothing later (the policy the app already shows).
   - Helper: always 100 % back to the seeker.
   - What is not refunded is released to the helper as in step 5.
7. **Problem.** Until the release, the seeker can report a problem
   (`reportSessionProblem`). The consultation becomes `under_review`, the
   release waits, and the founder decides in the Stripe and Firebase
   consoles (refund, or set it back to `paid`). A Stripe dispute does the
   same automatically.

Why held funds instead of paying the helper at booking: a no-show or a
cancellation is then a plain refund from the platform, with no money to
claw back from the helper.

## Consultation States

`paid` → `completed` (released) | `cancelled` (refunded, part may be
released) | `under_review` (held for the founder).
Free consultations (price 0) are still written by the app, with cost 0 and
no payment, as `scheduled`.

## Reviews

A review needs a consultation the server marked `completed`, paid by the
reviewer. Free or invented consultations cannot be reviewed.

## Old App Builds

`chargeStoredPaymentMethod` and `createStripeCheckoutSession` refuse
("Please update the app"). Paid sessions are off for every build until the
founder turns them on, after the new build is out.

## Setup The Founder Does

- Stripe test keys for staging (secret as `STRIPE_SECRET`, publishable for
  the staging build), and a test-mode webhook endpoint for
  `handleStripeWebhook` with its signing secret as `STRIPE_WEBHOOK_SECRET`.
- The same in live mode for production, when paid sessions go live.
- Stripe Connect enabled on the account (Express, Canada).
- Legal and tax: GST/QST registration, refund policy in the Terms,
  business registration.
