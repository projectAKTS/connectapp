# KINDUPP Rebranding Report

**Status:** prepared on `feature/kindupp-rebranding`; not released.
**Base:** `fb1c0596be7ca5b26d548f0ddd39292b9329ed29` (`call-v2`, snapshot `snapshot-2026-11-20`).
**Targets:** app display name KINDUPP, `https://kindupp.com`, `support@kindupp.ca`.

## Completed in this checkout

- Updated the brand config, English/French app copy, legal/support destinations,
  Android launcher label, iOS display-name overrides, CallKit display names,
  Android incoming-call app name, and generated legal-site HTML.
- Settings now links to the draft Privacy and Terms pages and support page;
  legal rows visibly identify the documents as drafts.
- Kept the existing text wordmark. Added `public/favicon.svg` and
  `public/og-kindupp.png` using only the existing KINDUPP text treatment and
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

Old-name search results remain in code identifiers, historical docs, service
project names and diagnostics by design; user-facing display locations above
were updated. See the exact diff in this branch before release.
