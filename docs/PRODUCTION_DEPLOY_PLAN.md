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
