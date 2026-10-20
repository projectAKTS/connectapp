# Active Revision - Final Fast Hangup Safety

Branch: `call-v2`

Starting SHA: `15828dbc5fdd94e69d0d75d15359ecc63e930b45`

## Goal

Preserve prompt owned call-route dismissal while closing two source-reviewed
safety gaps: revalidate exact route ownership at the final synchronous boundary
before navigation, and start exact active-media teardown without waiting for the
authoritative Firestore terminal transaction.

## Allowed Files

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart` only if an exact ownership API or
  deterministic test hook is strictly required
- directly relevant tests under `test/call_v2/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Corrections

1. Immediately before production `Navigator.pop`, synchronously revalidate the
   exact active session, invite, lifecycle generation, accepted CallKit
   identity, route owner, route attempt, and current `ModalRoute`. No await may
   separate this final check from navigation.
2. On valid local hangup, establish exact ending ownership and begin shutdown
   of the matching active RTC/physical audio owner without waiting for the
   Firestore terminal transaction.
3. Keep the authoritative terminal transaction mandatory and independently
   awaited by eventual cleanup.
4. Preserve exact native CallKit cleanup, hard reset, accepted-continuation
   cancellation, idempotence, and the existing process-wide cleanup gate.
5. A late Call A route or cleanup continuation must never pop, terminate,
   reset, or otherwise mutate Call B.
6. Cleanup failure must still attempt exact native cleanup and must not
   incorrectly release the next-engine gate.
7. Add deterministic production-path tests using controlled asynchronous
   barriers for the final pre-pop race, Firestore-blocked media shutdown,
   cleanup-gate exclusion, eventual authoritative/native cleanup, duplicate
   exits, and sequential Audio A -> Audio B -> Video C viability.

## Strict Non-Goals

Do not change connection setup, Agora tokens, backend, Firestore acceptance
semantics, PushKit/APNs, native CallKit implementation, camera/video setup,
audio join timing, cleanup-gate policy, watchdog timing, dependencies, build
flags, post-terminal continuation, or Navigator push guards. Video C remains
unproven and receives no speculative fix.

Preserve all untracked files, including
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` and Aider artifacts, unchanged.

No TestFlight build, backend deployment, physical call, or physical-fix claim is
authorized.

## Validation

Run focused final pre-pop, media-owner, cleanup-coordinator/gate, exact CallKit,
accepted-recovery, rapid-lifecycle, repeated-call, route-ownership, background
audio, and sequential audio/audio/video regressions. Then run the full Call V2
suite, `flutter analyze`, formatting, dependency diff inspection, and
`git diff --check`.

## Commit And Handoff

Commit implementation and tests separately from the final agent-loop handoff.
Then replace `HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit
metadata, push `origin/call-v2`, and stop.
