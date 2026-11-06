# Privacy Policy Drafts: What Needs Checking

These drafts are not published:
- `en/privacy-policy.md`
- `fr/politique-confidentialite.md`

The live text is still `lib/config/legal_texts.dart` (and `public/`).

## Facts Verified In The Code (2026-10-31)

| Statement | Evidence |
|---|---|
| Analytics and Crashlytics are off until the user turns them on, are not linked to the account, and no advertising id is collected | `lib/services/app_telemetry.dart`; native flags in `AndroidManifest.xml` and `Info.plist`; `test/mvp/telemetry_consent_test.dart` |
| No call recording | No recording code; Agora is used for live media only |
| Push tokens and installation id | `users/{uid}/pushInstallations` |
| App language mirrored for notifications | `users.appLocale` |
| What account deletion removes and keeps | `connect_functions/account/delete_account.js`: the user doc, posts, followers, Storage folders, review text and the Auth user are removed; chats, `callInvites`, reports, consultations and Stripe data are kept |
| Emails are private | `users/{uid}/private/account` (server-only) |

## Needs Factual Verification (Founder / Console)

1. **Data locations: verified 2026-11-05** (read-only `gcloud`, production
   `connectapp-278b4`):
   - Firestore `(default)`: `nam5`, a United States multi-region;
   - Storage `connectapp-278b4.firebasestorage.app`: `US-CENTRAL1` (Iowa);
   - backups `connectapp-278b4-backups`: `US` multi-region;
   - Functions: all 23 in `us-central1`;
   - post photos and video thumbnails are sent to Google Cloud Vision
     through the global endpoint `vision.googleapis.com`, so the
     processing location is not pinned to a region.

   So "hosted in the United States" in the drafts is accurate. **Gap:** the
   EN and FR privacy-policy drafts do not mention the automatic photo
   check (Google Cloud Vision); only the PIA draft does. Law 25
   transparency likely needs a sentence in both. Also found:
   Firestore delete protection and point-in-time recovery are both off
   (a setting change; founder's decision).
2. **Retention settings:** the Analytics data-retention setting (2 or 14
   months) and the Crashlytics retention.
3. **Agora:** the data-processing terms and regions used for the project.
4. **Stripe:** the account country and which card fields the app shows
   (brand and last 4).
5. **Call records:** `callInvites` are never deleted, so a retention period
   must be decided. Suggestion: 12 months, with a TTL field, as a separate
   task.
6. **Legal identity:** the operator's legal name, business registration and
   city.

## Needs Legal Review

- Law 25:
  - the privacy impact assessment for transfers outside Québec (Firebase,
    Agora, Stripe);
  - the person-in-charge wording;
  - the confidentiality incident register.
- Whether keeping reports, call records and messages after deletion is
  justified, and for how long.
- The 30-day response time and the complaint authorities.
- Consent wording for optional crash reports and usage statistics (they
  are opt-in now).
- The 18+ statement and how it is enforced (see `docs/AGE_18_PLAN.md`).
- Whether French must be shown first to Québec users (Charter s.55 for
  the Terms; good practice for the policy).

## Placeholders To Fill (Do Not Publish Without Approval)

`[LEGAL NAME ...]`, `[CITY]`, `[TITLE]`, `[PRIVACY CONTACT EMAIL]`,
`[SUPPORT EMAIL]`, `[DATE]`
