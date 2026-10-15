# Active Revision - Durable Diagnostic Storage Atomicity

Branch: `call-v2`

Starting SHA: `1aeb7c41b5931dd67442b80f838fbc03c825f9ba`

Reviewed implementation SHA: `b017ab007308fe31837174f2e06269f5dd7202c5`

## Goal

Correct only two reviewed durability defects in the Dart durable accepted-call
diagnostic recorder:

1. Replace direct JSON overwrite with an atomic same-directory snapshot
   replacement that preserves the previous valid target when preparation or
   replacement fails.
2. Commit `_events` cache state only after durable-store write succeeds, so a
   failed write is never reported as persisted and later writes resume from the
   last committed snapshot.

## Allowed Files

- `lib/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart`
- `test/call_v2/diagnostics/call_v2_durable_boundary_diagnostics_test.dart`
- directly relevant new tests under `test/call_v2/diagnostics/**` only if needed
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Required Implementation

- Write the full encoded snapshot to a temporary file in the target directory.
- Flush the temporary file before replacement.
- Use a verified filesystem operation appropriate to the iOS Application
  Support filesystem to atomically replace the target.
- Preserve the previous valid target on failures before replacement.
- Remove temporary artifacts on failure where safe.
- Keep all writes asynchronous and serialized; no call-critical path may await
  diagnostic persistence.
- Build candidate events from a copy of the last committed cache.
- Update the in-memory cache only after `_store.write()` succeeds.
- A failed write must leave both disk and cache at the last committed snapshot.
- Later successful writes must continue from that committed snapshot.

## Required Tests

- Real temporary-filesystem proof that pre-commit failure preserves a valid
  previous target and never exposes partial JSON.
- Failed write does not expose an uncommitted event through the current or a
  newly constructed recorder.
- Recovery after failure preserves prior A/B/C ordering.
- A later successful write continues from the last committed sequence.
- Retention and fingerprint privacy remain unchanged.
- Record submission remains nonblocking and storage failures remain isolated.

## Strict Non-Goals

Do not change native CallKit, accepted recovery, Firestore transaction logic,
timeouts, retries, Agora/media ownership, engine cleanup, audio/video behavior,
PushKit/APNs, backend, dependencies, or any native source/test file.

Preserve the pre-existing untracked
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` unchanged.

No deployment, TestFlight build, physical call, root-cause claim, or physical-fix
claim is authorized.

## Validation

Run focused diagnostics tests, focused ownership/recovery tests, the full Call
V2 suite, `flutter analyze`, `git diff --check`, and dependency diff inspection.
Report iOS RunnerTests accurately; native code is unchanged and they need not be
rerun for this revision.

## Commit And Handoff

Commit the focused implementation separately. Then replace `HANDOFF.md`, set
`STATE.json` to `ready_for_review` with exact results, commit metadata
separately, push `origin/call-v2`, and stop.
