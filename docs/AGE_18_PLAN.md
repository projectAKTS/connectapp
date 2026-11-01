# 18+ Policy: Implementation Plan (for approval; not implemented)

The founder's provisional decision is 18+ for the MVP, because strangers
communicate and conversations may later be paid. This plan uses
self-declaration, with no identity verification.

## Today

- The English Terms already say 18+.
- Sign-up and onboarding ask nothing about age.
- `users` has no age or birthdate field.

## Proposed Implementation

| Step | What | Data | Risk |
|---|---|---|---|
| 1. Declaration in onboarding | A required checkbox on the first onboarding step: "I confirm I am 18 or older" (FR: "Je confirme avoir 18 ans ou plus"). Covers email, Google and Apple sign-ups, which all pass through onboarding. | `ageConfirmedAt` (server timestamp) and `ageConfirmedVersion: 1` on `users/{uid}`; no birthdate (data minimization) | Low. Additive fields; the current rules already allow them (not protected). |
| 2. Existing accounts | One-time blocking screen after sign-in when `ageConfirmedAt` is missing: [I'm 18 or older] / [I'm under 18]. "Under 18" explains the policy and offers account deletion (existing flow) and sign out. | Same fields | Medium. It adds a gate in `AuthGate`; it must not loop for older builds. Older builds ignore the field and keep working; the gate only exists in new builds. |
| 3. Terms and privacy | The Terms state 18+ (already in English; French draft done). The privacy policy says the service is not for minors (drafts updated). | — | Low |
| 4. Store settings (founder, consoles) | App Store age rating questionnaire (user-generated content and unrestricted messaging); Google Play target audience 18+ (keeps the app out of the Families policy). | — | Needs review of the current questionnaires |
| 5. Server enforcement (later) | Optionally refuse paid bookings for profiles without `ageConfirmedAt` (`chargeStoredPaymentMethod`). | — | Payment change; separate approval |

Estimated effort: about 1 day including tests. There is a widget test for
each path and a regression test that old docs without the field are gated
exactly once.

## Not Proposed

- Birthdate collection, ID scans or third-party age verification.
  Self-declaration is the common, proportionate approach for this risk
  level; stronger checks would need a separate proposal.

## Needs Professional Review

- **Québec Law 25:** consent for minors under 14 needs a parent. With
  18+ and self-declaration, check how to handle discovered minors (delete
  their data promptly).
- **Store policies:**
  - Apple: user-generated content apps need report and block features
    (already done);
  - Google Play: target audience and content declarations must match 18+.
- **Paid sessions:** whether contracting with 18+ adults only removes the
  need for minors-specific consumer protection steps in Québec.
- **Self-declaration wording:** whether a checkbox is enough evidence, or
  the Terms acceptance should record it.
