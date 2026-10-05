# Post-Call Redial Gate Ordering Correction Handoff

STATUS: `ready_for_review`

STARTING_SHA: `2d4882af94e90dc8dfbcc5fbc402a98e6bb65b07`
IMPLEMENTATION_SHA: `edc5c57d0516b06e8f4814932197f0822f8094ac`
ENDING_SHA: `SELF`

## Root Cause Being Fixed

Terminal route cleanup kept the lifecycle arbiter in teardown while awaiting
exact Call A native CallKit end/verification and scoped persisted accepted-
recovery clearing. By that point the old route, listener, timers, session, and
UI ownership could already be detached, so those exact-A-only waits
unnecessarily serialized a new outgoing reservation.

This corrects the source-proven ordering defect. It does not claim that this
ordering was the sole cause of the previously observed physical 5-10 second
redial window.

## Ordering

Old:

`route closed -> local detach -> await exact A native/persisted cleanup -> arbiter release/claim`

New:

`route closed -> detach listener/timers/session/UI -> invalidate matching local A recovery request -> verify A generation -> start immutable exact-A cleanup -> atomically claim pending incoming or release to idle -> await exact-A cleanup completion`

The exact arbiter release point is
`CallV2CallLifecycleArbiter.completeTeardownAndClaimPending()` after all local
Call A ownership is detached and generation-verified. A pending incoming invite
is claimed by that same transition, so an outgoing reservation cannot steal it.

## Deferred Exact Cleanup

Only these operations may remain incomplete after arbiter release:

- exact native CallKit end/verification for detached Call A;
- scoped persisted accepted-recovery clearing for detached Call A.

Both receive immutable invite/CallKit identity captured before release. The
native end path filters every retry/verification by that exact CallKit ID. The
stored recovery clearer invalidates a matching Dart coordinator before its
platform await and sends the same scoped identity to native. Neither completion
reads `_current`, changes lifecycle generation, releases the arbiter, or resets
Call B.

## Files Changed

- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_exact_callkit_ownership_test.dart`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`

The pre-existing untracked `docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` remains
untouched.

## New Regression Tests

- `blocked exact A end releases lifecycle and late completion preserves B`
- `blocked exact A stored recovery clear does not block or clear B`
- `pending incoming is claimed before deferred A cleanup settles`
- `normal teardown performs exact cleanup and reaches idle`

Existing tests also retain coverage for stale A cleanup against B, exact UUID
ownership, notification ownership, rapid lifecycle generations, repeated-call
cleanup, and accepted pending handoff.

## Validation

- `flutter analyze`: passed, no issues.
- Exact CallKit ownership: passed, 14 tests.
- Notification ownership: passed, 38 tests.
- Rapid lifecycle manager: passed, 65 tests.
- Repeated-call lifecycle: passed, 50 tests.
- Foreground recovery: passed, 3 tests.
- Full `test/call_v2`: passed, 2313 tests from the final tracked-clean tree.
- iOS `RunnerTests`: passed, 21 tests.
- `git diff --check`: passed.
- `pubspec.yaml` / `pubspec.lock`: unchanged.

The first unsigned simulator attempt could not launch because dyld rejected the
unsigned embedded `aosl.framework`. The required normally signed simulator run
then passed all RunnerTests; no project setting or source was changed.

## Adversarial Review

For `A route close -> arbiter release -> B reserve -> late A completion`, late
A work retains only immutable A identifiers and cannot end, clear, release, or
mutate B. Tests hold each deferred future open until B owns a newer generation,
then complete A and verify B remains current, connected, and route-active.

For `A route close -> pending incoming B -> outgoing race`, the arbiter claims B
atomically instead of entering idle. The focused regression verifies the
pending slot is transferred and a competing outgoing reservation is rejected.

## Scope

No Firestore terminal/acceptance behavior, PushKit, native UUID propagation,
CallKit watchdog timing, Navigator architecture, Agora engine gate, backend,
dependency, Flutter, or package version changed. No backend deployment or
TestFlight build was performed.

## Next

After review, perform one physical immediate-redial validation using the same
two-device procedure. Do not claim the historical timing issue fixed until that
physical result is captured.
