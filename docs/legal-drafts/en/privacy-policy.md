## Privacy Policy (DRAFT, not published)

_Last updated: [DATE]_

This policy explains what personal information Kindupp collects, why, who
receives it, and your rights. It is written for Canada's PIPEDA and
Québec's Act respecting the protection of personal information in the
private sector (Law 25). [LEGAL REVIEW]

### Who is responsible
Kindupp is operated by [LEGAL NAME OF THE SOLE PROPRIETOR / BUSINESS NAME],
[CITY], Québec. [VERIFY: business registration]

**Person in charge of the protection of personal information:**
[TITLE, e.g. "Founder"] — [PRIVACY CONTACT EMAIL, e.g. privacy@...]
[DO NOT publish personal contact details without the founder's approval]

### What we collect
- **Account:** name, email address, sign-in method (email, Google or Apple).
- **Profile:** photo, bio, city, country, time zone, the languages you speak,
  topics you need help with, the experience you can share, availability.
- **Content you create:** posts, comments, messages and attachments (photos,
  videos), reviews you give after a booked session.
- **Calls:** who called whom, when, call type and status. The audio and
  video of calls are not recorded or stored by Kindupp.
- **Bookings and payment-related records:** free consultations and related
  records. The Phase 3 client and Functions code has payment collection,
  card setup, subscription, and payout flows disabled by default; the
  deployed production app and Functions settings have not been verified.
  Earlier or separately enabled payment flows can create Stripe customer,
  payment method, payment intent, connected-account, consultation, and
  payout references. [VERIFY production status and exact stored fields
  before publication; card display fields and provider retention also need
  confirmation.]
- **Age declaration:** your confirmation that you are 18 or older, with
  its date. We do not collect your birthdate or ID.
- **Safety:** reports you file or that concern you, and who you blocked.
- **Device:** push notification tokens and a random installation id, used
  to deliver messages and calls to your device; your app language, used to
  write notifications in it.
- **Crash reports (optional, off by default):** if you turn on "Send crash
  reports", technical details of crashes (device model, OS and app version,
  error and stack trace). Not linked to your account.
- **Usage statistics (optional, off by default):** if you turn on "Share
  usage statistics", which screens and features are used. Not linked to your
  account and never includes your messages or posts. No advertising
  identifier is collected.

We do not use your information for advertising and we do not sell it.

### Why we use it
- To run Kindupp: accounts, profiles, matching people by topic and language,
  posts, messages, calls, bookings and payments.
- To keep the community safe: moderation, reports, blocking, preventing
  abuse and fraud.
- To send notifications you have enabled.
- If you allow it: to fix crashes and improve the app.

### Who receives it (service providers)
| Provider | Purpose | Data | Location |
|---|---|---|---|
| Google Firebase (Authentication, Cloud Firestore, Cloud Storage, Cloud Functions, Cloud Messaging, App Check, Hosting) | Accounts, database, files, server logic, notifications, abuse protection, website | All app data above | [VERIFY: Firestore/Storage region, e.g. United States] |
| Google Firebase Crashlytics / Analytics | Crash reports / usage statistics, only if you turn them on | Device and usage data above | United States [VERIFY] |
| Apple (APNs, PushKit, Sign in with Apple) and Google (FCM, Google Sign-In) | Notifications, incoming calls, sign-in | Device tokens, sign-in identity | United States |
| Google Cloud Vision SafeSearch | Automated check of post images and a thumbnail/frame from post videos; chat media is not sent by the reviewed code | Submitted post image or video frame; result is written to post moderation fields | Global Vision endpoint; processing region and provider terms [VERIFY] |
| Agora | Real-time audio and video calls; no recording found in reviewed client code | Call media in transit and call metadata | [VERIFY: Agora routing, telemetry, regions and data processing terms] |
| Stripe | Payment methods, payments and helper payouts if/when enabled | Payment and payout information and provider identifiers | [VERIFY account country, enabled state and processing terms] |
| Netlify Forms | Website contact form | Name, email, topic and message | [VERIFY data location, access, retention and deletion] |

Other users see your public profile, your posts and comments, and the
messages you send them.

### Transfers outside Québec and Canada
Our providers process and store information outside Québec, including in
the United States, where it may be accessible to authorities under local
law. Before publication, confirm the required assessment of privacy
protections for these transfers and whether it has been completed.
[LEGAL REVIEW]

### How long we keep it
- **Account deletion:** the app starts a server-side deletion workflow.
  Reviewed code removes the Auth account, user profile and subcollections,
  authored posts and their subcollections, selected references, and user/post
  media. A failed/incomplete deletion is recorded for scheduled retry. The
  code does not establish an overall completion deadline, and cleanup can
  remain incomplete after retries. [Do not promise immediate or 30-day
  completion; confirm operational status and decide a truthful service level.]
- **Kept after deletion:**
  - Messages you sent remain in the recipients' conversations.
  - Review stars remain in a helper's average without your name; review
    comments are removed. Reviews about you as a helper are deleted.
  - Your comments on other people's posts are deleted (or emptied, if
    others replied under them), and your name is removed from call
    records.
  - Messages and chat media remain in the other participant's conversation;
    reports and call invite records are not removed by this deletion code.
  - Consultation/payment records, Stripe customer or connected-account data,
    provider logs, and backups may remain; exact retention and deletion
    controls are unresolved.
- **Crash reports and usage statistics:** optional controls are off by default
  in reviewed client code. Provider retention settings have not been
  verified; do not state a duration until checked in the project settings.

### Optional data: how we ask
After sign-up we ask once, separately, whether you want to share crash
reports and usage statistics. Both are off unless you turn them on, and
saying no changes nothing else. You can change either at any time in
Settings.

### Your choices and rights
- View and edit your profile, change the app language, turn crash reports
  and usage statistics on or off, block people, and delete your account, all
  in the app.
- Ask to access or correct your personal information, withdraw consent, or
  ask about how it is handled: [PRIVACY CONTACT EMAIL]. [Confirm the response
  process and applicable timelines before publication.]
- You may complain to the Commission d'accès à l'information du Québec or
  the Office of the Privacy Commissioner of Canada.

### Children
Kindupp is intended for people aged 18 and over. The app uses a self-
declaration; the reviewed code does not verify age using identity documents
or a date of birth. [Confirm 18+ policy and underage-account handling.]

### Security incidents
We will handle confidentiality incidents and any notices as required by law.
[VERIFY the incident-response process and review this wording with counsel.]

### Changes
We will tell you in the app about important changes to this policy.

### Contact
[PRIVACY CONTACT EMAIL] · support@kindupp.ca
