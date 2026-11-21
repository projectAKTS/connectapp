# Kindupp Rebranding Report

**Status:** prepared on `feature/kindupp-rebranding`; not released.
**Base:** `fb1c0596be7ca5b26d548f0ddd39292b9329ed29` (`call-v2`, snapshot `snapshot-2026-11-20`).
**Targets:** app display name Kindupp, `https://kindupp.com`, `support@kindupp.ca`.

## Completed in this checkout

- Updated the brand config, English/French app copy, legal/support destinations,
  Android launcher label, iOS display-name overrides, CallKit display names,
  Android incoming-call app name, and generated legal-site HTML.
- Settings now links to the draft Privacy and Terms pages and support page;
  legal rows visibly identify the documents as drafts.
- Kept the existing text wordmark. Added `public/favicon.svg` and
  `public/og-kindupp.png` using only the existing Kindupp text treatment and
  palette; the social image is 1200×630. No logo mark was invented.
- Updated the existing brand helper to use reviewed, targeted paths and to
  print the localization-generation step.

## Identity and integration values intentionally preserved

- Android package/application ID and iOS bundle ID: `com.yakup.helperly`.
- Firebase project/client registrations: `connectapp-278b4`.
- Google OAuth reverse-client scheme, Apple sign-in, Stripe callback scheme
  `connectapp`, and existing identity-linked URI scheme.
- FCM/APNs/PushKit identity, entitlements, Firebase options, and Function URLs.
- `HELPERLY_ENV`, legacy class/file names, and internal diagnostic strings;
  these are technical identifiers rather than public brand copy.

## Console work still required

This branch cannot verify or change provider consoles. Before a mobile release,
confirm the Apple/Google store display name, support/privacy/deletion URLs,
Firebase Auth email templates and OAuth authorized domains, OAuth client
registrations, APNs/PushKit topic and credentials, FCM delivery, and Stripe's
public business details. Test Google/Apple login, incoming pushes/calls, and
existing deep-link/callback flows on signed staging builds. Do not rename IDs
without a separate migration plan.

## Remaining reference inventory and disposition

| Reference/path | Disposition |
|---|---|
| `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, Kotlin package paths/classes, Android Firebase `google-services.json` | Keep `com.yakup.helperly`; this is the registered package/Firebase app identity. The manifest's user-visible label is Kindupp. |
| `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Runner/GoogleService-Info.plist`, `lib/services/firebase_options.dart` | Keep bundle/Firebase client IDs and URL schemes. Display-name keys are Kindupp; callback and identity configuration stays unchanged. |
| `android/app/src/main/kotlin/com/yakup/helperly/HelperlyApplication.kt`, `MainActivity.kt` | Keep class/package names and the `helperly:accepted_call` event key; native registration and Dart event handling are coupled. |
| `lib/services/helperly_test_runtime.dart` and its imports across `lib/` | Test harness/internal dependency injection name; not shown to users. Renaming touches many call, feed, chat, profile and notification paths without a brand benefit. |
| `HELPERLY_ENV`, `HELPERLY_TEST_MODE`, `firebase_options_staging.dart`, `tool/build_staging.sh`, staging smoke/deploy scripts, `helperly-call-v2-dev` | Preserve environment switches and staging project references; these identify service environments and guarded operations. |
| `lib/services/app_prefs.dart` (`helperly_app_prefs.json`), `lib/services/push_installation_id.dart` (`helperly_push_installation_id`) | Preserve persisted file keys so existing local settings and installation identity are not orphaned. |
| `lib/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart`, `ios/Runner/AppDelegate.swift`, `lib/services/notification_service.dart` diagnostic fingerprints/log labels | Internal telemetry/debug strings; retained to avoid changing diagnostic fingerprints or log filters. They can be relabeled only with a separate diagnostics migration if desired. |
| `tool/apply_brand.mjs` | Old `Helperly` and `support@helperly.app` strings are intentional detection inputs for the targeted migration helper. Do not remove them while that helper is meant to detect legacy state. |
| `CLAUDE.md`, `docs/PRODUCTION_DEPLOY_PLAN.md`, `docs/ACCOUNT_DELETION_E2E.md`, `docs/BETA_OPS_CHECKLIST.md`, `docs/PAID_SESSIONS_DESIGN.md` | Historical instructions/snapshots still mention old support/domain/name. Read this Phase 3 report before reusing them; update/mark their historical sections before future deployment or payment work. Do not interpret these old strings as approved contact details. |

The mobile app, website generator and generated public pages contain no active
`support@helperly.app` or old marketing URL. The detector in
`tool/apply_brand.mjs` intentionally retains that email as a migration input;
historical planning documents also retain old values in dated context. The
remaining old-brand matches in Android/iOS/app code are technical/internal
items listed above. The five stale planning documents remain a follow-up
documentation cleanup, not release-ready instructions.
