# Android Incoming Call Handoff

STATUS: `ready_for_review`

BRANCH: `call-v2`
STARTING_SHA: `e65e3c5`
AUTHORIZATION_SHA: `35c3aa6`
IMPLEMENTATION_SHA: `11d46e0`
ENDING_SHA: `SELF`

## Changes

Android call invites that arrive while the app is in the background or
killed now show the `flutter_callkit_incoming` ringing UI (caller name,
Decline/Answer, ringtone, full screen when locked). Before this change they
showed only a plain FCM notification. Every iOS code path is unchanged; each
new branch is gated on `Platform.isAndroid`.

1. Server (`call_invite_fcm_message.js`, `index.js` `onCallInviteCreated`):
   - The call-invite FCM message has no top-level `notification`. Android
     uses `priority: high` and a 40 s TTL.
   - iOS keeps the same title, body and sound through
     `apns.payload.aps.alert`.
   - Token selection is unchanged.
   - **Not deployed.**
2. `android_incoming_call.dart` (new): a pure `decide()` for push to UI,
   plus `apply()`.
   - Skips pushes older than 40 s, based on `sentTime`.
   - Ring time is 45 s minus the push age.
   - id = `normalizeCallkitId(inviteId, channel)`; the invite fields go in
     `extra`.
   - `call_end` ends that id.
3. Background handler (`main.dart`):
   - Presents or ends the plugin UI.
   - Relays a killed-app Decline over HTTPS `callInviteTransition`
     (`decline`, `endReason: callkit_decline`).
   - The relay is **not awaited**. FlutterFire runs background messages one
     at a time and blocks on each handler (`latch.await()`). An awaited relay
     held back the caller's `call_end` until the 45 s timeout; this was seen
     and fixed on the emulator.
4. `notification_service.dart`, Android branches:
   - Plugin events are bound.
   - `_listActiveCallkitCalls` includes Android, so the manager sees the
     plugin UI as the incoming owner.
   - When the app is not active, `call_invite` presents the plugin UI
     instead of a local notification.
   - `call_end` ends the plugin UI.
   - `_endActiveCallkitCall` uses `endCall` / `endAllCalls`.
   - A cold-start accept resumes from `activeCalls()` `isAccepted` through
     the existing `_recoverAcceptedCallkitEvent`.
5. `call_session_manager.dart`: the exact native audio-session gate for a
   CallKit-accepted callee applies only where CallKit activates audio, i.e.
   not on Android. Without this, an accepted Android call stalled until
   `accepted_joining_timeout`. iOS still gets `true`.
6. `AndroidManifest.xml`: `MainActivity` `launchMode` `singleTop` ->
   `singleTask`. The plugin's accept intent was starting a second Flutter
   engine, which caused a double media join and `agora_failure`.

## Validation

- `flutter test test/android/`: 10/10.
- Server `node --test test/call_invites/*.test.js` on Node 22.20.0: 10/10.
- Full `flutter test` at `376940d` in a clean detached worktree: +2427 -2.
  - The 2 failures are the pre-existing HELPERLY_TEST_MODE wrappers in
    `test/call_message_stability_test.dart`.
  - In the main checkout, 4 Call V2 working-tree guards (7BG-7BJ) also fail.
    They run `git status --untracked-files=all` and flag the user's untracked
    Aider/architecture files, which are intentionally preserved.
  - Before commit, the 10 guards that check `git diff HEAD` also fail. They
    pass once the work is committed.
- `flutter analyze`: no issues. `git diff --check`: clean.
- Emulator E2E: two Android 16 (API 36) emulators, two real connected
  accounts, with the current production server (which still sends the
  `notification` block).

| Scenario (callee B) | Result |
|---|---|
| background, Answer | both connected 10.3 s after Answer |
| killed, Answer (cold start) | both connected 12.6 s after Answer |
| background, Decline | caller idle and UI dismissed in 6.0 s |
| killed, Decline | caller idle in 9.6 s (was a 44 s timeout before the relay) |
| background, caller cancel | UI dismissed in 4.5 s |
| killed, caller cancel | UI dismissed in 4.4 s |
| background-only process left by a killed run: Decline | 10.2 s |
| background-only process left by a killed run: cancel | 4.5 s (was 45 s with an awaited relay) |
| foreground audio, ended by caller | ring 3.0 s, connected 3.9/6.1 s |
| foreground video, ended by callee | ring 3.2 s, connected 4.1/6.7 s |

The call UI appeared on B 5.5-6.7 s after dial. After each scenario there
were 0 leftover callkit notifications.

## Known gaps

1. Until `onCallInviteCreated` is deployed, Android also shows the old plain
   FCM notification next to the call UI (`plainFcmNotifications` counted in
   the matrix). The user runs the deploy:
   `firebase deploy --only functions:onCallInviteCreated --project connectapp-278b4`.
   Never deploy unscoped functions.
2. Answered elsewhere: multi-device ringing and stale active call (next task).
3. Background Decline takes 6-10 s to clear the caller; not investigated.
4. The package id is still `com.example.connect_app`.
5. A force-stopped app receives no FCM messages. This is Android platform
   behavior.
6. Not tested on physical Android phones.

PHYSICAL_FIX_CLAIM: `NONE` (emulators only; physical Android and post-deploy
verification pending)
