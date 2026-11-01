# English/French Foundation Handoff (I18N-1)

STATUS: `ready_for_review` (reviewer: the founder; implemented by Claude)

BRANCH: `call-v2`
STARTING_SHA: `47b8a8e`
ENDING_SHA: `SELF`

## Implementation Commits

| Stage | SHA | What |
|---|---|---|
| 1 Foundation | `46909eb` | gen_l10n with EN (template, fallback) and FR ARB files; device language by default; Settings > App language (Device / English / Français), saved on the device; globe button on login; `appLocale` mirrored to the account; Analytics opt-in |
| 2 Formatting | `946f422` | `AppFormat`: dates, times and CAD money per app language and device region (`4,99 $` in fr_CA, `CA$` outside Canada) |
| 3 Stored values | `1240ec1` | `ValueLabels`: translated labels for topics, expertise, countries and report reasons; stored ids unchanged |
| 4 Spoken languages | `6ea61ba` | `spokenLanguages` (ISO 639-1), separate from app language; legacy `language` read and still written; device time zone pre-fills the editable field; availability stored in a fixed format |
| 5 Screens | `a37e603`, `f79f03f`, `ccd03fc`, `143217d`, `d7cb4f4`, `d9e195d`, `079204a`, `2ddc3b4`, `5c29096` | All reachable screens; flutter_chat_ui texts; call messages translated only where drawn; a guard test against new hard-coded text |
| 6 Native | `8efada3` | iOS `fr.lproj/InfoPlist.strings` and `CFBundleLocalizations`; Android `localeConfig`; Android incoming-call UI in the device language |
| 7 Backend | `7696d7e` | Push texts in the recipient's `appLocale`; consultation reminder UTC bug fixed |
| 9 Legal drafts | `c02bd97` | `docs/legal-drafts/fr/` (drafts only, not used) |

## Compatibility

- **Stored values unchanged:** topic, expertise, country, report reason,
  post type and filter values are not translated in the database.
  Matching compares the same ids in every language (regression tests).
- **Older installed builds:**
  - every save still writes legacy `language` (English / French / Other),
    so their onboarding gate passes;
  - an empty spoken-language list writes nothing;
  - availability is written as "9:00 AM–5:00 PM", which all builds read.
- **English unchanged:** existing UI, pushes and incoming-call wording are
  the same (tests pin them).
- **Additive fields only:** `spokenLanguages` and `appLocale`. They pass
  the current rules (only protected fields are blocked), so no rules
  change is needed.

## Validation

- **Flutter:**
  - full suite: 2499 passed, 16 failed; all 16 are the known failures
    (14 working-tree guards, 2 test-mode integration tests);
  - `flutter analyze lib`: no issues;
  - `test/i18n`: 41 tests covering resolution, fallback, persistence,
    ARB parity and placeholders, formatters, labels and matching parity,
    legacy and new language data, the old-build gate, availability round
    trip, the French picker, report ids, the Android call UI language,
    and the no-hard-coded-text guard.
- **Node:** push_text 5/5; other suites 47/47.
- **Emulator:**
  - call_v2 + Firestore rules: 265/265;
  - Storage rules: 5/5.
- **Builds:** Android debug APK built; iOS `--no-codesign` built, with
  `fr.lproj` in the bundle.
- **Emulator A** (Android):
  - switch to French in Settings; the choice survives a restart; back to
    device language works;
  - per-app locale `fr-CA` opens the app in French, `tr-TR` falls back to
    English;
  - existing account skips onboarding;
  - Find a helper lists the same helpers, and the French filter finds the
    legacy "French" helper;
  - Home, Find a helper, Profile and Settings checked in French, with no
    overflow seen.

## Not Tested

- **iOS device:** not run on a phone; the build and bundle contents were
  checked.
- **Physical calls in French:** not tested. Call logic did not change;
  only labels changed.
- **Push text:** needs a deploy, so it was not observed on a device.
- **Screen sweep:** not every screen was screenshotted in French; tests
  cover the rest.
- **Password-reset email language:** not observed (needs a real send).

## Remaining Risks And Known Gaps

- **Badge names:** stored English strings on user docs, shown untranslated
  on Profile.
- **Search:** a French topic suggestion searches the French label; posts
  tagged with English ids are not matched across languages (P2).
- **Home question-line detection:** checks English "What/How" prefixes, so
  French template prompts are not bolded (cosmetic).
- **French terminology:** "aidant" may read as caregiver in Québec; it is
  flagged for the reviewer.
- **Gated or unreachable screens:** premium, boost, explore, comment,
  Followers/Following, expert directory and select consultant are not
  translated. The guard test lists them; they must be translated before
  any is enabled.
- **Android incoming-call UI:** uses the device language, not the in-app
  choice, because no I/O is allowed in the background isolate.

## Decisions Needing The Founder

1. **Crash reporting:** still on in release and linked to the user id; not
   changed, pending review. Recommendation: keep it on, drop the user id
   link, and add a Settings toggle.
2. **English Privacy Policy:** it still says usage statistics are
   collected; the app now collects them only on opt-in. Approve the
   update (the French draft already has it).
3. **French legal drafts:** reviewer, terminology, minimum age, and the
   Law 25 person-in-charge line.
4. **Deploy:** `onChatMessageCreated` and `scheduledConsultationReminder`
   are added to the batch in `docs/DEPLOY_MVP.md`.
