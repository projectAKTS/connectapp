# Manual Tests On Staging (Founder Operates, Claude Guides)

Prerequisites:
- staging deployed (`docs/STAGING_PLAN.md`);
- the staging build installed: Android `tool/build_staging.sh android`;
  iPhone `tool/build_staging.sh ios`, then install with Xcode or
  devicectl. This replaces the installed app; reinstall the normal build
  afterwards.

Accounts: three new accounts with your Gmail `+aliases` (`+hb-a`, `+hb-b`,
`+hb-c`). Staging has no real users.

Mark each check **PASS / FAIL / BLOCKED**, with a note.

| # | Area | Steps | Expected |
|---|---|---|---|
| 1 | Sign-up | Phone 1: sign up `+hb-a` | Onboarding; the 18+ box is required |
| 2 | Language | Settings > Language > Français; kill and reopen; back to Device language | Screens in French and stay French after restart; then back to English |
| 3 | 18+ | During onboarding try Continue without the box; then tick it | Blocked with a message; then continues |
| 4 | Privacy choice | After onboarding | One sheet, two switches, both off; Done; it never appears again |
| 5 | Profile | Edit profile: expertise "Housing search", languages FR/EN, city | Saved; visible on the profile |
| 6 | Discovery | Phone 2: sign up `+hb-b` as a seeker > Find a helper > topic "Logement" | `+hb-a` is listed with French labels |
| 7 | Chat | B messages A; A replies | Both arrive; one notification each |
| 8 | Audio call | B calls A with A's phone locked | Rings (CallKit on iPhone); answer; audio both ways; hang up |
| 9 | Video call | A calls B | Video both ways; hang up |
| 10 | Report and block | B reports A's post, then blocks A | Confirmations; A's posts are hidden; A can no longer call or message B |
| 11 | No payments | Open A's menu and B's Profile | No "Book a call" or "Billing". (The server also refuses charges.) |
| 12 | Login | Log out, log in again as A | Works; same language |
| 13 | Password reset (EN) | App in English > Forgot password > `+hb-c` | The email arrives in English |
| 14 | Password reset (FR) | App in French > Forgot password > `+hb-c` | The email arrives in French |
| 15 | Account deletion | Phone 2 (B) > Settings > Delete account | "Account deleted"; signed out; login as B fails; A's chat shows B as "User" |
| 16 | Restricted account | Sign up `+hb-c` and choose "I'm under 18" on the existing-account screen if shown (or set it via the console in staging) | Paused screen; only delete and sign out work |

Automated checks run before this (2026-11-01):
- Flutter targeted suites and analyze;
- Node 63/63;
- rules 275/275;
- deletion end-to-end 3/3;
- CI full suite on a clean checkout.
