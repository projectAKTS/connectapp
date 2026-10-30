# Active Task - Show An Answered Call Over The Lock Screen (F7)

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `64f0655`

## Review Of F3b (Claude, 2026-10-30)

Accepted: `4c16626`. On the A55 the caller now shows "Reconnecting…" within
5 s of a Wi-Fi gap, and a mute does not trigger it.

## Problem (F7)

The A55 had a temporary PIN; the call was answered from the plugin's
lock-screen call UI.
- Audio connected.
- `MainActivity` stayed behind the keyguard, because it has no
  `showWhenLocked`.
- The manager waits for `_isAppActuallyForeground`, so it logged
  `accepted_route_navigator_unavailable` every 250 ms and never opened the
  call screen. The user could not see or end the call without unlocking.

## Goal (WhatsApp-like)

An answered call shows the call screen over the lock screen without asking
for the PIN. The rest of the app stays behind the keyguard.
1. Android `MainActivity` gets a `connectapp/callLockScreen` method channel
   with `setShowOverLockScreen(bool)`. API 27+ uses
   `setShowWhenLocked`/`setTurnScreenOn`, older versions the window flags.
2. A new `lib/services/call_lock_screen.dart` holds the state. It is
   Android-only, de-duplicated, fire-and-forget, and swallows errors.
3. `CallSessionManager` turns it on at `accept_tap`. It turns it off:
   - at the terminal-signal publish;
   - when session state is detached;
   - on a failed route rollback;
   - on accepted-native-watch cleanup;
   - on test idle;
   - when an accept ends busy, terminal, ignored or failed with no active
     call.
4. iOS is unchanged (CallKit owns its lock screen).

## Allowed Files

- `android/app/src/main/kotlin/com/yakup/helperly/MainActivity.kt`
- New `lib/services/call_lock_screen.dart`
- `lib/services/call_session_manager.dart` (the calls above only)
- `test/call_v2/real_flow/call_v2_background_audio_media_integration_test.dart`
  (new test)
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`

## Strict Non-Goals

- No server change, no deploy, no TestFlight.
- Ringing, decline and the plugin's lock-screen UI stay unchanged.
- Never dismiss the keyguard (no `requestDismissKeyguard`).

## Validation

- New test: a background-accepted call turns the lock-screen flag on, and
  ending the call turns it off. RED before, GREEN after.
- `flutter test test/call_v2 test/multi_device test/android`: no new
  failures beyond the known working-tree guards.
- `flutter analyze lib test integration_test`: clean.
- Physical, on the A55 with the temporary PIN 1234:
  - locked and locked_killed answers show the call screen and connect;
  - after the call ends, the lock screen is back (PIN required);
  - then remove the PIN.

## Commit And Handoff

- Implementation: `fix(calls): show an answered call over the Android lock screen`.
- Handoff: `chore(agent-loop): record lock screen call review handoff`.
- Push `call-v2`.
