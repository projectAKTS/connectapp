# Active Task - Physical Diagnostics Access Correction

Branch: `call-v2`

Starting SHA: `25911fb55411a3766ce5d0cf369feb7b51d21fd7`

## Goal

Correct only the developer physical-diagnostics access boundary. The enabled
overlay mounted from `MaterialApp.builder` must open through the existing app
`navigatorKey`, explicitly handle the nullable builder child, and automatically
merge the native safe timeline before displaying or copying the report.

## Allowed Files

- `lib/main.dart`
- `lib/call_v2/diagnostics/**`
- `test/call_v2/diagnostics/**`
- `test/call_v2/ui/call_v2_physical_diagnostics_view_test.dart`
- `docs/agent-loop/**`

Do not change routing, accepted continuation, lifecycle ownership, Agora/RTC,
tokens, Firebase/backend, Firestore protocol or rules, PushKit/CallKit
presentation, or native watchdog semantics.

## Required Behavior

- Use the existing app Navigator explicitly; do not resolve a Navigator from
  the overlay context above `MaterialApp`'s Navigator.
- Add no second Navigator and no route registration.
- Keep diagnostics behind the existing Call V2 real-flow developer flag.
- Treat a null `MaterialApp.builder` child safely.
- Refresh native diagnostics automatically on open.
- Copy only the latest native-refreshed report.
- Render and copy no private ownership values.

## Required Tests

- Mount the enabled overlay in the real `MaterialApp.builder` topology with a
  `navigatorKey`, tap the real diagnostics button, and prove the view opens.
- Prove opening and copying refreshes a fake native-only checkpoint.
- Preserve the disabled-overlay isolation test.

## Validation

```bash
flutter analyze
flutter test test/call_v2/diagnostics/call_v2_physical_diagnostic_ledger_test.dart test/call_v2/ui/call_v2_physical_diagnostics_view_test.dart --no-pub
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,id=154D1A5C-282D-4696-AE27-1FBF98B4A198' -only-testing:RunnerTests -parallel-testing-enabled NO test
git diff --check
```

Do not deploy or build TestFlight. Do not claim the physical call issue is
fixed.
