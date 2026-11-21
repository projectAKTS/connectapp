# KINDUPP iOS QA and Rebrand Verification

**Candidate:** `feature/kindupp-rebranding` (source only; no App Store upload).
**Bundle identity preserved:** `com.yakup.helperly`.

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
- `flutter build ios --release --no-codesign --no-pub`: passed; built
  `build/ios/iphoneos/Runner.app` (154.7 MB). It is unsigned and was not
  installed or submitted.
- Full Functions run in local Firebase emulators: 423 passed, 1 failed,
  3 skipped. The failure was a Storage rules test whose fixture project ID
  differs from the emulator's project ID; all 5 tests in that file pass when
  run by itself using the fixture's `demo-helperly-mvp-storage` project.
  Firebase CLI warned JDK 17 support will be dropped in a future CLI release.

No signing, TestFlight, or App Store upload is authorized.

## Manual staging/device checklist

- [ ] Home screen, app switcher, notifications and CallKit sheets display
      KINDUPP in English and French.
- [ ] Google and Apple sign-in callbacks use existing OAuth clients/schemes.
- [ ] APNs, PushKit `.voip` and FCM token delivery remain intact for the current
      bundle/project identity.
- [ ] Incoming call answer/decline, audio/video Agora connection and lifecycle
      behavior work on a physical device; no recording is introduced.
- [ ] Settings opens the draft Privacy/Terms pages and support URL.
- [ ] Payment setup route is disabled; free consultation flow remains zero-cost.
- [ ] Report/block and account deletion are exercised with disposable staging
      accounts.
- [ ] Stripe callback route remains unchanged; confirm no payment UI reaches a
      live Stripe flow while flags are off.

Production app settings, signing identity, APNs credential validity, and
provider console state are not verified by a no-code-sign build.
