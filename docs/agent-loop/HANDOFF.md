# Review Handoff

Phase: `physical_callkit_native_safety_diagnostics`
Status: `ready_for_review`
Starting checkpoint: `ad2a5149a44bc053ee54ca3bfd93b2327765c36c`
Implementation commit: `899578f4162e1ef3196b1fed708db4682b239ba9`

## Diagnostic Ledger

- Adds a process-local ordered ledger retaining at most the previous and current
  native-accepted call timelines.
- Each exported checkpoint contains only a controlled stage, monotonic sequence,
  and elapsed milliseconds. Summary state contains only booleans, counters, and
  a controlled blocker code.
- Native and Flutter entries merge through a private ordinal while exact native
  ownership values remain outside every safe snapshot and copied report.
- An explicitly developer-gated overlay provides refresh, screenshot, and copy
  access to compact `CALL 1`, `CALL 2`, and `SAFE STATE` output. It adds no route
  and is absent unless the existing real-flow developer build flag is enabled.

## Native Watchdog

- Native CallKit Accept starts one exact-UUID 20-second watchdog; duplicate
  Accept callbacks for the same UUID coalesce.
- The existing native acceptance UUID is retained privately and used for the
  exact end request. The watchdog does not reconstruct ownership from invite or
  channel data.
- A matching terminal event or a matching Flutter `callkitRouteOwned` ACK
  cancels the watchdog. Late ACKs and stale timeouts have no owner and are
  ignored.
- Timeout removes watchdog ownership first, requests one exact native end,
  verifies active calls after a bounded delay, and permits one exact-ID retry.
  Safe state records `native_end_unverified` if verification still fails.

## Flutter Route ACK

- Flutter sends the exact native ownership ACK only after the existing
  Navigator push has succeeded and the accepted-native watch still owns the
  same session.
- No ACK is sent for unavailable Navigator, pending teardown, accepted
  Firestore state, route-busy, or failed route-push outcomes.
- ACK dispatch is best-effort and non-blocking, so diagnostics cannot roll back
  or stall an otherwise successful route.
- Existing routing, accepted continuation, RTC cleanup, Agora/token behavior,
  Firestore protocol, and PushKit/CallKit presentation ownership are unchanged.

## Tests

- Dart ledger tests cover ordered bounded retention, native merge, safe output,
  exact private ACK transport, unavailable-Navigator behavior, and late ACK.
- Lifecycle ownership tests prove one ACK only after actual route open and no
  ACK while Navigator is unavailable.
- Signed iOS simulator tests cover one watchdog, duplicate Accept coalescing,
  route ACK cancellation, exact timeout/end verification, terminal
  cancellation, sequential calls, and safe native output.
- Production UI isolation remains passing after locating the developer view in
  the diagnostics boundary rather than the production UI module.

## Validation

- `flutter analyze`: passed, no issues.
- Focused diagnostic, UI, and ownership tests: passed, 37 tests.
- `flutter test test/call_v2 --no-pub`: passed, 2,282 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`:
  passed, 3 tests.
- `xcodebuild ... -only-testing:RunnerTests ... test`: passed, 6 tests.
- `git diff --check`: passed.

## Safety

No backend/functions, Firebase configuration, Firestore rules, Agora engine
cleanup, token/App ID behavior, dependency files, or deployment configuration
changed. No backend/Firebase deployment or TestFlight build was performed.

## Physical Follow-up

Install the pushed branch tip on both physical iPhones and reproduce Call 1,
then background Call 2 Accept. Open the developer diagnostic overlay after the
result, copy the two-call report, and verify that an unopened route causes the
exact native CallKit session to end within 20 seconds without force quit.
