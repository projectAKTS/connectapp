# Active Task - English/French Foundation (I18N-1)

Branch: `call-v2`

Starting SHA: `de0e1fb`

Approved by the founder on 2026-10-31 after
`docs/research/I18N_ARCHITECTURE_REPORT.md`, with conditions. The
founder's conditions are binding.

## Stages (one or more focused commits each)

1. Localization infrastructure: `gen_l10n`, `app_en.arb` / `app_fr.arb`,
   device locale detection, a persisted manual choice (System / English /
   Français), and an English fallback.
2. Locale-aware date, time and currency formatting.
3. Display labels for stored values (topics, expertise, countries,
   languages). **Stored values and matching IDs stay unchanged.**
   Regression tests: English and French users match the same categories.
4. `spokenLanguages` (ISO 639-1), separate from the interface language.
   Legacy `language` stays readable and is still written for old
   installed builds. Location fields are kept; the device time zone
   pre-fills the editable field.
5. Localize the active user-facing screens. Unreachable screens (Explore,
   Comment, Boost) are excluded, **not deleted**.
6. Native strings: iOS permission strings and localizations; Android
   per-app language; incoming-call texts.
7. Backend push text per recipient language; fix the UTC time in the
   consultation reminder.
8. Privacy defaults: Analytics off until the user turns it on.
   Crash-reporting behaviour reviewed and documented; changes need
   approval.
9. French legal texts as **drafts only**, not wired into the app or the
   site.

## Not Allowed

- Deleting Firebase data, deploying, publishing, or changing payments.
- Replacing published legal texts.
- Deleting unused screens.
- Changing stored category, country or language values.
- Breaking older installed builds.

## Validation Per Stage

- `flutter analyze` on touched files; `flutter test test/mvp/` plus the
  related suites; the full suite at the end.
- Emulator: English/French switching, persistence after restart, fallback,
  login/onboarding, Find a helper results unchanged.
- Node tests for the Functions changes.
