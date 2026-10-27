# Active Task - Android Build Repair

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `7430a15`

Authorized by the user on 2026-10-27 after the emulator call test report.

## Problem

The Android app does not build with the installed Flutter 3.35.4:
- Flutter rejects AGP 8.1.0. The minimum is 8.1.1.
- `flutter_local_notifications` requires core library desugaring.
- NDK 21 is pinned.

After the build is fixed, startup logs `flutter_stripe initialization failed`,
because `MainActivity` is not a `FlutterFragmentActivity`. That aborts the
rest of the foreground bootstrap (subscriptions, dynamic links).

## Goal

The Android debug app builds, starts without the Stripe failure, and keeps the
verified foreground call behavior. iOS is untouched.

## Allowed Files

- `android/settings.gradle`, `android/build.gradle`,
  `android/gradle/wrapper/gradle-wrapper.properties`
- `android/app/build.gradle`
- `android/app/src/main/kotlin/com/example/connect_app/MainActivity.kt`
- `android/app/src/main/res/values/styles.xml`,
  `android/app/src/main/res/values-night/styles.xml`
- `docs/agent-loop/NEXT_TASK.md`, `docs/agent-loop/STATE.json`,
  `docs/agent-loop/HANDOFF.md`

## Strict Non-Goals

- No Dart, iOS, backend, rules or dependency version changes.
- `pubspec.lock` stays unchanged.
- No package id change.
- No deploy and no store upload.

## Validation

- `flutter build apk --debug`
- Install on two Android 16 emulators.
- No Stripe initialization failure at startup.
- Foreground audio and video calls connect and tear down with zero Firestore
  fallbacks.
- `git diff --check`
- Diff limited to the allowed files.

## Commit And Handoff

- Implementation commit:
  `build(android): make the Android app build and start on current Flutter`.
- Handoff commit: `chore(agent-loop): record android build review handoff`.
- Push `call-v2`.
