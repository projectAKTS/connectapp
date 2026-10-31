# MVP Server Hardening Handoff (MVP-2)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `080bd1f`
AUTHORIZATION_SHA: `cd9f8d5`
IMPLEMENTATION_SHAS:
- `185a201`: price consultations on the server
- `9d48b3f`: Firestore rules (protected user fields, private reports,
  participant-only consultations, blocked chat sends)
- `c853dfc`: Storage rules (chat participants, per-owner post media,
  limits) and the client upload paths
- `99d2d80`: `deleteAccount` and `processAccountDeletionRequests`
- `7234e31`: email out of the public user doc, plus the migration script
- `f95cdd6`: calls from blocked people never reach the callee
- `0fd1e49`: legal site on hosting and real Stripe return URLs
ENDING_SHA: `SELF`

**Nothing is deployed.** The deploy batch, its order and the rollback are in
`docs/DEPLOY_MVP.md`.

## Validation

- Node tests: `call_invites` + `consultations` + `account` 37/37 (new:
  pricing 5, deletion 4, blocked caller 2).
- Firestore rules emulator: MVP 5/5; the Call V2 rules are unchanged at
  10/10.
- Storage rules emulator, with Firestore: 5/5.
- `flutter analyze lib`: clean.
- Full `flutter test`: +2456 -6. The 6 failures are the same known set as
  MVP-1: 4 working-tree guards and 2 test-mode-only integration tests.

## Notes

- Storage rules must go out together with or after the new app build,
  because older builds upload post media to the flat paths, which become
  read-only.
- Premium perks in booking stay off (`MvpFeatures.premium`) until premium
  has a server-side entitlement.
- Account deletion keeps payment records and messages already sent to
  others, as the privacy text says.
