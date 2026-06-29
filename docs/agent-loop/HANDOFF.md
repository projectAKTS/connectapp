# External Review Handoff

Phase: 3A
Status: ready_for_review
Implementation SHA: 009a1f372fabe26fe10394519ff47739788d982a
Pushed branch-tip SHA: SELF

## Files changed

- `lib/call_v2/call_navigation_coordinator_v2.dart`
- `lib/call_v2/call_session_manager_v2.dart`
- `lib/call_v2/call_v2_api.dart`
- `lib/call_v2/domain/call_snapshot.dart`
- `lib/call_v2/domain/call_v2_models.dart`
- `test/call_v2/call_v2_behavior_test.dart`
- `test/call_v2/call_v2_models_test.dart`

## Codex summary

Phase `3A`, authoritative NEXT_TASK sha256 `57aa1d079007f5c4da2465ec1c981441ff5cf0a31f929b9a6273e4ce8441defd`.

Changed files:
- [lib/call_v2/call_navigation_coordinator_v2.dart](/home/runner/work/connectapp/connectapp/lib/call_v2/call_navigation_coordinator_v2.dart)
- [lib/call_v2/call_session_manager_v2.dart](/home/runner/work/connectapp/connectapp/lib/call_v2/call_session_manager_v2.dart)
- [lib/call_v2/call_v2_api.dart](/home/runner/work/connectapp/connectapp/lib/call_v2/call_v2_api.dart)
- [lib/call_v2/domain/call_snapshot.dart](/home/runner/work/connectapp/connectapp/lib/call_v2/domain/call_snapshot.dart)
- [lib/call_v2/domain/call_v2_models.dart](/home/runner/work/connectapp/connectapp/lib/call_v2/domain/call_v2_models.dart)
- [test/call_v2/call_v2_behavior_test.dart](/home/runner/work/connectapp/connectapp/test/call_v2/call_v2_behavior_test.dart)
- Deleted [test/call_v2/call_v2_models_test.dart](/home/runner/work/connectapp/connectapp/test/call_v2/call_v2_models_test.dart)

What changed:
- Collapsed `call_v2_models.dart` into harmless exports so the accepted domain contract stays authoritative.
- Removed client-supplied authenticated identity from request context and request payloads.
- Replaced message-only client errors with a small controlled error-code contract.
- Updated `CallSessionManagerV2` to use an injected local role for phase derivation, reject stale/different-call ownership changes, suppress duplicate in-flight commands, and clear terminal ownership idempotently.
- Made `CallNavigationCoordinatorV2` stateful so it dedupes open/close intents by call/version.
- Hardened `CallSnapshot.fromPublicData` to reject the private request-shape keys called out in the task.
- Replaced the old weak test file with behavioral tests covering request shape, error codes, caller/callee ringing phases, terminal monotonicity, ownership rejection, cleanup, duplicate taps, and navigation dedupe.

Validations run:
- `dart format lib/call_v2 test/call_v2`
- `git diff --check`
- `HOME=/tmp dart analyze lib/call_v2 test/call_v2`  
  - Passed with no issues.
- `flutter pub get`  
  - Failed in this environment because the Flutter SDK cache path is read-only.
- `flutter analyze lib/call_v2 test/call_v2`  
  - Failed for the same read-only Flutter SDK cache reason.
- `flutter test test/call_v2`  
  - Failed for the same read-only Flutter SDK cache reason.
- `HOME=/tmp flutter analyze lib/call_v2 test/call_v2`  
  - Still failed on the read-only Flutter SDK cache.
- `HOME=/tmp flutter test test/call_v2`  
  - Still failed on the read-only Flutter SDK cache.

Remaining risks:
- I could not execute the required Flutter toolchain commands in this workspace because the SDK cache location is not writable here, so Flutter-side validation remains unconfirmed in this environment.
- The changes are uncommitted by design, per your instruction.

Safety constraints confirmed:
- V1 untouched.
- V2 remains disabled by default.
- No deployment.
- No live services contacted.
- No live configuration, IAM, OIDC, queues, secrets, native code, or production values changed.
- Only allowed `lib/call_v2/**` and `test/call_v2/**` files were modified.

## Validation

- Node 20 backend checks passed
- Deployment readiness validation passed
- Firestore rules tests passed
- Full backend emulator suite passed three times
- Flutter formatting passed
- Focused Flutter analysis passed
- Focused Flutter tests passed
- `git diff --check` passed
- Workflow run: https://github.com/projectAKTS/connectapp/actions/runs/28369246060

## Safety

- V1 files were not modified.
- The V2 feature gate remains disabled by default.
- No production service was contacted.
- No live configuration was changed.
- Nothing was deployed.

