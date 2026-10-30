# Earpiece Proximity Handoff (F8)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `fd99084`
AUTHORIZATION_SHA: `79dd002`
IMPLEMENTATION_SHA: `a41c564`
ENDING_SHA: `SELF`

## Change

Android audio calls start on the earpiece and turn the screen off at the ear,
like WhatsApp. Video calls and iOS audio stay on the speaker.
- New `lib/services/call_audio_route.dart`:
  - `callStartsOnSpeaker(isVideo:)`, with a test override;
  - `CallProximity`: Android-only, de-duplicated, fire-and-forget, over
    `connectapp/callProximity`.
- `CallV2AgoraMediaRuntime`: the default route and the initial
  `speakerEnabled` come from `callStartsOnSpeaker`.
- `AgoraCallScreen`:
  - `_speakerOn` starts from the same helper;
  - the screen's engine path uses it for the default route;
  - `build` holds proximity while it is an audio call that is not ended
    and the speaker is off;
  - `dispose` releases it.
- `MainActivity`: `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, only if supported. It is
  released with `RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY` and in `onDestroy`.
  `WAKE_LOCK` is already in the merged manifest.

Why: the speaker default was copied in 3e9628d; it was not a bug workaround.
There was no proximity handling at all, so an earpiece default on its own
would have let a cheek tap hang-up or mute.

## Validation

- New `call_audio_route_test`: 3/3. It is RED (+2 -1) with the screen change
  reverted.
- `flutter test test/call_v2 test/multi_device test/android`: +2441 -4. All 4
  failures are the known Phase 7BG-7BJ working-tree guards.
- `flutter analyze lib test integration_test`: clean.

Physical runs: S21 FE (Android 16), `app-release-f8.apk`.

| Check | Result |
|---|---|
| Audio call start | `MODE_IN_COMMUNICATION`, no preferred device (earpiece), proximity lock held |
| Speaker on | route `speaker`, lock released |
| Speaker off | earpiece, lock held again |
| Phone mute, then unmute | the caller logged `remote_audio_muted` true, then false |
| After the call | lock released |

## Same Session, Earlier Builds (S21 FE)

- Outgoing calls from the phone (Baris) to emulator venus: PASS 4/4, bg and
  killed callee, ended by either side.
  - Accept to connected: 3.1 s.
  - The harness "connected" figure of 13-19 s is the emulator shade and
    uiautomator time.
- Two-way audio by ear (the user): phone to Mac and Mac to phone, with the
  emulator host mic on (`adb emu avd hostmicon`). The echo came from the
  two devices sitting side by side.
- F1, answering over the screensaver (Android 16, Colors dream): PASS 2/2,
  awake and connected about 1.5 s after the tap. Decline PASS; the phone
  stays dreaming. The screensaver and timeout settings were restored.

## Open

- iOS: earpiece-first needs `proximityMonitoringEnabled` and a TestFlight
  run.
- Bluetooth headset: not tested.

## Extra Physical Checks (S21 FE, after F8)

- Video call with a 12 s Wi-Fi gap: both sides showed "Reconnecting…" at
  about 4 s and recovered when Wi-Fi came back. They ended cleanly.
  - Harness note: the video answer action is "Video", not "Yanıtla".
  - The caller's video hang-up is at (646, 2206).
- F2 decline-elsewhere: venus on the phone and on emulator B, both in the
  background. Results, 3/3:
  - phone decline: B stopped ringing 1.1 s and 0.6 s later;
  - phone answer: B stopped ringing 0.6 s later;
  - no stale callkit notification and no missed-call notification.
