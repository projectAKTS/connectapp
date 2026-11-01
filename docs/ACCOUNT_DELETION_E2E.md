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
| Review A wrote | Text emptied, stars kept, `reviewerDeleted: true` | Yes (documented) |
| Chat and messages between A and B (both directions), chat media | Kept | Yes, documented: stays with the other person |
| `callInvites` | Kept | Documented; retention proposal pending |
| Reports | Kept | Documented (safety) |
| Consultations, `paymentOperations` | Kept | Documented (financial records) |
| **A's comment on B's post** | **Kept, with A's display name** | **Gap** |
| **Reviews about A (A as helper)** | **Kept** | **Gap** (proposal: follow the helper's account) |
| Everything of B (Auth, profile, subcollections, posts, Storage) | Untouched | Yes |
| Running deletion again | Harmless | Yes |

## Gaps And Proposed Fixes (Not Implemented)

1. **A's comments on other people's posts remain, with `userName`.**
   - Fix: also delete `collectionGroup('comments')` and `replies` where
     `userID == A`.
   - This needs a collection-group index exemption on `userID` (a deploy
     step), plus a test.
   - Size: small. Recommended before public launch; acceptable for a small
     beta if disclosed.
2. **Reviews about a deleted helper remain.** Fix: delete
   `reviews where helperUid == A` (a single-field query, no new index).
   Small.
3. Not in the code path: likes and "helpful" marks A gave (`likedBy`
   arrays, `helpfuls`). Low sensitivity; it can join fix 1.

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
