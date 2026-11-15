# Switching To The Final Name And Support Address

The app is ready for the final brand: the name and the support e-mail are
set in one place and applied with one command.

## What The Founder Decides

- The public name (for example Peerway).
- A monitored support address (and privacy address, if separate).
- The web domain for the Terms, privacy and delete-account pages.

## What Claude Does Then

1. `node tool/apply_brand.mjs --name "<Name>" --support "<address>"`
   changes the app texts (EN, FR), the in-app legal texts, the web pages
   and the iOS and Android app names (91 places), then
   `flutter pub get` and the full tests.
2. A staging build checked on the emulators.
3. Hosting on the new domain (Firebase Hosting custom domain), only with
   the founder's go-ahead, since it publishes the legal pages.
4. A TestFlight build.

## What Stays The Same

The bundle id (`com.yakup.helperly`), the Firebase projects, the
repository and code names. Users never see these. App Store Connect and
Stripe names are changed in their own consoles (Stripe: Settings, Public
details).
