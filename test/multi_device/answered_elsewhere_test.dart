import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart';
import 'package:connect_app/services/call_invite_signaling.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';
import 'package:connect_app/services/push_installation_id.dart';

/// Server contract for `accept` from a second installation (the server
/// logic itself is covered by connect_functions/test/call_invites).
class _AcceptedElsewhereSignaling implements CallInviteSignaling {
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>?> transition(
    String action,
    Map<String, Object?> data,
  ) async {
    requests.add(<String, Object?>{'action': action, ...data});
    if (action == 'accept') {
      return <String, dynamic>{
        'decision': 'acceptedElsewhere',
        'invite': <String, dynamic>{'status': 'accepted'},
      };
    }
    return <String, dynamic>{'applied': false, 'status': 'accepted'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'multi_caller';
  const calleeUid = 'multi_callee';
  const phone = 'phone_installation_1';
  const tablet = 'tablet_installation_2';

  late FakeFirebaseFirestore firestore;
  late GlobalKey<NavigatorState> navigatorKey;
  late CallSessionManager manager;
  late List<NativeCallSnapshot> nativeCalls;
  late List<String> endedNative;
  late List<String> opened;

  NativeCallSnapshot nativeFor(String inviteId) => NativeCallSnapshot(
        callkitId: normalizeCallkitId(
          rawId: inviteId,
          fallback: 'channel_$inviteId',
        ),
        inviteId: inviteId,
        channel: 'channel_$inviteId',
      );

  Future<void> seed(String inviteId, {Map<String, dynamic>? extra}) {
    return firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': 'Multi Caller',
      'toUid': calleeUid,
      'toName': 'Multi Callee',
      'channel': 'channel_$inviteId',
      'isVideo': false,
      'status': CallInviteStatus.ringing.name,
      'createdAt': Timestamp.now(),
      ...?extra,
    });
  }

  Future<Map<String, dynamic>> invite(String inviteId) async =>
      (await firestore.collection('callInvites').doc(inviteId).get()).data()!;

  Future<void> acceptOn(String inviteId, String installationId) {
    return firestore.collection('callInvites').doc(inviteId).set({
      'status': CallInviteStatus.accepted.name,
      'acceptedAt': Timestamp.now(),
      'calleeStage': 'accepted',
      'acceptedInstallationId': installationId,
    }, SetOptions(merge: true));
  }

  void configure({
    required String installationId,
    CallInviteSignaling? signaling,
  }) {
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => List<NativeCallSnapshot>.from(nativeCalls),
      endNativeCall: (callkitId) async {
        endedNative.add(callkitId);
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
      presentNativeIncomingCall: (payload) async {
        nativeCalls.add(nativeFor(payload.inviteId));
        return true;
      },
      iosCallkitOnlyIncomingUiForTest: true,
      skipActiveInviteBindingForTest: true,
      installationId: installationId,
      callInviteSignalingForTest: signaling,
      callScreenOpenRecorderForTest: ({
        required String inviteId,
        required String channel,
        required String acceptedCallkitId,
        required bool isVideo,
        required String otherUserName,
        required String? otherUserId,
        required bool isCaller,
        required connectionSystem,
        required bool callV2FallbackUsed,
        required String callV2BlockerCode,
      }) async {
        opened.add(inviteId);
      },
    );
  }

  /// This device rings for [inviteId] through CallKit.
  Future<void> ringHere(WidgetTester tester, String inviteId) async {
    await seed(inviteId);
    nativeCalls.add(nativeFor(inviteId));
    await manager.handleNotificationInviteTap(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      isVideo: false,
      fromName: 'Multi Caller',
      fromUid: callerUid,
      source: 'multi_device_test',
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(manager.debugSnapshot()['incomingUiOwner'], 'callkit');
  }

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 30 && !done(); i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void expectIdle() {
    final snapshot = manager.debugSnapshot();
    expect(snapshot['sessionIdle'], isTrue);
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.none.name);
    expect(snapshot['activePromptCount'], 0);
  }

  Future<void> expectNextCallRings(WidgetTester tester, String next) async {
    await ringHere(tester, next);
    expect(manager.debugSnapshot()['activePromptCount'], 1);
  }

  setUp(() async {
    CallV2PhysicalDiagnosticLedger.instance.resetForTest();
    firestore = FakeFirebaseFirestore();
    navigatorKey = GlobalKey<NavigatorState>();
    nativeCalls = <NativeCallSnapshot>[];
    endedNative = <String>[];
    opened = <String>[];
    manager = CallSessionManager.instance;
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Multi Callee',
    );
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Multi Callee',
    );
    PushInstallationId.debugSetForTest(null);
  });

  tearDown(() async {
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
    CallV2PhysicalDiagnosticLedger.instance.resetForTest();
    PushInstallationId.debugSetForTest(null);
  });

  Widget harness() => MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      );

  testWidgets(
      'accepted on another installation: this device stops ringing, writes '
      'nothing, and the next call rings', (tester) async {
    await tester.pumpWidget(harness());
    configure(installationId: tablet);
    await manager.bindIncomingInviteListener();
    await ringHere(tester, 'inv_a');

    await acceptOn('inv_a', phone);
    await pumpUntil(
      tester,
      () =>
          manager.isAnsweredElsewhere('inv_a') &&
          manager.debugSnapshot()['sessionIdle'] == true,
    );

    expect(manager.isAnsweredElsewhere('inv_a'), isTrue);
    expectIdle();
    expect(endedNative, contains(nativeFor('inv_a').callkitId));
    expect(opened, isEmpty);

    // Ending the native UI emits plugin end/timeout/decline events. None of
    // them may touch the call the phone answered.
    await manager.handleSystemEndedInvite(
      inviteId: 'inv_a',
      source: 'callkit_end',
    );
    await manager.handleSystemTimeoutInvite(
      inviteId: 'inv_a',
      source: 'callkit_timeout',
    );
    await manager.declineInvite(inviteId: 'inv_a', source: 'callkit_decline');
    final data = await invite('inv_a');
    expect(data['status'], CallInviteStatus.accepted.name);
    expect(data['acceptedInstallationId'], phone);
    expect(data.containsKey('endedAt'), isFalse);

    await expectNextCallRings(tester, 'inv_b');
  });

  testWidgets(
      'an unmarked system end never ends a call another installation '
      'answered, but still ends this device\'s own call', (tester) async {
    await tester.pumpWidget(harness());
    configure(installationId: tablet);

    await seed('inv_other');
    await acceptOn('inv_other', phone);
    await manager.handleSystemEndedInvite(
      inviteId: 'inv_other',
      source: 'callkit_end',
    );
    expect(
        (await invite('inv_other'))['status'], CallInviteStatus.accepted.name);

    await seed('inv_own');
    await acceptOn('inv_own', tablet);
    await manager.handleSystemEndedInvite(
      inviteId: 'inv_own',
      source: 'callkit_end',
    );
    expect((await invite('inv_own'))['status'], CallInviteStatus.ended.name);

    // Old clients record no answering installation: unchanged behavior.
    await seed('inv_legacy', extra: {
      'status': CallInviteStatus.accepted.name,
    });
    await manager.handleSystemEndedInvite(
      inviteId: 'inv_legacy',
      source: 'callkit_end',
    );
    expect((await invite('inv_legacy'))['status'], CallInviteStatus.ended.name);
  });

  testWidgets('the answering installation ignores its own accept snapshot',
      (tester) async {
    await tester.pumpWidget(harness());
    configure(installationId: phone);
    await manager.bindIncomingInviteListener();
    await ringHere(tester, 'inv_here');

    await acceptOn('inv_here', phone);
    await pumpFor(tester, const Duration(seconds: 1));

    expect(manager.isAnsweredElsewhere('inv_here'), isFalse);
    expect(endedNative, isEmpty);
  });

  testWidgets(
      'acceptedElsewhere from the server never opens the call and stops '
      'ringing', (tester) async {
    await tester.pumpWidget(harness());
    final notifications = NotificationService();
    notifications.debugBeginPushBindingForTest(calleeUid);
    final signaling = _AcceptedElsewhereSignaling();
    configure(installationId: tablet, signaling: signaling);
    await seed('inv_race');
    await acceptOn('inv_race', phone);
    nativeCalls.add(nativeFor('inv_race'));

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'inv_race',
      channel: 'channel_inv_race',
      isVideo: false,
      fromName: 'Multi Caller',
      fromUid: callerUid,
      callkitId: nativeFor('inv_race').callkitId,
    );
    await pumpUntil(tester, () => manager.isAnsweredElsewhere('inv_race'));

    expect(signaling.requests.first['action'], 'accept');
    expect(signaling.requests.first['installationId'], tablet);
    expect(opened, isEmpty);
    expect(manager.isAnsweredElsewhere('inv_race'), isTrue);
    expect(endedNative, contains(nativeFor('inv_race').callkitId));
    expect(
        (await invite('inv_race'))['status'], CallInviteStatus.accepted.name);
    await notifications.dispose();
  });

  testWidgets(
      'answered_elsewhere push dismisses other installations and is ignored '
      'by the answering one', (tester) async {
    await tester.pumpWidget(harness());
    final notifications = NotificationService();
    notifications.debugBeginPushBindingForTest(calleeUid);
    configure(installationId: tablet);
    PushInstallationId.debugSetForTest(tablet);

    RemoteMessage push(String inviteId, String answering) => RemoteMessage(
          data: <String, dynamic>{
            'type': 'call_end',
            'action': 'call_end',
            'status': 'answered_elsewhere',
            'channel': 'channel_$inviteId',
            'callId': inviteId,
            'inviteId': inviteId,
            'acceptedInstallationId': answering,
          },
        );

    await ringHere(tester, 'inv_push');
    await acceptOn('inv_push', phone);
    await notifications
        .debugHandleRemoteMessageForTest(push('inv_push', phone));
    await pumpUntil(tester, () => manager.isAnsweredElsewhere('inv_push'));
    expect(manager.isAnsweredElsewhere('inv_push'), isTrue);
    expect(endedNative, contains(nativeFor('inv_push').callkitId));

    endedNative.clear();
    await ringHere(tester, 'inv_mine');
    await notifications
        .debugHandleRemoteMessageForTest(push('inv_mine', tablet));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(manager.isAnsweredElsewhere('inv_mine'), isFalse);
    expect(endedNative, isEmpty);
    await notifications.dispose();
  });
}

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  for (var i = 0; i < duration.inMilliseconds ~/ 100; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
