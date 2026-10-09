# Call Route Ownership + Authoritative Terminal Transition Handoff

STATUS: `ready_for_review`

STARTING_SHA: `9ed7df1ad8825390e5776a95b911f524c7a30491`
IMPLEMENTATION_SHA: `e4904c103938ba191bb5fee94b9251cdcab8302b`
ENDING_SHA: `SELF`

## Root Cause Being Fixed

Call-screen exits were not uniformly owned by `CallSessionManager`: the Audio
AppBar close action and some loading/error/back paths could pop without first
performing managed terminal transition and teardown. Terminal classification
also depended on local stage, so stale local `ringing` state could attempt a
caller cancellation after Firestore had already advanced to
`accepted`/`joining`/`connected`. Finally, a stale route completion could clear
process-global route state belonging to a newer call, and destructive chat
navigation could replace the route while call lifecycle still owned it.

## Route Exit Model

Old:

`UI close/back/error -> route pop may occur independently -> best-effort cleanup`

New:

`UI close/back/error -> exact route owner asks manager to terminate -> authoritative terminal transaction -> exact teardown -> pop is authorized`

`PopScope` now covers loading, active, error, and ended states. The Audio and
Video variants share the same managed exit behavior. A route already proven
terminal by its exact manager ownership may close without a second terminal
write; an error label alone is not terminal authority.

## Authoritative Terminal Transition

The local-exit transaction reads the current invite and classifies from its
authoritative Firestore state:

- `ringing` plus caller exit becomes `cancelled`;
- `accepted`, `joining`, or `connected` plus participant exit becomes `ended`;
- an already-terminal document keeps its existing status and reason;
- a participant mismatch cannot mutate the invite;
- stale local `ringing` cannot regress an advanced server state.

The transition is single-flight per exact session. Existing terminal status and
the existing Agora-derived terminal reason are preserved rather than
overwritten by route-close cleanup.

## Exact Route Owner

`CallSessionManager` now records route ownership as exact session identity,
invite identity, accepted CallKit identity, and lifecycle generation. Route
completion clears route state only when that owner still matches. A delayed
Call A route callback cannot clear or terminalize Call B, and duplicate route
completion cannot perform a second terminal transition.

This does not change exact CallKit UUID propagation or cleanup architecture.

## Chat Navigation

Pending destructive chat navigation remains queued while call lifecycle owns
an active route. It is retried only after `CallSessionManager` reports that
destructive navigation is safe, including a second safety check after Navigator
availability. No chat request is discarded solely because call teardown is in
progress.

## Files Changed

- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/real_flow/call_v2_route_ownership_terminal_transition_test.dart`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/STATE.json`

The pre-existing untracked `docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` remains
untouched.

## Regression Tests

The new focused file contains 14 passing tests covering:

- stale local `ringing` with authoritative `accepted`, `joining`, or
  `connected` transitions to `ended`;
- caller exit from authoritative `ringing` transitions to `cancelled`;
- every existing terminal state and Agora terminal reason is preserved;
- active Audio close, loading close, system back, terminal UI-only close, and
  Audio/Video parity use managed route ownership;
- delayed Call A route completion cannot mutate Call B;
- duplicate route completion produces one terminal transition;
- destructive chat navigation defers while the call route is owned and resumes
  when lifecycle becomes safe.

## Validation

- `flutter analyze`: passed, no issues.
- New route ownership / terminal transition tests: passed, 14 tests.
- Exact CallKit ownership tests: passed, 14 tests.
- Notification ownership tests: passed, 38 tests.
- Rapid lifecycle manager tests: passed, 65 tests.
- Repeated-call lifecycle tests: passed, 50 tests.
- Foreground recovery tests: passed, 3 tests.
- Full `test/call_v2 --no-pub`: passed, 2327 tests.
- `test/notification_foreground_recovery_test.dart --no-pub`: passed, 3 tests.
- iOS `RunnerTests`: passed, 21 tests, 0 failed, 0 skipped.
- `git diff --check`: passed.
- `pubspec.yaml`, `pubspec.lock`, `ios/Podfile`, and `ios/Podfile.lock`:
  unchanged.

The full Call V2 run was performed with the preserved untracked architecture
document temporarily outside the repository because four historical audit
tests intentionally enumerate repository paths. The document was restored
unchanged immediately afterward.

## Adversarial Races

- **A: stale local ringing versus accepted server state.** The transaction
  uses authoritative status and writes `ended`, never a regressive
  cancellation reason.
- **B: delayed Call A route completion after Call B owns the route.** Exact
  route-owner and generation checks leave B untouched.
- **C: duplicate close/completion for one route.** The per-session single-flight
  terminal transition and owner check allow one mutation and one teardown.
- **D: destructive chat navigation during route ownership.** Navigation stays
  queued until lifecycle is safe, then resumes once.

## Scope

No PushKit/APNs behavior, exact CallKit UUID ownership, accepted-recovery or
Firestore accept architecture, Navigator architecture, Agora media/token
configuration, redial-gate ordering, watchdog timing, backend, dependencies,
Flutter version, or plugin version changed. No backend deployment or TestFlight
build was performed. This handoff does not claim physical validation.

## Next

Review the implementation and automated evidence before authorizing any
TestFlight build or physical validation.
