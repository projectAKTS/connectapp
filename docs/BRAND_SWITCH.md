# Kindupp mobile brand switch

Current public values:

- App display name: `Kindupp`
- Website: `https://kindupp.com`
- Support: `support@kindupp.ca`

The applied changes affect visible Flutter text, Android/iOS display names,
CallKit and incoming-call names, Settings legal/support links, and the legacy
Firebase Hosting page copy. The in-app Privacy and Terms rows open the
corresponding website drafts and label them as drafts.

`tool/apply_brand.mjs` updates source copy and hosted pages. It deliberately
does not rename application IDs, Firebase projects, OAuth redirect schemes,
Stripe callback schemes, APNs/FCM/PushKit configuration, database names,
or code identifiers. Review its diff manually and run `flutter gen-l10n`
after changing localization source strings.

Before any store submission, verify the generated Android label and iOS
home-screen/CallKit labels in builds, inspect the app icons and splash screens,
check Firebase Auth email templates and authorized domains, and update the
App Store / Play Console metadata and Stripe public details separately.

The current Android and iOS icons are still the existing Flutter default
assets. Keep them until an approved Kindupp mark is supplied; do not invent
or substitute a logo.
