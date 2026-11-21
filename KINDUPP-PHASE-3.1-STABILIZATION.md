# KINDUPP Phase 3.1 — Release Stabilization

**Date:** 2026-11-21  
**Branch:** `feature/kindupp-rebranding`  
**Scope:** Local build and test verification only. No production Firebase connection, DNS change, application publication, or real payment was performed.

## Release summary

| Target | Result | Evidence |
|---|---|---|
| Android release APK | Passed; 274.1 MB | `flutter build apk --release`; output at `build/app/outputs/flutter-apk/app-release.apk` |
| Android App Bundle | Passed; 172.1 MB | `flutter build appbundle --release`; output at `build/app/outputs/bundle/release/app-release.aab` |
| Android debug APK | Artifact integrity passed; `IntegrationTestPlugin` is present in DEX | Existing debug output at `build/app/outputs/flutter-apk/app-debug.apk`; `unzip -tq` passed |
| iOS release app | Passed without code signing; 154.7 MB | `flutter build ios --release --no-codesign --no-pub`; output at `build/ios/iphoneos/Runner.app` |
| Flutter tests | 2,556 passed, 0 failed | 2,554 normal tests in a clean worktree plus 2 explicitly enabled stability tests |
| Firebase Functions and emulator tests | 427 passed, 0 failed, 0 skipped | 202 Node tests plus 225 emulator tests using demo project IDs |
| Dart analysis | Passed | `flutter analyze lib test` — no issues found |

Android outputs are local artifacts and were not uploaded. The iOS app is unsigned and cannot be installed on a device until it is signed.

## Android release build

### Registrant failure and cause

`integration_test` is a development dependency. Flutter registers it in the debug-generated `GeneratedPluginRegistrant.java`, while the release classpath excludes the development-only package. The release compile error occurs when Gradle sees a stale/debug registrant that still names `dev.flutter.plugins.integration_test.IntegrationTestPlugin`.

The failure was reproduced with `flutter build apk --release --no-pub`. That option skips Flutter's Pub/platform-tooling regeneration, so the stale generated file remains. A normal Flutter release build regenerated the release registrant and compiled successfully. A debug build running against the same checkout can regenerate the file back to its debug form, so build modes must not run concurrently in one checkout. Keep `integration_test` configured; do not call Gradle's release task directly against a debug-generated registrant.

At the end of verification, the source-tree registrant was debug-oriented and contained `integration_test` (consistent with the debug build). The successful release APK and AAB were built through Flutter's release commands, which generated the appropriate release inputs for those builds.

### Versions and SDK warnings

- Flutter 3.35.4; Dart 3.9.2.
- Java 17; Gradle wrapper 8.10.2; Android Gradle Plugin 8.7.3.
- The legacy Kotlin classpath declared 1.8.22 while `settings.gradle` already declared Kotlin 2.1.0. `android/build.gradle` now aligns the classpath to 2.1.0. The Kotlin deprecation warning did not appear in the final serialized APK/AAB builds.
- The current branch's Android app configuration uses `compileSdk = 36` and `targetSdk = 36`; the application ID remains `com.yakup.helperly`. The compile/target SDK change is in commit `753d52d`, not the Kotlin/emulator commit from this stabilization pass.
- A one-off overlapping build emitted an Android SDK XML v4/tooling-version warning. The final serialized release builds succeeded; update Android command-line tools if that warning recurs. It was separate from the API-level and Kotlin warnings.

### Commands and results

```sh
flutter build apk --release --no-pub   # reproduced stale-registrant failure
flutter build apk --release            # passed; 274.1 MB
flutter build appbundle --release      # passed; 172.1 MB
```

The original failure was:

```text
package dev.flutter.plugins.integration_test does not exist
```

The final APK build took 168.5 seconds; the final AAB build took 23.3 seconds. A separate release attempt overlapped a debug build and reproduced the registrant race, so use the Flutter commands above sequentially.

## iOS build

The no-code-sign release command passed:

```sh
flutter build ios --release --no-codesign --no-pub
```

The first attempt exhausted local disk space while Xcode compiled gRPC and wrote its result bundle. After deleting only generated Android intermediate files (retaining the APK and AAB), the retry completed and produced `Runner.app` at 154.7 MB. This is a build artifact, not a signed device install or store submission.

## Flutter test failures from the prior run

The prior report was 2,540 passed and 16 failed. The failures divide into two call-stability cases and fourteen workspace guards.

| Test | Root cause | Resolution |
|---|---|---|
| `test/call_message_stability_test.dart` — “outgoing invite creation does not depend on caller profile read” | The test-only path was invoked without `HELPERLY_TEST_MODE=true`. | Run this test with the explicit test-mode define; no production behavior was relaxed. |
| `test/call_message_stability_test.dart` — “50 stability cycles stay flat and idle” | The test helper did not reserve/own outgoing lifecycle state with a generation, and the test could fall through to the real callable transport. | `startOutgoingCallForTest` now models lifecycle ownership/generation; the stability test injects an unavailable callable transport so the fake Firestore fallback is exercised. All 50 cycles pass. |

The following fourteen tests all failed their shared assertion, “only allowed files are changed in the working tree.” They were run in a checkout containing unrelated preserved local changes, so the guards correctly rejected that checkout. They passed in the clean worktree at the stabilization commit; they are not application defects.

- `call_v2_disabled_runtime_construction_gate_hardening_audit_test.dart`
- `call_v2_disabled_runtime_construction_gate_test.dart`
- `call_v2_disabled_runtime_construction_plan_boundary_hardening_audit_test.dart`
- `call_v2_disabled_runtime_construction_plan_boundary_test.dart`
- `call_v2_disabled_runtime_construction_planner_interface_hardening_audit_test.dart`
- `call_v2_disabled_runtime_construction_planner_interface_test.dart`
- `call_v2_disabled_runtime_construction_scaffold_hardening_audit_test.dart`
- `call_v2_disabled_runtime_construction_scaffold_test.dart`
- `call_v2_disabled_runtime_preflight_boundary_hardening_audit_test.dart`
- `call_v2_disabled_runtime_preflight_boundary_test.dart`
- `call_v2_disabled_startup_execution_boundary_hardening_audit_test.dart`
- `call_v2_disabled_startup_execution_boundary_test.dart`
- `call_v2_first_actual_app_wiring_touchpoint_hardening_audit_test.dart`
- `call_v2_first_actual_app_wiring_touchpoint_test.dart`

Final clean-worktree commands and results:

```sh
flutter test --exclude-tags test-mode --reporter expanded
# 2,554 passed, 0 failed

flutter test test/call_message_stability_test.dart \
  --dart-define=HELPERLY_TEST_MODE=true --reporter expanded
# 2 passed, 0 failed; includes 50 call/chat stability cycles

flutter analyze lib test
# No issues found
```

The dirty-checkout rerun produced 2,540 passed and exactly the fourteen workspace-allowlist failures above. The clean-worktree run accounts for all 2,554 non-test-mode tests. Including the two explicit test-mode cases, the complete suite result is **2,556 passed, 0 failed**.

## Firebase Functions and emulator tests

Added `firebase.emulators.json` as an isolated test configuration. It starts Auth on 9099, Firestore on 8080, and Storage on 9199, reads the existing rules files, and disables single-project mode. Production `firebase.json` and production data were not changed or accessed.

| Suite | Demo project ID | Result |
|---|---|---:|
| Functions Node tests excluding emulator-only files | — | 202/202 passed |
| Firestore rules | `demo-helperly-call-v2-rules` | 58/58 passed |
| Storage rules | `demo-helperly-mvp-storage` | 5/5 passed |
| Account deletion with Auth, Firestore, and Storage | `demo-helperly-delete-e2e` | 3/3 passed |
| Call V2 start-call tests | `demo-helperly-call-v2` | 159/159 passed |

Total: **427 passed, 0 failed, 0 skipped**. Each emulator run used a `demo-*` project ID, which prevents access to non-emulated Firebase services. Firebase CLI 14.20.0 warned that its upcoming v15 will drop Java versions below 21; the current Java 17 runs completed successfully.

The exact emulator commands (from `connect_functions/`) were:

```sh
npx firebase-tools emulators:exec --config ../firebase.emulators.json \
  --project demo-helperly-call-v2-rules --only firestore \
  'node --test test/mvp/firestore_rules_*.test.js test/call_v2/firestore_rules_v2.test.js'

npx firebase-tools emulators:exec --config ../firebase.emulators.json \
  --project demo-helperly-mvp-storage --only firestore,storage \
  'node --test test/mvp/storage_rules_mvp.test.js'

npx firebase-tools emulators:exec --config ../firebase.emulators.json \
  --project demo-helperly-delete-e2e --only auth,firestore,storage \
  'node --test test/account/delete_account_e2e.test.js'

npx firebase-tools emulators:exec --config ../firebase.emulators.json \
  --project demo-helperly-call-v2 --only firestore \
  'node --test test/call_v2/start_call_v2.test.js'
```

The 202 non-emulator Functions tests were run with:

```sh
find test -name '*.test.js' \
  ! -name 'firestore_rules_*.test.js' \
  ! -name 'storage_rules_mvp.test.js' \
  ! -name 'delete_account_e2e.test.js' \
  ! -name 'start_call_v2.test.js' -print0 | xargs -0 node --test
```

## Payment safety verification

- Mobile `MvpFeatures.paymentsEnabled` defaults false and only permits an explicit staging build. `premium`/subscriptions and paid sessions have additional gates. Payment setup, payout setup/status, post boost, and premium screens return disabled states when those gates are off.
- Signup only calls `createStripeCustomer` when the payment gate is enabled (`lib/screens/auth/signup_screen.dart`, commit `753d52d`).
- Functions `MVP_PAYMENTS_ENABLED` and `PAID_SESSIONS_ENABLED` default false. Payment setup/customer methods, paid booking, connected-account links/status, and the legacy stored-card charge route check the server flags. `bookPaidSession` checks both flags before creating a PaymentIntent; scheduled `releaseDue` returns before transfers unless both flags are enabled.
- Stripe's webhook verifies signatures and reconciles payment/account events; it does not create PaymentIntents, charges, or transfers. It may reconcile an already-existing pending intent even after gates are disabled; that is not a new transaction.
- Source review found no backend transaction route that bypasses the disabled payment gates. The transaction-capable backend paths are `bookPaidSession`/`charge_operation` for PaymentIntents and `releaseDue` for transfers; the gates protect those paths.
- App Store subscriptions use `SubscriptionService.buySubscription`, which checks the client-side premium compile-time gate before calling StoreKit. No server-side receipt verification was found in this review. Keep premium disabled until StoreKit products and entitlement verification are reviewed; a client gate alone is not a server security boundary.
- `node --test test/payments/*.test.js` passed 31/31 using fake Stripe dependencies. The Flutter production-default feature-flag tests passed in the full suite. No real transaction or Stripe account action was performed.

The deployed production Functions parameter values were not queried. Before launch, verify in the production Firebase Functions configuration that `MVP_PAYMENTS_ENABLED=false` and `PAID_SESSIONS_ENABLED=false`; the source defaults and local release build do not prove the live deployed values.

## Controlled device test plan

### Automated before device testing

- Run the full Flutter commands above and the Firebase emulator suites above.
- Keep the fifty-cycle call/chat stability test in CI with `HELPERLY_TEST_MODE=true`.
- Continue the Firestore/Storage ownership and account-deletion emulator tests; they cover authorization and deletion data boundaries without production services.
- Do not treat emulator tests as verification of APNs, CallKit, camera/microphone hardware, Agora media quality, or background delivery.

### Physical Android and iOS checklist

- [ ] Register with each supported sign-in method; verify validation, email verification/password recovery where supported, and logout/login persistence.
- [ ] Create/edit a profile; grant and deny photo/camera permissions; upload and replace a profile image.
- [ ] Run AI matching with two real test accounts; verify empty, slow, and populated results.
- [ ] Create a post with image/video, view it from another account, and verify upload retry after network loss.
- [ ] Search users/posts; exercise no-result, partial-query, and pagination behavior.
- [ ] Send/receive messages on two devices; verify read state, media, ordering, and reconnect behavior.
- [ ] Verify standard push notifications in foreground, background, and terminated states; test notification tap routing.
- [ ] Place and receive Agora audio and video calls on two physical devices; accept, reject, mute, switch camera, speaker, and end.
- [ ] On iOS, verify incoming/outgoing CallKit presentation, lock-screen actions, PushKit wake, duplicate delivery, and app resume after accept/end.
- [ ] Block and report another account; confirm the blocked user cannot message/call and report flows complete.
- [ ] Delete an account; verify signed-out state, removed profile/posts/media according to policy, and that a second account's data remains.
- [ ] Background/foreground during login, upload, message, and call flows; test Wi-Fi/cellular switch, airplane mode, temporary offline, and recovery without duplicate actions.
- [ ] For notifications, camera, microphone, photos, and tracking if applicable, test allow, deny, deny permanently, and re-enable in OS Settings.

Automated tests cover source logic, simulated lifecycle, callable behavior, and emulator rules. Agora media, APNs/PushKit delivery, CallKit presentation, OS permission prompts, network transitions, and real-device account flows still require physical devices. The iOS artifact is unsigned; signing and device installation remain manual.

## Remaining launch blockers and manual actions

1. Run the physical checklist on at least one current iPhone and one Android device; use two devices for call and messaging cases.
2. Verify the deployed production Functions payment flags are false in Firebase Console. No production credential was used here.
3. Sign the iOS build with the intended development team before installing it on an iPhone. Android release signing configuration is conditional on a local upload key; verify the intended signing key before any store upload.
4. Use Flutter's normal mode-aware release commands and serialize debug/release builds when sharing a checkout. Do not use `--no-pub` for the release build while relying on Flutter to regenerate the registrant.
5. Update Java to 21 before moving to Firebase CLI v15; the current emulator suites passed with Java 17 and CLI 14.20.0.

No publication, push, DNS edit, production Firebase operation, or real payment remains part of this stabilization work.

## Files and commits

Files changed by the stabilization commits:

- `android/build.gradle` — align Kotlin plugin classpath to 2.1.0.
- `firebase.emulators.json` — isolated Auth/Firestore/Storage emulator configuration.
- `KINDUPP-PHASE-3.1-STABILIZATION.md` — this report.
- `lib/services/call_session_manager.dart` — test-only outgoing call lifecycle ownership.
- `integration_test/call_message_stability_test.dart` — deterministic fake transport and lifecycle stability coverage.
- `.github/workflows/app-flutter-tests.yml` and `docs/TESTING.md` — dedicated test-mode invocation and updated test instructions.

Related branch commits:

- `9969582 fix: align Android Kotlin and isolate Firebase emulators` — created during this stabilization pass.
- `e6be3eb test: stabilize call lifecycle harness` — call stability and test isolation changes.
- `753d52d fix(android): Play-ready release build; no Stripe customer at signup` — Android SDK/signing version wiring and signup payment gate; already present on the branch during this pass.

The pre-existing uncommitted `ios/Podfile.lock`, `pubspec.lock`, localization output, notes, and architecture document were preserved and are not included in these commits. No changes were pushed.
