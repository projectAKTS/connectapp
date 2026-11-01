import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

String norm(String s) {
  const fold = {
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'à': 'a',
    'â': 'a',
    'ç': 'c',
    'î': 'i',
    'ô': 'o',
    'û': 'u',
    'ù': 'u',
    '’': "'"
  };
  return s.toLowerCase().split('').map((c) => fold[c] ?? c).join();
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  group('cross-language topic search', () {
    test('a French topic word also finds English-tagged posts', () {
      final terms = ValueLabels.topicSearchTerms('logement', norm);
      expect(terms, containsAll(['logement', 'housing', 'housing search']));
    });

    test('an English topic word also finds French text', () {
      final terms = ValueLabels.topicSearchTerms('housing', norm);
      expect(terms, contains('logement'));
    });

    test('accents do not matter', () {
      final terms = ValueLabels.topicSearchTerms(norm('Vie étudiante'), norm);
      expect(terms, contains('student life'));
    });

    test('ordinary words and very short queries are left alone', () {
      expect(ValueLabels.topicSearchTerms('pizza', norm), {'pizza'});
      expect(ValueLabels.topicSearchTerms('lo', norm), {'lo'});
    });

    test('every topic id is covered', () {
      for (final id in ValueLabels.topicIds) {
        expect(ValueLabels.topic(en, id), id);
        expect(ValueLabels.topic(fr, id), isNot(id));
      }
    });
  });

  group('badges', () {
    test('the emoji stays and the name is translated', () {
      expect(ValueLabels.badge(fr, '🏅 First Contributor'),
          '🏅 Première contribution');
      expect(ValueLabels.badge(fr, '🥉 Beginner Helper'),
          '🥉 Personne-ressource débutante');
    });

    test('English and unknown badges are shown as stored', () {
      expect(ValueLabels.badge(en, '🏅 First Contributor'),
          '🏅 First Contributor');
      expect(ValueLabels.badge(fr, '🎉 Something New'), '🎉 Something New');
      expect(ValueLabels.badge(fr, 'NoEmoji'), 'NoEmoji');
    });
  });
}
