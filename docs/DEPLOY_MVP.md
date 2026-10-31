# MVP Deploy Checklist

Prepared by Claude on 2026-10-31 for the user to run in one batch.
Everything here is committed on `call-v2` and tested locally: Node tests,
the Firestore and Storage rules emulators, and the Flutter suite.

> **Important:** the Firebase CLI's active project is `helperly-call-v2-dev`.
> Every command below passes `--project connectapp-278b4` explicitly. Never
> run an unscoped `firebase deploy --only functions`.

## Order

The order matters: the new Storage rules make the old post-media paths
read-only.

### 1. Functions

These are the changed and new ones only.

```bash
cd ~/connectapp
firebase deploy --project connectapp-278b4 --only \
functions:chargeStoredPaymentMethod,\
functions:deleteAccount,\
functions:processAccountDeletionRequests,\
functions:onAuthUserCreated,\
functions:createExpressAccountLink,\
functions:onCallInviteCreated,\
functions:createStripeCustomer,\
functions:createSetupIntent,\
functions:createStripeCheckoutSession,\
functions:listPaymentMethods,\
functions:removePaymentMethod,\
functions:setDefaultPaymentMethod
```

What each change does:

| Function | Change |
|---|---|
| `chargeStoredPaymentMethod` | The server prices the session. A client amount is accepted only if it is an offered price, and the charge records metadata. |
| `deleteAccount` (new) | Deletes the account and personal data at once. |
| `processAccountDeletionRequests` (new, daily) | Handles deletion requests made from MVP-1 builds. |
| `onAuthUserCreated` | Puts the email in the private `users/{uid}/private/account` doc; empty bio. |
| `createExpressAccountLink` | Real Stripe return URLs (hosting pages); email from Auth. |
| `onCallInviteCreated` | Calls from someone the callee blocked are never delivered. |
| The six Stripe customer functions | The Stripe customer email comes from Auth instead of the public doc. |

### 2. Release the new app build

TestFlight and APK. It uploads post media to the new `post_*/{uid}/` paths
and uses the new deletion and payment calls.

### 3. Rules and hosting

```bash
firebase deploy --project connectapp-278b4 --only firestore:rules,storage,hosting
```

- Storage rules now read Firestore (to check chat participants). The CLI
  may ask to grant Storage access to Firestore; answer **yes**.
- Hosting publishes `index`, `privacy`, `terms` and `safety` pages and the
  Stripe return pages at `https://connectapp-278b4.web.app/`.
- Put `https://connectapp-278b4.web.app/privacy.html` in App Store Connect
  and the Play Console as the privacy policy URL.
- In the Play Console Data safety form, give
  `https://connectapp-278b4.web.app/delete-account.html` as the account
  deletion link (Play requires a web path besides in-app deletion).

### 4. Move existing emails out of public profiles

This is a one-off. Run the dry run first; it prints counts only.

```bash
cd ~/connectapp/connect_functions
gcloud auth application-default login
GOOGLE_CLOUD_PROJECT=connectapp-278b4 node scripts/migrate_public_emails.js
GOOGLE_CLOUD_PROJECT=connectapp-278b4 node scripts/migrate_public_emails.js --apply
```

### 5. Crash reporting and analytics (MVP-3)

- In the Firebase console, open **Crashlytics** and click **Enable
  Crashlytics**. The SDK is in the app, but the project setting is off, so
  no reports are collected yet.
- Analytics needs no deploy. Events appear in **Analytics > Events** within
  a day.
- iOS crash symbols: for readable iOS stack traces, add the Crashlytics dSYM
  upload run script in Xcode later (optional for launch).
- Update the store privacy forms to declare crash data and usage data
  (product interaction), both linked to the user id:
  - App Store Connect "App Privacy";
  - Play Console "Data safety".
- Builds on this Mac use the local `pubspec.lock` / `Podfile.lock` changes,
  which are not committed, per the repo rule. A fresh clone resolves the
  same pinned FlutterFire versions from `pubspec.yaml`.

## Rollback

- **Rules:** revert `firestore.rules` and `storage.rules` with `git revert`,
  then redeploy the same targets.
- **Functions:** redeploy from the previous commit (`fd7ad91`) with the same
  `--only` list.

## Still open (needs you)

- **Support email:** set a real address in `lib/config/legal_texts.dart`
  (`supportEmail`), then run `python3 tool/build_legal_site.py`.
- **Legal review:**
  - the Terms and Privacy drafts;
  - the RCIC rule on paid immigration advice;
  - French for Quebec.
- **Test data:** approve deleting the test accounts and posts in production.
