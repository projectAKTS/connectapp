/// On-device scam signals for the chat warning (docs/SAFETY_ROADMAP.md #4).
///
/// A received message that asks for money, payment codes or passwords, or to
/// move to another app, shows a "Be careful" banner to the recipient. The
/// message is not blocked and nothing leaves the device.
class ScamSignals {
  ScamSignals._();

  static final List<RegExp> _patterns = [
    // Money transfers and payment apps (EN/FR).
    RegExp(
        r'\b(e-?transfer|interac|virement|western union|moneygram|paypal|cash ?app|venmo|zelle|wire transfer|wise\.com)\b'),
    RegExp(r'\b(send|lend|transfer)\b.{0,20}\b(money|cash|\$|dollars?)\b'),
    RegExp(
        r"(^|[^a-zà-ÿ])(envoie|envoyez|envoyer|prête|prêter|prêtez)([^a-zà-ÿ]).{0,20}\b(argent|dollars?)\b"),
    // Gift cards and crypto.
    RegExp(
        r'\b(gift ?cards?|cartes?[- ]cadeaux?|itunes card|google play card|steam card|bitcoin|btc|crypto|usdt)\b'),
    // Codes and passwords.
    RegExp(
        r'\b(verification code|security code|one[- ]time code|otp|pin code|password|code de (vérification|sécurité|confirmation)|mot de passe|nip)\b'),
    // Moving the conversation elsewhere.
    RegExp(r'\b(whatsapp|telegram|signal app|snapchat|wechat|kik)\b'),
  ];

  /// Whether [text] contains a scam signal.
  static bool matches(String text) {
    final t = text.toLowerCase();
    if (t.trim().isEmpty) return false;
    return _patterns.any((p) => p.hasMatch(t));
  }
}
