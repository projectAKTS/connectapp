# Active Task - Background Accepted Audio Media Ownership

Branch: `call-v2`

Starting SHA: `2906cd605c31679919fb961c7433668861ca3672`

## Goal

Allow an authoritatively accepted incoming audio call to acquire token, Agora
engine, event-handler, and channel ownership without requiring a Flutter route
or Navigator. A later foreground call screen must attach to that exact media
owner instead of starting a second media session.

The implementation must extract and reuse the physically validated
`AgoraCallScreen` media behavior. It must not wire the dormant V2 media
controller or RTC adapters into production.

## Authorized Scope

### 1. Exact Physical Media Owner

- Introduce one production media owner keyed by immutable `inviteId`, exact
  accepted CallKit ID when present, lifecycle generation, channel, media type,
  direction, and connection system.
- The owner may own token acquisition, Agora engine, event handler,
  `joinChannel`, media state, remote-participant state, controls, and cleanup.
- Navigator and route ownership remain outside the media owner.
- Terminal lifecycle invalidates exact media ownership and cleans only the
  matching engine/session.

### 2. Reuse The Validated Agora Runtime

- Extract the current production token selection, engine initialization,
  event registration, audio/video setup, join, callback, control, and cleanup
  behavior from `AgoraCallScreen` into one reusable runtime.
- Preserve the existing token path, identity mode, connection-system choice,
  engine options, callback semantics, and process cleanup coordinator.
- Do not create a second independent Agora implementation.
- Do not directly use `CallV2MediaSessionController`,
  `AgoraCallV2RtcAdapter`, or `AgoraSdkCallV2RtcEngineClient`.

### 3. Background Accepted Audio Startup

- Incoming accepted audio may start media before a Flutter route only after:
  authoritative acceptance succeeds, exact lifecycle ownership remains
  current, exact CallKit audio-session readiness is known, microphone
  permission is already granted, and the process cleanup gate allows a new
  engine.
- CallKit audio activation is readiness only and never acceptance authority.
- Preserve an early exact audio activation until matching authority arrives.
- If microphone permission is unavailable in background, do not prompt;
  terminate the exact call safely with a stable safe reason.

### 4. One Owner And Screen Attachment

- A later `AgoraCallScreen` attaches to the existing exact audio owner and
  observes connection, mute, speaker, remote-participant, terminal, and failure
  state.
- Attachment must not fetch another token, create another engine, register
  another handler, or join again.
- Widget disposal detaches UI observation only. It must not destroy active
  shared media unless managed call lifecycle has ended.
- Foreground incoming audio may use the shared owner while preserving current
  externally visible sequencing.
- Outgoing audio remains route-first.
- Video remains route-first.

### 5. Exact Native Audio Readiness And Media ACK

- Bridge exact CallKit audio-session readiness without using plugin-global or
  last-call identity as authority.
- Add a distinct exact-ID media-owned acknowledgment only after the matching
  runtime actually joins RTC and Dart lifecycle generation is still current.
- Keep `callkitRouteOwned` route-specific and send it only after successful
  route opening.
- Media ownership may satisfy the native no-owner safety watchdog, but route
  ownership must remain independently observable.
- A late Call A activation or acknowledgment must never apply to Call B.

### 6. Shared Cleanup And Callback Ownership

- Every physical runtime must use the existing process-wide Agora cleanup-gate
  semantics; do not create another cleanup coordinator.
- Token, engine, handler, join, and cleanup must each be single-flight per
  exact media key.
- RTC callbacks must validate immutable media identity and engine generation.
- Late Call A callbacks or cleanup must not mutate or release Call B.
- Headless joining, connected, remote-offline, and failure progress must flow
  through existing `CallSessionManager` authoritative lifecycle APIs without
  requiring a screen.

## Authorized Files

Modify or add only files strictly required from:

- `lib/call_v2/real_flow/call_v2_physical_media_owner.dart`
- `lib/call_v2/real_flow/call_v2_agora_media_runtime.dart`
- `lib/call_v2/real_flow/call_v2_engine_cleanup_coordinator.dart` only if a
  minimal shared-instance exposure is required; preserve its semantics
- `lib/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart`
- `lib/screens/call/agora_call_screen.dart`
- `lib/services/call_session_manager.dart`
- `lib/services/notification_service.dart`
- `ios/Runner/AppDelegate.swift`
- focused regression files under `test/call_v2/**`
- `test/notification_foreground_recovery_test.dart` only if required
- `ios/RunnerTests/RunnerTests.swift`

Do not modify backend, Firestore rules/schema, dependency metadata, or unrelated
platform configuration.

## Strict Non-Goals

Do not redesign or change:

- video-call UX or video route-first sequencing
- outgoing-call sequencing or outgoing audio route-first behavior
- accepted transaction authority or Firestore accept retries
- route ownership correction or post-call redial gate
- PushKit/APNs delivery or incoming presentation policy
- backend `callInvites` protocol except strictly necessary existing media
  progress writes
- token backend, Agora version, plugin version, Flutter version, or dependency
  versions
- native watchdog duration

Do not increase timeouts, deploy, build TestFlight, or claim physical success.

## Required Regression Tests

1. Background accepted audio starts token/engine/join without Navigator.
2. Audio activation before authority and authority before activation each
   converge to one start.
3. Foreground during token acquisition attaches without a second token,
   engine, handler, or join.
4. Duplicate accepted recovery and duplicate activation retain one owner.
5. Screen attachment observes existing media; screen disposal does not dispose
   active media.
6. Terminal before startup and during token acquisition prevent later startup.
7. Missing microphone permission causes no background prompt and safely
   terminalizes the exact call.
8. Exact media ACK mismatch is ignored; media and route ACKs remain distinct.
9. Late Call A callbacks/cleanup cannot affect Call B.
10. The shared cleanup gate orders Call A cleanup before Call B engine creation.
11. Later route attachment retains the same joined session.
12. Foreground video and outgoing audio remain route-first.
13. Rapid audio -> video -> audio sequencing has one engine owner at a time.
14. Native activation and ACK handling is exact-ID, duplicate-safe, and
    terminal-safe.

## Validation

Run and pass:

```bash
flutter analyze
flutter test test/call_v2 --no-pub
flutter test test/notification_foreground_recovery_test.dart --no-pub
git diff --check
```

Also run the focused media-owner/runtime tests, existing exact CallKit
ownership tests, notification ownership tests, lifecycle/repeated-call tests,
diagnostic ledger tests if changed, and iOS RunnerTests because native bridge
behavior is authorized. Confirm dependency and lock files remain unchanged.

## Commit And Handoff

After validation, create one focused implementation commit, update
`docs/agent-loop/HANDOFF.md` and `STATE.json` to `ready_for_review` in a
separate metadata commit, push `origin/call-v2`, and stop. Do not build
TestFlight, deploy, request physical testing, or claim the physical issue is
fixed.
