# Active Task - Android Full-Screen Incoming Call

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `e65e3c5`

Authorized by the user on 2026-10-27 ("onerdigin sekilde baslayalim onay
veriyorum"). Sequence: build repair (done), then this task, then
answered-elsewhere.

## Problem

On Android, when the app is in the background or killed, an incoming call
appears only as a plain FCM notification: no ringing full-screen UI and no
accept/decline. This was verified on two Android 16 emulators.

Causes:
- `firebaseMessagingBackgroundHandler` only initializes Firebase.
- The server sends call invites to Android with a top-level `notification`
  block, so Android shows a plain notification itself.
- Android never presents the `flutter_callkit_incoming` UI.
- The Android paths for ending the native call UI and for recovering a
  cold-start accept are iOS-only.

## Goal

When the app is not in the foreground, an Android call invite shows the
`flutter_callkit_incoming` full-screen ringing UI with Accept/Decline.
- Accept opens the app and joins through the existing accept flow, including
  from a cold start.
- Decline, caller cancel and timeout dismiss the UI.

Foreground behavior (the in-app prompt) and every iOS path stay unchanged.

## Allowed Files

- `lib/main.dart` (background handler only)
- new `lib/services/android_incoming_call.dart`
- `lib/services/notification_service.dart`, Android branches only:
  - present when not foreground
  - end the native UI on `call_end`
  - `_endActiveCallkitCall` on Android
  - cold-start accepted recovery from `activeCalls()`
- `lib/services/call_session_manager.dart` — only the exact audio-session
  gate for a CallKit-accepted callee. iOS waits for CallKit audio activation;
  Android has none. Added 2026-10-27 after emulator evidence: the accepted
  Android call stalled until `accepted_joining_timeout`.
- `android/app/src/main/AndroidManifest.xml`: `MainActivity` `launchMode` only.
  The plugin's accept intent otherwise starts a second `MainActivity`, which
  means a second Flutter engine and a double media join. Seen on the emulator
  as `agora_failure`.
- `connect_functions/index.js` (`onCallInviteCreated` FCM message shape only)
- new `connect_functions/call_invites/call_invite_fcm_message.js` and tests
- new tests under `test/android/**`
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`

## Required Implementation

1. Server: build the call-invite FCM message without a top-level
   `notification`. Use Android `priority: high` and a 40 s TTL.
   - Keep the existing title/body/sound for iOS in `apns.payload.aps.alert`,
     so iOS display is unchanged.
   - Token selection stays unchanged.
2. Background handler (Android only): `call_invite` presents CallKit, with the
   id taken from `normalizeCallkitId(inviteId, channel)` and the invite fields
   in `extra`.
   - Skip pushes older than 40 s, based on FCM `sentTime`.
   - The ring duration is 45 s minus the push age.
   - `call_end` ends that CallKit id.
3. Foreground handler, Android, app not active: present the same CallKit UI
   instead of the local notification. `call_end` ends it.
4. `_endActiveCallkitCall` on Android: `FlutterCallkitIncoming.endCall(id)`.
   `_listActiveCallkitCalls` includes Android, so the manager sees the plugin
   UI as the incoming owner.
5. Android cold start: `activeCalls()` entries with `isAccepted` feed the
   existing `_recoverAcceptedCallkitEvent`.
6. Unit tests for the push decision and params, and for the server message
   shape.
7. Killed-app decline: when the app is not running, the plugin delivers the
   Decline tap only to the background engine, where nothing listens, so the
   caller rang until timeout (44 s on the emulator). Added 2026-10-27: the
   background handler listens for this CallKit id's outcome during the ring
   window and reports a decline through the existing HTTPS
   `callInviteTransition` (`decline`, `endReason: callkit_decline`).
   - The listener must not be awaited. FlutterFire runs background messages
     one at a time and blocks on each handler
     (`FlutterFirebaseMessagingBackgroundService`, `latch.await()`).
   - Seen on the emulator: an awaited listener held back the caller's
     `call_end` until the 45 s timeout.

## Strict Non-Goals

- No iOS native or iOS Dart behavior change.
- No change to the accept/terminal state machine, rules, dependency versions,
  or package id.
- The deploy of `onCallInviteCreated` is run by the user after review.
- No TestFlight or store upload.

## Validation

- New Dart and server unit tests.
- The full Flutter `test/` folder (pre-existing failures noted).
- `flutter analyze`.
- Server `node --test`.
- Emulator E2E, with a deployed or locally simulated data-only push:
  - callee in background, then accept;
  - callee killed, then accept;
  - decline;
  - caller cancel dismisses the UI;
  - foreground calls unchanged.
- `git diff --check`.

## Commit And Handoff

- Implementation commit:
  `feat(android): full-screen incoming call when app is not in foreground`.
- Handoff commit: `chore(agent-loop): record android incoming call review handoff`.
- Push `call-v2`.
