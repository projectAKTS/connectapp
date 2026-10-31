import 'package:connect_app/services/content_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ordinary help requests pass', () {
    for (final text in [
      'Where can I find an apartment near Montreal?',
      'My assistant helped me with the resume.',
      'Scunthorpe, Middlesex and Essex are places.',
      'Dickens is my favourite author.',
      'Désolé, je suis en retard pour le rendez-vous.',
      'Amina helped me find a school.',
      'Philip K. Dick wrote great books.',
      'How do I get a SIN number?',
      'Ankara’dan Montreal’e taşındım, iş arıyorum.',
      'Je cherche un logement à Québec.',
    ]) {
      expect(ContentFilter.isAllowed(text), isTrue, reason: text);
    }
  });

  test('slurs and explicit words are blocked as whole words', () {
    expect(ContentFilter.isAllowed('you are a faggot'), isFalse);
    expect(ContentFilter.isAllowed('send me porn'), isFalse);
    expect(ContentFilter.isAllowed('Siktir git'), isFalse);
    expect(ContentFilter.isAllowed('quelle salope'), isFalse);
  });

  test('simple character swaps do not get around the filter', () {
    expect(ContentFilter.isAllowed('f@ggot'), isFalse);
    expect(ContentFilter.isAllowed('p0rn'), isFalse);
    expect(ContentFilter.isAllowed('wh0re'), isFalse);
  });

  test('the blocked word is reported', () {
    expect(ContentFilter.blockedWordIn('hello PORN world'), 'porn');
    expect(ContentFilter.blockedWordIn('hello world'), isNull);
  });
}
