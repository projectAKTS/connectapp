# Lock Screen Call Handoff (F7)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `64f0655`
AUTHORIZATION_SHA: `34b5915`
IMPLEMENTATION_SHA: `754980a`
ENDING_SHA: `SELF`

## Change

An answered call now shows its call screen over the Android lock screen,
like WhatsApp.
- `MainActivity` exposes `connectapp/callLockScreen` with
  `setShowOverLockScreen(bool)`: `setShowWhenLocked` and `setTurnScreenOn` on
  API 27+, window flags below that. The keyguard is never dismissed.
- `lib/services/call_lock_screen.dart` is Android-only, de-duplicated,
  fire-and-forget, and never awaited in call paths.
- `CallSessionManager` turns it on at `accept_tap`. It turns it off:
  - at the terminal-signal publish;
  - on `_detachSessionState`;
  - on `_rollbackFailedRouteSession`;
  - on accepted-native-watch cleanup;
  - on `forceIdleForTest`;
  - when an accept ends busy, terminal, ignored or failed with no active
    call.

Why: with a PIN on the A55, an answer from the plugin's lock-screen UI
connected audio, but `MainActivity` stayed stopped behind the keyguard. The
route waited for `_isAppActuallyForeground` (log:
`accepted_route_navigator_unavailable` every 250 ms). The user could neither
see nor end the call.

## Validation

- New test, "an answered call shows over the lock screen until it ends (F7)":
  RED (`shown` false after the accept), then GREEN. Its file passes 15/15.
- `flutter test test/call_v2 test/multi_device test/android`: +2438 -4. All 4
  failures are the known Phase 7BG-7BJ working-tree guards.
- `flutter analyze lib test integration_test`: clean.

Physical runs: A55 with the temporary PIN 1234, on `app-release-f7.apk`. The
PIN was removed afterwards.

| Run | Before F7 | F7 |
|---|---|---|
| PIN, locked answer | FAIL: audio only, no call screen | PASS 2/2: call screen over the keyguard, connected, ended from the phone |
| PIN, locked, app killed | not reachable | PASS 2/2 |
| PIN, locked decline | PASS | PASS |
| After the call | n/a | `isKeyguardShowing=true`, `occluded=false`, app window not visible, so the PIN is asked again |
| Unlocked regression: fg, bg, killed, locked and locked_killed answers, bg decline | | PASS 6/6 |

## Notes

- Foreground in-app ring latency is 1.08 s after the caller's tap
  (Firestore 0.69 s, FCM 1.03 s). The harness's fg "ring" figure of ~6 s is
  uiautomator overhead.
- Harness: with a PIN, HOME does nothing under the keyguard, so
  `locked_killed` must unlock first, then HOME, kill and lock.
