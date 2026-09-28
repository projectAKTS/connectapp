# Active Revision — Exact CallKit End Retry Semantics

Branch: `call-v2`

Starting SHA: `1693b63a832df5bc58282ba86f55bc9ba8b984e9`

## Goal

Restore the existing native watchdog's legitimate second exact-end attempt
without weakening exact per-call CallKit ownership.

`CallV2ExactCallkitEndRequester` may coalesce concurrent requests for the same
UUID only while one native transaction request is in flight. A later explicit
request for that UUID must submit a new `CXEndCallAction`, because successful
`CXCallController.request` completion does not prove `CXCallObserver` no longer
contains the call.

## Authorized Scope

1. Remove permanent successful-request suppression from
   `CallV2ExactCallkitEndRequester`.
2. Keep one in-flight request per exact UUID and fan its result out to concurrent
   waiters.
3. Remove in-flight ownership when the native request callback completes,
   regardless of success or failure.
4. Permit a later exact request for the same UUID to submit another native
   transaction.
5. Preserve exact UUID targeting and isolation from plugin-global PushKit state.
6. Add native RunnerTests for concurrent coalescing, later retry, exact
   isolation, invalid UUID rejection, and real watchdog escalation composition.

## Required Watchdog Proof

Through the real watchdog/requester composition:

- exact A remains active after the first accepted native end request;
- observer verification causes a second exact A request;
- A becomes inactive after the second request;
- final verification emits `nativeCallEnded`, `nativeCallEndVerified`, and one
  `exactEndVerified` callback;
- `native_end_unverified` is absent; and
- no request targets B.

## Preserve Accepted Behavior

Do not change exact UUID propagation, screen exact-ID preference, normal screen
removal of `endAllCalls()`, Helperly-owned `CXEndCallAction`, accepted incoming
`setCallConnected()` suppression, delayed-A ownership guards, exact-scoped
stored recovery clearing, stale-B protection, or provable orphan cleanup.

## Authorized Files

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`
- agent-loop handoff/state metadata

No Dart production change is authorized unless strictly required to compile,
which is not expected.

## Strict Non-Goals

Do not change Firestore authority or accepted transactions, NotificationService
recovery architecture, Navigator, PushKit presentation, watchdog duration or
verification delay, Agora, RTC tokens, backend, dependencies, Flutter, plugin
source, deployment, or TestFlight configuration.

## Validation

Run and pass:

```bash
xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
  -only-testing:RunnerTests
flutter analyze
flutter test test/call_v2/real_flow/call_v2_exact_callkit_ownership_test.dart --no-pub
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

Verify dependency files remain unchanged. Do not deploy, build TestFlight, or
claim physical success.
