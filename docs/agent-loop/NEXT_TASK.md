# Active Task - Search Results Fixes (MVP-6)

Branch: `call-v2`

Starting SHA: `3b7e7ea`

Search read profile photos from `photoURL`/`avatar`, but the app stores
them as `profilePicture`, so search never showed a photo. It also listed
you, people you blocked and accounts being deleted, and a slow, older query
could overwrite newer results.

## Scope

- People results: photo from `profilePicture` (older fields as fallback),
  name with a `fullName` fallback, a "Helper" label for helper roles; skip
  yourself, blocked people and accounts with `deletionRequestedAt`.
- Post results: skip blocked authors.
- Only the newest search writes results.
- A shared `InitialsAvatar` widget for Search and Find a helper.
- Search history stays off: it would be written to the public user doc.

## Allowed Files

- `lib/screens/search/search_screen.dart`
- `lib/screens/search/find_helper_screen.dart`
- `lib/widgets/initials_avatar.dart`
- `test/mvp/initials_avatar_test.dart`
- `docs/agent-loop/**`

## Validation

- `flutter test test/mvp/`, and `flutter analyze` on the touched files.
- Emulator A: search shows initials and the Helper label, and never shows
  yourself.

## Safety

Client only. No deploys.
