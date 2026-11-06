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

## Done (2026-11-02)

- **#1, safety tips:** a card at the top of a new chat.
- **#2, block and report in the chat:** the first-contact banner has
  Block and Report buttons, as well as the menu. Report from the call
  screen is deferred: call screens are kept stable.
- **#3, first contact:**
  - A stranger's first message arrives normally, under a "First time
    talking with X" banner.
  - Until the other person writes, only text without links can be sent.
  - Non-helpers can be called only after they have written; helpers
    stay callable, since that is the core flow.
  - Enforced by the rules (`repliedBy`, written only by the server).
  - Existing chats need `tool/backfill_replied_by.mjs`.
- **#4, scam warnings:**
  - When a received message mentions money transfers, gift cards,
    crypto, codes or passwords, or moving to another app (EN/FR), the
    banner turns into a "Be careful" warning with Block and Report.
  - On-device only: nothing is blocked or sent
    (`lib/services/scam_signals.dart`).
  - Live in production since 2026-11-02; #4 since TestFlight
    `202611040659`.

## Next (Recommended Order)

| # | Feature | What it does | Like | Effort |
|---|---|---|---|---|
| 1 | **Safety tips on the first chat** | One card at the top of a new conversation: "Never send money or codes; keep conversations in Helperly; report anything uncomfortable" | Bumble, Airbnb | Small |
| 2 | **Report and block from the chat and the call screen** | One tap, without leaving the conversation (today it is in the chat menu) | WhatsApp, Instagram | Small |
| 3 | **First-contact safety** (instead of a requests folder) | A stranger's first message arrives normally, with a notification. A banner says "First time talking with X · Reply / Block / Report". Until the recipient replies once, the stranger can only send text: no calls, photos or links | WhatsApp (unknown numbers) | Medium |
| 4 | **Scam and contact warnings** | When a message asks for money, gift cards, banking codes or moves to another app, show a warning to the recipient ("Be careful: …"). The message is not blocked | Facebook Marketplace, Tinder | Medium |
| 5 | **Limits for new accounts**, at public launch | For example, at most 20 new conversations a day in the first week, against spam from fresh accounts. Normal users never reach it. **Not needed for the invite-only beta** | Most platforms | Small |
| 6 | **Image safety** | iOS: blur sensitive images (Apple SensitiveContentAnalysis, on-device). Android: a later step | iMessage, Bumble | Medium |
| 7 | **Moderation routine** | Daily report review; act on harassment within 24 h; repeat offenders are suspended (`BETA_OPS_CHECKLIST.md`) | All | Operational |

## Decisions (2026-11-02)

- **No Instagram-style requests folder.** On Helperly, people seeking
  help write to helpers they do not know. A requests folder would delay
  the replies that make the app useful.
- **Item 3 uses the WhatsApp pattern instead:** delivery is immediate;
  calls and media wait for the first reply.
- **Item 5 waits for the public launch.**

## Principles

- **Warn rather than read:** checks run on the device or on the message
  as it is sent. No human reads chats unless a report shares them.
- **Server-enforced:** every block and limit is in the rules or
  functions, not only in the app.
- **Privacy-safe:** no new data is collected for safety beyond what the
  feature needs. Law 25 data minimization applies.
