# Review Handoff

STATUS: `ready_for_review`

STARTING_SHA: `1693b63a832df5bc58282ba86f55bc9ba8b984e9`
IMPLEMENTATION_SHA: `3eba03e82d6fdb6b3d42aa8fed4df2b037138612`
ENDING_SHA: `SELF`

## Root Review Blocker

`CallV2ExactCallkitEndRequester` permanently remembered every UUID whose
`CXCallController.request(CXEndCallAction)` callback succeeded. A later exact
request for that UUID returned success without submitting another native
transaction. That defeated the existing watchdog escalation when CallKit
accepted the first transaction but `CXCallObserver` still reported the exact
call active after the verification delay.

## Requester Semantics

Before:

- Requests for an exact UUID were coalesced while one transaction was in
  flight.
- A successful transaction permanently inserted the UUID into `completed`.
- Every later retry for that UUID became a no-op, even when the observer still
  showed the call active.

After:

- Requests for an exact UUID are coalesced only while the same native request
  is in flight.
- The in-flight waiter entry is removed when the native callback completes.
- A later explicit retry submits a new exact `CXEndCallAction`.
- Invalid UUIDs submit no transaction, and an A retry never targets B.

## Watchdog Escalation Proof

`testWatchdogEscalationSubmitsSecondExactEndAfterObserverStillActive` composes
the real `CallV2NativeRouteSafetyWatchdog` with the real
`CallV2ExactCallkitEndRequester`:

1. Exact A starts active alongside unrelated B.
2. The first exact A request reports success but intentionally leaves A active.
3. The watchdog's observer verification still sees A.
4. The watchdog submits a second native exact A request.
5. The second request removes A; B remains active and is never requested.
6. Final verification records `nativeCallEnded` once,
   `nativeCallEndVerified` once, and invokes `exactEndVerified` once.
7. `native_end_unverified` is not produced.

The test failed against the reviewed implementation before the requester fix
and passes afterward.

## Tests

- `testExactCallkitEndCoalescesConcurrentRequestsOnlyWhileInFlight`: two
  concurrent A callers share one in-flight transaction and both receive its
  result.
- `testExactCallkitEndAllowsLaterRetryAfterSuccessfulRequest`: a later A call
  submits a new native transaction after the first callback completed.
- `testExactCallkitEndRetryTargetsOnlySuppliedUuidDespiteNewerGlobalState`: both
  A attempts target A while unrelated B remains active.
- `testExactCallkitEndRejectsInvalidUuidWithoutNativeTransaction`: malformed
  identity returns false without requesting CallKit.
- `testWatchdogEscalationSubmitsSecondExactEndAfterObserverStillActive`: proves
  the full observer-driven two-request escalation and exact isolation.

All previously accepted exact UUID propagation, exact screen teardown,
duplicate Accept suppression, stale-B protection, and recovery ownership tests
remain passing.

## Validation Counts

- iOS RunnerTests: passed, 21 tests.
- `flutter analyze`: passed, no issues.
- Focused exact CallKit ownership: passed, 10 tests.
- Full Call V2: passed, 2309 tests.
- Foreground recovery: passed, 3 tests.
- `git diff --check`: passed.
- `pubspec.yaml` and `pubspec.lock`: unchanged.

The full suite's worktree-isolation tests inspect untracked files. The
pre-existing untracked `docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` was left
untouched, temporarily excluded through local `.git/info/exclude` for the
decisive suite run, and immediately unexcluded afterward.

## Files Changed

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`

## Scope Check

The correction only removes permanent success memory from the exact native end
requester and adds native regression coverage. Exact UUID targeting and
in-flight coalescing remain intact. No Firestore authority, accepted recovery,
Navigator, PushKit presentation, watchdog timing, Agora/RTC/token behavior,
backend, dependency, Flutter, or plugin source changed. No deployment,
Firebase operation, or TestFlight build was performed.

Physical testing is still required. This handoff makes no physical-fix claim.

## Next

Install a build containing `3eba03e82d6fdb6b3d42aa8fed4df2b037138612`
on both physical iPhones and repeat the exact Call A end followed by immediate
Call B acceptance scenario.
