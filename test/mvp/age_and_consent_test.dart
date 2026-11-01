import 'package:connect_app/models/age_policy.dart';
import 'package:connect_app/screens/age/age_gate_screens.dart';
import 'package:connect_app/services/app_prefs.dart';
import 'package:connect_app/services/app_telemetry.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/widgets/telemetry_consent_prompt.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
        firestore: firestore, currentUid: 'me');
    AppPrefs.debugSetForTest({});
  });
  tearDown(HelperlyTestRuntime.clear);

  test('age status of new, old and declared accounts', () {
    expect(AgePolicy.statusOf({}), AgeStatus.unknown);
    expect(AgePolicy.statusOf({'ageDeclaration': 'adult'}), AgeStatus.adult);
    expect(AgePolicy.statusOf({'ageDeclaration': 'minor'}), AgeStatus.minor);
    expect(AgePolicy.statusOf({'ageDeclaration': 'other'}), AgeStatus.unknown);
    final d = AgePolicy.declaration(adult: true);
    expect(d['ageDeclaration'], 'adult');
    expect(d['agePolicyVersion'], 1);
    expect(d.keys, isNot(contains('birthdate')), reason: 'no birthdate kept');
  });

  Future<void> pump(WidgetTester tester, Widget w) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: w));
  }

  testWidgets('an existing account confirms 18+ once', (tester) async {
    await firestore.collection('users').doc('me').set({'fullName': 'Me'});
    await pump(tester, const AgeConfirmScreen());
    await tester.tap(find.byKey(const Key('age_adult')));
    await tester.pumpAndSettle();
    final me = (await firestore.collection('users').doc('me').get()).data()!;
    expect(me['ageDeclaration'], 'adult');
    expect(me['fullName'], 'Me', reason: 'nothing else changes');
  });

  testWidgets('declaring under 18 asks again, then restricts (no deletion)',
      (tester) async {
    await firestore.collection('users').doc('me').set({'fullName': 'Me'});
    await pump(tester, const AgeConfirmScreen());
    await tester.tap(find.byKey(const Key('age_minor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    var me = (await firestore.collection('users').doc('me').get()).data()!;
    expect(me.containsKey('ageDeclaration'), isFalse);

    await tester.tap(find.byKey(const Key('age_minor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('age_minor_confirm')));
    await tester.pumpAndSettle();
    me = (await firestore.collection('users').doc('me').get()).data()!;
    expect(me['ageDeclaration'], 'minor');
    expect(me['fullName'], 'Me');
  });

  testWidgets('the restricted screen offers deletion and sign-out only',
      (tester) async {
    await pump(tester, const AgeRestrictedScreen());
    expect(find.text('Your account is paused'), findsOneWidget);
    expect(find.byKey(const Key('age_restricted_settings')), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('consent: asked once, two separate choices, both off',
      (tester) async {
    await pump(tester,
        const TelemetryConsentPrompt(child: Scaffold(body: Text('home'))));
    await tester.pumpAndSettle();
    SwitchListTile toggle(String k) =>
        tester.widget<SwitchListTile>(find.byKey(Key(k)));
    expect(toggle('consent_crash').value, isFalse);
    expect(toggle('consent_usage').value, isFalse);

    await tester.tap(find.byKey(const Key('consent_crash')));
    await tester.pumpAndSettle();
    expect(AppTelemetry.crashReportsEnabled, isTrue);
    expect(AppTelemetry.usageStatsEnabled, isFalse, reason: 'independent');
    await tester.tap(find.byKey(const Key('consent_done')));
    await tester.pumpAndSettle();

    // Next start: not asked again.
    await tester.pumpWidget(const SizedBox());
    await pump(tester,
        const TelemetryConsentPrompt(child: Scaffold(body: Text('home'))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('consent_crash')), findsNothing);
  });

  testWidgets('dismissing the consent sheet counts as no, and is not repeated',
      (tester) async {
    await pump(tester,
        const TelemetryConsentPrompt(child: Scaffold(body: Text('home'))));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // barrier
    await tester.pumpAndSettle();
    expect(AppTelemetry.crashReportsEnabled, isFalse);
    expect(AppTelemetry.usageStatsEnabled, isFalse);
    expect(AppPrefs.getBool(TelemetryConsentPrompt.shownPrefKey), isTrue);
  });
}
