# Physical Android Verification Handoff

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `341cf94`
AUTHORIZATION_SHA: `eabc8dd`
IMPLEMENTATION_SHA: `f7d414c` (F2 server), `bbb0a23` + `613c2f7` (F1),
`8c1b6f6` (F4)
ENDING_SHA: `SELF`

## Devices

| | P1 | P2 |
|---|---|---|
| Model | Galaxy A55 (SM-A556E) | Galaxy S21 FE (SM-G990E) |
| OS | Android 14, One UI 6.1 | Android 16, One UI 8.0 |
| Settings | battery saver on, screensaver while charging, silent mode | none special |
| Network | Wi-Fi only (mobile data off) | Wi-Fi only (mobile data off) |
| Lock | swipe only, no PIN | swipe only, no PIN |

- The caller is always Baris on emulator A. Venus is signed in on the
  phones.
- Release APK `com.yakup.helperly`, sideloaded.
- The phones were taken away before the end of the session. P2 is left
  signed out.

## Findings

1. **F1: answering over the screensaver hid the call screen.** Fixed.
   - Context: the A55 shows a screensaver (dream) while charging.
   - Before the fix: "Yanıtla" on the call notification accepted the call
     and joined Agora, but the call screen stayed behind the dream until
     the user touched the screen. Dart logged
     `accepted_route_navigator_unavailable` every 250 ms.
   - First attempt (`bbb0a23`): `setTurnScreenOn` in `MainActivity`. It
     did nothing, because the activity behind the dream receives the
     intent only once it is visible.
   - Fix (`613c2f7`): `HelperlyApplication` takes a 3 s
     `ACQUIRE_CAUSES_WAKEUP` wake lock when the plugin's accept trampoline
     is created. No `showWhenLocked`.
   - Verified on P1: `Waking up from Dreaming ... helperly:accepted_call`
     at the moment of the tap, and the call screen visible 6 s later with
     no user touch.
   - Regression on P1: background, killed, locked and locked+killed
     answers all pass.
2. **F2: a decline on one device left the callee's killed device ringing
   for ~40 s.** Fix written; not deployed.
   - Evidence: the A55 received only the invite FCM.
     `terminalCallInviteRecipients` sends a `declined` `call_end` to the
     caller only.
   - Fix (`f7d414c`): the callee also gets the `call_end`, over FCM only.
     There is no VoIP push, so iOS is unchanged.
   - Tests: functions 256/256 with the emulator, rules 10/10.
   - **Needs deploy:** `firebase deploy --only functions:onCallInviteUpdated --project connectapp-278b4`.
     After the deploy it must be re-verified on two phones.
3. **F3: a network gap of ~20 s ends the call; there is no reconnect grace
   period.** Not fixed (product decision).
   - P2 Wi-Fi off 5 s: Samsung needed ~17 s more to reassociate. P2's
     Agora rejoined 23.4 s after the drop. Emulator A had already ended
     the call 0.2 s earlier on `userOfflineDropped`.
   - P2 Wi-Fi off 45 s: A ended at ~20 s. P2 kept showing "Connected"
     for the whole outage, then cleaned up 5 s after Wi-Fi returned. No
     native notification was left behind.
   - Candidate: keep the call in a "Reconnecting" state for 20-30 s after
     `userOfflineDropped` or `connectionLost` before ending it.
4. **F4: a native Accept was dropped when Firestore saw the invite
   first.** Fixed in source; the device race was not reproduced again.
   - Seen on P1, app in the background: the Firestore listener saw the
     invite 5 s before the FCM push showed the native call. The invite was
     owned by a Flutter prompt still waiting for the app to resume.
   - The native Accept was suppressed as a duplicate; the user saw Home
     and the call rang out.
   - Fix (`8c1b6f6`): a native accept also wins when the Flutter owner's
     prompt is not on screen yet. A shown prompt keeps its current
     behaviour.
   - New regression test: RED before the fix, GREEN after.
   - After the fix, 5 background answers on P1 all passed, but all 5 had
     the native call arrive first. The race depends on FCM timing.
5. **F6: Android rings 4-5 s later than it could.** Not fixed.
   - `onCallInviteCreated` sends the Android FCM only after the iOS VoIP
     push and the 4 s delayed APNS alert check
     (`CALL_ALERT_FALLBACK_DELAY_MS`). Venus has an iOS VoIP token.
   - The call UI appeared 6-7 s after the caller tapped, on every phone
     scenario.
   - Candidate: send the Android FCM before the APNS alert wait.
6. **E1 (environment): after a reboot of P2, FCM was dead for over
   8 minutes.**
   - GMS reported `connected=mtalk.google.com`, but "Seen good heartbeat
     in last connection? false". FCM accepted the sends (`serverFcmSent`
     unchanged), and nothing arrived on the device.
   - It stayed that way even after the app was opened once.
   - Toggling Wi-Fi forced a new GMS connection, and the next call rang
     in 6.7 s. Not an app bug, but every FCM-based app is affected.
7. **Side findings:**
   - The `chats` list queries (`participants`/`users` `arrayContains`)
     fail with `PERMISSION_DENIED`. The rules' `keys().hasAny` OR cannot
     be proven for those queries. This is unrelated to calls and has
     existed for a while.
   - The missed-call notification is disabled on purpose
     (`missedCallNotification.showNotification: false`). It is a product
     gap compared with WhatsApp.
   - One UI sometimes collapses the call notification in the expanded
     shade ("Genişlet"). The heads-up notification and the full-screen UI
     are unaffected.

## Validation

**P2 single device, 16/16:** fg/bg/killed/locked/locked+killed ×
answer/decline/cancel, plus killed and locked timeout.
- The call UI appeared 5.3-7.8 s after the caller tapped.
- A decline settled within 5.4-5.7 s, a cancel within 2.5-2.7 s, and a
  timeout after 45-46 s.
- There were no active callkit notifications afterwards and no plain FCM
  notifications.

**P1 single device, 16/16:** the same matrix, under battery saver.
- The first run lost the foreground and background answers to the
  screensaver; that was F1.

**First call on each phone:** the notification prompt appears after login,
then the microphone prompt on the first answer. On P1 this was answered
over the lock screen.
- Both phones report `android_call_permissions` as
  `notificationsAllowed: true, fullScreenIntent: true`.

**Killed-app answer latency on real hardware**, measured from the tap:

| Device / state | `accept_tap` | Agora join |
|---|---|---|
| P2, killed | 5.3 s | 6.7 s |
| P2, Doze + killed | 2.9 s | 4.4 s |
| P1 | 2.4-3.4 s | 4.2-5.4 s |

The emulator measured ~20 s.

**Multi-device, venus on both phones:** answer on one phone, the other in
fg/bg/killed/locked, in both directions. All passed.
- The other phone went silent 3.1-7 s after the answer, via
  `answered_elsewhere` (push or Firestore).
- The call held for 8 s, and no notification was left behind.
- Decline: the other phone in the background stopped in 3.2 s. The other
  phone killed failed; that is F2.

**Power, on P2:** forced Doze (`deviceidle force-idle`, unplugged), Doze
with the app killed, standby bucket `restricted` (45), and `rare` (40).
- All four rang in 6.4-7.8 s and connected.

**Video, on P2:** the first-call camera prompt appeared; video flowed both
ways (P2's real camera seen on A).
- Switching the camera worked.
- Ending from P2 left both sides idle.

**Reboot:** see E1.

**Dart:**
- New test: RED, then GREEN.
- `flutter test test/call_v2 test/multi_device test/android`: +2414 -14.
  The 14 failures are the working-tree guards (Phase 7AW-7BJ).
- `flutter analyze lib test integration_test`: no issues.

**Functions:** `test:call-v2:emulator` 256/256, `test:call-v2:rules`
10/10, `test/call_invites` 22/22.

**Harness** (git-excluded, `test_artifacts/bin`):
- `phys_call.sh`: modes fg, bg, killed, locked, locked_killed, doze,
  doze_killed, restricted, rare.
- `phys_matrix.sh`, `phys_multi.sh`, `dream_call.sh`, `net_call.sh`,
  `notif.sh`.
- `notif.sh` counts only Samsung's active notification list, not the
  archive.

## Not Tested

- Audio between two physical phones, and an outgoing call from a physical
  phone. The phones left before this could run.
- A PIN or secure lock screen (approved, not run). With a PIN, the accept
  trampoline's `requestDismissKeyguard` should show the bouncer.
- Bluetooth headset, earpiece/proximity, a GSM call during an app call.
- F2 after deploy, and F1 on the S21 FE.

## Next-Task Candidates

1. Deploy `onCallInviteUpdated` (F2), then re-check decline-elsewhere on
   two Android devices.
2. F6: send the Android FCM before the 4 s APNS alert wait. Expected gain:
   ~4 s faster ring on Android.
3. F3: a reconnect grace period and a "Reconnecting" UI.
4. iOS verification of steps 2-5 through a controlled TestFlight (needs
   approval).

PHYSICAL_FIX_CLAIM:
- F1: verified on P1 (A55).
- F2, F4: source and tests only.
