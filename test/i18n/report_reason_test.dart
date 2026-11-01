import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(HelperlyTestRuntime.clear);

  testWidgets('a report made in French stores the same reason id',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
        firestore: firestore, currentUid: 'me');
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: AppLanguages.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    final sent = SafetyService.instance
        .reportWithSheet(ctx, type: 'post', targetId: 'p1', targetUid: 'u2');
    await tester.pumpAndSettle();
    expect(find.text('Pourquoi signalez-vous ce contenu?'), findsOneWidget);
    await tester.tap(find.text('Pourriel ou arnaque'));
    await tester.pumpAndSettle();
    expect(await sent, isTrue);
    final report = (await firestore.collection('reports').get()).docs.single;
    expect(report.data()['reason'], 'Spam or scam');
  });
}
