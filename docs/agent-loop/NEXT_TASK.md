# Active Task - Android Release Readiness

Branch: `call-v2` (known-good tags `stable-calls-oct-26`, `stable-calls-oct-27`;
do not modify them or `stable/calls-oct-26`)

Starting SHA: `38bbd25`

Authorized by the user on 2026-10-28:
- "sen bu uygulamanin engineerisin artik sen kararlari ver": Claude reviews
  handoffs and picks the next task. No ChatGPT review round.
- The Android package id becomes `com.yakup.helperly`, the same as the
  iOS bundle id.
- A physical Android phone is available for the next step (step 5).

## Review Of Steps 2 And 3 (Claude, 2026-10-28)

- Step 2 (`11d46e0`, handoff `d7f208b`): accepted.
  - A Decline on a backgrounded (not killed) app can be relayed twice, by
    the main isolate and the background isolate. This is harmless:
    `decline` applies only to `ringing`.
- Step 3 (`50766c4`, `8c2d0ee`, `f271b20`, handoff `38bbd25`): accepted.
  - Extra E2E during review: B killed answers from the plugin UI while C
    rings in the foreground.
    - The accept carried the installation id (`accept_tap
      identifierFieldPresent: true`).
    - The server pushed to exactly C (`identifierPresent: true,
      fcmCount: 1`), and C was dismissed.
  - The cold-start gap in the step-3 handoff did not occur.
  - Killed answer to connected took ~28 s on the debug build: activity
    3.7 s, Dart start to accept 6.8 s, server accept 3.7 s, Agora join
    4.3 s. Debug JIT dominates; this task measures the release build.

## Problem

Every Android test so far used the debug APK. The release build has never
been built or run.
- R8 shrinking (`minifyEnabled true`) can strip classes that plugins load
  reflectively. This breaks only release builds. Affected plugins include
  `flutter_callkit_incoming`, Agora, FCM and Stripe.
- The package id `com.example.connect_app` is rejected by Play. It must
  change before real devices collect push tokens and installation ids
  under it.
- Android 14+ can deny the full-screen intent. The app does not know
  whether it has it.

## Goal

A release APK under `com.yakup.helperly` installs and runs on the
emulators. The call matrix passes on it, so step 5 can go straight to a
physical phone.

## Allowed Files

- `android/app/build.gradle`: `namespace` and `applicationId` only.
- `android/app/src/main/AndroidManifest.xml`: the `package` attribute only.
- Move `android/app/src/main/kotlin/com/example/connect_app/MainActivity.kt`
  to `android/app/src/main/kotlin/com/yakup/helperly/MainActivity.kt` and
  change its `package` line.
- `android/app/google-services.json`: replace it with the user-supplied
  file or the approved CLI output. It holds only Firebase client config.
- `lib/services/firebase_options.dart`: the `android` options only.
- `android/app/proguard-rules.pro`: keep rules, only for release failures
  that were actually observed.
- `lib/services/notification_service.dart`: a startup diagnostic for the
  Android notification and full-screen-intent permission state. No new UI.
- Tests under `test/android/**`.
- `docs/agent-loop/NEXT_TASK.md`, `STATE.json`, `HANDOFF.md`.

## Required Implementation

### Part 1 - Release build on the current package

This separates shrink failures from rename failures.

1. `flutter build apk --release`, signed with the debug key for sideloading.
   A real upload key is a separate decision before Play.
2. Install it on A, B and C. Run the single-device matrix and the
   multi-device scenarios.
3. On a failure, read the release logcat for `ClassNotFoundException`,
   `NoSuchMethod` or missing plugin classes. Add the narrowest keep rule
   and repeat.

### Part 2 - Package id `com.yakup.helperly`

4. Firebase needs an Android app for `com.yakup.helperly` in
   `connectapp-278b4`, plus the debug signing key's SHA-1 and SHA-256 for
   Google Sign-In. Either:
   - the user adds it in the Firebase Console and supplies
     `google-services.json`; or
   - with the user's per-action approval, Claude runs
     `firebase apps:create android` and `firebase apps:android:sha:create`.
5. Leave the old `com.example.connect_app` Firebase app as is.
6. Rename `namespace`, `applicationId`, the manifest `package`, and the
   MainActivity package and directory. Set the `android` `appId` in
   `firebase_options.dart` to the new app.
7. After the rename the emulators need reinstall and re-login. The user
   types the passwords. Update the local `test_artifacts/bin` scripts'
   package name.

### Part 3 - Permission state diagnostics

8. At NotificationService startup on Android, record a push diagnostic
   with:
   - whether notifications are allowed;
   - `FlutterCallkitIncoming.canUseFullScreenIntent()` (Android 14+).
   Never throw.
9. On the emulator, deny the full-screen intent
   (`adb shell appops set <pkg> USE_FULL_SCREEN_INTENT deny`). Check that a
   killed-app call still rings as a heads-up notification and can be
   answered. Restore the permission afterwards.

## Strict Non-Goals

- No new permission UI, no Play upload, and no upload key.
- No change to call logic, the server, rules, iOS, or dependency
  versions.
- No deploy. No TestFlight. No physical calls; those are step 5 and need
  approval.
- Do not delete or modify the old Firebase Android app or any production
  data.

## Validation

- `flutter build apk --release` succeeds for both packages.
- Release E2E on emulators under `com.yakup.helperly`:
  - foreground audio and video;
  - background/killed × answer/decline/cancel;
  - multi-device killed and background in both directions, where the other
    device must be silent within 15 s;
  - killed answer to connected time.
- The full-screen-intent denied fallback (item 9).
- `flutter test test/android test/multi_device`, the full `flutter test`
  (pre-existing failures noted), and
  `flutter analyze lib test integration_test`.
- `git diff --check`.

## Commit And Handoff

- Implementation commits:
  - `build(android): release build and package id com.yakup.helperly`;
  - plus `fix(android): ...` for any keep rules.
- Handoff commit:
  `chore(agent-loop): record android release readiness review handoff`.
- Push `call-v2`.
