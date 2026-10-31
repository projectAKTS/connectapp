# Active Task - Earpiece First With Proximity On iOS (F8b)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `3f9561d`

## Review Of F8 (Claude, 2026-10-30)

Accepted: `a41c564`.
- S21 FE: earpiece default, the speaker toggle, the proximity lock and mute
  are all verified.
- Extra checks: a video call through a Wi-Fi gap, and F2 decline-elsewhere
  3/3 on the phone.

## Goal

Bring F8 to iOS, WhatsApp-like. The user approved an iPhone test, by cable
or through TestFlight.
1. `callStartsOnSpeaker`: audio is earpiece-first on iOS too; video stays
   on the speaker.
2. `CallProximity` also calls the channel on iOS.
3. `AppDelegate` gets `connectapp/callProximity`; `setProximityScreenOff`
   sets `UIDevice.current.isProximityMonitoringEnabled`.

## Allowed Files

- `lib/services/call_audio_route.dart`
- `ios/Runner/AppDelegate.swift` (the new channel only)
- `test/call_v2/real_flow/call_audio_route_test.dart`
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`

## Strict Non-Goals

- No CallKit, PushKit or audio-session change.
- No server change, no deploy.
- No TestFlight upload without the user's per-action approval.

## Validation

- The route test is updated for iOS; the suite has no new failures, and
  analyze is clean.
- Physical iPhone:
  - an audio call starts on the receiver;
  - proximity blanks the screen at the ear;
  - the speaker toggle works;
  - answers work from killed, background and the lock screen;
  - the F3/F3b reconnect works through a Wi-Fi gap.
  - The iPhone is never called while it is signed in as Baris.

## Commit And Handoff

- Implementation: `feat(calls): start iOS audio calls on the receiver with proximity`.
- Handoff: `chore(agent-loop): record iOS earpiece review handoff`.
- Push `call-v2`.
