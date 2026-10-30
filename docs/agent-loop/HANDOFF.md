# Reconnect Grace Handoff (F3)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `cd64273`
AUTHORIZATION_SHA: `14b9dad`
IMPLEMENTATION_SHA: `6ca5e19` (+ `e6c9b1b`: remote audio state log)
ENDING_SHA: `SELF`

## Change

A connected call now survives a short network drop, WhatsApp-like.

| Event | Before | Now |
|---|---|---|
| Remote `userOfflineDropped` (Agora, ~20 s without packets) | call ended | "Reconnecting…", 25 s more to rejoin, then `ended` with `endReason: remote_left:<reason>:grace_expired` |
| Remote `userOfflineQuit` (hang-up) | call ended | unchanged |
| Local `connectionStateReconnecting` | logged only; screen said "Connected" | "Reconnecting…"; after 45 s without recovery it ends like a local hang-up (`local_network_lost`) |
| Remote audio `remoteAudioStateFrozen` for 2 s | nothing | "Reconnecting…" (UI only) |

- `lib/services/call_reconnect_watch.dart` (new) owns the three timers and
  the `CallReconnectStatus` notifier.
- `CallSessionManager`:
  - `reportRemoteOffline` starts the grace for a network drop on a
    connected call.
  - `reportRemoteJoined` cancels it.
  - New `reportLocalConnectionState` and `reportRemoteAudioFrozen`.
  - The watch is reset where every terminal signal is published, and in
    `forceIdleForTest`.
  - Expiries act only when the session is still the same object
    (`expectedSession` or `identical`).
- Audio path: `CallV2AgoraMediaRuntimeConfig` has two optional callbacks,
  wired by the manager.
- Video path: `AgoraCallScreen` reports the same events. It no longer marks
  the call ended on a network drop.
- UI: the audio status line and the video status pills show
  "Reconnecting…" (video icon `wifi_off_rounded`).

## Validation

- `call_reconnect_watch_test.dart`: 7/7.
- `call_v2_reconnect_grace_test.dart`: 5 tests.
  - RED with API stubs: 4 failed with no "Reconnecting…" shown.
  - GREEN after the change.
  - The remote-hang-up test passed both times; it is the regression guard.
- `flutter test test/call_v2 test/multi_device test/android`: +2426 -14.
  - +12 is the new tests.
  - The 14 failures are the known Phase 7AW-7BJ working-tree guards.
- `flutter analyze lib test integration_test`: no issues.
- Emulator, release APK, A (Baris) calls venus on B. B accepts, then B is
  put in airplane mode for the gap:

  | Gap | Timeline (s after the cut) | Verdict |
  |---|---|---|
  | 10 s | B "Reconnecting…" at 0; net back at 11; both "Connected" at 18; later A hung up and both were idle | PASS |
  | 35 s | B "Reconnecting…" at 0; A "Reconnecting…" at 21 (remote dropped; before this change A hung up here); net back at 37; both "Connected" at 48; A hung up normally | PASS |
  | 75 s | A "Reconnecting…" at 26; B ended at 47 (`local_network_lost`); A ended at ~52 (grace expired, terminal write applied) | PASS: both ended, nothing left reconnecting |

- Frozen remote audio was not seen on the emulators: they run with
  `-no-audio`, so B sends no audio stream. `e6c9b1b` logs
  `media_runtime_remote_audio_state` so a phone run can confirm it.
- After recovery, B briefly showed "Reconnecting…" again (43 s), then
  "Connected": B's own view of A dropping and rejoining.

## Pending

- Physical: a Wi-Fi gap on the user's Android phone (APK
  `test_artifacts/work/app-release-f3b.apk`).
- iOS: same Dart code, not run on an iPhone.

PHYSICAL_FIX_CLAIM: none.
