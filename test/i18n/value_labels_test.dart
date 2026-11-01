import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/models/help_topics.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));
  final ids = [...HelpTopics.topics, ...HelpTopics.expertise];

  group('stored values are identifiers', () {
    test('English labels equal the stored values, so English is unchanged', () {
      for (final id in ids) {
        expect(ValueLabels.topic(en, id), id);
      }
      for (final id in SafetyService.reportReasons) {
        expect(ValueLabels.reportReason(en, id), id);
      }
      for (final id in const ['Canada', 'USA', 'Other']) {
        expect(ValueLabels.country(en, id), id);
      }
    });

    test('every topic, expertise and report reason has a French label', () {
      for (final id in [...ids, ...SafetyService.reportReasons]) {
        final label = id == 'Immigration experience' ||
                HelpTopics.topics.contains(id) ||
                HelpTopics.expertise.contains(id)
            ? ValueLabels.topic(fr, id)
            : ValueLabels.reportReason(fr, id);
        expect(label, isNot(id), reason: 'untranslated: $id');
      }
    });

    test('labels are unique, so a French choice maps back to one id', () {
      for (final l in [en, fr]) {
        final labels = ids.toSet().map((id) => ValueLabels.topic(l, id));
        expect(labels.toSet().length, ids.toSet().length);
      }
    });

    test('unknown stored values are shown as stored', () {
      expect(ValueLabels.topic(fr, 'Custom tag'), 'Custom tag');
      expect(ValueLabels.country(fr, 'Mexico'), 'Mexico');
    });
  });

  group('English and French users match the same helpers', () {
    // What a UI does: list ids, show labels, store the picked id.
    String pick(AppLocalizations l, String label) =>
        HelpTopics.topics.firstWhere((id) => ValueLabels.topic(l, id) == label);

    final helpers = <String, List<String>>{
      'resume': ['Resume review'],
      'housing': ['Housing search'],
      'settler': ['Settlement tips', 'Language practice'],
      'legacy': [],
    };
    const legacyTags = {
      'legacy': ['Housing']
    };

    Set<String> matches(String topicId) => helpers.entries
        .where((h) => HelpTopics.helperFitsTopic(
              topic: topicId,
              expertiseTags: h.value,
              legacyTags: legacyTags[h.key] ?? const [],
            ))
        .map((h) => h.key)
        .toSet();

    test('the same topic picked in either language gives the same result', () {
      for (final id in HelpTopics.topics) {
        final fromEnglish = pick(en, ValueLabels.topic(en, id));
        final fromFrench = pick(fr, ValueLabels.topic(fr, id));
        expect(fromFrench, fromEnglish);
        expect(matches(fromFrench), matches(fromEnglish));
      }
      expect(matches(pick(fr, 'Logement')), {'housing', 'settler', 'legacy'});
      expect(matches(pick(fr, "Recherche d'emploi")), {'resume'});
    });
  });

  group('spoken languages', () {
    test('legacy English names map to codes', () {
      expect(ValueLabels.codeForLanguage('English'), 'en');
      expect(ValueLabels.codeForLanguage('French'), 'fr');
      expect(ValueLabels.codeForLanguage('tr'), 'tr');
      expect(ValueLabels.codeForLanguage('Other'), isNull);
      expect(ValueLabels.codeForLanguage('Klingon'), isNull);
    });

    test('codes and legacy names show in the app language', () {
      expect(ValueLabels.language(fr, 'tr'), 'Turc');
      expect(ValueLabels.language(fr, 'English'), 'Anglais');
      expect(ValueLabels.language(en, 'ht'), 'Haitian Creole');
      expect(ValueLabels.language(fr, 'Other'), 'Autre');
    });

    test('every offered code has a label in both languages', () {
      for (final code in ValueLabels.languageCodes) {
        expect(ValueLabels.language(en, code), isNot(code));
        expect(ValueLabels.language(fr, code), isNot(code));
      }
    });
  });
}
