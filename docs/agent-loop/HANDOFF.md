# Store Compliance And Research Handoff (MVP-4)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `2e3e424`
IMPLEMENTATION_SHAS:
- `d763923`: objectionable-word filter for posts, comments and chat
  (App Store 1.2); the old comment flow no longer stores the email as the
  public name
- `bb5174a`: `delete-account.html` web page for Google Play's Data safety
  deletion link
- `c555209`: `docs/research/MVP_LANSMAN_ARASTIRMA.md`, the launch rules
  and risks with sources (Turkish)
ENDING_SHA: `SELF`

## Why

Checking the official App Store guideline text showed that 1.2 also
requires a filtering method, besides report and block (done in MVP-1).
Google Play requires a web path for account deletion.

## Validation

- `content_filter_test`: 4/4, including innocent words: French "en
  retard", the names Amina and Dick, "assistant", Scunthorpe.
- `flutter analyze lib`: clean.
- The site builder regenerates all pages, including `delete-account.html`.

## Decisions Waiting For The User

These are listed in the research doc: support email, launch city (French),
paid sessions at launch versus free first (helper payouts are not wired in
the booking charge), pricing differences across the docs and the free
1-minute call, test-data cleanup, and the lawyer review.
