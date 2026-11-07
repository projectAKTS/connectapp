import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/screens/call/incoming_call_screen.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/push_installation_id.dart';

/// iOS: while CallKit rings and the app is in the foreground, the app also
/// shows its own Accept/Decline screen; both act through CallKit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'ios_screen_caller';
  const calleeUid = 'ios_screen_callee';

  late FakeFirebaseFirestore firestore;
  late GlobalKey<NavigatorState> navigatorKey;
  late CallSessionManager manager;
  late List<NativeCallSnapshot> nativeCalls;
  late List<String> answered;
  late List<String> ended;
  late bool foreground;

  NativeCallSnapshot nativeFor(String inviteId) => NativeCallSnapshot(
        callkitId: normalizeCallkitId(
          rawId: inviteId,
          fallback: 'channel_$inviteId',
        ),
        inviteId: inviteId,
        channel: 'channel_$inviteId',
      );

  Future<Map<String, dynamic>> invite(String inviteId) async =>
      (await firestore.collection('callInvites').doc(inviteId).get()).data()!;

  void configure({bool withAnswerer = true}) {
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => foreground,
      listNativeCalls: () async => List<NativeCallSnapshot>.from(nativeCalls),
      endNativeCall: (callkitId) async {
        ended.add(callkitId);
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
      answerNativeCall: withAnswerer
          ? (callkitId) async {
              answered.add(callkitId);
              return true;
            }
          : null,
      presentNativeIncomingCall: (payload) async {
        nativeCalls.add(nativeFor(payload.inviteId));
        return true;
      },
      iosCallkitOnlyIncomingUiForTest: true,
      skipActiveInviteBindingForTest: true,
    );
  }

  Future<void> pumpFor(WidgetTester tester, [int ticks = 10]) async {
    for (var i = 0; i < ticks; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// CallKit rings on this device for [inviteId].
  Future<void> ring(WidgetTester tester, String inviteId) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': 'Screen Caller',
      'toUid': calleeUid,
      'toName': 'Screen Callee',
      'channel': 'channel_$inviteId',
      'isVideo': false,
      'status': CallInviteStatus.ringing.name,
      'createdAt': Timestamp.now(),
    });
    nativeCalls.add(nativeFor(inviteId));
    await manager.handleNotificationInviteTap(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      isVideo: false,
      fromName: 'Screen Caller',
      fromUid: callerUid,
      source: 'ios_screen_test',
    );
    await pumpFor(tester);
    expect(manager.debugSnapshot()['incomingUiOwner'], 'callkit');
  }

  Widget harness() => MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('home')),
      );

  setUp(() async {
    CallV2PhysicalDiagnosticLedger.instance.resetForTest();
    firestore = FakeFirebaseFirestore();
    navigatorKey = GlobalKey<NavigatorState>();
    nativeCalls = <NativeCallSnapshot>[];
    answered = <String>[];
    ended = <String>[];
    foreground = true;
    manager = CallSessionManager.instance;
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Screen Callee',
    );
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Screen Callee',
    );
    PushInstallationId.debugSetForTest(null);
  });

  tearDown(() async {
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.clear();
    CallV2PhysicalDiagnosticLedger.instance.resetForTest();
  });

  testWidgets('app open: the screen shows; Accept answers the CallKit call',
      (tester) async {
    await tester.pumpWidget(harness());
    configure();
    await ring(tester, 'inv_accept');

    expect(find.byType(IncomingCallScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.call));
    await pumpFor(tester);

    expect(answered, [nativeFor('inv_accept').callkitId]);
    expect(find.byType(IncomingCallScreen), findsNothing);
    // Accepting through CallKit runs the native accept path; the screen
    // itself writes nothing.
    expect((await invite('inv_accept'))['status'], 'ringing');
  });

  testWidgets('Decline writes declined and ends the CallKit call',
      (tester) async {
    await tester.pumpWidget(harness());
    configure();
    await ring(tester, 'inv_decline');

    await tester.tap(find.byIcon(Icons.call_end));
    await pumpFor(tester);

    expect((await invite('inv_decline'))['status'], 'declined');
    expect(ended, contains(nativeFor('inv_decline').callkitId));
    expect(answered, isEmpty);
    expect(find.byType(IncomingCallScreen), findsNothing);
  });

  testWidgets('the caller cancels: the screen closes and nothing is answered',
      (tester) async {
    await tester.pumpWidget(harness());
    configure();
    await ring(tester, 'inv_cancel');
    expect(find.byType(IncomingCallScreen), findsOneWidget);

    await firestore.collection('callInvites').doc('inv_cancel').update({
      'status': CallInviteStatus.cancelled.name,
    });
    await pumpFor(tester);

    expect(find.byType(IncomingCallScreen), findsNothing);
    expect(answered, isEmpty);
    expect((await invite('inv_cancel'))['status'], 'cancelled');
  });

  testWidgets('app in the background: no screen until the app resumes',
      (tester) async {
    await tester.pumpWidget(harness());
    foreground = false;
    configure();
    await ring(tester, 'inv_resume');
    expect(find.byType(IncomingCallScreen), findsNothing);

    // The user taps the CallKit banner or the notification.
    foreground = true;
    final shown = manager.presentForegroundCallkitIncomingScreen(
      source: 'test_resume',
    );
    await pumpFor(tester);
    expect(find.byType(IncomingCallScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call));
    await pumpFor(tester);
    await shown;
    expect(answered, [nativeFor('inv_resume').callkitId]);
  });

  testWidgets('without the native answerer (Android, tests): CallKit only',
      (tester) async {
    await tester.pumpWidget(harness());
    configure(withAnswerer: false);
    await ring(tester, 'inv_callkit_only');

    expect(find.byType(IncomingCallScreen), findsNothing);
    expect(answered, isEmpty);
  });
}
