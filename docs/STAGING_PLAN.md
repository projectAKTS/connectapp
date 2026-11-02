# Staging Plan (Deployed 2026-11-01)

**Status:** deployed to `helperly-call-v2-dev` only, with the founder's
approval. Production was not touched. The sections below are the
approval package as it was reviewed; the results are in
`docs/agent-loop/HANDOFF.md`.

## 1. Project

**`helperly-call-v2-dev`** ("Helperly Call V2 Dev", project number
270649452680). Production is `connectapp-278b4` (33757728932).

## 2. Resources

| Resource | State | Action |
|---|---|---|
| Android app `com.yakup.helperly` | **Created 2026-11-01** (`1:270649452680:android:4ce86accbe73644dbe973d`), approved | — |
| iOS app `com.yakup.helperly` | Exists | — |
| Firestore `(default)` | Exists | Rules and indexes will be **modified** |
| Storage bucket `helperly-call-v2-dev.firebasestorage.app` | **Missing** | **You:** Firebase console > Storage > Get started (location `us-central1`, production mode) |
| Hosting site `helperly-call-v2-dev.web.app` | Exists | Will be **modified** (legal and delete pages) |
| Cloud Functions | Only `callV2RtcToken` | **Create 21** (list below); `callV2RtcToken` untouched |
| Secrets | All present | `STRIPE_SECRET` is a **test** key ✓. **`AGORA_APP_ID` is the production Agora app ✗**; replace with a test project (below) |
| `.env.helperly-call-v2-dev` (git-ignored) | Present | No production ids; `CALL_V2_ENABLED=false`; `PAID_SESSIONS_ENABLED=false` (added) |
| Staging client configs | `config/staging/` (git-ignored) | Generated from the staging apps |

## 3. Functions And Rules

- **Functions (21):** the 18 production functions plus `deleteAccount`,
  `processAccountDeletionRequests` and `onReviewCreated`:
  - `callInviteTransition`, `getAgoraRtcToken`, `onCallInviteCreated`,
    `onCallInviteUpdated`, `onChatMessageCreated`, `onAuthUserCreated`,
    `healthCheck`, `scheduledConsultationReminder`;
  - `createStripeCustomer`, `createSetupIntent`, `listPaymentMethods`,
    `setDefaultPaymentMethod`, `removePaymentMethod`,
    `cancelConsultation`, `chargeStoredPaymentMethod`,
    `createExpressAccountLink`, `createStripeCheckoutSession`,
    `handleStripeWebhook`;
  - `deleteAccount`, `processAccountDeletionRequests`, `onReviewCreated`.
- **Never deployed:** the 11 Call V2 functions.
- **Rules:** `firestore.rules` (18+, private collections, chat and
  payment markers), `storage.rules`, `firestore.indexes.json` (comment and
  reply collection-group overrides).

## 4. Cost (Staging, Estimate)

- Usage-billed, inside the Blaze free tiers at test volume:
  - about 9,000 scheduler runs a month (reminder every 5 minutes, plus
    daily deletion);
  - a few thousand Firestore operations;
  - a few MB of Storage.
- Cloud Scheduler: 2 jobs, $0–0.20 a month.
- Artifact Registry (function images): about $0.10–0.50 a month.
- Cloud Build: free tier.
- **Expected total: under $5 a month.** Delete the functions after the
  beta to stop scheduler runs.

## 5. Isolation

- **Different GCP project:** separate Auth, Firestore, Storage, Functions,
  secrets and logs.
- **App:**
  - `tool/build_staging.sh` swaps in the staging native configs and
    restores production's on exit. The production configs were restored
    after the test build, verified with git.
  - The staging APK's native config contains only `helperly-call-v2-dev`
    (checked automatically).
  - At startup, a staging build **refuses to run** if it is connected to
    any other project (`StagingFirebaseOptions.assertIsolated`).
  - Production builds are unchanged (`HELPERLY_ENV` unset).
- **Server:** `tool/deploy_staging.sh check` hard-stops if the target is
  production, the list contains a Call V2 function, the env file mentions
  production, the Stripe key is not a test key, the Agora app is
  production's, or the bucket is missing. **It currently stops on Agora.**
- **Payments:** off by `PAID_SESSIONS_ENABLED=false` and Stripe test mode.

## 5b. Two Things Only You Can Do Before Deploy

1. **Agora test project.** In console.agora.io, create a project
   "Helperly Staging" (Secured mode, with an app certificate). Then run:
   ```bash
   firebase functions:secrets:set AGORA_APP_ID --project helperly-call-v2-dev
   firebase functions:secrets:set AGORA_APP_CERTIFICATE --project helperly-call-v2-dev
   ```
   Paste the values at the prompts; never in chat or git.
2. **Storage:** Firebase console > `helperly-call-v2-dev` > Storage > Get
   started.

## 6. Commands (After Approval)

```bash
tool/deploy_staging.sh check     # must print "isolation checks passed"
tool/deploy_staging.sh deploy    # indexes -> rules/storage/hosting -> 21 functions
tool/build_staging.sh android    # staging APK (and: tool/build_staging.sh ios)
```

## Rollback

- **Functions:** delete them:
  `firebase functions:delete <the 21 names> --project helperly-call-v2-dev --region us-central1`.
- **Rules:** redeploy the previous versions from git.
- **Data:** synthetic only. Delete the test users in the console.
- **App:** reinstall the normal (production) build.
