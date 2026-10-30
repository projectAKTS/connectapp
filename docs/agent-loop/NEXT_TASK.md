# Active Task - Earpiece First With Proximity For Android Audio Calls (F8)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `fd99084`

## Review Of F7 (Claude, 2026-10-30)

Accepted: `754980a`.
- PIN-locked answers pass on the A55, including with the app killed. After
  the call the keyguard is back.
- On the S21 FE (Android 16):
  - outgoing calls from the phone pass 4/4;
  - two-way audio was confirmed by ear by the user (phone <-> emulator with
    the host mic on).

## Problem (F8)

Audio calls start on the loudspeaker:
- `CallV2AgoraMediaRuntime` calls `setDefaultAudioRouteToSpeakerphone(true)`
  with `speakerEnabled: true`;
- the screen's engine path does the same.

This was copied in 3e9628d, not chosen to work around a bug. WhatsApp starts
audio calls on the earpiece and turns the screen off at the ear. The app has
no proximity handling at all, so an earpiece default alone would let a cheek
tap the hang-up or mute button.

## Goal (Android only; iOS and video unchanged)

1. A new `lib/services/call_audio_route.dart` with:
   - `callStartsOnSpeaker(isVideo:)`: true for video, and for audio on
     iOS; false for audio on Android. It has a test override.
   - `CallProximity`: Android-only, de-duplicated, fire-and-forget, over the
     `connectapp/callProximity` channel.
2. The runtime and the screen use `callStartsOnSpeaker` for the default route
   and the initial `speakerEnabled`/`_speakerOn`.
3. `AgoraCallScreen` holds proximity while it is an audio call that is not
   ended and the speaker is off. It releases on speaker on, end, and dispose.
4. `MainActivity` holds a `PROXIMITY_SCREEN_OFF_WAKE_LOCK` (if supported)
   and releases it with `RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY` and on destroy.

## Allowed Files

- New `lib/services/call_audio_route.dart`
- `lib/call_v2/real_flow/call_v2_agora_media_runtime.dart` (default route only)
- `lib/screens/call/agora_call_screen.dart` (default route, proximity sync)
- `android/app/src/main/kotlin/com/yakup/helperly/MainActivity.kt`
- New `test/call_v2/real_flow/call_audio_route_test.dart`
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`

## Strict Non-Goals

- No iOS change (it needs proximity monitoring and a TestFlight run).
- No video change; video stays speaker-first.
- No server change, no deploy.

## Validation

- New widget test, with earpiece-first forced:
  - the audio screen starts with the speaker off;
  - proximity is held;
  - tapping the speaker releases it, and tapping again re-holds it;
  - ending the call releases it.
  - Video holds nothing.
- `flutter test test/call_v2 test/multi_device test/android`: no new
  failures beyond the known guards. `flutter analyze` clean.
- Physical (S21 FE):
  - an audio call routes to the earpiece (`dumpsys audio` communication
    device);
  - the speaker toggle moves it to the speaker and back;
  - the proximity wake lock is held only on the earpiece;
  - mute reaches the caller (`remote_audio_muted`).

## Commit And Handoff

- Implementation: `feat(calls): start Android audio calls on the earpiece with proximity`.
- Handoff: `chore(agent-loop): record earpiece proximity review handoff`.
- Push `call-v2`.
