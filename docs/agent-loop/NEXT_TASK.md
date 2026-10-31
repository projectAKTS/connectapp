# Active Task - MVP Launch Blockers, Client Side (MVP-1)

Branch: `call-v2`

Starting SHA: `fd7ad91`

## Context

The user is launching Helperly as an MVP. Claude audited the app on
2026-10-31; see the memory note `mvp-launch-audit`. The user shared the
product docs (vision deck, roadmap, pricing, gamification, palette) as
direction rather than fixed rules, and asked Claude to start fixing.

Product decision (Claude, delegated): keep the newcomers-to-Canada niche,
framed as **settlement experience, not legal advice**.
- Paid help covers jobs and career, housing, student life, daily life,
  language practice, and family.
- Immigration, PR and refugee topics: experience sharing only, with a "not
  legal advice" notice. Paid immigration advice waits for verified RCICs.
- Mental health support leaves the MVP. Crisis resources are linked
  instead.

## Scope (client only, no deploy)

1. One shared topic and expertise list (`lib/models/help_topics.dart`), used
   by onboarding, edit profile, Find a helper and Search. Existing stored
   values stay valid.
2. MVP feature flags (`lib/config/mvp_features.dart`) hide Premium, post
   boost, the test plan, streak and XP.
3. Remove Firebase Dynamic Links; the service has been shut down.
4. Report and block:
   - "Report" on any post, and "Report user" / "Block user" on profiles
     and in chat;
   - reports go to `/reports` (create is already allowed);
   - blocked uids are stored on the blocker's own user doc and filtered
     from the feed, Find a helper and chat.
5. Settings screen from Profile:
   - Help & safety, including crisis lines (988, 911);
   - Terms and Privacy (in-app drafts that need legal review);
   - Delete account, which goes live after MVP-2;
   - Log out.
6. Trust notices:
   - Find a helper and consultation booking carry a "helpers share personal
     experience; not legal, immigration or medical advice" notice;
   - signup links to Terms and Privacy.
7. Visual fixes:
   - cards use #FBFAF8 (the user's palette);
   - the search fields no longer clip on the right;
   - the duplicate post timestamp is removed;
   - the literal "No bio available yet." is no longer stored or shown;
   - Find a helper hides profiles without a name.

## Non-goals

- No rules or functions changes (MVP-2), no deploy, no TestFlight.
- No call-path changes.

## Validation

- `flutter analyze` is clean; the full suite shows no new failures; new
  widget tests cover the flags, report and block, and topics.
- The emulator screens are checked visually.
