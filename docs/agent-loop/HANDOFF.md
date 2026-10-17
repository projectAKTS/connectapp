# Post-Terminal Accepted Continuation Replay Handoff

STATUS: `ready_for_review`

STARTING_SHA: `f1e0499bf93cb294374efaa789510a97d1679d01`
IMPLEMENTATION_SHA: `d994cdba749afac10da97542a2739e35e0c6195b`
ENDING_SHA: `SELF`

## Root Cause

An accepted-route continuation could remain owned after its call terminalized.
`CallV2CallLifecycleArbiter.ownsGeneration()` still recognizes the last
generation after the arbiter returns to idle, so generation-only readiness
checks allowed a delayed continuation to recreate `_current`, open a route, and
claim a second physical audio runtime for the terminated call. The route path
also continued after `markJoining()` rejected the stale transition.

## Correction

- Terminal cleanup invalidates only the continuation matching the session's
  invite, lifecycle generation, and accepted native CallKit identity.
- Exact invalidation cancels the matching accepted-route readiness work.
- Continuations can proceed only while they remain the identical owned object,
  retain their lifecycle generation, and the arbiter is `joining` or
  `connected`.
- Accepted continuation ownership is rechecked after foreground readiness,
  subscription cancellation/binding, Navigator readiness, and immediately
  before a route is counted or opened.
- Rejected `markJoining()` transitions stop activation.
- Route activation uses exact attempt/session tokens so late Call A completion
  cannot clear Call B's opening state, subscription, current session, route, or
  accepted continuation.
- Terminal watch and rollback cleanup recheck exact ownership after awaited
  cancellation before mutating shared state.
- Legitimate foreground attachment while an accepted audio call is still
  joining/connected reuses the existing physical media owner.

## Files Changed

- `lib/services/call_session_manager.dart`
- `test/call_v2/real_flow/call_v2_background_audio_media_integration_test.dart`
- `docs/agent-loop/NEXT_TASK.md`
- `docs/agent-loop/STATE.json`
- `docs/agent-loop/HANDOFF.md`

The pre-existing untracked
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` remains unchanged with SHA-256
`d33b3bf300a4980807b863d6c4b29465548284b1c6004638dcfa7fbcb2eda0f3`.

## Regression Proof

- `background accepted audio terminalizes before foreground and never restarts media`
  proves terminal cleanup reaches idle and late readiness creates no route,
  token request, engine, join, session, continuation, or second media owner.
- `terminal during awaited foreground readiness cannot reopen the call` uses a
  controlled readiness barrier and proves no route or media restart after the
  terminal event wins.
- `late Call A readiness cannot mutate active Call B` proves delayed A work
  cannot replace, cancel, or terminate B.
- `foreground route attaches after headless join without second RTC` preserves
  the valid background-audio-to-foreground attachment path.
- `audio then audio then video stay single-owner across terminal cleanup`
  proves sequential reuse with one route and one RTC owner per call.
- Existing exact CallKit, route ownership, accepted recovery, physical media,
  rapid lifecycle, repeated-call, and foreground recovery regressions remain
  green.

## Validation

- Background audio integration: 11 passed.
- Foreground recovery: 3 passed.
- Accepted recovery, route ownership, exact CallKit ownership, physical media,
  rapid lifecycle, and repeated-call focused suites: 192 passed.
- Full clean-tree Call V2 suite: 2,365 passed.
- `flutter analyze`: passed, no issues.
- Formatting check: passed.
- `git diff --check`: passed.
- Dependency diff: none for `pubspec.yaml` or `pubspec.lock`; no platform,
  backend, or package files changed.
- iOS RunnerTests: not rerun because no native production or test file changed.

The full suite's historical working-tree allowlist audits require a clean tree.
The agent-loop metadata was temporarily stashed and the pre-existing untracked
architecture document temporarily moved for that validation only; both were
restored afterward, and the architecture document hash remained identical.

## Safety

No caller connected-marker timing, close-screen UX, Firestore acceptance
transaction/retry/timeout, native watchdog, PushKit/APNs, Agora token/runtime,
backend, dependency, video/outgoing-audio sequencing, media-owner architecture,
or cleanup-gate architecture changed. No backend/Firebase deployment,
TestFlight build, or physical call was performed.

PHYSICAL_FIX_CLAIM: `NONE`

## Next

Review the exact post-terminal continuation invalidation and asynchronous
ownership guards before authorizing any physical build.
