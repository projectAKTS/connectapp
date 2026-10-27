# Android Build Repair Handoff

STATUS: `ready_for_review`

BRANCH: `call-v2`
STARTING_SHA: `7430a15`
AUTHORIZATION_SHA: `cab349d`
IMPLEMENTATION_SHA: `ad786b8`
ENDING_SHA: `SELF`

## Changes (Android only)

- AGP 8.1.0 -> 8.7.3, in both the plugins block and the legacy buildscript
  classpath. Flutter 3.35.4 rejects anything below 8.1.1.
- Gradle wrapper 8.5 -> 8.10.2.
- Core library desugaring enabled (`desugar_jdk_libs` 2.1.4), as required by
  `flutter_local_notifications`.
- `ndkVersion = flutter.ndkVersion` replaces the pinned NDK 21.
- `MainActivity` extends `FlutterFragmentActivity`.
- Launch/Normal themes use AppCompat/MaterialComponents parents, as
  `flutter_stripe` requires.

Before this change, Stripe init threw on every resume and skipped
subscription and dynamic-link setup.

## Validation

- `flutter build apk --debug` passes from `call-v2`. `pubspec.lock` is
  unchanged.
- Two Android 16 (API 36, Google Play) emulators, logged in by the user as
  two connected accounts:
  - Startup shows no `flutter_stripe initialization failed` and no
    `Foreground bootstrap failed`.
  - Foreground audio call, ended by the callee: ring 2.7 s, accept to callee
    connected 10.8 s (first call after app start), teardown 4-6 s.
  - Foreground video call, ended by the caller: ring 2.7 s, accept to
    connected 4.1 s, teardown 3-5 s. Remote video was rendered on both sides.
  - Earlier session with the same changes: 3 more audio calls passed with
    accept to connected of about 3.3 s.
  - Every transition went through `callInviteTransition`, with 0 Firestore
    fallbacks.
- `git diff --check` is clean, and the diff touches only the 7 allowed files.

## Known gaps (not in scope, recorded for the next tasks)

1. When the app is in the background, an incoming call appears only as a
   plain FCM notification. There is no full-screen ringing UI and no
   accept/decline, because `firebaseMessagingBackgroundHandler` is empty.
   Opening the app shows the prompt within about 2 s, and accepting connects.
2. Multi-device: an accept does not record which device accepted. Baris's
   iPhone kept call 1 active after the emulator accepted it, then declined
   call 2 with `busy_active_call`. This was proven from the iPhone's CallKit
   ledger: the ledger ids are the hex of invite ids `PAXoGi…` and
   `ZJmRINMo…`.
3. The package id is still `com.example.connect_app`, which Play Store
   rejects.
4. A force-stopped app receives no FCM messages. This is Android platform
   behavior.

PHYSICAL_FIX_CLAIM: `NONE` (emulators only; physical Android pending)
