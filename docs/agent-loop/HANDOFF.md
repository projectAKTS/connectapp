# English/French Foundation Handoff (I18N-1, with the founder's follow-up)

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

---

## Follow-Up Round (Founder Decisions, 2026-10-31)

| Item | SHA | Result |
|---|---|---|
| Crashlytics privacy-first | `0d83b6e` | Opt-in; native flags off; no user id; no keys or logs; unsent reports deleted while off; the choice persists |
| French terminology | `0fce9b9` | "personne-ressource" / "Trouver de l'aide" / "Partager mon expérience" / "les membres"; `docs/i18n/FR_GLOSSARY.md` |
| Search and badges | `404153b` | Cross-language topic search; accented display names; translated badges |
| Privacy drafts (EN/FR), deploy review, 18+ plan | `5184fa6` | `docs/legal-drafts/`, `docs/DEPLOY_FUNCTIONS_REVIEW.md`, `docs/AGE_18_PLAN.md` |

### Verification

- **Flutter:** full suite 2509 passed, 16 failed (the same 16, see below);
  `flutter analyze lib` clean.
- **Node:** 47/47.
- **Android emulator (debug build):** the Crashlytics SDK keeps
  `firebase_crashlytics_collection_enabled=false` in its preferences
  after start.
- **iOS build:** `FirebaseCrashlyticsCollectionEnabled` and
  `FIREBASE_ANALYTICS_COLLECTION_ENABLED` are both false in the built
  `Info.plist`.
- **Not verified:** the "on" state needs a release build, which forces
  collection off in debug. That means a release install, which needs a
  reinstall and test login. Not done on an iOS device either.

### The 16 Failing Flutter Tests

- **14 working-tree guards:** the "only allowed files are changed in the
  working tree" test in each of these
  `test/call_v2/integration/*_test.dart` files (phases 7AW to 7BJ):
  - `first_actual_app_wiring_touchpoint` (+ hardening audit);
  - `disabled_startup_execution_boundary` (+ audit);
  - `disabled_runtime_preflight_boundary` (+ audit);
  - `disabled_runtime_construction_gate` (+ audit);
  - `disabled_runtime_construction_plan_boundary` (+ audit);
  - `disabled_runtime_construction_scaffold` (+ audit);
  - `disabled_runtime_construction_planner_interface` (+ audit).
  
  Cause: they assert that `git diff --name-only HEAD` (except
  `pubspec.lock`) lists only their phase files. The local
  `ios/Podfile.lock` is modified and kept uncommitted by repo rule.
  Evidence: in clean worktrees of both HEAD `5cc7d4e` and the pre-i18n
  baseline `47b8a8e`, all 14 pass. The pre-i18n full run (MVP-5) had the
  same 16 failures. Production impact: none; they are source-history
  guards.
- **2 in `test/call_message_stability_test.dart`:**
  - "outgoing invite creation does not depend on caller profile read"
  - "50 stability cycles stay flat and idle"
  
  Cause: without `--dart-define=HELPERLY_TEST_MODE=true` they throw
  "startOutgoingCallForTest is test-mode only". With it, the first passes
  and the second expects the invite status `connected` after
  `reportRemoteJoined`, but gets `accepted`. Identical at `47b8a8e` and
  `5cc7d4e`; that test was last changed on 2026-09-13.
  
  Production impact: none found. It is a harness expectation, and
  physical calls were verified in October with the current behaviour.
  It needs a call-flow decision (update the test or the status write) in
  a separate call task. The call code is not touched here.

**Plan:** run the 14 guards only on a clean tree (CI or a worktree), or
exclude them by tag in the default run. Move the 2 stability tests into
`integration_test` runs that pass `HELPERLY_TEST_MODE`, then fix the
`connected` expectation in a call-flow task.

### Still Open

- **Password reset email language:** the code sets `setLanguageCode`.
  Verifying it means sending a real reset email to a test account
  (founder approval needed). Also check in the Firebase console that the
  email templates are not customized in English only.
- **iOS device check:** French UI, French permission prompts, iOS
  per-app language, crash-report toggle. Needs the iPhone on cable and a
  dev build.
- **Implemented after review:** the 18+ gate (plan only), the call-record
  retention TTL, the Stripe idempotency key, and a reminder dedupe
  marker.

---

## Stabilization Round (2026-11-01)

| Item | SHA |
|---|---|
| Stripe: one charge per booking attempt; fixed the shadowed `charge` (refunds had no `paymentIntentId`) | `2ceb2ee` |
| Notifications: one chat push and one reminder per event | `9378e43` |
| 18+ self-declaration and the one-time separate privacy choice | `bf318dc` |
| CI: pinned Flutter, full suite on a clean checkout, test-mode tag, guard script | `bdfae39` |
| Retention classification; privacy drafts updated | `c4bf0c7` |
| Release checklist (16 functions) | `ec3d51c` |

### Validation

- **Node:** 60/60 (payments 9, claim 4).
- **Emulator rules:** 268/268.
- **Flutter:**
  - `test/mvp` + `test/i18n` + startup wiring: 79/79;
  - analyze clean;
  - clean-tree guards: 221/221 via `tool/run_clean_tree_guards.sh`.
- **Emulator A:** the existing account sees the one-time 18+ screen. Not
  confirmed, to avoid a production write.
- **CI `App Flutter Tests` run 41278268754** (clean checkout, Flutter
  3.35.4):
  - full suite: 2529 passed, 0 failed, guards included;
  - test-mode step: 1 passed, 1 failed (the tracked `connected`
    expectation), visible as an error annotation.

### Blocked

- **iPhone checks:** a paired iPhone is visible, but the checks need the
  founder to operate it, and installing a dev build replaces TestFlight.
- **Password reset email:** both test accounts use Gmail inboxes that are
  not the founder's, so they cannot be read and might be real people. A
  founder-controlled test address is needed (for example a `+alias` of
  the founder's Gmail).

---

## Pre-Beta Gate Round (2026-11-01)

| Item | SHA |
|---|---|
| Free beta: `PAID_SESSIONS_ENABLED` (default false) gates charges, Checkout and payout onboarding on the server; booking and billing are hidden in the app | `6ed2c8d` |
| 18+ enforced in Firestore rules (legacy-safe, sticky minors, `createdAt` integrity); restricted accounts hidden from lists | `cc74672` |
| Account deletion end-to-end in the emulators; call-test root cause | `d1ef290` |
| Minimum retention, manual device tests, pre-beta deploy checks | `5aa3961` |

### Validation

- **Flutter local:** 2515 passed, 14 failed (only the dirty-tree
  guards). `flutter analyze lib` clean.
- **CI on `cc74672`:** success on a clean checkout.
- **Node:** 62/62.
- **Rules emulator:** 274/274 (age 6).
- **Deletion E2E (Auth + Firestore + Storage emulators):** pass.

### Findings

- **Deletion gaps:** A's comments on other people's posts, and reviews
  about A, remain (see `docs/ACCOUNT_DELETION_E2E.md`).
- **Web deletion page:** uses the placeholder `support@helperly.app`.
- **Known call test:** an outdated test-mode helper, no production impact
  (see `docs/TESTING.md`).

---

## Final Beta Blockers Round (2026-11-01)

| Item | SHA |
|---|---|
| Deleted users leave no identifiable references (comments, replies, reviews, call names, follows, likes, connections); cleanup failures never block deletion; collection-group index added | `e44812f` |
| Every account declares 18+ before interacting (no grandfathering, no lock-out); createdAt rules removed | `34b3544` |
| Staging plan (verified read-only) and operations checklist | this commit |

### Validation

- **Rules emulator:** 275/275.
- **Deletion:** unit 6/6; end-to-end with three users passes.
- **Payments:** the paid-session switch test still passes (charges,
  Checkout and payouts are off on the server).
