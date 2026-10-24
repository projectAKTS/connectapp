# Active Revision - Persistent Terminal Route Diagnostics

Branch: `call-v2`

Starting SHA: `30a1303da11ee249fc3303319c635286e8fe7f69`

## Goal

Extend the existing bounded, privacy-safe durable Call V2 boundary recorder so
terminal route navigation outcomes survive process restart and distinguish normal
pop, exact covered/detached removal, transient retry, retry exhaustion, and stale
ownership rejection without changing terminal-route behavior.

## Allowed Files

- `lib/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart`
- `lib/screens/call/agora_call_screen.dart`
- directly relevant diagnostic and terminal-route tests under `test/call_v2/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Implementation

- Add durable terminal-route stages for exit request, safe ownership rejection,
  covered route, Navigator pop request, exact-route removal request/completion,
  route disposal, retry scheduling/attempt, and retry exhaustion.
- Reuse existing hashed call/CallKit fingerprints and lifecycle generation.
- Persist no raw identifiers, credentials, contact data, channel, UID, token, or
  payload values.
- Submit diagnostics without awaiting file I/O on navigation, RTC, CallKit, or
  cleanup-critical paths. Logging failure must not affect navigation.
- Preserve recorder retention/bounds and avoid duplicate disposal records for one
  logical route where possible.
- Add deterministic persisted-timeline and restart-recovery coverage for normal
  pop, covered removal, detached ownership, transient failure/retry, retry
  exhaustion, and stale Call A rejection after B ownership.
- Prove instrumentation does not alter navigation ordering or the existing strict
  2,000 ms simulated terminal-disposal budget.

## Strict Non-Goals

Do not change RTC/media setup, Firestore terminal authority, PushKit/APNs, native
CallKit, cleanup gates, route-removal semantics, retry limits, dependencies,
backend/Firebase, release configuration, or the accepted terminal-route correction.
Do not build/upload TestFlight, deploy, or place physical calls.

## Validation

Run focused durable diagnostics and exact route-ownership tests, affected recovery
and lifecycle regressions, the complete Call V2 suite, available iOS RunnerTests,
`flutter analyze`, formatting checks, dependency diff inspection, and
`git diff --check`.

## Commit And Handoff

Commit implementation/tests separately from the final agent-loop handoff. Replace
`HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit metadata, push
`origin/call-v2`, and stop. Do not claim physical verification or 100% reliability.
