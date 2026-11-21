# Kindupp Android QA and Rebrand Verification

**Candidate:** `feature/kindupp-rebranding` (source only; no Play upload).
**Package identity preserved:** `com.yakup.helperly`.

## Automated checks

Executed checks:

- `flutter analyze lib test`: passed, no issues.
- Focused `flutter test test/mvp/payment_feature_flags_test.dart
  test/i18n/report_reason_test.dart`: passed (3 tests).
- Full `flutter test`: 2,540 passed, 16 failed. The failures include
  call-v2 source-isolation tests that assert only their allowlisted files are
  changed; this Phase 3 branch intentionally changes other files. Run again
  from a clean candidate after review.
- `node --test connect_functions/test/payments/paid_sessions.test.js`: passed
  (4 tests); JavaScript syntax checks passed.
- Full Functions unit run excluding emulator-dependent rules tests: 202 passed,
  1 failed because `test/call_v2/start_call_v2.test.js` requires
  `FIRESTORE_EMULATOR_HOST`; 3 tests skipped. Emulator attempt did not start
  because Firebase CLI could not find a Java runtime. With `JAVA_HOME` pointed
  to the installed JDK 17, the full suite did start against local emulators;
  see the iOS QA report for combined suite counts and the project-ID mismatch.
- `flutter build apk --release --no-pub`: failed at Java compilation because
  the generated registrant references the dev-only
  `dev.flutter.plugins.integration_test.IntegrationTestPlugin`, which is absent
  from the release classpath. The current SDK also warns this app compiles
  against Android API 35 while several plugins request API 36, and warns about
  Kotlin Gradle plugin 1.8.22.

Build output is a local QA artifact only. Do not upload or distribute it as a
production release.

## Manual staging/device checklist

- [ ] Launcher/app switcher displays Kindupp in English and French.
- [ ] Email/password, Google, and Apple sign-in paths work; OAuth return uses
      the existing registered scheme/client.
- [ ] FCM token registration and ordinary message notifications work.
- [ ] Incoming call notification opens/accepts/declines correctly in foreground,
      background and locked states; existing app identity is unchanged.
- [ ] Audio/video calls connect over Agora; no recording behavior is introduced.
- [ ] Settings opens Kindupp Privacy/Terms draft URLs and support site; failure
      to open URLs is handled.
- [ ] Payment setup route shows the disabled screen. Free call booking shows no
      price/payout and still creates the intended free consultation.
- [ ] Report/block flows work; French “Compte de mineur” stores the stable
      reason ID `Underage account`.
- [ ] In-app account deletion completes for a disposable staging account and
      retained records match the reviewed disclosure.

No production Firebase configuration or app publication is part of this QA.
