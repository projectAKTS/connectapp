import 'package:connect_app/l10n/formatters.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  test('English post badges are unchanged; French ones are translated', () {
    expect(ValueLabels.postType(en, 'Quick'), 'Quick Post');
    expect(ValueLabels.postType(en, ''), 'Quick Post');
    expect(ValueLabels.postType(en, 'Experience'), 'Experience Post');
    expect(ValueLabels.postType(en, 'Advice Request'), 'Advice Request Post');
    expect(ValueLabels.postType(en, 'Custom'), 'Custom Post');
    expect(ValueLabels.postType(fr, 'Quick'), 'Publication rapide');
    expect(ValueLabels.postType(fr, 'How-To Guide'), 'Guide pratique');
    expect(ValueLabels.postType(fr, 'Custom'), 'Custom Post');
  });

  Future<List<String>> ago(WidgetTester tester, Locale locale) async {
    final now = DateTime(2026, 10, 31, 12);
    late List<String> out;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: AppLanguages.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        out = [
          for (final d in const [
            Duration.zero,
            Duration(seconds: 30),
            Duration(minutes: 5),
            Duration(hours: 3),
            Duration(days: 2),
            Duration(days: 14),
            Duration(days: 90),
            Duration(days: 800),
          ])
            AppFormat.timeAgo(context, now.subtract(d), now: now),
        ];
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    return out;
  }

  testWidgets('relative times read naturally in both languages',
      (tester) async {
    expect(await ago(tester, const Locale('en')), [
      'now',
      '30s ago',
      '5m ago',
      '3h ago',
      '2d ago',
      '2w ago',
      '3mo ago',
      '2y ago'
    ]);
    expect(await ago(tester, const Locale('fr')), [
      "à l'instant",
      'il y a 30 s',
      'il y a 5 min',
      'il y a 3 h',
      'il y a 2 j',
      'il y a 2 sem.',
      'il y a 3 mois',
      'il y a 2 ans',
    ]);
  });
}
