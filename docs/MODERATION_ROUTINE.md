# Moderation routine

Who: the founder, daily during the beta (BETA_OPS_CHECKLIST.md #11, #12).
Time: about 5 minutes a day while reports stay few.

## 1. Look (read-only)

```bash
node tool/moderation_report.mjs
```

Uses your signed-in `gcloud` account and changes nothing. User ids are
shortened (`abcd…`). It lists:

- open reports grouped by what was reported, with reasons and how long
  they have waited;
- 🔴 harassment, threats, danger, sexual content or minors: act within
  24 hours;
- 🟠 anything else waiting more than 3 days;
- posts already hidden automatically: by 3 or more reporters
  (`hiddenByReports`) or by the photo check (`hiddenBySafety`).

## 2. Decide

| What you see | Usual action |
|---|---|
| Harassment, threats, scams, sexual content | Remove the content; suspend the account; keep the report |
| Spam or advertising | Remove the content; warn, suspend if it repeats |
| A disagreement or a post someone dislikes | No action; close the report |
| A minor (under 18) | Suspend the account at once (AGE_18_PLAN.md) |
| Danger to someone's life | Tell them to call 911; contact the police if needed |

Block or suspend first and look further after. Acting on a user (removing
content, suspending) is the founder's decision; the tool never does it.

## 3. Act (Firebase console, project `connectapp-278b4`)

- **Remove a post:** Firestore → `posts/{id}` → delete the document.
- **Hide a post but keep it for evidence:** set `hiddenByReports` to `true`.
- **Suspend an account:** Authentication → find the user → Disable account.
- **Close a report:** `reports/{id}` → set `status` to `closed` and add
  `resolution` (for example `removed`, `no_action`, `suspended`).

## 4. Check costs (read-only, weekly)

```bash
node tool/usage_report.mjs
```

Shows the number of stored documents, the photo and video storage, and the
last 7 days of reads, writes, function calls and downloads next to the free
allowances. If a line shows ⚠️ over free, tell engineering before it turns
into a bill.

Both tools take `--project=helperly-call-v2-dev` to look at staging instead.

## First run: 10 Nov 2026 (production)

- 1 open report: a post, "Inappropriate content", waiting 7 days. Waiting
  for the founder's decision.
- Usage is well inside the free allowances. Videos already take 0.45 GB of
  0.53 GB stored; post videos are now made smaller before upload.
