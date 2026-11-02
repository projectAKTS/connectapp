# Staging Deployment Plan (for approval; NOT executed)

## Target (Verified Read-Only, 2026-11-01)

| | Staging | Production |
|---|---|---|
| Project id | `helperly-call-v2-dev` ("Helperly Call V2 Dev", #270649452680) | `connectapp-278b4` (#33757728932) |
| Registered apps | 1 iOS app | iOS + Android |
| Deployed functions | `callV2RtcToken` (Call V2 dev; **leave untouched**) | 18 (see `RELEASE_CHECKLIST.md`) |
| Firebase CLI default | Yes (`firebase use`) | Always pass `--project connectapp-278b4` |

## Isolation

- **Separate GCP project:** its own Auth users, Firestore, Storage bucket,
  Functions, secrets, logs and billing. Nothing is shared with
  production.
- **App build:** a staging build uses Firebase options generated for
  `helperly-call-v2-dev`, selected at build time
  (`--dart-define=HELPERLY_ENV=staging`). The production build is
  unchanged.
- **Payments:** Stripe **test** keys only, and `PAID_SESSIONS_ENABLED`
  false anyway.
- **Agora:** use a separate Agora test project (app id and certificate);
  otherwise staging calls count toward production usage.

## Needed Before Deploying (Founder Approvals And Actions)

1. **Register an Android app** in `helperly-call-v2-dev`. This creates a
   resource and needs approval. Then run
   `flutterfire configure --project=helperly-call-v2-dev --out=lib/services/firebase_options_staging.dart`
   (Claude adds the `HELPERLY_ENV` switch in `main.dart`; the default
   stays production).
2. **Billing:** confirm Blaze is on (functions are already deployed, so it
   most likely is).
3. **Secrets** (`firebase functions:secrets:set <NAME> --project helperly-call-v2-dev`):
   - `STRIPE_SECRET` (test key `sk_test_…`);
   - `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE` (test project);
   - `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_VOIP_KEY_P8`
     (only for iPhone call tests; Android tests need none).
4. **`.env.helperly-call-v2-dev`** (gitignored):
   - `PAID_SESSIONS_ENABLED=false`;
   - `CALL_V2_ENABLED=false`;
   - the `CALL_V2_*` params as in production (needed only for parsing).
5. **Test accounts:** 2–3 accounts you control (Gmail `+aliases`).

## Procedure (Scoped, Never Unscoped)

```bash
cd ~/connectapp
P=helperly-call-v2-dev
# 1. Indexes first (comment/reply collection-group overrides). Answer "No"
#    if asked to delete indexes that are not in the file.
firebase deploy --project $P --only firestore:indexes
# 2. Rules and hosting
firebase deploy --project $P --only firestore:rules,storage,hosting
# 3. The 16 functions, listed explicitly (bash, so the list splits)
bash -c 'firebase deploy --project helperly-call-v2-dev --only functions:chargeStoredPaymentMethod,functions:handleStripeWebhook,functions:createStripeCustomer,functions:createSetupIntent,functions:createStripeCheckoutSession,functions:listPaymentMethods,functions:removePaymentMethod,functions:setDefaultPaymentMethod,functions:createExpressAccountLink,functions:onChatMessageCreated,functions:scheduledConsultationReminder,functions:onCallInviteCreated,functions:onAuthUserCreated,functions:deleteAccount,functions:processAccountDeletionRequests,functions:onReviewCreated'
# 4. Check nothing else changed
firebase functions:list --project $P   # callV2RtcToken still there, no other V2
```

Then:
- `flutter build apk --debug --dart-define=HELPERLY_ENV=staging`, install
  it on emulator A and B;
- run `docs/BETA_MANUAL_TESTS.md` (Android first; iPhone when connected).

## Rollback And Recovery (Staging)

- **Functions:** `firebase functions:delete <names> --project helperly-call-v2-dev --region us-central1`.
  `callV2RtcToken` is never in the list.
- **Rules:** redeploy the previous `firestore.rules` / `storage.rules`
  from git.
- **Data:** staging holds only test data. If needed, delete the test
  accounts in the console. No backup is required, but take one export
  first to rehearse the production backup and restore
  (`RELEASE_CHECKLIST.md` § Backup).

## Is Staging Safe To Begin?

**Yes, technically, once steps 1–5 above are approved and done.**
Nothing in this plan touches production. The only shared item would be
the Agora app, which is why a test project is recommended.
