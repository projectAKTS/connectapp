# Data Retention: Classification And Proposal (for approval; nothing implemented)

Prepared 2026-11-01. **No production record is deleted or modified by
this document.** The periods below are proposals. Legal periods need
confirmation by the accountant or lawyer.

## Principles

- **Temporary operational data:** short, automatic expiry.
- **Records needed for safety, disputes or the law:** kept for a defined
  period, then deleted.
- **User content:** follows the account. Deletion rules are already in
  `account/delete_account.js`.
- **Mechanism:** Firestore TTL policies on an `expireAt` timestamp field,
  set when the record is written. TTL deletion is automatic and
  **irreversible**, and existing records need a backfill, which is a
  production write. Both steps need separate approval.

## Classification

| Data | Where | Today | Proposed | Why |
|---|---|---|---|---|
| Pending call invitation (ringing) | `callInvites` with status `ringing` | Kept forever | **7 days** after creation | Ringing ends in 45 s; a few days covers support questions about "it didn't ring" |
| Missed / declined / unavailable call event | `callInvites` with status `missed`, `declined`, `cancelled`, `callee_unavailable` | Kept forever | **30 days** | Lets users and support see recent missed calls; the chat also shows a "Missed call" message, which follows the chat |
| Completed call metadata (who, when, how long) | `callInvites` with status `accepted` / `ended` | Kept forever | **90 days** | Abuse and harassment reports usually arrive within weeks. If a report or a paid consultation refers to the call, it is kept with that record (below) |
| Call diagnostics inside invites | `callInvites.serverDiag*`, `calleeStage`, installation ids | Kept with the invite | Expire with the invite (above) | Debugging only |
| Temporary signaling (Call V2, not deployed) | `callOps`, `callCommandKeys`, `commands`, `taskOutbox`, `activeCallLocks` | TTLs already configured (`ttlAt`, `opsRetentionExpiresAt`) | **Keep the existing TTLs**; `activeCallLocks` should get one when V2 goes live | Pure plumbing |
| Push installations (device tokens) | `users/{uid}/pushInstallations` | Removed on sign-out and account deletion | **Also expire after 90 days without use** | Stale tokens are useless and are personal data |
| Paid sessions | `consultations` | Kept forever | **6 years** after the session [VERIFY: CRA books-and-records rule, 6 years from the end of the tax year] | Tax and accounting records, refunds, chargebacks |
| Payment attempts | `paymentOperations` | Kept forever (new) | **Same as consultations (6 years)** if succeeded; **90 days** if failed or never completed | Succeeded attempts are financial records; failed ones only help debugging |
| Stripe data | Stripe | Stripe's own retention | Governed by Stripe's terms | — |
| Safety reports and disputes | `reports` | Kept forever | **2 years after the report is closed**; longer only while an investigation or legal hold is open [LEGAL REVIEW] | Repeat-abuse patterns; possible legal claims |
| Blocks | `users.blockedUids` | Follows the account | Follows the account | User setting |
| Chats and messages | `chats/{id}/messages` | Kept; messages stay with the other participant after deletion | **Proposal for later:** delete a chat 12 months after both participants deleted their accounts or the chat has been inactive for 2 years [DECIDE] | User content; needs a product decision |
| Reviews | `reviews` | Text removed on reviewer deletion; stars kept | **Follow the helper's account**; delete when the helper deletes | Reputation data belongs to the helper profile |
| Account deletion requests | `users.deletionRequestedAt` | Processed daily | Already handled | — |
| Age declaration | `users.ageDeclaration` | Follows the account | Follows the account; a restricted "minor" account is reviewed and then deleted or restored within **30 days** [DECIDE] | Data minimization for minors |
| Crash reports / usage statistics | Firebase | Opt-in | Crashlytics 90 days; Analytics retention set to **2 months** [VERIFY setting] | Minimization |

## What Could Be Automatic After Approval

- **Can be automatic (TTL, low risk):**
  - pending, missed and completed call invites;
  - failed payment attempts;
  - stale push installations.
- **Needs review before deletion (no automatic TTL at first):**
  - reports;
  - consultations;
  - succeeded payment attempts;
  - chats;
  - restricted minor accounts.

## Implementation Steps (After Approval)

1. **New records:** functions and the app set `expireAt` when writing
   `callInvites` (based on status) and `paymentOperations`. This is a code
   change only.
2. **TTL policies:** enabled per collection in `firestore.indexes.json`
   (`fieldOverrides` `ttl: true`). This is a deploy step.
3. **Backfill:** a dry-run script counts existing records per category.
   The founder approves, then a real run sets `expireAt` on old records.
   This is a production write.
4. **Privacy policy:** update the retention section. The drafts already
   carry [VERIFY / DECIDE] markers for these lines.

## Needs Legal Or Accounting Review

- How long tax and accounting records must be kept (consultations,
  payments).
- Report retention and legal holds.
- Whether keeping messages after account deletion is acceptable, and for
  how long.
- Handling data of declared minors (Québec Law 25: minors under 14
  require parental consent).
