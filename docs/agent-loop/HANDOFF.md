# Review Handoff

Phase: `physical_diagnostics_access_correction`
Status: `ready_for_review`
Starting checkpoint: `25911fb55411a3766ce5d0cf369feb7b51d21fd7`
Implementation commit: `3b810f5d74c7b6f85241283cfe2f0bea69c71317`

## Diagnostics Access

- The existing `MaterialApp.builder` overlay now receives the app's existing
  `navigatorKey` and obtains a context from that Navigator's overlay before
  opening the diagnostics bottom sheet. It adds no Navigator or route.
- The builder's nullable child is handled explicitly with an inert non-null
  fallback.
- The diagnostics button has no dependency on an ancestor Navigator or Overlay,
  so it remains operable from its actual builder position above the Navigator.
- The existing Call V2 real-flow developer flag remains the sole enablement gate.

## Native Timeline Freshness

- Opening the view automatically refreshes and merges the native safe timeline
  before rendering the report.
- Copy performs another native refresh and copies that same latest merged report.
- Reports remain limited to controlled stages, timestamps, counters, booleans,
  and controlled blocker state; private ownership values are not rendered or
  copied.

## Tests

- The focused ledger and widget suite passed 8 tests.
- The integration-shaped widget test installs the enabled overlay through
  `MaterialApp.builder`, preserves its real Navigator child, taps
  `call-v2-diagnostics-open`, and proves the diagnostics sheet opens without a
  Navigator/context error.
- The same test proves a native-only checkpoint appears on initial open and a
  newly supplied native-only checkpoint is included by Copy after a fresh bridge
  load. The disabled-overlay isolation test remains passing.

## Validation

- `flutter analyze`: passed, no issues.
- Focused physical diagnostics ledger/widget tests: passed, 8 tests.
- `flutter test test/call_v2 --no-pub`: passed, 2,283 tests.
- `flutter test test/notification_foreground_recovery_test.dart --no-pub`:
  passed, 3 tests.
- Signed iOS simulator `RunnerTests`: passed, 6 tests.
- `git diff --check`: passed.

## Safety

Routing, accepted continuation, lifecycle ownership, Agora/RTC behavior, token
handling, Firebase/backend, Firestore protocol/rules, PushKit/CallKit
presentation, and native watchdog termination semantics were not changed. No
deployment or TestFlight build was performed. This correction does not claim
the physical repeat-call issue is fixed; it makes the next physical diagnostic
report reliably accessible and current.

## Physical Follow-up

Install the reviewed branch tip on both physical iPhones, reproduce the failed
second-call sequence, then immediately open and copy the refreshed Call V2
diagnostic report for source-level triage.
