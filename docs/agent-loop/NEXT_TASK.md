# Active Task - Fast Hangup UI With Owned Background Cleanup

Branch: `call-v2`

Starting SHA: `1937701449ca5ab6d7f5fd30938b938b7183c4d8`

## Goal

Make local-hangup and remote-terminal call routes leave the screen promptly and
deterministically once exact-call termination owns the lifecycle, while the
strictly owned teardown continues asynchronously behind the existing cleanup
gate.

## Allowed Files

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- directly relevant Call V2 diagnostics or cleanup-owner files only when the
  source trace proves they are required
- directly relevant tests under `test/call_v2/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Investigation And Implementation

- Trace local hangup and remote-terminal route-exit awaits and identify the
  source-proven operations that block `Navigator.pop`.
- Add privacy-safe monotonic diagnostics for terminal ownership, Firestore
  transition, engine cleanup, exact native cleanup, hard reset, route-pop,
  disposal, and cleanup-gate readiness.
- Decouple visual route dismissal from slow teardown only after exact-call
  terminal or local-hangup ownership is established.
- Keep eventual Firestore, RTC, native CallKit, accepted-continuation, and hard
  reset cleanup strictly owned and idempotent.
- Preserve the process-wide cleanup gate so a later call cannot create or join
  RTC until prior teardown has actually completed.
- Revalidate exact invite, CallKit identity, lifecycle generation, session, and
  route ownership across asynchronous boundaries so late Call A work cannot
  mutate or dismiss Call B.
- Add deterministic Completer-driven regressions for prompt local and remote
  exits, overlapping terminal signals, background cleanup, sequential calls,
  and late-cleanup isolation.
- Investigate Video C only from existing diagnostics and source. Do not modify
  its Agora, PushKit, token, Firebase, native CallKit, or media path without a
  separately proven and approved cause.

## Strict Non-Goals

Do not change CallKit connected timing, Agora/token/media initialization,
PushKit/APNs, accepted Firestore authority, backend services, dependencies,
watchdog timing, or cleanup-gate safety. Do not add arbitrary sleeps or shorten
timeouts. Preserve managed `PopScope` route ownership.

Preserve all untracked files, including
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` and Aider artifacts, unchanged.

No TestFlight build, backend deployment, physical call, or physical-fix claim is
authorized.

## Validation

Run the new navigation-latency regressions, relevant route-exit UI suites,
background accepted audio, cleanup coordinator and process-wide gate tests,
accepted recovery and exact CallKit ownership, repeated-call and rapid lifecycle
tests, sequential audio/audio/video regression, the full Call V2 suite,
`flutter analyze`, formatting, dependency diff inspection, and
`git diff --check`.

## Commit And Handoff

Commit implementation and tests separately from the final agent-loop handoff.
Then replace `HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit
metadata, push `origin/call-v2`, and stop.
