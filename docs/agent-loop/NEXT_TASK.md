# Active Task - Post-Terminal Accepted Continuation Replay

Branch: `call-v2`

Starting SHA: `f1e0499bf93cb294374efaa789510a97d1679d01`

## Goal

Correct the source- and runtime-proven replay where a background accepted audio
call reaches terminal cleanup and lifecycle idle, but its retained accepted-route
continuation later recreates the Flutter route and a second physical media owner.

## Allowed Files

- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart` only if exact readiness cancellation
  requires it
- directly relevant tests under `test/call_v2/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Implementation

- Terminal cleanup must invalidate only the accepted continuation matching the
  exact invite, lifecycle generation, and available accepted CallKit identity.
- Matching accepted-route readiness work must be cancelled or invalidated so
  delayed callbacks cannot revive the terminated call.
- Accepted continuation callbacks must revalidate exact ownership and lifecycle
  state after awaited work and immediately before session assignment/route push.
- `_resumeAcceptedRouteContinuation()` and `_openConfirmedAcceptedRoute()` must
  require a valid nonterminal lifecycle state, not generation equality alone.
- A rejected `markJoining()` transition must prevent session activation.
- Late Call A work must not clear, cancel, terminate, or replace Call B.
- Legitimate foreground attachment must keep using the existing physical media
  owner without a second token, engine, or join.

## Required Tests

- Background accepted audio terminalizes before foreground and never restarts
  media.
- Terminal during awaited Navigator readiness cannot push a route or start media.
- Late Call A continuation cannot mutate active Call B.
- Legitimate foreground attachment reuses one media owner/runtime.
- Audio -> audio -> video sequential behavior remains intact.
- A media-owned native watch still receives exact terminal continuation cleanup.
- Prefer Completer-controlled races over sleep-based timing.

## Strict Non-Goals

Do not change caller CallKit connected-marker timing, caller close-screen UX,
Firestore acceptance transactions/retries/timeouts, native watchdog behavior,
APNs/PushKit, Agora token/backend services, dependencies, media-owner architecture,
video/outgoing-audio sequencing, or cleanup-gate architecture.

Preserve the pre-existing untracked
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` unchanged.

No deployment, TestFlight build, physical call, or physical-fix claim is
authorized.

## Validation

Run the new deterministic regressions, background-audio integration tests,
accepted-recovery tests, route-ownership tests, native exact-ownership tests,
physical-media-owner tests, rapid lifecycle tests, repeated-call tests,
foreground-recovery tests, the full Call V2 suite, `flutter analyze`, dependency
diff inspection, and `git diff --check`.

## Commit And Handoff

Commit implementation and tests separately from the final agent-loop handoff.
Then replace `HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit metadata,
push `origin/call-v2`, and stop.
