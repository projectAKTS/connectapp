# Fast Hangup UI With Owned Background Cleanup Handoff

STATUS: `ready_for_review`

STARTING_SHA: `1937701449ca5ab6d7f5fd30938b938b7183c4d8`
AUTHORIZATION_SHA: `bd12a7c9e8d2db9944fd9980d576142e9822de82`
IMPLEMENTATION_SHA: `f27e3ec5b91c84195ea0be8f9e84e9d7e9fa350d`
ENDING_SHA: `SELF`

## Physical Observation And Source Finding

Physical build `1.0.2 (202610170043)` showed Audio A and B connecting, while
the caller's call route remained visible for about 10-15 seconds after hangup.
The source-proven delay was ordering: both local hangup and remote-terminal
paths awaited authoritative Firestore terminal work, engine cleanup, exact
CallKit cleanup, and hard reset before invoking Navigator pop. Existing evidence
does not isolate which awaited operation accounted for the full physical delay.

The route now dismisses after synchronous exact-call teardown ownership is
established. The authoritative transition and all owned cleanup continue in the
background behind the unchanged process cleanup gate.

## Ownership And Cleanup

- `beginEndCallFromLocalUser()` validates the exact invite, lifecycle
  generation, and accepted CallKit identity, enters ending ownership before its
  first asynchronous boundary, and returns the eventual terminal-transition
  future.
- The call screen revalidates the exact active route owner before and after its
  frame boundary, and refuses to pop a stale or non-current route.
- Firestore terminal transition, engine cleanup, exact native CallKit cleanup,
  and exact-identity hard reset continue after the route is dismissed.
- The cleanup coordinator and next-engine gate are unchanged. A later engine
  cannot start until the prior cleanup actually completes.
- Hard reset retains expected invite and exact CallKit identity checks, so late
  Call A cleanup cannot reset or dismiss owned Call B.
- Duplicate exit requests share one route dismissal and one teardown future.

## Diagnostics

Privacy-safe monotonic teardown checkpoints now cover hangup/remote terminal,
teardown ownership, Firestore transition, route authorization and pop, route
disposal, engine cleanup, exact CallKit cleanup, hard reset, and cleanup-gate
release. Metadata is limited to elapsed counts, booleans, controlled stages,
and safe status/error categories; it contains no raw identifiers or payloads.

## Regression Proof

The production widget path blocks the authoritative transaction with a
`Completer`, taps the real hangup control, and proves the call route returns to
Home while the transaction remains blocked and lifecycle state remains
`ending`. Additional deterministic tests prove prompt remote-terminal exit,
duplicate-exit coalescing, and that a stale Call A screen cannot pop or mutate
owned Call B.

The focused matrix also covers background accepted audio, exact CallKit
ownership, physical media ownership, repeated calls, rapid lifecycle changes,
notification ownership, foreground recovery, and the existing route-first
accepted-video path.

## Video C

No retained physical Video C timeline was found in the local terminal, build
logs, or diagnostic exports. Automated accepted-video coverage passes, but the
physical failure's first blocking stage is not available. Its root cause remains
unproven, and no Agora, token, PushKit, Firebase, native CallKit, permission, or
video-media code was changed.

## Files Changed

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_route_ownership_terminal_transition_test.dart`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

The pre-existing untracked architecture document and Aider artifacts remain
untouched.

## Validation

- Focused route/cleanup/recovery/media matrix: 211 passed.
- Route ownership and terminal transition file: 18 passed.
- Foreground recovery: 3 passed.
- Full Call V2 suite at exact implementation commit: 2,370 passed.
- `flutter analyze`: passed, no issues.
- Formatting check: passed.
- `git diff --check`: passed.
- Dependency diff: none.

The full suite was run in a detached clean worktree at the exact implementation
commit because four legacy source-isolation audits reject every untracked file.
This preserved the required untracked architecture document and Aider artifacts
in the main workspace while exercising all audits under their intended clean
conditions.

## Safety

No cleanup timeout, cleanup-gate policy, connection setup, RTC/token behavior,
CallKit connected timing, PushKit/APNs, Firestore authority protocol, backend,
dependency, or platform configuration changed. No TestFlight build, backend
deployment, or physical call was performed.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review the fast route dismissal and exact owned background cleanup, then perform
one controlled two-iPhone validation only after approval.
