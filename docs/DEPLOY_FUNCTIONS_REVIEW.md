# Cloud Functions Deploy Review (for approval; NOT deployed)

Project `connectapp-278b4`, region `us-central1`, Node 22. Prepared
2026-10-31 from `call-v2`. Deploys are run by the founder, never by Claude.

## Baseline

On 2026-10-27, 18 functions were deployed. `index.js` exports more,
including 11 Call V2 functions that must stay undeployed, so **never run an
unscoped `firebase deploy --only functions`.** Before deploying, compare
the live list (`firebase functions:list --project connectapp-278b4`) with
the table below.

## Functions In This Batch

"Existing" means already deployed with older code; "new" means not
deployed.

| Function | New? | Trigger | Collections / services touched | Purpose of change |
|---|---|---|---|---|
| `chargeStoredPaymentMethod` | Existing | Callable | Stripe PaymentIntents; `users` (read) | The server prices the session; a client amount is accepted only if it is an offered price; metadata added |
| `createStripeCustomer`, `createSetupIntent`, `listPaymentMethods`, `removePaymentMethod`, `setDefaultPaymentMethod`, `createStripeCheckoutSession` | Existing | Callable | Stripe; `users/{uid}/private/account` (read email) | The Stripe customer email comes from the private doc or Auth, not the public profile |
| `createExpressAccountLink` | Existing | Callable | Stripe Connect | Return/refresh URLs point to live hosting pages (Dynamic Links are shut down) |
| `onAuthUserCreated` (gen1) | Existing | Auth user created | `users/{uid}`, `users/{uid}/private/account` | Email stored privately; empty bio |
| `onCallInviteCreated` | Existing | Firestore create `callInvites/{id}` | `users` (callee read), `callInvites` (blocked → missed), FCM/APNs | Calls from blocked callers are not delivered; alert fallback in the callee's language |
| `onChatMessageCreated` | Existing | Firestore create `chats/{id}/messages/{id}` | `chats`, `users` (unread counters), FCM/APNs | "Sent you a message" in the recipient's language (message text untouched) |
| `scheduledConsultationReminder` | Existing | Schedule, every 5 min | `consultations` (read), `users` (read), FCM | Language per participant; "Starts in N minutes" instead of a UTC clock time |
| `deleteAccount` | **New** | Callable | User doc and subcollections, posts and comments, followers, Storage folders, Auth user, review text | In-app account deletion (App Store 5.1.1(v)) |
| `processAccountDeletionRequests` | **New** | Schedule, every 24 h | `users where deletionRequestedAt != null` (max 100/run) | Processes deletion requests made when the callable is unavailable |
| `onReviewCreated` | **New** | Firestore create `reviews/{consultationId}` | `reviews`, `users/{helperUid}` (rating fields) | Keeps the helper's average rating |

No equivalent of the three new functions exists in production.

Rules (`firestore:rules`, `storage`) and hosting are a separate step in
`docs/DEPLOY_MVP.md`. `onReviewCreated` is useless until the rules that
allow `reviews` writes are deployed.

## Duplicates, Retries And Idempotency

None of these functions set `retry: true`, so failed runs are not retried.
Firestore and scheduled triggers are still at-least-once: a rare duplicate
delivery can happen.

| Function | Duplicate effect | Guard |
|---|---|---|
| `onReviewCreated` | Would double-count a rating | **Idempotent:** a transaction sets `countedAt` and skips if it is already set |
| `onCallInviteCreated` | A second push for the same call | Pre-existing. Clients dedupe by invite/callkit id; the blocked path writes in a transaction that only acts on `ringing` |
| `onChatMessageCreated` | A second push and +1 unread | Pre-existing, **no guard**. Rare; the badge self-corrects when the chat is opened. Suggested later: a `notifiedAt` marker on the message |
| `scheduledConsultationReminder` | Can send two reminders: the window is inclusive at both ends and there is no "sent" marker | Pre-existing. Suggested: a `reminderSentAt` field set in a transaction |
| `processAccountDeletionRequests` / `deleteAccount` | Re-running deletes what is left | Safe: deleting missing docs is a no-op; Auth `user-not-found` is tolerated |
| `chargeStoredPaymentMethod` | **A client retry could charge twice** | **No Stripe idempotency key, a pre-existing risk.** Recommended before paid sessions launch: pass `idempotencyKey` (for example the booking id) to `paymentIntents.create`. This is a payment-logic change, so it needs approval. |

## Cost (MVP Scale, Estimate)

- **Invocations:** callables and triggers run per user action; at MVP
  volume, well inside the free tier (2M invocations a month).
- **New Firestore reads:**
  - one user-doc read per reminder recipient;
  - the callee doc read already existed;
  - chat locale comes from a read that already existed.
- **Schedules:** `processAccountDeletionRequests` adds 30 runs a month.
  The reminder schedule already ran 8,640 times a month.
- **Bill:** expected change of $0 to a few dollars a month. There is no
  new paid service.

## Environment And Permissions

- **Secrets (already set):** `STRIPE_SECRET`, the `APNS_*` secrets, and
  the `AGORA_*` secrets (unchanged).
- **Params:** `defineString` params, including the Call V2 ones, are read
  from the existing gitignored `.env.connectapp-278b4`. That file must be
  present on the deploying machine.
- **New permissions:**
  - `deleteAccount` uses Admin Auth (`auth.deleteUser`) and Storage
    `deleteFiles`, both covered by the default service account;
  - the Storage rules deploy may ask to grant Storage access to Firestore:
    answer yes.

## Rollback

```bash
git checkout fd7ad91 -- connect_functions   # last deployed source state
firebase deploy --project connectapp-278b4 --only <same function list>
git checkout call-v2 -- connect_functions
```

- **New functions:** remove them with
  `firebase functions:delete deleteAccount processAccountDeletionRequests onReviewCreated --project connectapp-278b4 --region us-central1`.
- **Coordination:** the app's delete-account fallback (writing
  `deletionRequestedAt`) works without the callable.

## Test Evidence (2026-10-31, local)

- **Node unit tests:**
  - push texts 5/5;
  - reviews, account deletion, consultation price and call invites 47/47.
- **Firestore emulator:**
  - Call V2 suite and Firestore rules (MVP, reviews, Call V2) 265/265;
  - Storage rules 5/5.
- **Not tested:** live Stripe, APNs or FCM delivery, and deployed-trigger
  behavior. These need a staging project or a careful production smoke
  test after deploy.

## Exact Command (Run By The Founder After Approval)

Check the live list first, then run:

```bash
cd ~/connectapp
firebase deploy --project connectapp-278b4 --only \
functions:chargeStoredPaymentMethod,\
functions:deleteAccount,\
functions:processAccountDeletionRequests,\
functions:onAuthUserCreated,\
functions:createExpressAccountLink,\
functions:onCallInviteCreated,\
functions:onReviewCreated,\
functions:onChatMessageCreated,\
functions:scheduledConsultationReminder,\
functions:createStripeCustomer,\
functions:createSetupIntent,\
functions:createStripeCheckoutSession,\
functions:listPaymentMethods,\
functions:removePaymentMethod,\
functions:setDefaultPaymentMethod
```

**Recommendation:** first diff the deployed source against local (method
in the project notes), then deploy in two steps:
1. The existing functions only, followed by a smoke test (chat push, call,
   reminder).
2. The three new functions together with the rules.
