import 'dart:convert';
import 'dart:io';

import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/screens/settings/settings_screen.dart';
import 'package:connect_app/services/app_prefs.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/locale_controller.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final controller = LocaleController.instance;

  setUp(() {
    AppPrefs.debugSetForTest({});
    controller.choice.value = null;
  });

  tearDown(HelperlyTestRuntime.clear);

  group('language resolution', () {
    test('French devices get French, any region', () {
      expect(
          AppLanguages.resolve(const Locale('fr', 'CA')), const Locale('fr'));
      expect(
          AppLanguages.resolve(const Locale('fr', 'FR')), const Locale('fr'));
    });

    test('unsupported device languages fall back to English', () {
      for (final device in const [
        Locale('tr', 'TR'),
        Locale('ar'),
        Locale('es', 'MX'),
      ]) {
        expect(AppLanguages.resolve(device), const Locale('en'));
      }
      expect(AppLanguages.resolve(null), const Locale('en'));
    });

    test('formatting keeps the device region', () {
      expect(
          AppLanguages.formatLocale(
              const Locale('fr'), const Locale('en', 'CA')),
          'fr_CA');
      expect(
          AppLanguages.formatLocale(
              const Locale('en'), const Locale('tr', 'TR')),
          'en_TR');
      expect(AppLanguages.formatLocale(const Locale('en'), const Locale('en')),
          'en');
    });
  });

  group('saved choice', () {
    test('a choice is saved and restored on the next start', () async {
      await controller.select(const Locale('fr'));
      expect(AppPrefs.getString(LocaleController.prefKey), 'fr');

      controller.choice.value = null; // a restart
      controller.loadSaved();
      expect(controller.choice.value, const Locale('fr'));
      expect(controller.effective, const Locale('fr'));
    });

    test('"device language" clears the choice', () async {
      await controller.select(const Locale('fr'));
      await controller.select(null);
      expect(AppPrefs.getString(LocaleController.prefKey), isNull);
      controller.loadSaved();
      expect(controller.choice.value, isNull);
    });

    test('a saved language that is no longer offered is ignored', () {
      AppPrefs.debugSetForTest({LocaleController.prefKey: 'xx'});
      controller.loadSaved();
      expect(controller.choice.value, isNull);
    });

    test('the effective language is mirrored to the account for pushes',
        () async {
      final firestore = FakeFirebaseFirestore();
      HelperlyTestRuntime.configureForTest(
          firestore: firestore, currentUid: 'me');
      await firestore.collection('users').doc('me').set({'fullName': 'Me'});
      controller.choice.value = const Locale('fr');
      await controller.syncToAccount();
      final me = (await firestore.collection('users').doc('me').get()).data()!;
      expect(me['appLocale'], 'fr');
      expect(me['fullName'], 'Me');
    });
  });

  group('translations', () {
    Map<String, dynamic> arb(String name) =>
        jsonDecode(File('lib/l10n/$name').readAsStringSync())
            as Map<String, dynamic>;
    Set<String> keys(Map<String, dynamic> m) =>
        m.keys.where((k) => !k.startsWith('@')).toSet();

    test('French has every English string and no extra ones', () {
      final en = keys(arb('app_en.arb'));
      final fr = keys(arb('app_fr.arb'));
      expect(en.difference(fr), isEmpty, reason: 'missing in French');
      expect(fr.difference(en), isEmpty, reason: 'not in the English template');
    });

    test('placeholders match between languages', () {
      final en = arb('app_en.arb');
      final fr = arb('app_fr.arb');
      // {name} or {name, plural, ...}; not words inside plural branches.
      final ph = RegExp(r'\{(\w+)\s*[},]');
      for (final key in keys(en)) {
        final a = ph.allMatches('${en[key]}').map((m) => m[1]).toSet();
        final b = ph.allMatches('${fr[key]}').map((m) => m[1]).toSet();
        expect(b, a, reason: key);
      }
    });

    testWidgets('without a localization delegate, English is used',
        (tester) async {
      late String title;
      await tester.pumpWidget(Builder(builder: (context) {
        title = context.l10n.settingsTitle;
        return const SizedBox();
      }));
      expect(title, 'Settings');
    });
  });

  testWidgets('Settings switches English and French and saves the choice',
      (tester) async {
    await tester.pumpWidget(ValueListenableBuilder<Locale?>(
      valueListenable: controller.choice,
      builder: (_, locale, __) => MaterialApp(
        locale: locale ?? const Locale('en'),
        supportedLocales: AppLanguages.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsScreen(),
      ),
    ));
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language_option_fr')));
    await tester.pumpAndSettle();

    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text("Langue de l'application"), findsOneWidget);
    expect(AppPrefs.getString(LocaleController.prefKey), 'fr');

    await tester.tap(find.byKey(const Key('settings_language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language_option_en')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('usage statistics are off until turned on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    final toggle = find.byKey(const Key('settings_usage_stats'));
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
  });
}
