/// In-app legal and safety texts (Markdown).
///
/// DRAFTS written for the MVP launch: they must be reviewed by a lawyer
/// before public release. [supportEmail] must be set to a real support
/// address the operator monitors.
class LegalTexts {
  LegalTexts._();

  static const String supportEmail = 'support@helperly.app';
  static const String lastUpdated = 'October 31, 2026';

  static const String safety = '''
## If you are in danger

- **Emergency:** call **911**.
- **Suicide or mental health crisis:** call or text **988** (Canada, 24/7).
- **Under 20:** Kids Help Phone, call **1-800-668-6868** or text **686868**.

Helperly is a peer community. Helpers share their own experience. They are
not lawyers, licensed immigration consultants, doctors or counsellors, and
nothing on Helperly is legal, immigration, medical or financial advice.

## Stay safe

- Keep payments inside Helperly. Never send money outside the app.
- Do not share passwords, banking details or ID documents.
- For immigration applications, use a licensed consultant (RCIC) or a lawyer.
- Report anyone who makes you uncomfortable. Use the **...** menu on a post,
  profile or chat. Reports are private.
- Block people you don't want to hear from.

Questions? Contact us at $supportEmail.
''';

  static const String guidelines = '''
## Community guidelines

Helperly works when people feel safe asking for help.

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
## Terms of Use

_Last updated: ${lastUpdated}_

By creating an account or using Helperly, you agree to these terms.

### 1. Who can use Helperly
You must be at least 18 years old and able to enter a binding agreement.

### 2. What Helperly is
Helperly connects people who want help with people who share their lived
experience (for example, settling in Canada, finding housing or work).
Helpers are independent community members, not employees or agents of
Helperly. **Content and conversations on Helperly are not legal,
immigration, medical, financial or other professional advice.** For
immigration applications, consult a licensed immigration consultant (RCIC)
or a lawyer.

### 3. Your account
Keep your login details secure. You are responsible for activity on your
account. You can delete your account at any time in Settings.

### 4. Your content
You keep ownership of what you post. You give Helperly a licence to host,
display and distribute it within the service. Don't post anything you
don't have the right to share or that breaks the Community guidelines.

### 5. Paid sessions
Some helpers offer paid audio or video sessions. Prices are shown before
you book. Payments are processed by Stripe; Helperly keeps a platform fee
and pays the rest to the helper. Cancellations and refunds follow the
policy shown when you book.

### 6. Safety and moderation
You can report and block other users. We may remove content, limit
features or suspend accounts that break these terms or the Community
guidelines.

### 7. Disclaimers and liability
Helperly is provided "as is". We don't guarantee the accuracy of any
information shared by users, and to the extent permitted by law we are not
liable for decisions you make based on it.

### 8. Changes
We may update these terms. We'll let you know about important changes in
the app.

### 9. Contact
$supportEmail
''';

  static const String privacy = '''
## Privacy Policy

_Last updated: ${lastUpdated}_

This policy explains what personal information Helperly collects and how we
use it, in line with Canada's PIPEDA.

### What we collect
- **Account:** name, email, sign-in provider.
- **Profile:** photo, bio, country, languages, topics and expertise you add.
- **Content:** posts, comments, messages and attachments you share.
- **Calls:** who called whom, when, and for how long. We don't record the
  audio or video of calls.
- **Payments:** handled by Stripe. We store a payment reference, never your
  full card number.
- **Device:** push notification tokens, app version, and diagnostic data
  that helps us fix problems.

### How we use it
To run the service (profiles, matching, messages, calls, payments), to keep
the community safe (moderation, reports, blocking), to send notifications
you've enabled, and to fix bugs and improve the app.

### Who we share it with
Service providers who run parts of Helperly for us: Google Firebase
(hosting, database, sign-in, notifications), Agora (calls) and Stripe
(payments). Other users see your public profile and the content you post.
We don't sell personal information.

### Where it is stored
Our providers may store data outside Canada, including in the United
States.

### How long we keep it
While your account is active. When you delete your account, we delete your
profile and personal data within 30 days, except records we must keep by
law (for example, payment records).

### Your choices and rights
You can view and edit your profile, change notification settings, and
delete your account in Settings. You can ask us for access to or
correction of your personal information at $supportEmail.

### Contact
$supportEmail
''';
}
