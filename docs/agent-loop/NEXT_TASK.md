# Active Task - Crash Reporting And Analytics (MVP-3)

Branch: `call-v2`

Starting SHA: `06a7209`

An MVP exists to learn from users. The app had no crash reporting and no
analytics, and it still depended on Firebase Dynamic Links, which has been
shut down.

## Scope

- Remove `firebase_dynamic_links`. Add `firebase_crashlytics` 4.3.6 and
  `firebase_analytics` 11.4.6, pinned to the FlutterFire set already in use
  (`firebase_core` 3.13.1), so the call-path SDKs stay unchanged.
- Android: the Crashlytics Gradle plugin, 2.9.9, which is compatible with
  google-services 4.3.15.
- `AppTelemetry`:
  - Crashlytics on in release (Flutter and platform errors);
  - Analytics screen views;
  - user id by uid only;
  - events with no personal data: `post_created`, `consultation_booked`,
    `report_submitted`, `user_blocked`, `account_deleted`.
- The privacy text and site mention crash reports and analytics.

## Validation

- `flutter analyze` is clean, and the full suite shows no new failures.
- The Android release build launches on the emulator and Crashlytics
  initializes.
- The iOS release build compiles.
- `pubspec.lock` and `Podfile.lock` stay uncommitted (the user's rule).
