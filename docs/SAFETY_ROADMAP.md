# Chat And Call Safety: What We Have And What Comes Next

Prepared 2026-11-02. Patterns come from apps that let strangers talk
(Instagram, WhatsApp, Bumble, Hinge), scaled to a small team.

## Already Live

- **18+ only:**
  - a one-time declaration;
  - a declared minor is restricted: they cannot message or call, and
    nobody can call them.
- **Block:** a blocked person cannot message or call. Enforced by the
  server rules, not only the app.
- **Report** a user or a post. Reports are private, visible to the
  operator only.
- **Advice notice:** "Helpers share personal experience. This is not
  legal, immigration or medical advice."
- **No call recording.** Messages stay with the other person after an
  account deletion; this is stated in the app.

## Next (Recommended Order)

| # | Feature | What it does | Like | Effort |
|---|---|---|---|---|
| 1 | **Safety tips on the first chat** | One card at the top of a new conversation: "Never send money or codes; keep conversations in Helperly; report anything uncomfortable" | Bumble, Airbnb | Small |
| 2 | **Report and block from the chat and the call screen** | One tap, without leaving the conversation (today it is in the chat menu) | WhatsApp, Instagram | Small |
| 3 | **Message requests** | A stranger's first message goes to "Requests". The recipient accepts or deletes it, and the sender cannot send more until accepted. Calls only after acceptance | Instagram, Messenger | Medium |
| 4 | **Scam and contact warnings** | When a message asks for money, gift cards, banking codes or moves to another app, show a warning to the recipient ("Be careful: …"). The message is not blocked | Facebook Marketplace, Tinder | Medium |
| 5 | **Limits for new accounts** | For example, at most 10 new conversations a day in the first week. This slows spam and harassment | Most platforms | Small |
| 6 | **Image safety** | iOS: blur sensitive images (Apple SensitiveContentAnalysis, on-device). Android: a later step | iMessage, Bumble | Medium |
| 7 | **Moderation routine** | Daily report review; act on harassment within 24 h; repeat offenders are suspended (`BETA_OPS_CHECKLIST.md`) | All | Operational |

## Principles

- **Warn rather than read:** checks run on the device or on the message
  as it is sent. No human reads chats unless a report shares them.
- **Server-enforced:** every block and limit is in the rules or
  functions, not only in the app.
- **Privacy-safe:** no new data is collected for safety beyond what the
  feature needs. Law 25 data minimization applies.
