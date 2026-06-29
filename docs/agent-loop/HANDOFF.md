# External Review Handoff

Phase: 3A
Status: revision_required
Implementation SHA: 0e8b3a77fcd1e1cfc4a26ee1de2f19d5bab5d7fb
Pushed branch-tip SHA: call-v2

## Review result

The focused parser retry succeeded, but Phase 3A is not accepted as complete.

Workflow run `28339163243` passed backend and focused Flutter validation. The prior parser failure from workflow run `28336086589` appears fixed: public call snapshots now require different `callerUid` and `calleeUid`, exact participant UID matching, and caller/callee role matching.

External review found remaining required Phase 3A scope missing or not visible on branch:

- `docs/call-v2/PHASE_3A_FLUTTER_CLIENT_GROUNDWORK.md` is missing.
- No visible `CallSessionManagerV2` implementation was found.
- No visible `CallNavigationCoordinatorV2` interface/value contract was found.
- No visible callable API boundary for the exact V2 callable names was found.
- No visible disabled-by-default feature gate implementation was found.
- Required tests for manager ownership, command serialization, navigation intent dedupe, disabled gate, callable request shape, and no production service contact are missing.

## Files reviewed

- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/NEXT_TASK.md`
- `lib/call_v2/domain/call_snapshot.dart`
- `test/call_v2/domain/call_snapshot_parser_test.dart`
- Workflow run `28339163243`
- Previous failed workflow run `28336086589`

## Required next action

Run a bounded targeted retry against `docs/agent-loop/NEXT_TASK.md`. Preserve the parser fix and complete the missing Phase 3A Flutter client-groundwork pieces only inside the allowed paths.

## Validation status

- Workflow run `28339163243`: passed.
- Backend validation: passed.
- Focused Flutter analysis/tests: passed.
- Acceptance review: revision required due missing Phase 3A scope.

## Safety

- V1 files must remain untouched.
- V2 feature gate must remain disabled by default.
- No production service may be contacted.
- No live configuration may be changed.
- Nothing may be deployed.
