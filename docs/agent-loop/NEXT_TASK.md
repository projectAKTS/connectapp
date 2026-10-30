# Active Task - Remote Audio Stall From Audio Stats (F3b)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `f161b25`

## Review Of F3 (Claude, 2026-10-30)

Physical run on the user's A55 (Android 14), with emulator A as the caller:
- 10 s Wi-Fi gap: PASS. The phone showed "Reconnecting…" and recovered
  about 5 s after Wi-Fi came back.
- 35 s gap: PASS. The caller showed "Reconnecting…" from the
  `userOfflineDropped` grace, and the call continued.
- Ring time after F6, across bg, killed and locked: 2.2-3.2 s (5.5-6.4 s
  before).

Accepted: `6ca5e19` and `e6c9b1b`.

## Problem (F3b)

While the phone was offline, the caller's screen kept showing "Connected" for
~20 s, until `userOfflineDropped` fired. In both runs Agora reported
`remoteAudioStateFrozen` about 1 s into the outage, then
`remoteAudioStateDecoding` (reason `NetworkRecovery`) exactly 2.0 s later,
while the phone was still offline. The 2 s frozen debounce therefore never
showed anything.

## Goal

Detect a remote audio stall from `onRemoteAudioStats`, which Agora reports
every 2 s for each remote user that is sending audio:
- A report with `receivedBitrate > 0` means audio is flowing. It clears the
  stall and re-arms a 3.5 s silence timer.
- No positive report for 3.5 s shows "Reconnecting…". This is UI only.
- A remote mute (`onUserMuteAudio` true) stops the timer and clears the
  stall. Muting is not a network problem.
- Nothing is armed until the first positive report.
- The frozen remote-audio state stays logged but no longer drives the UI.
- Both the audio runtime and the video screen handler use the new signal.

## Allowed Files

- `lib/services/call_reconnect_watch.dart` and its test.
- `lib/services/call_session_manager.dart`: replace
  `reportRemoteAudioFrozen` with `reportRemoteAudioStats` /
  `reportRemoteAudioMuted`, plus the runtime wiring.
- `lib/call_v2/real_flow/call_v2_agora_media_runtime.dart`: the stats and
  mute callbacks, and a diag log when the flow starts or stops.
- `lib/screens/call/agora_call_screen.dart`: video handler reporting.
- `test/call_v2/real_flow/call_v2_reconnect_grace_test.dart`.
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`.

## Strict Non-Goals

- No server change, no deploy, no TestFlight.
- Leave the drop grace and the local limit (F3) as they are.

## Validation

- Watch and widget tests updated; the stall test is RED on the old frozen
  signal.
- `flutter test test/call_v2 test/multi_device test/android`: no new
  failures beyond the 14 known working-tree guards.
- `flutter analyze lib test integration_test`: clean.
- Physical: a 10 s and a 35 s Wi-Fi gap on the phone. The caller shows
  "Reconnecting…" within ~6 s. A mute does not show it.

## Commit And Handoff

- Implementation: `fix(calls): show reconnecting when remote audio stops arriving`.
- Handoff: `chore(agent-loop): record remote audio stall review handoff`.
- Push `call-v2`.
