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

1. **Data locations:** the Firestore and Storage location of
   `connectapp-278b4` (Firebase console > project settings), and the
   Functions region (`us-central1` in code).
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
