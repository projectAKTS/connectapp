# MVP Launch Blockers Handoff, Client Side (MVP-1)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `fd7ad91`
AUTHORIZATION_SHA: `aa5e3b8`
IMPLEMENTATION_SHAS:
- `f10f71d`: one settlement-focused topic list
- `c2a1c2e`: hide Premium and streak/XP behind MVP flags
- `f5dbfe8`: drop Firebase Dynamic Links usage
- `331dfa9`: list only real helper profiles; no stored placeholder bio
- `061ff48`: report and block for posts, profiles and chats
- `71aa58b`: settings with safety, legal texts and account deletion
- `ba7dc8c`: palette cards, unclipped search pills, single post time
ENDING_SHA: `SELF`

## Done (client only, nothing deployed)

- **Topics:** `HelpTopics` is the single list. Immigration is "Immigration
  experience" (experience sharing, not legal advice); mental health support
  is removed. Existing stored values still match.
- **Flags:** `MvpFeatures.premium` and `MvpFeatures.gamificationStats` are
  false, so the Premium row and `/premium` route are hidden and the profile
  shows only Helpful. Boost was already unreachable.
- **Dynamic Links:** the code is removed. The package stays in `pubspec`
  until the next dependency change (with Crashlytics).
- **Report and block:** `SafetyService` files reports to `/reports` and
  keeps `blockedUids` on the blocker's own user doc.
  - Menus: others' posts ("..."), other profiles and chats.
  - Blocked people are filtered from the feed, Find a helper and the chat
    list, and a blocked chat cannot send.
- **Settings:** a gear on your own profile opens Help & safety (911, 988,
  Kids Help Phone), Community guidelines, Terms, Privacy, Log out and Delete
  account.
  - Delete account writes `deletionRequestedAt` and signs out. The actual
    deletion is MVP-2.
  - Signup links to Terms and Privacy.
- **Notices:** an advice notice on Find a helper and on booking.
- **Helper list:** skips yourself, nameless profiles, deletion requests and
  blocked people. New signups no longer store "No bio available yet."
- **Visual:** cards are #FBFAF8, the search pills no longer clip, and the
  post time is shown once.

## Validation

- `safety_service_test`: 4/4.
- Full `flutter test`: +2456 -6.
  - 4 failures are the known Phase 7BG-7BJ working-tree guards.
  - 2 are `call_message_stability_test`, an integration test that needs
    `HELPERLY_TEST_MODE`.
  - Neither group is related to this change.
- `flutter analyze lib`: clean.
- Emulator, `app-release-mvp1.apk`: Find a helper (notice, unclipped
  search, nameless profile gone), Profile (Helpful only, no Premium, gear)
  and Settings were checked visually.

## Needs The User

- A real support email, replacing the placeholder `support@helperly.app`
  in `LegalTexts`.
- Legal review of the Terms and Privacy drafts, the immigration rule
  (RCIC), and French for Quebec.
- Approval to delete the test accounts and posts in production
  ("testttt", "lalslslkk", ...).
- MVP-2 (next) needs a rules and functions deploy by the user:
  - Storage: chat attachments for participants only, and per-uid post media
    paths with size and type limits.
  - Firestore: consultations for participants only, reports not readable,
    protected user fields (`isVerified`, badges, counters, premium, Stripe
    ids), and email moved out of the public user doc.
  - A `deleteAccount` callable.
  - Blocked users are rejected for calls and messages server-side.
