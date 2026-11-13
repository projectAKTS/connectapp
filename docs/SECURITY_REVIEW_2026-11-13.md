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
- Chat safety checks apply only to two-person chats; a chat created with
  one or three participants skips them.
- Two accounts of one person can hide any post (report threshold).
- A post can be created with server-only flags (`isBoosted`,
  `imageSafety`, `hiddenBySafety`).
- Call invites: either party can change any field.
- `users/{uid}` is readable by every signed-in user, `blockedUids` included.

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

## Still To Ship

`getAgoraRtcToken` to production, by the founder, from the main checkout
(it has `connect_functions/.env.connectapp-278b4`; a worktree does not),
after this branch is merged there:

    firebase deploy --only functions:getAgoraRtcToken --project connectapp-278b4

Then one call on the iPhone (unlocked, locked, killed).
