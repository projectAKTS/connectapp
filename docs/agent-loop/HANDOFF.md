# Search Results Handoff (MVP-6)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `3b7e7ea`
IMPLEMENTATION_SHAS:
- `d4fd8ef`: search reads `profilePicture`, labels helpers, skips yourself,
  blocked people and deleted accounts, and ignores late results from older
  queries; a shared `InitialsAvatar` for Search and Find a helper
ENDING_SHA: `SELF`

## Why

The app stores photos as `profilePicture`, but search read `photoURL` and
`avatar`, so it never showed a photo. It also listed the signed-in user and
blocked people.

## Validation

- `test/mvp`: 16/16, including `initials_avatar_test` (2).
- `flutter analyze` on the touched files: clean.
- Emulator A (debug APK): "y" shows "Yakup Akturk 2026 · Helper" with
  "YA". Posts show B/V initials. "bar" no longer lists the signed-in user.

## Kept As Is

Search history stays off. Turning it on would write it to the public user
doc.

## Not Deployed

Client only; ships with the next app build.
