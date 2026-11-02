# Account Deletion: End-To-End Verification

Run 2026-11-01 against the Auth, Firestore and Storage emulators with two
disposable users (A deleted, B bystander). The test is
`connect_functions/test/account/delete_account_e2e.test.js`; the steps to
run it are in its header. It uses a temporary emulator config with Auth
enabled, because `firebase.json` has no Auth emulator entry. Result:
**pass**. No production data was touched.

## Results

| Data | After deleting A | Expected? |
|---|---|---|
| Firebase Auth user A | Deleted | Yes |
| `users/A`, `pushInstallations`, `private/account` | Deleted | Yes |
| A's posts (`userID` and legacy `userId`) and every comment on them, including B's | Deleted | Yes (the post is gone) |
| `followers/A` and its subcollection | Deleted | Yes |
| Storage `users/A/`, `post_images/A/`, `post_videos/A/`, `post_video_thumbs/A/` | Deleted | Yes |
| Review A wrote | Text and reviewer id removed, stars kept for the helper's average | Yes |
| Chat and messages between A and B (both directions), chat media | Kept | Yes, documented: stays with the other person |
| `callInvites` | Kept | Documented; retention proposal pending |
| Reports | Kept | Documented (safety) |
| Consultations, `paymentOperations` | Kept | Documented (financial records) |
| A's comments on others' posts | Deleted; when someone replied under one, it becomes an empty anonymous placeholder so their replies survive | Yes (fixed) |
| A's replies | Deleted | Yes (fixed) |
| Reviews about A (A as helper) | Deleted: their only purpose was A's profile; no legal need to keep them | Yes (fixed) |
| A's name on call records | Removed (`fromName` / `toName`); the records follow the retention policy | Yes (fixed) |
| A in other people's followers/following and post likes | Removed | Yes (fixed) |
| Connections with A (all three schemas) | Deleted | Yes (fixed) |
| Everything of B (Auth, profile, subcollections, posts, Storage) | Untouched | Yes |
| Running deletion again | Harmless | Yes |

## Gaps Closed (2026-11-01)

`scrubReferences` in `account/delete_account.js` handles everything marked
"fixed" above. It is safe to rerun.
- **Failures:** if a cleanup step fails (for example the collection-group
  index is missing), the account deletion still completes; the error is
  logged as `account_delete_scrub_failed`.
- **Index:** the comment and reply queries need the collection-group index
  overrides in `firestore.indexes.json`. Deploy them **before** the
  functions.
- **Tests:** `delete_account_e2e.test.js` covers three users (A deleted, B
  and C bystanders) and every row above. `delete_account.test.js` covers
  the failure-tolerance path.

## Store Requirements

- **Apple 5.1.1(v): in-app deletion.** Profile > Settings > Delete account
  (`SettingsScreen`, calls the `deleteAccount` callable). It falls back to
  `deletionRequestedAt` plus the daily job, and to the restricted (18+)
  screen. It works once `deleteAccount` is deployed. Until then, the
  fallback records a request that only the (also undeployed) daily job
  processes.
- **Google Play: web deletion link.** `public/delete-account.html`
  explains in-app deletion and email deletion. **Blocker:** it points to
  `support@helperly.app`, which is a placeholder. It needs a real,
  monitored address, and hosting must be deployed.
