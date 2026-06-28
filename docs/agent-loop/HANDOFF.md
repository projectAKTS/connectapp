# External Review Handoff

Phase: 3A
Status: ready_for_review
Implementation SHA: 0e8b3a77fcd1e1cfc4a26ee1de2f19d5bab5d7fb
Pushed branch-tip SHA: SELF

## Files changed

- `lib/call_v2/domain/call_snapshot.dart`
- `pubspec.lock`
- `test/call_v2/domain/call_snapshot_parser_test.dart`

## Codex summary

Implemented the focused parser fix in [`lib/call_v2/domain/call_snapshot.dart`](/home/runner/work/connectapp/connectapp/lib/call_v2/domain/call_snapshot.dart) and added targeted parser tests in [`test/call_v2/domain/call_snapshot_parser_test.dart`](/home/runner/work/connectapp/connectapp/test/call_v2/domain/call_snapshot_parser_test.dart).

What changed:
- Added strict public parsing entry points for V2 snapshots and participant snapshots.
- Enforced:
  - `callSystem == "v2"`
  - valid `callId` and `version`
  - present and different `callerUid` / `calleeUid`
  - exact two distinct participant UIDs
  - exact set `{callerUid, calleeUid}`
  - caller participant role must be `caller`
  - callee participant role must be `callee`
- Rejected:
  - same caller/callee
  - wrong participant IDs
  - missing caller/callee participant
  - duplicate participant UIDs
  - duplicate/wrong roles
  - unknown lifecycle/media values

Validation:
- `dart format lib/call_v2 test/call_v2` ran successfully.
- `flutter analyze lib/call_v2 test/call_v2` could not run in this sandbox because Flutter tries to write engine cache files under `/opt/hostedtoolcache`, which is read-only here.
- `flutter test test/call_v2` failed for the same sandbox reason.

Notes:
- I left the implementation changes uncommitted, per your instruction.
- `pubspec.lock` was already modified before this work and was not touched.

## Validation

- Node 20 backend checks passed
- Deployment readiness validation passed
- Firestore rules tests passed
- Full backend emulator suite passed three times
- Flutter formatting passed
- Focused Flutter analysis passed
- Focused Flutter tests passed
- `git diff --check` passed
- Workflow run: https://github.com/projectAKTS/connectapp/actions/runs/28339163243

## Safety

- V1 files were not modified.
- The V2 feature gate remains disabled by default.
- No production service was contacted.
- No live configuration was changed.
- Nothing was deployed.

