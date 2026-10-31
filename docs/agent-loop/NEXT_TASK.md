# Active Task - Session Ratings And Reviews (MVP-5)

Branch: `call-v2`

Starting SHA: `0b604be`

Trust is what makes a seeker book a stranger. Find a helper already sorts
and shows `rating`, but nothing ever wrote it, so every helper showed no
rating.

## Scope

- `reviews/{consultationId}`: one review per consultation, written by the
  person who booked it (`consultations.userId`), after its start time and
  unless it was cancelled. Whole stars 1-5, optional text up to 500
  characters, no extra fields, no edits or deletes by clients.
- `onReviewCreated` (new function): updates the helper's `rating`,
  `ratingCount` and `ratingSum` in a transaction, counting each review once
  (`countedAt`). `ratingSum` joins the protected user fields.
- Account deletion clears the text of reviews the user wrote; stars stay in
  the helper's average.
- App:
  - My consultations: "Rate this session" on past sessions the user booked;
    "You rated this session" afterwards;
  - a rating sheet with stars and an optional comment, through the content
    filter;
  - profiles show the average and count, and the five newest written
    reviews, without reviewer names.
- Privacy text and site: reviews are shown without the reviewer's name.
- `docs/DEPLOY_MVP.md`: add the function and the rules note.

## Allowed Files

- `firestore.rules`
- `connect_functions/index.js`, `connect_functions/reviews/**`,
  `connect_functions/account/delete_account.js`
- `connect_functions/test/reviews/**`, `connect_functions/test/account/**`,
  `connect_functions/test/mvp/firestore_rules_reviews.test.js`
- `lib/services/review_service.dart`
- `lib/screens/consultation/my_consultation_screen.dart`
- `lib/screens/profile/profile_screen.dart`
- `lib/config/legal_texts.dart`, `public/**`
- `test/mvp/review_service_test.dart`
- `docs/DEPLOY_MVP.md`, `docs/agent-loop/**`

## Validation

- `node --test` for reviews, account, consultations and call invites.
- Rules emulator: MVP, reviews and Call V2 suites.
- `flutter test test/mvp/`, `flutter analyze` on the touched files, and the
  full Flutter suite (known failures only).

## Safety

No deploys. The function and rules go into the user's batch deploy.
