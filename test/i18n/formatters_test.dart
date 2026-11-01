import 'package:connect_app/l10n/formatters.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(AppFormat.init);
  // 2026-10-31 18:05 UTC; shown in the test machine's local time zone, so
  // the checks below use the local DateTime directly.
  final when = DateTime(2026, 10, 31, 14, 5);

  Future<Map<String, String>> formatted(
      WidgetTester tester, Locale app, Locale device) async {
    tester.platformDispatcher.localeTestValue = device;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    late Map<String, String> out;
    await tester.pumpWidget(MaterialApp(
      locale: app,
      supportedLocales: AppLanguages.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(builder: (context) {
        out = {
          'locale': AppFormat.localeOf(context),
          'date': AppFormat.date(context, when),
          'time': AppFormat.time(context, when),
          'money': AppFormat.money(context, 4.99),
          'whole': AppFormat.money(context, 20, decimals: 0),
        };
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
    return out;
  }

  testWidgets('English in Canada', (tester) async {
    final f =
        await formatted(tester, const Locale('en'), const Locale('en', 'CA'));
    expect(f['locale'], 'en_CA');
    expect(f['date'], 'Oct 31, 2026');
    expect(f['time'], contains('2:05'));
    expect(f['money'], '\$4.99');
    expect(f['whole'], '\$20');
  });

  testWidgets('French in Canada: comma decimals, dollar sign after, 24 h',
      (tester) async {
    final f =
        await formatted(tester, const Locale('fr'), const Locale('fr', 'CA'));
    expect(f['locale'], 'fr_CA');
    expect(f['date'], contains('oct.'));
    expect(f['time'], contains('14'));
    expect(f['money'], matches(RegExp(r'^4,99\s\$$')));
  });

  testWidgets('French chosen on an English Canadian phone is still Canadian',
      (tester) async {
    final f =
        await formatted(tester, const Locale('fr'), const Locale('en', 'CA'));
    expect(f['locale'], 'fr_CA');
    expect(f['money'], matches(RegExp(r'^4,99\s\$$')));
  });

  testWidgets('regions intl does not know fall back to the language',
      (tester) async {
    final f =
        await formatted(tester, const Locale('en'), const Locale('tr', 'TR'));
    expect(f['locale'], 'en');
    expect(f['date'], 'Oct 31, 2026');
    expect(f['money'], 'CA\$4.99', reason: 'outside Canada CAD is explicit');
  });
}
