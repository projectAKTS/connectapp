# Active Revision - Final Production Route Push Ownership Guard

Branch: `call-v2`

Starting SHA: `c5528da10fa485a237fd2940fa635acd1609c535`

## Goal

Close the final source-reviewed asynchronous boundary in
`CallSessionManager._openCallScreen()`: after the awaited `route_push`
diagnostic, revalidate exact route ownership immediately before production
`Navigator.push()` so a terminalized Call A cannot push over Call B.

## Allowed Files

- `lib/services/call_session_manager.dart`
- directly relevant tests under `test/call_v2/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Implementation

- Add a minimal post-diagnostic/pre-production-push ownership guard.
- Validate the exact current session, accepted continuation when applicable,
  current route attempt, and exact route owner.
- Return `staleOwnership` without mutating another call when ownership changed.
- Preserve the existing test-recorder behavior.
- Add a deterministic production-navigation-path regression with a controlled
  asynchronous barrier proving late A cannot push or clear B.

## Strict Non-Goals

Do not refactor lifecycle architecture or change CallKit connected timing,
close-screen UX, Firebase/Firestore transaction behavior, Agora, PushKit,
dependencies, backend services, native watchdogs, or cleanup-gate design.

Preserve all untracked files, including
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md`, unchanged.

No TestFlight build, backend deployment, physical call, or physical-fix claim is
authorized.

## Validation

Run the deterministic regression, background audio integration, accepted
recovery, route ownership, physical media ownership, foreground recovery,
repeated-call and lifecycle regressions, the full Call V2 suite,
`flutter analyze`, dependency diff inspection, and `git diff --check`.

## Commit And Handoff

Commit implementation and tests separately from the final agent-loop handoff.
Then replace `HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit metadata,
push `origin/call-v2`, and stop.
