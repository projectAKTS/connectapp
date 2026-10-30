# Active Task - Reconnect Grace For Connected Calls (F3)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `cd64273`

## Review Of F6 (Claude, 2026-10-29)

- Accepted: `bb1b254`, deployed by the user. Emulator tap-to-ring went from
  ~5.9 s to ~1.5 s (median); the iOS path is unchanged in the logs.
- A physical-phone measurement is still to come.

## Product Decision

The user delegated UX design: "WhatsApp-like, stability first".

## Problem (F3)

Seen on the S21 FE: Wi-Fi off for 5 s, and Samsung needed ~17 s more to
reassociate.
- Agora rejoined 23.4 s after the drop.
- The other side had already ended the call 0.2 s earlier, on
  `userOfflineDropped`, which Agora fires after ~20 s without packets.
- The offline side showed "Connected" through the whole outage.

Both media paths end a connected call on any `onUserOffline`:
- audio: `CallV2AgoraMediaRuntime` → `CallSessionManager.reportRemoteOffline`;
- video: `AgoraCallScreen.onUserOffline` plus `reportRemoteOffline`.

## Goal

WhatsApp-like behaviour:
1. **Remote dropped** (`userOfflineDropped`) on a connected call: show
   "Reconnecting…" and wait 25 s more for the remote to rejoin. If it
   rejoins, the call continues. If not, end the call with
   `endReason: remote_left:<reason>:grace_expired`.
2. **Remote quit** (a hang-up, `userOfflineQuit`) and offline before
   connect: unchanged, the call ends immediately.
3. **Local connection** `connectionStateReconnecting` on a connected call:
   show "Reconnecting…". Back to `connectionStateConnected` clears it.
   45 s without recovery ends the call like a local hang-up (`source:
   local_network_lost`).
4. **Remote audio** `remoteAudioStateFrozen` for 2 s: show
   "Reconnecting…". Decoding again clears it. This is UI only, with no
   timeout.

## Allowed Files

- New `lib/services/call_reconnect_watch.dart` (timers and status) and its
  test `test/call_v2/real_flow/call_reconnect_watch_test.dart`.
- `lib/services/call_session_manager.dart`:
  - `reportRemoteOffline` and `reportRemoteJoined`;
  - new `reportLocalConnectionState` and `reportRemoteAudioFrozen`;
  - reset on terminal and test idle;
  - the audio runtime config wiring.
- `lib/call_v2/real_flow/call_v2_agora_media_runtime.dart`: optional
  connection-state and remote-audio-frozen callbacks.
- `lib/screens/call/agora_call_screen.dart`: video-path event reporting,
  no immediate end on a network drop, and the "Reconnecting…" label.
- A new manager/screen widget test
  `test/call_v2/real_flow/call_v2_reconnect_grace_test.dart`.
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`.

## Strict Non-Goals

- No server change, no deploy, no TestFlight.
- No change to ringing, accept, decline or cancel paths.
- Do not change the existing `remote_hangup`-style ends.

## Validation

- New tests RED before the change, GREEN after.
- `flutter test test/call_v2 test/multi_device test/android`: no new
  failures beyond the 14 known working-tree guards.
- `flutter analyze lib test integration_test`: clean.
- Emulator: during a connected call, cut the callee emulator's network
  (`svc wifi`/`svc data` or airplane mode) for ~10 s, then restore. The
  call continues. For ~70 s, both sides end within ~50 s.
- Physical: Wi-Fi gap on the user's phone later today.

## Commit And Handoff

- Implementation: `fix(calls): keep a connected call through a short network drop`.
- Handoff: `chore(agent-loop): record reconnect grace review handoff`.
- Push `call-v2`.
