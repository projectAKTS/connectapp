import 'package:connect_app/l10n/app_localizations.dart';
import 'package:connect_app/screens/auth/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WelcomeScreen(),
        routes: {
          '/register': (_) => const Scaffold(body: Text('register page')),
          '/login': (_) => const Scaffold(body: Text('login page')),
        },
      );

  testWidgets('says what Kindupp is and shows an example', (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Someone has already solved the problem you’re facing.'),
        findsOneWidget);
    expect(find.text('Launched their first product on Amazon'), findsOneWidget);

    // The example changes on its own.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Found a flat in Montreal as newcomers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leads to sign up or sign in', (tester) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 2));
    await tester.ensureVisible(find.byKey(const Key('welcome_start')));
    await tester.tap(find.byKey(const Key('welcome_start')));
    await tester.pumpAndSettle();
    expect(find.text('register page'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('welcome_sign_in')));
    await tester.tap(find.byKey(const Key('welcome_sign_in')));
    await tester.pumpAndSettle();
    expect(find.text('login page'), findsOneWidget);
  });
}
