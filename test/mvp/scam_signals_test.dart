import 'package:connect_app/services/scam_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money, codes, gift cards and other apps are flagged (EN/FR)', () {
    for (final text in [
      'Can you send me money for the deposit?',
      'Send \$200 by Interac e-transfer please',
      'Peux-tu me prêter 200 dollars ?',
      'Envoie-moi de l’argent pour le dépôt',
      'Un virement de 300 dollars',
      'Buy two Google Play gift cards',
      'Achète des cartes-cadeaux',
      'Pay me in bitcoin',
      'What is the verification code you received?',
      'Donne-moi le code de vérification',
      'Tell me your password',
      'Quel est ton mot de passe ?',
      'Let’s continue on WhatsApp',
      'Écris-moi sur Telegram',
    ]) {
      expect(ScamSignals.matches(text), isTrue, reason: text);
    }
  });

  test('ordinary help conversations are not flagged', () {
    for (final text in [
      'Bonjour, je cherche un appartement, pouvez-vous m’aider ?',
      'The rent was about 1200 a month in Rosemont',
      'Pour le bail, demandez une copie signée',
      'I can call you tomorrow at 6pm',
      'Merci beaucoup pour ton aide !',
      'How did you find your first job here?',
      'Le code postal est H2X',
      '',
    ]) {
      expect(ScamSignals.matches(text), isFalse, reason: text);
    }
  });
}
