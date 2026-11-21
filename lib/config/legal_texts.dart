/// In-app legal and safety texts (Markdown).
///
/// DRAFTS written for the MVP launch: they must be reviewed by a lawyer
/// before public release. [supportEmail] must be set to a real support
/// address the operator monitors.
class LegalTexts {
  LegalTexts._();

  static const String supportEmail = 'support@kindupp.ca';
  static const String privacyUrl = 'https://kindupp.com/privacy/';
  static const String termsUrl = 'https://kindupp.com/terms/';
  static const String supportUrl = 'https://kindupp.com/support/';
  static const String lastUpdated = 'October 31, 2026';

  static const String safety = '''
## If you are in danger

- **Emergency:** call **911**.
- **Suicide or mental health crisis:** call or text **988** (Canada, 24/7).
- **Under 20:** Kids Help Phone, call **1-800-668-6868** or text **686868**.

KINDUPP is a peer community. Helpers share their own experience. They are
not lawyers, licensed immigration consultants, doctors or counsellors, and
nothing on KINDUPP is legal, immigration, medical or financial advice.

## Stay safe

- Keep payments inside KINDUPP. Never send money outside the app.
- Do not share passwords, banking details or ID documents.
- For immigration applications, use a licensed consultant (RCIC) or a lawyer.
- Report anyone who makes you uncomfortable. Use the **...** menu on a post,
  profile or chat. Reports are private.
- Block people you don't want to hear from.

Questions? Contact us at $supportEmail.
''';

  static const String guidelines = '''
## Community guidelines

KINDUPP works when people feel safe asking for help.

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
## Terms of Service (DRAFT)

The Terms of Service are still under review and are not final. Read the
current draft at https://kindupp.com/terms/. Do not treat it as a finalized
agreement.

Questions: $supportEmail
''';

  static const String privacy = '''
## Privacy Policy (DRAFT)

The Privacy Policy is still under review and is not final. Read the current
draft at https://kindupp.com/privacy/. Do not treat it as a finalized
privacy notice.

Questions: $supportEmail
''';
}
