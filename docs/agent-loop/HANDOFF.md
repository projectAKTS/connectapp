# Remote Audio Stall Handoff (F3b)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `f161b25`
AUTHORIZATION_SHA: `3e2d2ae`
IMPLEMENTATION_SHA: `4c16626`
ENDING_SHA: `SELF`

## Change

The "Reconnecting…" indicator for a remote audio stall now comes from
`onRemoteAudioStats` instead of the frozen remote-audio state.
- Each report with a positive bitrate re-arms a 3.5 s silence timer.
- A remote mute (`onUserMuteAudio`) disarms the timer.
- Nothing is armed until the first positive report.
- The audio runtime and the video screen use the same signal.
- The runtime logs `remote_audio_flow` (start and stop, with bitrate and loss)
  and `remote_audio_muted`.

Why: on the A55, Agora went `Frozen` ~1 s into a Wi-Fi outage and back to
`Decoding` (`NetworkRecovery`) 2.0 s later, while the phone was still offline.
The caller showed "Connected" for ~20 s.

## Validation

- `call_reconnect_watch_test`: 8/8. `call_v2_reconnect_grace_test`: 5/5. The
  new tests did not compile against the old API (RED), then passed.
- `flutter test test/call_v2 test/multi_device test/android`: +2437 -4. All 4
  failures are the known Phase 7BG-7BJ working-tree guards.
- `flutter analyze lib test integration_test`: clean.

Physical runs: A55 (Android 14) answering, emulator A calling, both on
`app-release-f3c.apk`.

| Run | Result |
|---|---|
| 10 s Wi-Fi gap | PASS. The caller showed "Reconnecting…" within 5 s (before: "Connected"), and the call recovered. |
| 35 s gap | PASS. Both sides showed "Reconnecting…" throughout, and the call recovered. |
| 75 s gap | PASS. The phone ended at ~45 s (`local_network_lost`), the caller at ~50 s (grace expired). Nothing was left stale. |
| 15 s phone mute | PASS. The caller stayed "Connected". |

## Also Measured (F6 on hardware)

Ring time, bg/killed/locked: 2.2-3.2 s (5.5-6.4 s before F6). The first
call after the install was a 6.4 s cold start.

Killed-app answers connected ~8 s after the tap; the cold start takes ~3 s
before `accept_tap`.

## New Finding (F7, next task)

With a PIN on the phone, a call answered from the lock-screen call UI gets
connected audio, but the call screen never appears.
- `MainActivity` has no `showWhenLocked`, so it stays behind the keyguard.
- `_isAppActuallyForeground` therefore stays false, and the log shows
  `accepted_route_navigator_unavailable` every 250 ms.
- The user cannot see or end the call without unlocking.
