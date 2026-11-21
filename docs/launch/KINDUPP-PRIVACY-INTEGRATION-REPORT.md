# KINDUPP Privacy and Integration Review

**Scope:** reviewed the current `call-v2` client, Functions code, English
Privacy Policy draft, French Privacy draft, Terms draft, Community Guidelines,
`LEGAL-REVIEW.md`, `PRIVACY_REVIEW.md`, and EFVP/PIA draft. Technical review
only; not legal advice or a compliance determination. All legal documents
remain drafts.

## Observed product/data flows

- Firebase Authentication supports email/password, Google, and Apple.
- Firestore stores profiles, posts/comments, messages, reviews, reports,
  blocks, call invites, consultations, and related operational references.
- Firebase Storage holds user/profile, post, video-thumbnail, and chat media.
- Cloud Functions provide server workflows, including moderation, messaging,
  calls, payments, and account deletion.
- FCM/APNs/PushKit tokens and notification delivery support messages/calls.
  Lock-screen notification content still needs a release-device check.
- Agora transports live audio/video. No recording path was found in the
  reviewed client. Confirm project routing, telemetry and any recording or
  transcription controls in provider settings.
- Google Cloud Vision SafeSearch checks post images and one thumbnail/frame
  from a post video; reviewed code does not submit chat media. Its Vision
  endpoint is global and the processing region is not pinned in this code.
- Analytics and Crashlytics are opt-in/off by default in reviewed app code and
  native configuration. Project retention and release SDK payloads remain to
  be verified.
- Netlify Forms receives contact name, email, topic and message. Recipient
  confirmation and data location/retention controls need owner verification.
- Phase 3 source gates Stripe customer/card, payment, subscription and payout
  functionality off by default. Production build and deployed Functions
  parameters are not verified. Existing Stripe references may remain in data.

## Priority findings in the drafts

1. **Operator/contact placeholders:** legal name, business address, privacy
   officer and monitored privacy contact remain unresolved. `support@kindupp.ca`
   must be confirmed as monitored before being represented as a privacy inbox.
2. **Automated image review:** draft now describes Cloud Vision post-image and
   video-frame checks, but provider terms/processing location and exact user
   notice still require confirmation.
3. **Deletion and retention:** removed unsupported immediate/30-day deletion
   promise and fixed Crashlytics/Analytics retention claims. Code retries
   incomplete deletion without a demonstrated overall deadline. Reports, call
   invites, recipient-held chat/media, consultations, Stripe data, provider
   logs and backups may remain; periods/reasons need decisions and enforcement.
4. **Payment statements:** draft now distinguishes free MVP intent and
   fail-closed Phase 3 source from unverified production behavior. Production
   settings and residual records must be checked before describing the live
   service.
5. **Age:** 18+ is a self-declaration in the reviewed flow, not ID/DOB
   verification. Added a dedicated translated `Underage account` report reason
   and urgent moderation classification; confirm response capacity and
   suspension procedure.
6. **Regions/providers:** `PRIVACY_REVIEW.md` records a read-only settings
   check dated 2026-11-05: Firestore `nam5`, Storage `US-CENTRAL1`, Functions
   `us-central1`, backups in US. Recheck current production settings. Agora,
   Vision, Stripe and Netlify provider terms/regions remain unresolved.
7. **Other open disclosures:** push preview text, email verification/password
   reset, AI matching outside this checkout, report access/retention, store
   privacy declarations, French-language obligations, rights request workflow,
   security-incident procedure and privacy-impact assessment need owner/counsel
   review.

## Evidence boundary

Local code review cannot establish deployed Firebase rules/functions, console
flags, SDK behavior of the exact release binary, provider contracts/retention,
or operational response capacity. No claim of legal compliance is made.
Question list and deletion specifics are in
`KINDUPP-ACCOUNT-DELETION-REPORT.md` and
`KINDUPP-MVP-RELEASE-CHECKLIST.md`.

## Prioritized questions requiring the owner's answer

1. **Legal operator/contact:** What exact legal name and public address should
   appear? Who is the privacy-responsible person, and is
   `support@kindupp.ca` monitored for privacy requests?
2. **Free launch:** Confirm the exact app build and production Functions should
   have all card, paid-session, subscription, boost, and payout paths disabled.
   Who will verify live parameters and Stripe mode before launch?
3. **Retention/deletion:** What periods and reasons apply to reports, call
   invites, messages/media held by recipients, consultations/payment records,
   provider logs, backups and failed-deletion records? What completion service
   level can be promised?
4. **Providers and locations:** Have Firebase, Agora, Google Vision, Stripe and
   Netlify data-processing terms and region settings been checked? Is the
   required privacy impact assessment complete?
5. **Safety operations:** Who monitors support/reports, at what hours, with what
   urgent response and appeal process? Is 18+ self-declaration the intended
   policy, and who responds to `Underage account` reports?
6. **Product disclosures:** Do push notifications show message previews? Is
   matching limited to this repo's search/filter code or does another AI vendor
   receive user information? Which Analytics/Crashlytics settings are active?
7. **Legal language:** Who will review French-language Québec obligations,
   consumer/refund wording before any future paid launch, privacy-rights
   response timing, and incident-response text?
