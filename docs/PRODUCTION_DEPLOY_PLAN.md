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
