# Active Task - MVP Server Hardening (MVP-2)

Branch: `call-v2`

Starting SHA: `080bd1f`

The user is asleep. The user said: "continue; I'll do all deploys together at
the end". Everything here is prepared and tested locally; no deploy, no
production data change.

## Findings Driving This Task

1. `chargeStoredPaymentMethod` charges whatever `amount` the client sends:
   a modified client can book 30 min for $0.01. Nothing records which
   consultation or helper a charge is for.
2. Premium discount and the free 5-min audio are decided on the client from
   `premiumStatus`, which the user can write on their own doc.
3. `createExpressAccountLink` uses placeholder `yourapp.page.link` URLs, so
   helper Stripe onboarding cannot complete.
4. Storage: any signed-in user can read, overwrite or delete any chat
   attachment and any post media. There are no size or type limits.
5. Firestore:
   - consultations are readable and creatable by anyone;
   - reports are readable by anyone;
   - users can write any field on their own doc (`isVerified`, ...);
   - email is in the world-readable user doc.
6. Account deletion is only a request flag (MVP-1).
7. Blocked people can still call (server) and message (rules).

## Scope

A. **Server-side consultation price.**
   - `consultations/consultation_price.js` holds the same table as
     `PricingConfig`.
   - The charge takes `durationMinutes`, `callType` and `helperId`.
   - A legacy `amount` is accepted only if it equals a table price.
   - The charge records metadata.
   - The client sends the new fields.
   - Premium discount and free audio are gated by `MvpFeatures.premium`.
B. **Helper onboarding.** Stripe return and refresh URLs point to hosting
   pages.
C. **Hosting.** `public/` gets privacy, terms and Stripe return pages (the
   App Store needs a privacy URL).
D. **Firestore rules.**
   - Reports are not readable by clients.
   - Consultations are read by participants only and created by the payer.
   - Protected user fields are server-only: verification, Stripe ids,
     rating.
   - Chat messages to someone who blocked you are rejected.
E. **Storage rules.**
   - Chat files are for chat participants only.
   - New post media goes under `post_*/{uid}/`, writable by its owner; the
     flat legacy paths become read-only.
   - Image and video size and type limits.
   - The client upload paths change to match.
F. **`deleteAccount` callable.**
   - It deletes the user's doc, private subdocs, posts and auth user.
   - A daily `processAccountDeletionRequests` handles MVP-1 requests.
   - The client calls the callable and falls back to the request flag.
G. **Email privacy.**
   - The client stops writing `email` to the public doc.
   - Functions read the email from Auth.
   - A one-off migration script moves the existing emails.
H. **Blocked calls.** `onCallInviteCreated` ends an invite whose callee
   has blocked the caller, before any push.

## Validation

- Node tests for pricing, deletion planning and the block check.
- Firestore and Storage rules tests on the emulator.
- `flutter analyze`; the full suite shows no new failures.
- Deploy list for the user: exact named functions, rules, storage and
  hosting, plus the migration command.
