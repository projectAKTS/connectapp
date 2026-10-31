# Helper Discovery Handoff (MVP-4b)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `b4c19d0`
IMPLEMENTATION_SHAS:
- `d812cc6`: Find a helper lists real helpers (`role` helper/both, plus
  legacy `isHelper`) with no unfiltered fallback; cards show expertise;
  topics match the expertise that answers them (`HelpTopics.helperFitsTopic`)
- `4c62329`: initials avatars for helpers without a photo; the tag says
  "Available" instead of "Available now" (it reflects a stated window, not
  live presence)
ENDING_SHA: `SELF`

## Why

`isHelper` is never written by the app, so the old query was always empty
and the screen fell back to the first 400 users of any kind. Seekers and
test accounts appeared as helpers.

## Validation

- `help_topics_test`: 3/3 (every topic is answerable by some expertise).
- `flutter analyze` on the touched files: clean.
- Emulator A: Find a helper shows only helper-role users, with expertise
  chips and initials.

## Not Deployed

Client-only change; ships with the next app build.
