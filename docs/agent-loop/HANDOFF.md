# Session Ratings Handoff (MVP-5)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `0b604be`
IMPLEMENTATION_SHAS:
- `60e2478`: `reviews/{consultationId}` rules; the `onReviewCreated`
  function keeps the helper's `rating` / `ratingCount` / `ratingSum`;
  `ratingSum` is a protected field; account deletion clears the text of
  reviews the user wrote
- `c4fb999`: "Rate this session" in My consultations, the rating sheet,
  the rating and reviews on profiles, the privacy text, and DEPLOY_MVP
ENDING_SHA: `SELF`

## Why

Find a helper sorted by and showed `rating`, but nothing wrote it. Ratings
from real, booked sessions are the main trust signal before a seeker books
a stranger.

## Design

- One review per consultation: the doc id is the consultation id, so a
  second write is an update, which rules deny.
- Only the person who booked can rate (`consultations.userId`), after the
  start time, not for cancelled sessions, and not themselves.
- The average is computed by the server in a transaction. `countedAt` stops
  a retried event from counting a review twice.
- Reviewers are anonymous on profiles ("Booked session" and the date).
  Stars-only reviews count in the average but are not listed.
- No composite index is needed: profile reviews are sorted on the client
  (up to 50).

## Validation

- Node: 42/42 (reviews 4, account 5, consultations, call invites).
- Rules emulator: 19/19 (MVP 5, reviews 4, Call V2 10).
- Flutter: `test/mvp` 14/14, including the sheet widget test (stars are
  required and the comment goes through the filter). `flutter analyze` is
  clean on the touched files.
- Full suite: 2456 passed, 16 failed. The failures are only the known
  working-tree guards.
- Not checked on a device: production rules do not allow `reviews` until
  the deploy.

## Not Deployed

`onReviewCreated` and the rules are in the user's batch
(`docs/DEPLOY_MVP.md`).
