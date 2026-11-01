# Release Checklist: Functions, Rules, App (for approval; NOT deployed)

Branch `call-v2`, prepared 2026-11-01. Per-function details are in
`docs/DEPLOY_FUNCTIONS_REVIEW.md`. Founder runs every command; Claude never
deploys.

## 0. Before Anything

- [ ] **Backup:** export Firestore to a bucket (point-in-time copy):
  ```bash
  gcloud firestore export gs://connectapp-278b4-backups/$(date +%F) --project connectapp-278b4
  ```
  - The bucket must exist, so create it once.
  - Optionally turn on Firestore PITR (7 days) in the console.
- [ ] **Compare functions:** run
  `firebase functions:list --project connectapp-278b4` and compare with
  the 16 below. Never deploy unscoped: 11 Call V2 exports must stay off.
- [ ] **Compare source:** diff the deployed source of each function
  against local, using the method in the project notes. If someone
  deployed from another machine, stop and reconcile.
- [ ] **Environment file:** `.env.connectapp-278b4` is present on the
  deploying machine (`defineString` params). The secrets already exist.
- [ ] **Stripe:**
  - test mode keys stay in test mode until paid sessions are approved;
  - the webhook endpoint subscribes to `payment_intent.succeeded`,
    `payment_intent.payment_failed` and `payment_intent.canceled`.

## 1. Functions (16)

Existing functions get new code; three are new.

| Group | Functions | Touches user data? |
|---|---|---|
| Payments | `chargeStoredPaymentMethod` (idempotent operations), `handleStripeWebhook` (reconciliation), `createStripeCustomer`, `createSetupIntent`, `createStripeCheckoutSession`, `listPaymentMethods`, `removePaymentMethod`, `setDefaultPaymentMethod`, `createExpressAccountLink` | Writes `paymentOperations`; reads `users` |
| Notifications | `onChatMessageCreated` (claim `notifiedAt`), `scheduledConsultationReminder` (claim `reminderSentAt`), `onCallInviteCreated` (blocked callers, language) | Writes markers on messages and consultations; unread counters |
| Accounts | `onAuthUserCreated` (private email), **`deleteAccount`** (new), **`processAccountDeletionRequests`** (new, daily) | **Deletes user data** |
| Reviews | **`onReviewCreated`** (new) | Writes rating fields |

**Account deletion review (destructive):**
- **Deletes:**
  - the user doc and its subcollections;
  - the user's posts with their comments;
  - follower lists;
  - Storage folders (`users/`, `post_images/`, `post_videos/`,
    `post_video_thumbs/` + uid);
  - review text;
  - the Auth user.
- **Keeps:** chats, `callInvites`, reports, consultations, payment records
  and review stars.
- **Scope:** only the caller's own uid (callable) or users who set
  `deletionRequestedAt` (daily job, at most 100 per run).
- **Not exercised against production data:** test with a throwaway
  account after deploy (smoke test 4).

## 2. Rules And Hosting

- [ ] `firestore:rules`:
  - protected rating fields;
  - `reviews`;
  - `paymentOperations` server-only;
  - message `notifiedAt` cannot be pre-set;
  - sticky `minor`;
  - private reports and consultations.
- [ ] `storage`: owner folders; chat media for participants; size and
  type limits. The CLI may ask to let Storage read Firestore: yes.
- [ ] `hosting`: legal pages (still the English live texts), the delete
  account page, the Stripe return pages.
- Emulator evidence (2026-11-01):
  - Firestore rules with Call V2: 268/268;
  - Storage: 5/5.

## 3. Compatibility With Builds Already Installed

| Change | Old build behaviour |
|---|---|
| Paid charge requires `operationId` | Gets "Please update the app" (paid sessions are not live) |
| Rules: message `notifiedAt` | Old builds never send it: no effect |
| Rules: sticky `minor` | Old builds don't write `ageDeclaration`: no effect |
| Rules: storage owner paths | Old post-media uploads to legacy flat paths fail (read still works). Release the new app build **before** the Storage rules |
| `spokenLanguages` / legacy `language` | The new app keeps writing `language`; old builds unaffected |
| 18+ gate, consent prompt | Only in the new build |

## 4. Order

1. Backup (step 0).
2. Existing functions except the payment pair.
3. Smoke tests 1–3 below.
4. Release the new app build (TestFlight / Play internal) to testers.
5. `firestore:rules,storage,hosting`.
6. New functions: `deleteAccount`, `processAccountDeletionRequests`,
   `onReviewCreated`. Then smoke tests 4–5.
7. Payment pair (`chargeStoredPaymentMethod`, `handleStripeWebhook`)
   **in Stripe test mode only**. Then smoke test 6.
8. Email migration script (`docs/DEPLOY_MVP.md` step 4). Dry run first.

## 5. Smoke Tests (Test Accounts Only)

1. A chat message gives exactly one push; the unread badge goes +1.
2. A call rings, can be answered and ends; the alert fallback appears in
   the callee's language.
3. A consultation 5–10 minutes out gives one reminder, "Starts in N
   minutes".
4. A throwaway account: Settings > Delete account removes the user doc,
   posts and Auth user; the app signs out.
5. A review on a past consultation updates the helper's `rating` /
   `ratingCount` once.
6. Stripe **test** card `4242…`: book, then retry the same booking
   (airplane mode mid-request) → one PaymentIntent in the Stripe test
   dashboard, `paymentOperations/{id}.status == succeeded`.

## 6. Monitoring (First 48 h)

- Functions logs: errors per function, `duplicate delivery skipped`
  counts, `Charge error`.
- Stripe test dashboard: one PaymentIntent per `operationId`.
- Crashlytics (opt-in users only), App Store / Play crash reports.

## 7. Rollback

- **Functions:** redeploy from the last deployed commit (`fd7ad91`) with
  the same `--only` list. Delete the new ones with
  `firebase functions:delete deleteAccount processAccountDeletionRequests onReviewCreated --region us-central1 --project connectapp-278b4`.
- **Rules:** `git revert` the rules commits, then redeploy
  `firestore:rules,storage`.
- **Data:** restore from the step 0 export (`gcloud firestore import`)
  only for a real incident; it overwrites documents.
- **App:** halt the phased release or expire the TestFlight build.

## 8. Not Covered

- Live Stripe charges or payouts (not authorized).
- TTL / retention (`docs/RETENTION_POLICY_PROPOSAL.md`, needs approval).
- Publishing legal texts (drafts only).
