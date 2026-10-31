# Crash Reporting And Analytics Handoff (MVP-3)

STATUS: `ready_for_review` (reviewer: Claude, per the user's delegation)

BRANCH: `call-v2`
STARTING_SHA: `06a7209`
IMPLEMENTATION_SHA: `d25e24a`
ENDING_SHA: `SELF`

## Change

- `firebase_dynamic_links` is removed.
- Added `firebase_crashlytics` 4.3.6 and `firebase_analytics` 11.4.6, pinned
  to the existing FlutterFire set (`firebase_core` 3.13.1).
  - A plain `pub add` had upgraded every Firebase package (core 3.15,
    Firestore 5.6.12, messaging, auth). That was rejected to keep the
    physically verified call SDKs, and the iOS F9 fix that depends on
    FlutterFire internals, unchanged.
- Android: Crashlytics Gradle plugin 2.9.9. Plugin 3.x requires
  google-services 4.4.1, and the project uses 4.3.15.
- `AppTelemetry.init()` is called right after `Firebase.initializeApp`.
  - Crashlytics is on in release builds only, for Flutter and platform
    errors.
  - Analytics records screen views and sets the user id to the uid.
  - Five events, with no personal data: `post_created`,
    `consultation_booked`, `report_submitted`, `user_blocked`,
    `account_deleted`.
  - The method is named `init()` because the owner-isolation test forbids
    `.start(` in `main.dart`.
- The privacy text and the regenerated `privacy.html` mention crash reports
  and analytics.

## Validation

- `flutter analyze lib test`: clean.
- Full suite: +2446 -16, all known. 14 working-tree guards fire because
  `pubspec.lock` and `Podfile.lock` are modified locally and intentionally
  uncommitted; the other 2 are test-mode-only integration tests.
- Emulator A, release APK: the app launches signed in, and Crashlytics
  19.4.2 initializes. The project setting `firebase_crashlytics_enabled` is
  false; the user must enable it in the console (`docs/DEPLOY_MVP.md`
  step 5).
- The iOS release build (no codesign) compiles. The first attempt hit a
  transient Xcode `CompileAssetCatalogVariant` error after the restart; the
  retry passed.
