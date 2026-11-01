# Manual Pre-Beta Tests (Founder On Device, Claude Guiding)

Mark each item **PASS / FAIL / BLOCKED**, with a note. A missing device or
account is **BLOCKED**, not PASS.

## Setup

- **iPhone:** connected by cable, unlocked, with a **development build**
  of the current `call-v2`. Installing it replaces the TestFlight app; the
  account data is in the cloud and is unaffected.
- **Second device for calls:** the Android emulator A or a second phone,
  signed in with the other test account.
- **Password-reset address:** a founder-controlled test email (for example
  `yourgmail+helperly-en@gmail.com` and `+helperly-fr`). Create these test
  accounts first. Never use real users' addresses.

## Checks

| # | Check | Steps | Expected |
|---|---|---|---|
| 1 | French UI | iOS Settings > Helperly > Language > Français (or the in-app Settings) | All screens are in French; "Trouver de l'aide", "personne-ressource" |
| 2 | Language persistence | Kill and reopen the app | Same language |
| 3 | Fallback | iOS language Türkçe, in-app "Device language" | English |
| 4 | Permission prompts | First call or photo with iOS in French | Camera and microphone prompts in French |
| 5 | New sign-up | Sign up with `+helperly-en` | Onboarding requires the 18+ box; the privacy sheet appears once with two separate switches, both off |
| 6 | Existing account | Sign in to an older test account | The one-time "Helperly is for adults" screen; confirm adult; Home loads |
| 7 | Crash reports opt-in | Settings: crash reports on; kill and reopen | The setting stays on. (Do not force a crash in production.) |
| 8 | Password reset (EN) | App language English > Forgot password > `+helperly-en` | The email arrives in English |
| 9 | Password reset (FR) | App language Français > Forgot password > `+helperly-fr` | The email arrives in French (needs the Firebase console template language left at default) |
| 10 | Find a helper | Topic "Logement" | Helpers with housing experience are listed |
| 11 | Message | Send a message to the other test account | It arrives; one notification |
| 12 | Audio call, locked screen | Call the iPhone while locked | CallKit rings; answer connects; audio both ways |
| 13 | Video call | Call from the iPhone | Connects; hang-up works on both sides |
| 14 | Report and block | Report a post, block a user | Confirmation shown; the blocked user's posts are hidden |
| 15 | Paid booking hidden | Open a helper's menu | No "Book a call" or "Billing" |
| 16 | Delete account | Create a throwaway account > Settings > Delete account | Signed out; signing in again fails |

Items 5, 6, 11, 14 and 16 need the new rules and functions deployed (in
staging first). Before deploy, record them as BLOCKED.
