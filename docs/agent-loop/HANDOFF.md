# External Review Handoff

Phase: 3A
Status: task_ready
Review decision: revision_required

## Review result

The previous parser-hardening retry passed validation in workflow run 28340624321, but Phase 3A is not complete enough to accept.

Accepted partial progress:
- `participantUids` is now required.
- The public snapshot parser rejects same caller/callee, mismatched participant identities, swapped roles, duplicate roles, and missing caller/callee participant data.
- Backend validation, deployment readiness validation, rules tests, emulator suite, Flutter formatting, focused Flutter analysis, focused Flutter tests, and `git diff --check` passed.

Remaining required Phase 3A work:
- Add `docs/call-v2/PHASE_3A_FLUTTER_CLIENT_GROUNDWORK.md`.
- Add or complete callable API boundary names: `startCallV2`, `acceptCallV2`, `declineCallV2`, `cancelCallV2`, `endCallV2`, `reportParticipantMediaV2`, `renewActiveCallLeaseV2`.
- Ensure request shape cannot send authenticated UID, staff status, rollout mode, percentage, salt, allowlist, or cohort data.
- Add a test transport abstraction and controlled callable error normalization.
- Add a single local owner skeleton named `CallSessionManagerV2`.
- Add `CallNavigationCoordinatorV2` intent-only route contract with no `Navigator` use.
- Add a disabled-by-default feature gate so disabled state performs no Firebase call and creates no session ownership.
- Add focused pure/unit tests for callable shape, forbidden fields, disabled gate, ownership, stale snapshot dedupe, local phases, terminal cleanup idempotence, duplicate command serialization, failed-command behavior, navigation intent dedupe, and no production service contact.

## Safety constraints

- Continue from current branch tip.
- Do not undo parser hardening.
- Modify only `lib/call_v2/**`, `test/call_v2/**`, `docs/call-v2/**`, and pubspec files when genuinely required.
- Do not modify legacy V1 call code, app startup, routes, native code, backend functions, Firebase config, rules, indexes, IAM/OIDC/secrets, or production settings.
- Do not deploy or contact production services.

See `docs/agent-loop/NEXT_TASK.md` for the active task.
