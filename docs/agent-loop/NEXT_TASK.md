# Active Revision - Critical Terminal Screen Deadlock

Branch: `call-v2`

Starting SHA: `b8f29c2836ba9cb0c27fc5bd6b0cb9293d6d0b0b`

## Goal

Deterministically reproduce the physical callee failure where remote hangup
shows `Call ended` but the mounted Flutter call route never returns Home, prove
the exact ownership/lifecycle cause, and only then apply the smallest safe
correction.

## Allowed Files

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart` only if the proven ownership
  contract requires a narrowly scoped API or test hook
- directly relevant tests under `test/call_v2/**`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

## Red-First Requirement

1. Build a deterministic widget regression using the real `MaterialApp`,
   `Navigator`, `PopScope`, `AgoraCallScreen`, and production
   `CallSessionManager` lifecycle methods.
2. On the unmodified baseline, prove that remote terminal handling can detach
   manager session/route ownership before the mounted terminal screen performs
   its automatic close.
3. Prove the screen remains visible after `Call ended`, the close timer, and an
   elapsed window beyond 40 seconds, with no retry.
4. Do not change production code if this exact causal path cannot be
   reproduced.

## Authorized Correction After Red Proof

Allow a genuinely terminal, still-mounted exact call route to dismiss itself
without depending on a live session ownership record already destroyed by
terminal cleanup. Preserve exact invite, lifecycle generation, accepted
CallKit identity, Navigator identity, and route identity. There must be no
await between final navigation validation and the exact route pop.

The correction must preserve stale-call isolation: Call A cannot pop or mutate
Call B, resurrect a terminal session, bypass required cleanup, create another
RTC owner, or weaken exact CallKit, Firestore, physical-media, engine-cleanup,
or next-engine-gate behavior.

## Required Coverage

- terminal signal before and after manager detachment
- CallKit termination before the one-second auto-close
- physical-media cleanup and Firestore terminal completion before navigation
- foreground/background transitions while terminal
- stale A callback after B owns a newer route
- repeated terminal callbacks and close requests
- current route versus an older covered route
- sequential Audio A -> Audio B -> Video C
- actual Home appearance, not only timer scheduling

## Strict Non-Goals

Do not change call connection setup, Agora, tokens, Firebase/backend, Firestore
authority/schema/rules, PushKit/APNs, native CallKit implementation, watchdogs,
dependencies, release configuration, cleanup-gate policy, or accepted-call
readiness. Preserve all untracked architecture and Aider files unchanged.

No TestFlight build, App Store Connect upload, backend deployment, physical
call, or physical-fix claim is authorized.

## Validation

Run the new red/green production-Navigator regression and relevant route
ownership, terminal transition, fast-hangup, background-audio, exact CallKit,
physical-media, engine-cleanup/gate, accepted-recovery, repeated-call, and
sequential audio/audio/video tests. Then run the full Call V2 suite,
`flutter analyze`, format checks, dependency diff inspection, and
`git diff --check`.

## Commit And Handoff

Commit implementation/tests separately from the final agent-loop handoff.
Replace `HANDOFF.md`, set `STATE.json` to `ready_for_review`, commit metadata,
push `origin/call-v2`, and stop.
