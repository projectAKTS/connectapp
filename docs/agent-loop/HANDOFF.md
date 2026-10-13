# Background Accepted Audio Media Ownership Handoff

STATUS: `ready_for_review`

STARTING_HEAD: `970b0a1f736969da71f405713ee7e3d005cf4e17`
ACCEPTED_CHECKPOINT_SHA: `2906cd605c31679919fb961c7433668861ca3672`
IMPLEMENTATION_SHA: `3e9628d8d224a5f7cb1667874e10211554b4fc23`
ENDING_SHA: `SELF`

## Implementation

Incoming authoritatively accepted audio calls can now acquire one exact,
manager-owned physical media session before a Flutter route exists. The owner
is keyed by invite identity, exact accepted CallKit identity, lifecycle
generation, channel, media type, direction, and connection system.

The production Agora setup previously embedded in `AgoraCallScreen` is shared
through `CallV2AgoraMediaRuntime`. A later audio screen attaches to the exact
existing owner and does not fetch a second token, create another engine,
register another handler, or join again. Screen disposal detaches observation
only; exact manager lifecycle termination owns media cleanup.

Video and outgoing audio remain route-first.

## Native Ownership

- Exact CallKit audio-session readiness converges whether activation or
  authoritative acceptance arrives first.
- `callkitMediaOwned` is sent only after the exact runtime joins RTC and the
  lifecycle generation is still current.
- The media-owned acknowledgment satisfies the native no-owner safety watch
  without asserting route ownership.
- `callkitRouteOwned` remains independent and is sent only after a real route
  opens.
- Duplicate, mismatched, terminal, and late acknowledgments are exact-ID safe.
- Native watchdog duration and termination semantics are unchanged.

## Lifecycle And Cleanup

- Headless joining, joined, remote-presence, offline, timeout, and failure
  progress flow through existing `CallSessionManager` lifecycle APIs.
- The later route reuses the exact existing manager session, preserving
  headless `joining` or `connected` state rather than replacing it with an
  older accepted snapshot.
- Token, engine, handler, join, and cleanup are single-flight per exact media
  key.
- Runtime callbacks validate media identity and engine generation.
- Terminal-before-start and terminal-during-token completion cannot create or
  join a late engine.
- Audio and existing video runtime cleanup use the same process-wide
  `callV2PhysicalEngineCleanupGate`.
- Late Call A callbacks, acknowledgments, route attachment, or cleanup cannot
  mutate or release Call B.

## Files Changed

- `ios/Runner/AppDelegate.swift`
- `ios/RunnerTests/RunnerTests.swift`
- `lib/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart`
- `lib/call_v2/real_flow/call_v2_agora_media_runtime.dart`
- `lib/call_v2/real_flow/call_v2_physical_media_owner.dart`
- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `test/call_v2/diagnostics/call_v2_physical_diagnostic_ledger_test.dart`
- `test/call_v2/real_flow/call_v2_background_audio_media_integration_test.dart`
- `test/call_v2/real_flow/call_v2_physical_media_owner_test.dart`
- `test/call_v2/ui/call_v2_physical_diagnostics_view_test.dart`
- `docs/agent-loop/HANDOFF.md`
- `docs/agent-loop/STATE.json`

The pre-existing untracked
`docs/CALL_V2_ARCHITECTURE_DEEP_DIVE.md` remains untouched.

## Test Evidence

- Focused background-audio/media/diagnostic/wiring set: 33 passed.
  - Physical media owner: 11 passed.
  - Background manager and real screen integration: 4 passed.
  - Physical diagnostic ledger: 6 passed.
  - Remaining diagnostics-view and real-flow wiring coverage passed in the
    combined focused run.
- Route ownership / authoritative terminal transition: 14 passed.
- Exact CallKit ownership: 14 passed.
- Notification ownership: 38 passed.
- Rapid lifecycle manager: 65 passed.
- Repeated-call lifecycle and cleanup/redial ownership: 50 passed.
- Foreground recovery: 3 passed.
- Full isolated Call V2 suite: 2,343 passed.
- iOS RunnerTests: 26 passed, 0 failed.
- `flutter analyze`: passed with no issues.
- Dart format check: 10 files checked, 0 changed.
- `git diff --check`: passed.
- Dependency diff: none for `pubspec.yaml`, `pubspec.lock`,
  `ios/Podfile`, or `ios/Podfile.lock`.

Four historical phase-isolation tests enumerate all untracked repository paths.
For the final full-suite run, the pre-existing architecture document was moved
temporarily outside the repository and restored immediately afterward. Its
SHA-256 was identical before and after:
`d33b3bf300a4980807b863d6c4b29465548284b1c6004638dcfa7fbcb2eda0f3`.

## Adversarial Races

- **A: activation before authority.** Exact readiness latches and starts the
  owner once after authoritative acceptance.
- **B: authority before activation.** No engine starts until matching exact
  native audio readiness arrives.
- **C: duplicate activation or accepted recovery.** One owner and one start
  future produce one token, engine, handler, and join.
- **D: foreground during token acquisition.** The route attaches to the
  in-flight owner without starting another runtime.
- **E: terminal before or during startup.** Epoch and ownership checks suppress
  late token/engine/join completion and clean the exact owner.
- **F: late Call A work after Call B owns media.** Immutable key, lifecycle
  generation, and engine generation checks leave B untouched.
- **G: screen disposal while audio remains active.** UI detaches; manager-owned
  media survives until exact lifecycle cleanup.
- **H: rapid audio -> video -> audio.** The shared process cleanup gate
  serializes engine cleanup and creation while video remains route-first.

## Scope

No APNs/PushKit delivery architecture, incoming presentation policy,
authoritative accept transaction, Firestore retry/schema/rules, route ownership
correction, redial-gate ordering, backend function, dependency, Flutter/Agora/
CallKit package version, or native watchdog timeout changed. No backend or
Firebase deployment and no TestFlight build were performed.

This handoff does not claim physical validation or that the physical audio issue
is fixed.

## Next

Review the implementation and automated evidence. Do not request physical
testing or create TestFlight before review acceptance.
