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

## Shipping

1. Staging: `firebase deploy --only firestore:rules,functions:getAgoraRtcToken --project helperly-call-v2-dev --force`, then `node tool/staging_smoke.mjs` and a call between the two emulators.
2. Production (the founder runs it, after the staging check):
   `firebase deploy --only firestore:rules --project connectapp-278b4` and
   `firebase deploy --only functions:getAgoraRtcToken --project connectapp-278b4`.
   The first is not one of the three allowed commands as written (that one
   also deploys storage and hosting, and hosting is held).
