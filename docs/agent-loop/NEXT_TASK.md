# Active Revision - Terminal Route Timing Verification

Branch: `call-v2`

Starting SHA: `7ac433472600527515365f3bc179c61a2622be09`

## Goal

Prove with deterministic production-path widget coverage that the accepted
terminal-route ownership correction returns an exact manager-owned receiving
call route to Home promptly, rather than relying on a coarse 40-second widget
clock jump.

## Allowed Files

- directly relevant tests under `test/call_v2/**`
- `lib/services/call_session_manager.dart` only if an identical red test proves
  a remaining production ownership defect
- `lib/screens/call/agora_call_screen.dart` only if an identical red test proves
  a remaining production navigation defect
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Proof

- Use a real `MaterialApp`, `Navigator`, `PopScope`, `AgoraCallScreen`, and an
  exact manager-owned receiving audio route.
- Trigger remote terminal state, observe `Call ended`, and reproduce the
  manager call made by native stale-UI reconciliation.
- Advance time in small frame intervals and prove route disposal/Home within a
  strict simulated two-second budget after terminal observation.
- Cover reconciliation immediately before and during auto-close, including a
  controlled final-pop barrier.
- Prove no later callback reopens the route, stale Call A cannot dismiss Call
  B, exact CallKit/media cleanup remains scoped, and the cleanup gate remains
  safe for the next call.
- Preserve the original baseline-red and fixed-green regression evidence.

## Strict Non-Goals

Do not change call connection setup, Agora, tokens, Firebase/backend,
Firestore authority/schema/rules, PushKit/APNs, native CallKit, watchdogs,
dependencies, release configuration, accepted recovery, or cleanup-gate
policy. Do not build TestFlight, deploy, or request physical testing.

## Validation

Run the new timing regressions, relevant route ownership/terminal/media/
CallKit/cleanup-gate/repeated-call tests, the full Call V2 suite,
`flutter analyze`, formatting checks, dependency diff inspection, and
`git diff --check`.

## Commit And Handoff

Commit implementation/tests separately from the final agent-loop handoff.
Replace `HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit metadata,
push `origin/call-v2`, and stop.
