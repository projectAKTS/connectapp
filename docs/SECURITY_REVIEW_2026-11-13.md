# Security Review, 2026-11-13

A read-only review of `firestore.rules`, `storage.rules` and
`connect_functions` found holes that let one signed-in user reach another
user's data. This file records what was fixed on branch
`fix/security-rules`, what is still open, and how to ship it.

## Fixed On This Branch

| Hole | Fix | Test |
|---|---|---|
| A stranger could add themselves to any chat (`chats` update accepted the *incoming* participant list) and then read its messages and media | Only people already in the chat may update it. A legacy chat without participant lists can be repaired only by a person whose uid is in the chat id | `firestore_rules_security.test.js` |
| A stranger could overwrite any connection | Same rule shape as chats | same |
| Replies could be written in someone else's name | `userID` must be the caller | same |
| Anyone could wipe or fake the likes on a post | A like adds or removes only the caller's own uid and moves the count by exactly one | same |
| Anyone could overwrite a post's old `reports` field | The field is no longer client-writable (the app reports through the private `reports` collection) | same |
| Any signed-in user could get an Agora token for another pair's call | `getAgoraRtcToken` refuses a `c_…` channel unless the caller's uid is one of the two in its name (`call_invites/channel_access.js`) | `channel_access.test.js` |

The app needs no change: the rules tests replay what the chat screen, the
missed-call note, `InteractionService`, `ConnectionService` and the post
card write.

## Still Open (Need A Decision Or More Work)

- **Fake reviews.** A user can create their own consultation with any
  helper and review it at once. Rules alone cannot tell a real session
  from an invented one. Options: accept reviews only after the server marks
  a consultation completed, or turn reviews off until paid sessions exist.
- **Refund against an invented payment** (`cancelConsultation`): harmless
  while payments are off; fix before turning them on.
- Two accounts of one person can hide any post (report threshold).
- `users/{uid}` is readable by every signed-in user, `blockedUids` included.
  Fixing it means moving `blockedUids` to an owner-only document and
  changing the app.
- Call invites: either side can still set any `status` (for example the
  caller can mark a call accepted). Who may set which status is not
  limited yet.

## Fixed On Branch `fix/rules-medium` (2026-11-13)

| Hole | Fix | Test |
|---|---|---|
| A chat with one or three people skipped the block, minor and first-contact checks | A chat names exactly two different people (both lists the same pair); an update cannot add, drop or swap anyone; a message needs exactly one other person | `firestore_rules_security_medium.test.js` |
| A post could be created with server-only flags or fake counts (`isBoosted`, `isFeatured`, `imageSafety`, `sensitive`, `hiddenBy*`, `likes`, `likedBy`, `commentsCount`, …) | A new post starts with zero counts and no boost; the safety and report flags cannot be set by a client | same |
| Either side of a call invite could change any field, including who calls whom | `fromUid`, `toUid`, `fromName`, `toName`, `channel` and `createdAt` cannot change after the invite is made | same |

Rules tests 51/51; node tests 87/87; the 221 working-tree guards pass in a
clean tree; staging smoke 33/33. On staging, between the two Android
emulators: a chat message sent, an audio call (Emu Callee to Amira)
connected on both, a second call declined, and the missed-call note
written; neither device logged a permission error.

## Shipped

- **Production, 2026-11-13:** `firestore.rules` deployed by the founder
  from this branch. The live ruleset is identical to the branch file
  (checked read-only).
- **Staging, 2026-11-13:** rules and `getAgoraRtcToken`.
  `tool/staging_smoke.mjs` now also checks the call token (both people get
  one, a third person gets `PERMISSION_DENIED`): 33/33. Before the deploy
  the third-person check failed, which showed the hole live. An audio call
  between the two Android emulators (Emu Callee to Amira) rang, was
  accepted and showed "Connected" on both; the function log shows a token
  issued to each for the app's own channel name.

- **Production, 2026-11-13:** `getAgoraRtcToken` deployed by the founder
  from the main checkout (updated 03:37 UTC on 2026-11-14). No errors or
  refusals in its log afterwards (checked read-only).

## Still To Ship

The `fix/rules-medium` rules to production, by the founder, from the main
checkout after the branch is merged there:

    cd ~/connectapp && firebase deploy --only firestore:rules --project connectapp-278b4

Then check read-only that the live ruleset equals `firestore.rules`. The
app needs no change.
