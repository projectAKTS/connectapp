import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/models/profile_languages.dart';
import 'package:connect_app/utils/availability_time.dart';
import 'package:connect_app/widgets/spoken_languages_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The onboarding gate of builds already installed on phones.
bool oldBuildPassesGate(Map<String, dynamic> doc) =>
    (doc['language'] ?? '').toString().trim().isNotEmpty;

void main() {
  group('reading spoken languages', () {
    test('the new field wins and is cleaned', () {
      expect(
          ProfileLanguages.read({
            'spokenLanguages': ['tr', 'fr', 'tr', 'xx'],
            'language': 'English',
          }),
          ['tr', 'fr']);
    });

    test('older profiles fall back to the legacy field', () {
      expect(ProfileLanguages.read({'language': 'English'}), ['en']);
      expect(ProfileLanguages.read({'language': 'French'}), ['fr']);
      expect(ProfileLanguages.read({'language': 'Other'}), isEmpty);
      expect(ProfileLanguages.read({}), isEmpty);
      expect(
          ProfileLanguages.read({
            'languages': ['French', 'English']
          }),
          ['fr', 'en']);
    });

    test('the onboarding gate accepts old and new profiles', () {
      expect(ProfileLanguages.hasAny({'language': 'Other'}), isTrue);
      expect(ProfileLanguages.hasAny({'language': 'English'}), isTrue);
      expect(
          ProfileLanguages.hasAny({
            'spokenLanguages': ['ar']
          }),
          isTrue);
      expect(ProfileLanguages.hasAny({'language': ''}), isFalse);
      expect(ProfileLanguages.hasAny({}), isFalse);
    });
  });

  group('writing spoken languages', () {
    test('every save keeps older builds out of onboarding', () {
      for (final codes in const [
        ['en'],
        ['fr'],
        ['tr'],
        ['ar', 'fr'],
        ['fr', 'en'],
      ]) {
        final doc = ProfileLanguages.fields(codes);
        expect(doc['spokenLanguages'], codes);
        expect(oldBuildPassesGate(doc), isTrue, reason: '$codes');
      }
      expect(ProfileLanguages.fields(['ar', 'fr'])['language'], 'French');
      expect(ProfileLanguages.fields(['fr', 'en'])['language'], 'English');
      expect(ProfileLanguages.fields(['tr'])['language'], 'Other');
    });

    test('an empty list writes nothing, so legacy values survive', () {
      expect(ProfileLanguages.fields([]), isEmpty);
    });

    test('a profile saved by the new build reads back the same', () {
      final doc = ProfileLanguages.fields(['tr', 'fr']);
      expect(ProfileLanguages.read(doc), ['tr', 'fr']);
    });
  });

  group('availability time', () {
    test('stored in one fixed English form, whatever the app language', () {
      expect(
          AvailabilityTime.store(const TimeOfDay(hour: 9, minute: 0),
              const TimeOfDay(hour: 17, minute: 30)),
          '9:00 AM–5:30 PM');
      expect(
          AvailabilityTime.store(const TimeOfDay(hour: 0, minute: 5),
              const TimeOfDay(hour: 12, minute: 0)),
          '12:05 AM–12:00 PM');
    });

    test('reads what any build wrote', () {
      for (final stored in const [
        '9:00 AM–5:30 PM',
        '09:00–17:30',
        '9 h 00–17 h 30',
      ]) {
        final r = AvailabilityTime.parse(stored)!;
        expect(r.$1, const TimeOfDay(hour: 9, minute: 0), reason: stored);
        expect(r.$2, const TimeOfDay(hour: 17, minute: 30), reason: stored);
      }
      expect(AvailabilityTime.parse(''), isNull);
      expect(AvailabilityTime.parse('Weekends'), isNull);
    });

    test('a stored value round-trips', () {
      const start = TimeOfDay(hour: 13, minute: 45);
      const end = TimeOfDay(hour: 23, minute: 15);
      final r = AvailabilityTime.parse(AvailabilityTime.store(start, end))!;
      expect(r, (start, end));
    });

    test('device time zone in the existing GMT±h form', () {
      expect(AvailabilityTime.deviceTimeZone(DateTime.now()),
          matches(RegExp(r'^GMT[+-]\d{1,2}(:\d{2})?$')));
    });
  });

  testWidgets('a French user picks spoken languages; codes are stored',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    var codes = <String>[];
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: AppLanguages.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SpokenLanguagesField(
            codes: codes,
            onChanged: (c) => setState(() => codes = c),
          ),
        ),
      ),
    ));
    expect(find.text('Choisir des langues'), findsOneWidget);
    await tester.tap(find.byKey(const Key('spoken_languages_field')));
    await tester.pumpAndSettle();
    // Alphabetical in French: Turc is near the end of the list.
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Turc'), 200, scrollable: list);
    await tester.tap(find.text('Turc'));
    await tester.scrollUntilVisible(find.text('Français'), -200,
        scrollable: list);
    await tester.tap(find.text('Français'));
    await tester.tap(find.byKey(const Key('spoken_languages_done')));
    await tester.pumpAndSettle();
    expect(codes, ['tr', 'fr']);
    expect(find.text('Turc, Français'), findsOneWidget);
  });
}
