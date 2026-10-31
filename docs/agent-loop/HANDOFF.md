# iOS Native Firestore Crash Handoff (F9, With F8b And F9b)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `ec46d49`
IMPLEMENTATION_SHAS:
- `1f66093`: F8b, iOS receiver-first with proximity
- `bdeea79`: F9, native Firestore through FlutterFire's cache
- `82f7d24`: F9b, callee media without a CallKit call
ENDING_SHA: `SELF`

## Findings On The User's iPhone 16 Pro Max (iOS 26.6.2, Cable Dev Build)

1. **Crash (F9).** Killed app, locked phone, the user tapped the incoming-call
   notification. The app crashed about 1 s after launch (SIGABRT, two
   identical reports). Dart's first `enableNetwork` reached
   `getFIRFirestoreFromAppNameFromPigeon`, then `-[FIRFirestore
   setSettings:]` on an already started instance.
   - Cause: the notification response handler's native `syncInviteStatus`
     started Firestore via `Firestore.firestore()` before Dart.
   - This has been in place since 255269c (2026-08-05).
2. **Silent accepted call (F9b).** After F9 the app opened and accepted, then
   waited forever on `audioSessionReadinessWaiting`. There was no CallKit call,
   so no CallKit audio session ever activated.
3. **No VoIP/CallKit for a killed app (open).** PushKit last arrived at
   23:57:48, with the app in the foreground. Calls at 23:59, 00:09, 00:18
   (after a reboot) and 00:37 came only as the APNs alert fallback, so there
   was no accept/decline call UI.
   - Likely cause: a test-environment artifact. The cable build has a sandbox
     VoIP token, and the server tries production first. A stale TestFlight
     production VoIP token is accepted but never delivered, so there is no
     `BadDeviceToken` retry in sandbox.
   - Not verified: function logs are not readable from this CLI (active
     project `helperly-call-v2-dev`), and a syslog tool install was denied.
   - Next step: a TestFlight build, which uses the production environment.

## Fixes

- **F9:** `flutterFireFirestore()` reuses FlutterFire's cached instance, or
  creates it as FlutterFire would and registers it. The registration uses the
  default settings and FlutterFire's dispatch queue, via
  `FLTFirebaseFirestoreUtils` and `FLTFirebaseFirestoreReader` at runtime. If
  the cache cannot be reached, it skips the native write; Dart's recovery
  owns it.
- **F9b:** `_calleeMediaNeedsNativeAudioSession` keeps the iOS audio-session
  gate only when the native CallKit list has the accepted call. If the list
  fails, the gate stays.
- **F8b:** iOS audio is receiver-first, with
  `UIDevice.isProximityMonitoringEnabled` over `connectapp/callProximity`.

## Validation

- F9b tests: a notification answer starts media (RED -1 before, GREEN
  after); a CallKit answer still waits for the CallKit audio session. The
  background audio file passes 17/17.
- Suite: +2433 -14. All failures are the known Phase 7AW-7BJ working-tree
  guards (more of them fired while `call_session_manager.dart` was
  uncommitted).
- `flutter analyze` is clean, and the iOS release build passes.
- iPhone:
  - F8b: the user confirmed the receiver/speaker toggle, and the screen
    blanks at the ear.
  - F9: no crash on the notification answer, and the native accept synced
    (`invite_status_synced`).
  - F9b: killed and locked, a notification answer connected at 00:37:27 with
    audio from the iPhone (18 kbps). No crash reports since the fix.

## Note

All phone builds today, the Android APKs and the iOS cable builds, were built
without `CALL_V2_REAL_FLOW_ENABLED`, so they used the legacyV1 connection
system, the same as yesterday's APKs. TestFlight builds pass
`CALL_V2_REAL_FLOW_ENABLED=true`, `CALL_V2_REAL_FLOW_DEV_CALLABLE=true`
and `CALL_V2_BUILD_COMMIT`.

## TestFlight Result (Build 202610310039, Commit d673113)

- Upload: the first try failed with "PLA Update available" and no "iOS
  Distribution" certificate. The user accepted the new Apple Developer
  agreement, and the same archive then uploaded.
- First call, TestFlight build installed as an update: still the APNs
  fallback notification. Production function logs (read-only): VoIP went to
  the one token with `sent: 1`, `failed: 0`, `environment: production`.
  Apple accepted it, but the device showed no CallKit UI.
- After the user deleted the app and reinstalled the same TestFlight build:
  - the native CallKit full-screen UI appeared on the lock screen;
  - the answer connected at 01:12:31 with audio flowing;
  - the call ended cleanly.
- Conclusion: the VoIP-to-CallKit path works. A delete and reinstall resets
  both a stale VoIP registration and iOS's PushKit penalty for an app that
  did not report calls (the F9 launch crashes today). The VoIP issue was not
  a server or code defect in the current build.

## Final iOS Checks (TestFlight 202610310039, 01:17)

The app was killed and the phone locked; the call was answered from the
CallKit UI.
- Audio came from the receiver (the user confirmed it).
- Wi-Fi was off for about 15 s on the iPhone. The caller logged
  `remote_audio_flow false` at 01:17:59, so it showed "Reconnecting…".
  Audio returned at 01:18:19 without a drop, and the call ended cleanly at
  01:18:25.

The calling phase is closed: Android (A55, S21 FE) and iOS (iPhone 16 Pro
Max) are physically verified for this round.
