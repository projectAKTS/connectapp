/// In-app legal and safety texts (Markdown).
///
/// Published with the v1.0.2 free MVP (founder approved publishing on
/// 2026-11-23); a lawyer review is still pending. The site pages are built
/// from these constants by tool/build_legal_site.py.
class LegalTexts {
  LegalTexts._();

  static const String supportEmail = 'support@kindupp.ca';
  static const String privacyUrl = 'https://kindupp.com/privacy/';
  static const String termsUrl = 'https://kindupp.com/terms/';
  static const String supportUrl = 'https://kindupp.com/support/';
  static const String lastUpdated = 'November 23, 2026';

  static const String safety = '''
## If you are in danger

- **Emergency:** call **911**.
- **Suicide or mental health crisis:** call or text **988** (Canada, 24/7).
- **Under 20:** Kids Help Phone, call **1-800-668-6868** or text **686868**.

Kindupp is a peer community. Helpers share their own experience. They are
not lawyers, licensed immigration consultants, doctors or counsellors, and
nothing on Kindupp is legal, immigration, medical or financial advice.

## Stay safe

- Keep payments inside Kindupp. Never send money outside the app.
- Do not share passwords, banking details or ID documents.
- For immigration applications, use a licensed consultant (RCIC) or a lawyer.
- Report anyone who makes you uncomfortable. Use the **...** menu on a post,
  profile or chat. Reports are private.
- Block people you don't want to hear from.

Questions? Contact us at $supportEmail.
''';

  static const String guidelines = '''
## Community guidelines

Kindupp works when people feel safe asking for help.

- **Be kind and respectful.** No harassment, hate, threats or bullying.
- **Share experience, not professional advice.** Say what worked for you.
  Don't present yourself as a lawyer, consultant or doctor unless you are
  verified as one.
- **Be honest.** No fake profiles, scams, spam or misleading claims.
- **Respect privacy.** Don't share other people's personal information.
- **Keep it legal and safe.** No illegal content, sexual content, or
  content that puts anyone at risk.

We may remove content or suspend accounts that break these rules.
''';

  static const String terms = '''
## Terms of Service

_Last updated: ${lastUpdated}_

By creating an account or using Kindupp, you agree to these terms.

### 1. Who can use Kindupp
You must be at least 18 years old and able to enter into a binding
contract.

### 2. What Kindupp is
Kindupp connects people looking for help with people who share their lived
experience (for example, settling in Canada, finding housing or a job).
Helpers are independent community members, not employees or agents of
Kindupp. **Content and conversations on Kindupp are not legal, immigration,
medical, financial or other professional advice.** For an immigration
application, consult a licensed immigration consultant (RCIC) or a lawyer.

### 3. Your account
Keep your sign-in details safe. You are responsible for activity on your
account. You can delete your account at any time in Settings.

### 4. Your content
You keep ownership of what you post. You give Kindupp a licence to host,
display and share it as part of the service. Do not post anything you do
not have the right to share or that breaks the Community Guidelines.

### 5. Kindupp is free
This version of Kindupp is free. Payments, subscriptions and payouts are
turned off. If we add paid features, we will show their terms and their
cancellation and refund rules before you book.

### 6. Safety and moderation
You can report and block other users. We may remove content, limit
features or suspend accounts that break these terms or the Community
Guidelines.

### 7. Disclaimers and liability
Kindupp is provided "as is". We do not guarantee that information shared
by users is accurate and, to the extent permitted by law, we are not
responsible for decisions you make based on it.

### 8. Changes
We may update these terms. We will tell you in the app about important
changes.

### 9. Contact
$supportEmail
''';

  static const String privacy = '''
## Privacy Policy

_Last updated: ${lastUpdated}_

This policy explains what personal information Kindupp collects, why, who
receives it, and your rights. It is written for Canada's PIPEDA and
Québec's Act respecting the protection of personal information in the
private sector (Law 25).

### Who is responsible
Kindupp is operated by Yakup Akturk, sole proprietor, Québec, Canada.

**Person in charge of the protection of personal information:** the
Founder, $supportEmail

### What we collect
- **Account:** name, email address, sign-in method (email, Google or Apple).
- **Profile:** photo, bio, city, country, time zone, the languages you speak,
  topics you need help with, the experience you can share, availability.
- **Content you create:** posts, comments, messages and attachments (photos,
  videos), and reviews you give after a session.
- **Calls:** who called whom, when, call type and status. The audio and
  video of calls are not recorded or stored by Kindupp.
- **Sessions:** free sessions you book and their status. Payments are
  turned off in this version, and Kindupp does not collect payment card
  information.
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
  posts, messages, calls and sessions.
- To keep the community safe: moderation, reports, blocking, preventing
  abuse and fraud.
- To send notifications you have enabled.
- If you allow it: to fix crashes and improve the app.

### Who receives it (service providers)
- **Google Firebase** (Authentication, Cloud Firestore, Cloud Storage, Cloud
  Functions, Cloud Messaging, App Check, Hosting): accounts, database, files,
  server logic, notifications, abuse protection and the website. Stored in
  the United States.
- **Google Firebase Crashlytics and Analytics:** crash reports and usage
  statistics, only if you turn them on. United States.
- **Apple** (push notifications, incoming calls, Sign in with Apple) and
  **Google** (Firebase Cloud Messaging, Google Sign-In): notifications and
  sign-in. Device tokens and sign-in identity. United States.
- **Google Cloud Vision SafeSearch:** automated safety check of post images
  and a frame from post videos. Chat media is not sent.
- **Agora:** real-time audio and video calls. Call media passes through
  Agora's network, which may use servers outside Canada. Calls are not
  recorded.

Other users see your public profile, your posts and comments, and the
messages you send them.

### Transfers outside Québec and Canada
Our providers process and store information outside Québec, including in
the United States, where it may be accessible to authorities under local
law. We choose providers whose terms require them to protect it.

### How long we keep it
- **Account deletion:** when you delete your account in the app, we delete
  your sign-in account, profile, posts and the photos and videos you
  uploaded. If part of the deletion fails, our servers retry it
  automatically.
- **Kept after deletion:** messages and chat media you sent stay in the
  other person's conversation. Review stars stay in a helper's average
  without your name; review comments are removed. Your comments on other
  people's posts are deleted (or emptied, if others replied under them),
  and your name is removed from call records. Reports and call invitation
  records may be kept to protect the community.
- **Crash reports and usage statistics:** kept by Google Firebase for a
  limited time under its retention settings.

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
  ask how it is handled: $supportEmail. We answer within 30 days.
- You may complain to the Commission d'accès à l'information du Québec or
  the Office of the Privacy Commissioner of Canada.

### Adults only
Kindupp is for people aged 18 and over. We rely on your declaration and do
not check ID. If we learn that an account belongs to someone under 18, we
suspend it.

### Security incidents
We keep a register of confidentiality incidents. When an incident presents
a risk of serious injury, we notify the Commission d'accès à l'information
and the people affected, as the law requires.

### Changes
We will tell you in the app about important changes to this policy.

### Contact
$supportEmail
''';
}
