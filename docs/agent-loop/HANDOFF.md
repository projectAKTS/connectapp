# Review Handoff

Phase: `accepted_call_exact_identity`
Status: `ready_for_review`
Starting checkpoint: `71fd2070cd60affe15019b8db0730e36f1a4015c`
Implementation commit: `cb913aa8377c799225aa2d9d682b2018f9ecd2a9`
Ending SHA: `SELF`

## Root Cause

`NotificationService` treated matching invite IDs as a fallback even when both
accepted events carried different non-empty exact CallKit IDs. This allowed a
new physical Call B to be coalesced with Call A. The manager already applied
the intended rule at its recovery-request generation boundary, but downstream
accepted owners and the recent-event ledger still had invite-only comparisons.

## Exact Identity Rule

- Normalize non-empty exact CallKit IDs for comparison.
- If both exact IDs exist, equality means the same physical accepted call and
  inequality always means distinct calls.
- Consult invite identity only when at least one exact CallKit ID is absent.
- Never let matching invite identity override two different exact IDs.

## Fix

- Notification recovery ownership, pending/retry ownership, scoped clearing,
  and recent accepted-event matching now use the canonical rule.
- CallSessionManager recovery generations, pending accepted ownership, native
  route watches, routed sessions, and active-route duplicate checks use the
  same rule.
- Accepted sessions retain the actual native CallKit ID. Terminal marking and
  native end cleanup use that retained ID directly; fallback reconstruction is
  used only when no exact accepted ID exists.
- Terminal recovery already invalidated its exact generation and retry. No
  separate retry mechanism change was needed; tests prove a terminal A retry
  cannot mutate or survive into B.

## Regression Proof

- `same invite with different exact CallKit IDs is not coalesced`: matching
  invite plus UUID A/UUID B is distinct and the new call reaches ownership.
- `accept duplicate while recovery in flight is coalesced`: matching invite
  plus the same exact UUID coalesces and opens one route.
- `matching invite is fallback when one exact CallKit ID is absent`: preserves
  compatibility fallback only at the missing-exact-ID boundary.
- `delayed duplicate A completion cannot suppress distinct accepted B`: stale
  A completion cannot clear or suppress B when the invite is reused but the
  exact UUID changes.
- `terminal accepted retry releases its generation before next exact call`:
  terminal A retry settles, remains inert, and cannot survive into B.
- `different invite and exact IDs route across A B C without reconstruction`:
  three sequential calls route in one service instance and terminal cleanup
  uses each actual exact native ID.
- `routed accepted terminal cleanup uses the exact native CallKit ID`: proves
  the reconstructed fallback ID is not used when the accepted native ID exists.

## Validation

- `flutter analyze`: passed, no issues.
- NotificationService accepted ownership: passed, 36 tests.
- CallSessionManager lifecycle/identity: passed, 57 tests.
- `flutter test test/call_v2 --no-pub`: passed, 2,289 tests.
- Foreground recovery: passed, 3 tests.
- `git diff --check`: passed.
- The local Flutter resolver transiently rewrote five lockfile entries;
  `pubspec.lock` was restored and dependency files are unchanged.

## Files Changed

- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/real_flow/call_v2_notification_ownership_test.dart`

## Scope Check

No changes were made to Agora, PushKit presentation, AppDelegate/native code,
the native safety watchdog or its timeout, Navigator architecture, Firebase or
backend code, Firestore schema/rules, dependencies, or deployment settings.
Nothing was deployed and no TestFlight build was created. This handoff does not
claim the physical issue is fixed.
