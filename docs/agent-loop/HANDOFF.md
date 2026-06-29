# External Review Handoff

Phase: 3A
Status: ready_for_review
Implementation SHA: bb04f993b6ad58ae6e53c11bcddadb3dbe101d3d
Pushed branch-tip SHA: SELF

## Files changed

- `lib/call_v2/domain/call_snapshot.dart`
- `test/call_v2/domain/call_snapshot_parser_test.dart`

## Codex summary

Implemented a narrow parser-hardening update in:
- [lib/call_v2/domain/call_snapshot.dart](/home/runner/work/connectapp/connectapp/lib/call_v2/domain/call_snapshot.dart)
- [test/call_v2/domain/call_snapshot_parser_test.dart](/home/runner/work/connectapp/connectapp/test/call_v2/domain/call_snapshot_parser_test.dart)

What changed:
- `participantUids` is now required; the parser no longer falls back to deriving the set from `participants`.
- The parser still rejects same caller/callee, mismatched participant identities, and role/UID mismatches.
- Added focused tests for:
  - missing `participantUids`
  - swapped caller/callee roles
  - the existing same caller/callee, wrong participant IDs, missing caller participant, missing callee participant, duplicate caller/callee roles, and exact-success cases remain covered

Validation:
- `dart format lib/call_v2 test/call_v2` passed.
- `flutter analyze lib/call_v2 test/call_v2` passed when run with `HOME=/tmp` and the local writable Flutter SDK copy.
- `flutter test test/call_v2` could not complete in this sandbox because Flutter test tries to bind a local server socket and the environment blocks that operation.

I left the changes uncommitted, per instruction.

## Validation

- Node 20 backend checks passed
- Deployment readiness validation passed
- Firestore rules tests passed
- Full backend emulator suite passed three times
- Flutter formatting passed
- Focused Flutter analysis passed
- Focused Flutter tests passed
- `git diff --check` passed
- Workflow run: https://github.com/projectAKTS/connectapp/actions/runs/28340624321

## Safety

- V1 files were not modified.
- The V2 feature gate remains disabled by default.
- No production service was contacted.
- No live configuration was changed.
- Nothing was deployed.

