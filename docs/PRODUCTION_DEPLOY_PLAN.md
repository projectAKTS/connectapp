# Production Deploy Plan (for approval; nothing executed)

Prepared 2026-11-02 from read-only checks of `connectapp-278b4`: the
functions list, the live rules and the deployed indexes. No production
data was read.

## What Is Live Today

| Part | Live in production | Since |
|---|---|---|
| Functions | 18, the same names as the local list (`onAuthUserCreated` is gen 1, as in the code) | last deploy `fd7ad91` |
| Firestore rules | commit `f271b20` | 2026-10-28 |
| Storage rules | flat `post_images/{file}` writes, no size per owner | 2025-09-26 |
| Indexes | 6 composite (posts feed, connections), no TTL | — |
| App | TestFlight 1.0.2 (202610310039) = commit `d673113`, before the 18+ and storage changes | 2026-10-31 |

**Problems in production today** (fixed by this deploy):
- **A first chat cannot open:** the read of the missing chat is denied.
- **Owners can write any field of their profile,** including `rating`
  and the Stripe ids.
- **Duplicate chat notifications** (app fix).
- **Tapping a chat notification can do nothing** (app fix).
- **A deleted account stays signed in** (app fix).

## Compatibility (Why The Order Matters)

| Combination | Effect |
|---|---|
| New app + old rules | Works, except post media upload: the new owner folder is denied by the old Storage rules |
| Old app + new Firestore rules | Accounts without an 18+ declaration cannot message, call or post, and the old app cannot declare |
| Old app + new Storage rules | Post media upload fails (old flat path) |
| New functions + old app | Works. Paid sessions are off (`PAID_SESSIONS_ENABLED` unset = false) |

So the order is:
1. functions first;
2. then the new app to all testers;
3. then the rules on the same day.

## Steps

**0. Before anything (founder):**
- Back up Firestore and wait for `done: true`:
  ```bash
  gcloud firestore export gs://connectapp-278b4-backups/$(date +%F) --project connectapp-278b4
  gcloud firestore operations list --project connectapp-278b4
  ```
- Run the read-only counts that decide side effects. Claude's permission
  system blocks production reads.
  - Users with `deletionRequestedAt` will be deleted by the daily job.
    Confirm each one is a real request.
  - The number of users without `ageDeclaration` is the number who will
    see the 18+ screen once.

**1. Functions (21) and the new APNs key:**
- Deploy the 18 existing functions plus `deleteAccount`,
  `processAccountDeletionRequests` and `onReviewCreated`, listed one by one.
  Never deploy unscoped, which would also deploy Call V2.
- The new APNs key (secret version 7) takes effect with this deploy.
- Upload `AuthKey_A55R9GWWX2.p8` in the production console (Cloud
  Messaging, development and production).
- **Smoke test** (test accounts):
  - one chat push;
  - one call that rings on a locked iPhone.

**2. Indexes:**
```bash
firebase deploy --only firestore:indexes --config firebase.production-indexes.json --project connectapp-278b4
```
- `deploy/production/firestore.indexes.json` keeps production's 6
  indexes and adds the comment and reply collection-group indexes that
  account deletion needs.
- **No TTL:** the main file's Call V2 TTL policies would start deleting
  documents. They need their own approval.
- Dry run validated against staging.

**3. New app:**
- **iOS:** TestFlight from the current `call-v2`, legacy calls (no Call V2
  flags). This is the configuration verified on the iPhone.
- **Android:** an internal-testing build.
- Ask every tester to update before step 4.

**4. Rules and hosting, the same day as step 3:**
```bash
firebase deploy --only firestore:rules,storage,hosting --project connectapp-278b4
```

**5. After 24 hours without incident:**
- Revoke the old APNs key `AJDC73P524`.
- Delete the `.p8` file.

## Rollback

- **Functions:** redeploy `fd7ad91` with the same list. Delete the three
  new ones.
- **Rules:**
  - Firestore: redeploy `f271b20`.
  - Storage: redeploy `deploy/production/previous/storage.rules`, a copy
    of the live rules.
- **APNs:** the old key stays valid until step 5.
- **App:** expire the TestFlight build.

## Not In This Deploy

- TTL / retention policies.
- Call V2.
- Paid sessions.
- Publishing the legal texts.
EOF

## Progress (2026-11-02)

- [x] **0. Backup:** `gs://connectapp-278b4-backups/2026-11-02-pre-mvp-deploy/`
  - private bucket, location US;
  - 1,787 documents, export `SUCCESSFUL`.
- [x] **1. Functions (founder ran the command):** 20 functions.
  - `deleteAccount` and `onReviewCreated` are new.
  - `processAccountDeletionRequests` was deployed afterwards by Claude:
    the founder confirmed every production account is a test account.
    Production now has 21 functions.
  - Verified:
    - `PAID_SESSIONS_ENABLED=false` on the three gated functions;
    - the APNs functions use secret `APNS_VOIP_KEY_P8` version 7, the
      new key `A55R9GWWX2`;
    - no errors in the logs since the deploy.
- [x] **2. Indexes:** deployed by Claude with the production-safe file.
  - Verified: the 6 composite indexes are kept, the 4 comment/reply
    overrides were added, no TTL.
- [x] **1b. Production console APNs key upload** (founder).
- [x] **3. iOS build** 1.0.2 (202611021334) uploaded to App Store Connect.
  - [ ] Android internal-testing build.
  - [x] Testers update: the founder updated the iPhone. (As of
    2026-11-05 the internal group has 2 team members; both run
    `202611040659`.)
- [x] **4. Rules:** `firestore:rules,storage` deployed by Claude.
  - The live rulesets are identical to the local files.
  - The indexes are unchanged: 6 composite, no TTL.
- [ ] **Hosting: held, not deployed.**
  - Production hosting serves only the default Firebase page.
  - Deploying would publish the Terms, the privacy policy and the
    delete-account page for the first time, against the instruction
    "do not publish legal documents".
  - Those pages also use the placeholder `support@helperly.app`.
  - Needs a real support address and the founder's decision.
- [x] **5. Revoke `AJDC73P524`:** revoked 2026-11-05 (see
  `docs/agent-loop/HANDOFF.md`).

## First-Contact Safety Release (2026-11-02, founder: "prod to all")

1. **`onChatMessageCreated`** deployed by Claude. It maintains `repliedBy`.
2. **Backfill:** dry run by Claude (34 chats); `--apply` run by the
   founder, because Claude's permissions block production writes.
   Verified: 34 of 34 chats have `repliedBy`.
3. **Firestore and Storage rules** deployed by Claude. The live ruleset
   is identical to `firestore.rules` (`200168a`). Hosting is still held.
4. **iOS build 1.0.2 (202611022213)** uploaded to App Store Connect.

## Video Thumbnail Check (2026-11-06)

- **`onPostImagesChanged`** deployed by the founder from `45950d1`: post
  video thumbnails (`videoThumbUrl`) now go through the SafeSearch check.
- Verified read-only: state `ACTIVE`, revision
  `onpostimageschanged-00002-dir`, 23 functions in total, no warnings or
  errors in the logs after the deploy.
- The CLI's `functions.config()` deprecation notice does not apply: the
  code does not use `functions.config()`.
- The app part (blurring sensitive video posts) ships with the next
  TestFlight build.
- **iOS build 1.0.2 (202611060504)** from `314a57e` uploaded by Claude
  (`EXPORT SUCCEEDED`). Testers get it after the export-compliance answer
  in App Store Connect.
  - 2026-11-06: export compliance answered by the founder; the founder
    tested the build on the iPhone (feed, normal video and photo posts,
    chat, call): no problems.

## Call Ringing Fix (2026-11-07)

Founder's report: after a few test calls, the callee's iPhone stopped
ringing (no CallKit screen, phone locked or app open).

Evidence (production logs, read-only):
- every incoming call got its VoIP push accepted by APNs (`sent: 1`);
- after every ended, cancelled, declined or missed call the server also
  sent a **VoIP push** (`APNS VoIP terminal result`), to the caller for
  declined/missed. The iOS app ends the CallKit call for these but never
  reports a new incoming call. iOS kills an app that does this and, after
  a few times, stops delivering VoIP pushes to it: calls stop ringing.
- separate problem: every FCM push to iOS fails since the old APNs key
  `AJDC73P524` was revoked (`messaging/third-party-auth-error: Invalid
  APNs credentials`, first seen 2026-11-07). The production Firebase
  console still uses the revoked key, so chat notifications do not
  arrive on iPhones.

Fix: `onCallInviteUpdated` sends no VoIP push for terminal and
answered-elsewhere updates, only the FCM push; a ringing call is ended by
the app's invite listener, that FCM push, or the CallKit ring timeout.
Guard test: `connect_functions/test/call_invites/voip_only_for_new_calls.test.js`.
Verified on staging: a cancelled invite sends FCM and no VoIP.

Founder:
1. [x] `firebase deploy --only functions:onCallInviteUpdated --project connectapp-278b4`: done by the founder; verified `ACTIVE`, revision `oncallinviteupdated-00008-dop`, no errors.
2. Firebase console (production) > Project settings > Cloud Messaging >
   Apple app `com.yakup.helperly` > APNs Authentication Key: replace the
   key with `AuthKey_A55R9GWWX2.p8`, Key ID `A55R9GWWX2`, Team ID
   `3UDYS4KQW3`.
3. Both test iPhones: delete Helperly and reinstall it from TestFlight
   (clears the iOS VoIP block), sign in, then test calls again.
2. [x] Production Firebase console: APNs key `A55R9GWWX2` uploaded by the
   founder for `com.yakup.helperly` (development and production).
3. [x] Both iPhones reinstalled. Founder's test 2026-11-07: calls (locked,
   app open, cancel, decline) and chat notifications all work.
   Saved as tag `stable-calls-2026-11-07` / branch `stable/calls-2026-11-07`.
   Known iOS behaviour: with the Sleep Focus on, calls do not show (chat
   notifications do); see the next section.

## In-App Incoming Screen on iOS (2026-11-07, branch `feat/ios-inapp-incoming`)

- Founder's request: like WhatsApp, show Accept/Decline inside the app
  when it is open, and when the user opens the app from the CallKit banner
  or the notification while the call rings.
- `44fe303`: the screen mirrors CallKit. Accept answers the exact CallKit
  call (`answerExactCallkitCall`), Decline uses `declineInvite`, so the
  tested CallKit paths run. Android unchanged. App-only: no server change.
- Tests: 5 new (`test/call/ios_incoming_screen_test.dart`); full suite
  2523 passed with the 16 known failures; clean-tree guards 221/221.
- iOS build 1.0.2 (`202611062156`) uploaded from the branch for the
  founder's iPhone test. Merge into `call-v2` only after that test.
- Restore point if needed: tag `stable-calls-2026-11-07`.
- `76b9278` fixes two cases where Flutter, not PushKit, presents CallKit (the
  Firestore invite arrives 1–4 s before the VoIP push): the screen now waits
  for the CallKit call to be listed, and a banner Decline with empty plugin
  data uses the call AppDelegate recorded. Build `202611081451`.
- [x] Founder's iPhone test 2026-11-08 (build `202611081451`): in-app screen
  on all 3 foreground calls, Accept and Decline from it, banner Accept in the
  background, banner Decline. Production invites confirmed `declined`.
  Merged into `call-v2`; tag `stable-calls-2026-11-08`.

## Missed-Call Note and Per-Chat Unread Fix (2026-11-08, branch `feat/missed-call-note`)

- `f1b166e`: a call that ends unanswered (ring timeout, or the caller hangs
  up while it rings) adds a system `missed_call` message from the caller to
  the chat, once per invite (`missedCallNoteAt`). The normal chat push then
  shows "<caller>: Missed audio/video call" in the callee's language. None
  for a decline, an accepted call, or a blocked caller.
- `69a8cbf`: per-chat unread counts were written as literal
  `unreadBy.<uid>` fields (`set` with merge does not read dots), so the
  chat list's unread badges never showed. Server and app now write the
  `unreadBy` map.
- Staging: both functions deployed; `node tool/staging_smoke.mjs` 30/30.
- **Order matters.** The old app clears unread with the literal field, so
  with the new server its per-chat badges would never clear. Ship the new
  app to both iPhones first, then deploy the functions.

Founder:
1. Install the new TestFlight build on both iPhones (nothing new shows yet:
   both changes need the functions).
2. [x] Done by the founder 2026-11-08; verified `ACTIVE`, revisions
   `oncallinviteupdated-00009-bat`, `onchatmessagecreated-00040-haz`, no errors.
   From the `feat/missed-call-note` checkout:
   ```bash
   firebase deploy --only functions:onCallInviteUpdated,functions:onChatMessageCreated --project connectapp-278b4
   ```
3. Test: an unanswered call leaves "Missed call" in the chat with a
   notification; a new message shows a badge on that chat; opening the chat
   clears it.
- Founder's test 2026-11-08: unanswered calls show the note and the push.
  Founder: a declined call showed nothing in the chat. Now a declined call
  also leaves the note, silent (`silent: true`: no push, no unread), as
  messaging apps show it. Staging smoke 31/31. Production: deployed by the
  founder 2026-11-08; verified `ACTIVE`, revisions `oncallinviteupdated-00010-diy`,
  `onchatmessagecreated-00041-lar`, no errors. Command used:
  ```bash
  cd /Users/yakup/connectapp && git switch feat/missed-call-note && git pull && firebase deploy --only functions:onCallInviteUpdated,functions:onChatMessageCreated --project connectapp-278b4
  ```

## Sign-In Profile Fix (2026-11-08, branch `feat/missed-call-note`)

- `13be5d3`: a fresh sign-in wrote the fallback name "User" over the real
  name (the profile read had the push-token write pending and looked empty).
  Google and Apple sign-in reset photo, bio, followers and counters on every
  sign-in; now only for a new account. Reproduced and verified on the staging
  emulator. Production (read-only): 0 of 71 users named "User".
- `6665fe1`: Android logs why a background call push did not ring.
- App-only. iOS build uploaded to TestFlight; no server change.

