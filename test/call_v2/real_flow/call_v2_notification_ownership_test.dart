import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/callkit_id.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'notify_caller';
  const calleeUid = 'notify_callee';
  const calleeName = 'Notify Callee';

  late FakeFirebaseFirestore firestore;
  late CallSessionManager manager;
  late NotificationService notifications;

  Future<void> seedInvite(
    String inviteId, {
    CallInviteStatus status = CallInviteStatus.accepted,
  }) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': 'Notify Caller',
      'toUid': calleeUid,
      'toName': calleeName,
      'channel': 'channel_$inviteId',
      'isVideo': false,
      'status': status.name,
      'createdAt': Timestamp.now(),
    });
  }

  Future<Map<String, dynamic>?> userData(String uid) async {
    final snapshot = await firestore.collection('users').doc(uid).get();
    return snapshot.data();
  }

  Future<List<Map<String, dynamic>>> installations(String uid) async {
    final snapshot = await firestore
        .collection('users')
        .doc(uid)
        .collection('pushInstallations')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  CallScreenOpenRecorderForTest placeholderCallOpenRecorder() {
    return ({
      required String inviteId,
      required String channel,
      required bool isVideo,
      required String otherUserName,
      required String? otherUserId,
      required bool isCaller,
      required connectionSystem,
      required bool callV2FallbackUsed,
      required String callV2BlockerCode,
    }) async {};
  }

  CallScreenOpenRecorderForTest recordingCallOpenRecorder(List<String> routes) {
    return ({
      required String inviteId,
      required String channel,
      required bool isVideo,
      required String otherUserName,
      required String? otherUserId,
      required bool isCaller,
      required connectionSystem,
      required bool callV2FallbackUsed,
      required String callV2BlockerCode,
    }) async {
      routes.add(inviteId);
    };
  }

  Future<void> pumpUntilRouteOpened(
    WidgetTester tester, {
    int expectedRoutes = 1,
  }) async {
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['routeOpenCount'] == expectedRoutes) {
        break;
      }
    }
  }

  Future<void> pumpUntilAcceptedNativeWatchSettles(
    WidgetTester tester,
  ) async {
    for (var i = 0; i < 40; i += 1) {
      await tester.pump(const Duration(milliseconds: 5));
      if (manager.debugSnapshot()['acceptedNativeWatchActive'] == false) {
        break;
      }
    }
    await manager.debugAwaitAcceptedNativeRouteWatchCleanupForTest();
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
    manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    manager.debugConfigureAcceptedNativeRouteWatchForTest(
      timeout: const Duration(seconds: 20),
    );
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
    notifications = NotificationService();
    notifications.debugBeginPushBindingForTest(calleeUid);
  });

  tearDown(() async {
    await notifications.dispose();
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
  });

  testWidgets(
      'native CallKit accept records ownership before navigator is ready',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    var appReady = false;
    await seedInvite('invite_nav_retry');
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(seconds: 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_nav_retry',
      channel: 'channel_invite_nav_retry',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await tester.pump();

    final pendingSnapshot = manager.debugSnapshot();
    expect(pendingSnapshot['acceptedBridgeIngestionStarted'], isTrue);
    expect(pendingSnapshot['acceptedOwnershipRecorded'], isTrue);
    expect(pendingSnapshot['acceptedRoutePending'], isTrue);
    expect(openedRoutes, isEmpty);
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isFalse,
    );
    expect(
      notifications.debugSnapshotForTest()['acceptedBridgeReadinessKick'],
      isTrue,
    );

    appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await pumpUntilRouteOpened(tester);
    await notifications.debugResumePendingAcceptedRouteForTest();

    final snapshot = manager.debugSnapshot();
    expect(snapshot['activeCallRouteCount'], 1);
    expect(openedRoutes, ['invite_nav_retry']);
    expect(snapshot['acceptedRecoveryPending'], isFalse);
    expect(snapshot['acceptedRecoveryAcknowledged'], isTrue);
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isFalse,
    );
    await manager.forceIdleForTest();
  });

  testWidgets(
      'exact native route ownership is acknowledged only after route opens',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    final acknowledgements = <String>[];
    var appReady = false;
    const exactNativeKey = 'exact_native_route_owner';
    await seedInvite('invite_exact_route_ack');
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
      acknowledgeNativeRouteOwnership: (exactKey) async {
        acknowledgements.add(exactKey);
        return true;
      },
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(seconds: 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_exact_route_ack',
      channel: 'channel_invite_exact_route_ack',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: exactNativeKey,
    );
    await tester.pump();

    expect(openedRoutes, isEmpty);
    expect(acknowledgements, isEmpty);

    appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await pumpUntilRouteOpened(tester);
    await notifications.debugResumePendingAcceptedRouteForTest();

    expect(openedRoutes, <String>['invite_exact_route_ack']);
    expect(acknowledgements, <String>[exactNativeKey]);
    await manager.forceIdleForTest();
  });

  testWidgets(
      'background accept during teardown waits for navigator without another resume',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    var appReady = false;
    await seedInvite('invite_physical_order', status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(seconds: 1),
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_physical_previous',
      channel: 'channel_invite_physical_previous',
    );
    await manager.debugMarkHeldRouteTerminalForTest(
      'invite_physical_previous',
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_physical_order',
      channel: 'channel_invite_physical_order',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await tester.pump();

    var snapshot = manager.debugSnapshot();
    expect(snapshot['acceptedBridgeIngestionStarted'], isTrue);
    expect(snapshot['acceptedOwnershipRecorded'], isTrue);
    expect(snapshot['pendingAcceptedIntent'], isTrue);
    expect(snapshot['acceptedRoutePending'], isFalse);
    expect(openedRoutes, isEmpty);
    expect(snapshot['flutterIncomingPromptCount'], 0);

    await manager.debugCloseHeldRouteForTest('invite_physical_previous');
    snapshot = manager.debugSnapshot();
    expect(snapshot['previousTeardownCompleted'], isTrue);
    expect(snapshot['acceptedRoutePending'], isTrue);
    expect(openedRoutes, isEmpty);

    appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await pumpUntilRouteOpened(tester);
    await notifications.debugResumePendingAcceptedRouteForTest();

    snapshot = manager.debugSnapshot();
    expect(openedRoutes, ['invite_physical_order']);
    expect(snapshot['routeOpenCount'], 1);
    expect(snapshot['rtcSetupOwnerCount'], 1);
    expect(snapshot['acceptedRoutePending'], isFalse);
    expect(
      notifications.debugSnapshotForTest()['acceptedBridgeReadinessKick'],
      isTrue,
    );
    await manager.forceIdleForTest();
  });

  testWidgets(
      'resume before native bridge is recovered by bridge readiness kick',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    var appReady = false;
    await seedInvite('invite_resume_first', status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(seconds: 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await notifications.debugResumePendingAcceptedRouteForTest();
    expect(manager.hasPendingAcceptedRouteOwnership, isFalse);

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_resume_first',
      channel: 'channel_invite_resume_first',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await tester.pump();
    expect(manager.hasPendingAcceptedRouteOwnership, isTrue);

    appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await pumpUntilRouteOpened(tester);
    await notifications.debugResumePendingAcceptedRouteForTest();

    expect(openedRoutes, ['invite_resume_first']);
    expect(manager.debugSnapshot()['routeOpenCount'], 1);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 1);
    expect(
      notifications.debugSnapshotForTest()['acceptedBridgeReadinessKick'],
      isTrue,
    );
    await manager.forceIdleForTest();
  });

  testWidgets('terminal invite before route clears ownership and native call',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    final nativeCalls = <NativeCallSnapshot>[
      const NativeCallSnapshot(
        callkitId: 'native_terminal_pending',
        inviteId: 'invite_terminal_before_route',
        channel: 'channel_invite_terminal_before_route',
        accepted: true,
      ),
    ];
    final endedNativeCalls = <String>[];
    await seedInvite('invite_terminal_before_route',
        status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (callkitId) async {
        endedNativeCalls.add(callkitId);
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
      appForegroundProvider: () async => false,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(seconds: 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_terminal_before_route',
      channel: 'channel_invite_terminal_before_route',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: 'native_terminal_pending',
    );
    await tester.pump();
    expect(manager.hasPendingAcceptedRouteOwnership, isTrue);
    expect(manager.debugSnapshot()['nativeAcceptedCallActive'], isTrue);

    await firestore
        .collection('callInvites')
        .doc('invite_terminal_before_route')
        .set(<String, dynamic>{
      'status': CallInviteStatus.ended.name,
    }, SetOptions(merge: true));
    await pumpUntilAcceptedNativeWatchSettles(tester);

    final snapshot = manager.debugSnapshot();
    expect(openedRoutes, isEmpty);
    expect(manager.hasPendingAcceptedRouteOwnership, isFalse);
    expect(snapshot['acceptedRouteTerminalObserved'], isTrue);
    expect(snapshot['acceptedNativeWatchTerminalObserved'], isTrue);
    expect(snapshot['acceptedNativeWatchActive'], isFalse);
    expect(snapshot['nativeEndRequested'], isTrue);
    expect(snapshot['nativeEndVerified'], isTrue);
    expect(snapshot['nativeAcceptedCallActive'], isFalse);
    expect(snapshot['sessionIdle'], isTrue);
    expect(endedNativeCalls, ['native_terminal_pending']);
    expect(nativeCalls, isEmpty);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(openedRoutes, isEmpty);
  });

  testWidgets('readiness deadline terminalizes an unrouteable accepted call',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    final nativeCalls = <NativeCallSnapshot>[
      const NativeCallSnapshot(
        callkitId: 'native_deadline_pending',
        inviteId: 'invite_route_deadline',
        channel: 'channel_invite_route_deadline',
        accepted: true,
      ),
    ];
    await seedInvite('invite_route_deadline', status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (callkitId) async {
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
      appForegroundProvider: () async => false,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(milliseconds: 40),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_route_deadline',
      channel: 'channel_invite_route_deadline',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: 'native_deadline_pending',
    );
    for (var tick = 0; tick < 8; tick += 1) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await notifications.debugResumePendingAcceptedRouteForTest();
    await pumpUntilAcceptedNativeWatchSettles(tester);

    final snapshot = manager.debugSnapshot();
    final invite = await firestore
        .collection('callInvites')
        .doc('invite_route_deadline')
        .get();
    expect(openedRoutes, isEmpty);
    expect(snapshot['acceptedRouteDeadlineReached'], isTrue);
    expect(snapshot['acceptedRoutePending'], isFalse);
    expect(snapshot['nativeAcceptedCallActive'], isFalse);
    expect(snapshot['sessionIdle'], isTrue);
    expect(nativeCalls, isEmpty);
    expect(invite.data()?['status'], CallInviteStatus.failed.name);
  });

  testWidgets(
      'accepted native watch ends the exact call for every remote terminal state',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 1),
      window: const Duration(seconds: 2),
    );
    final terminalStates = <CallInviteStatus>[
      CallInviteStatus.declined,
      CallInviteStatus.cancelled,
      CallInviteStatus.ended,
      CallInviteStatus.failed,
      CallInviteStatus.missed,
    ];

    for (final terminalStatus in terminalStates) {
      await manager.forceIdleForTest();
      final inviteId = 'watch_terminal_${terminalStatus.name}';
      final channel = 'channel_$inviteId';
      final actualCallkitId = 'actual_native_${terminalStatus.name}';
      final reconstructedCallkitId = normalizeCallkitId(
        rawId: inviteId,
        fallback: channel,
      );
      final nativeCalls = <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: actualCallkitId,
          inviteId: inviteId,
          channel: channel,
          accepted: true,
        ),
      ];
      final endedNativeCalls = <String>[];
      await seedInvite(inviteId, status: CallInviteStatus.ringing);
      manager.configure(
        navigatorKey: navigatorKey,
        listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
        endNativeCall: (callkitId) async {
          endedNativeCalls.add(callkitId);
          nativeCalls.removeWhere((call) => call.callkitId == callkitId);
        },
        appForegroundProvider: () async => false,
        callScreenOpenRecorderForTest: placeholderCallOpenRecorder(),
        skipActiveInviteBindingForTest: true,
        iosCallkitOnlyIncomingUiForTest: true,
      );
      manager.debugConfigureAcceptedNativeRouteWatchForTest(
        timeout: const Duration(seconds: 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
        inviteId: inviteId,
        channel: channel,
        isVideo: false,
        fromName: 'Notify Caller',
        fromUid: callerUid,
        callkitId: actualCallkitId,
      );
      await tester.pump();
      expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isTrue);

      await firestore.collection('callInvites').doc(inviteId).set(
        <String, dynamic>{'status': terminalStatus.name},
        SetOptions(merge: true),
      );
      await pumpUntilAcceptedNativeWatchSettles(tester);

      final snapshot = manager.debugSnapshot();
      expect(snapshot['acceptedNativeWatchActive'], isFalse);
      expect(snapshot['acceptedRoutePending'], isFalse);
      expect(snapshot['acceptedRecoveryPending'], isFalse);
      expect(snapshot['nativeAcceptedCallActive'], isFalse);
      expect(snapshot['nativeEndRequested'], isTrue);
      expect(snapshot['nativeEndVerified'], isTrue);
      expect(snapshot['matchingNativeCallCount'], 0);
      expect(snapshot['sessionIdle'], isTrue);
      expect(snapshot['routeOpenCount'], 0);
      expect(snapshot['rtcSetupOwnerCount'], 0);
      expect(
        notifications.debugSnapshotForTest()['acceptedRecoveryPayloadPending'],
        isFalse,
      );
      expect(endedNativeCalls, [actualCallkitId]);
      expect(endedNativeCalls, isNot(contains(reconstructedCallkitId)));
      expect(nativeCalls, isEmpty);
    }
    await tester.pump(const Duration(milliseconds: 5));
  });

  testWidgets('accepted native watchdog resolves without navigator readiness',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    const inviteId = 'watch_deadline_invite';
    const channel = 'channel_watch_deadline_invite';
    const actualCallkitId = 'watch_deadline_native';
    final nativeCalls = <NativeCallSnapshot>[
      const NativeCallSnapshot(
        callkitId: actualCallkitId,
        inviteId: inviteId,
        channel: channel,
        accepted: true,
      ),
    ];
    final endAttempts = <String>[];
    await seedInvite(inviteId, status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (callkitId) async {
        endAttempts.add(callkitId);
        if (endAttempts.length >= 2) {
          nativeCalls.removeWhere((call) => call.callkitId == callkitId);
        }
      },
      appForegroundProvider: () async => false,
      callScreenOpenRecorderForTest: placeholderCallOpenRecorder(),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    manager.debugConfigureAcceptedNativeRouteWatchForTest(
      timeout: const Duration(milliseconds: 40),
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 50),
      window: const Duration(seconds: 2),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: inviteId,
      channel: channel,
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: actualCallkitId,
    );
    await tester.pump(const Duration(milliseconds: 50));
    await pumpUntilAcceptedNativeWatchSettles(tester);

    final snapshot = manager.debugSnapshot();
    final invite =
        await firestore.collection('callInvites').doc(inviteId).get();
    expect(invite.data()?['status'], CallInviteStatus.failed.name);
    expect(snapshot['acceptedNativeWatchDeadlineReached'], isTrue);
    expect(snapshot['acceptedNativeWatchActive'], isFalse);
    expect(snapshot['acceptedRoutePending'], isFalse);
    expect(snapshot['nativeAcceptedCallActive'], isFalse);
    expect(snapshot['nativeEndRequested'], isTrue);
    expect(snapshot['nativeEndEscalated'], isTrue);
    expect(snapshot['nativeEndVerified'], isTrue);
    expect(snapshot['sessionIdle'], isTrue);
    expect(endAttempts, [actualCallkitId, actualCallkitId]);
    expect(nativeCalls, isEmpty);
  });

  testWidgets('route ownership transfer defeats a stale pending terminal event',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    final endedNativeCalls = <String>[];
    const inviteId = 'watch_route_transfer';
    const channel = 'channel_watch_route_transfer';
    const actualCallkitId = 'watch_route_transfer_native';
    await seedInvite(inviteId, status: CallInviteStatus.ringing);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: actualCallkitId,
          inviteId: inviteId,
          channel: channel,
          accepted: true,
        ),
      ],
      endNativeCall: (callkitId) async => endedNativeCalls.add(callkitId),
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: inviteId,
      channel: channel,
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: actualCallkitId,
    );
    await pumpUntilRouteOpened(tester);
    expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isFalse);

    await firestore.collection('callInvites').doc(inviteId).set(
      <String, dynamic>{'status': CallInviteStatus.ended.name},
      SetOptions(merge: true),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(openedRoutes, [inviteId]);
    expect(manager.debugSnapshot()['routeOpenCount'], 1);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 1);
    expect(endedNativeCalls, isEmpty);
    await manager.forceIdleForTest();
  });

  testWidgets('terminal ownership prevents a concurrent late route open',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    final nativeCalls = <NativeCallSnapshot>[
      const NativeCallSnapshot(
        callkitId: 'terminal_wins_native',
        inviteId: 'terminal_wins_invite',
        channel: 'channel_terminal_wins_invite',
        accepted: true,
      ),
    ];
    await seedInvite('terminal_wins_invite', status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (callkitId) async {
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
      appForegroundProvider: () async => false,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 500),
      window: const Duration(seconds: 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'terminal_wins_invite',
      channel: 'channel_terminal_wins_invite',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
      callkitId: 'terminal_wins_native',
    );
    await tester.pump();

    await firestore
        .collection('callInvites')
        .doc('terminal_wins_invite')
        .set(<String, dynamic>{
      'status': CallInviteStatus.ended.name,
    }, SetOptions(merge: true));
    await pumpUntilAcceptedNativeWatchSettles(tester);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    final lateResume = notifications.debugResumePendingAcceptedRouteForTest();
    await tester.pump(const Duration(milliseconds: 500));
    await lateResume;

    expect(openedRoutes, isEmpty);
    expect(nativeCalls, isEmpty);
    expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isFalse);
    expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
    expect(manager.debugSnapshot()['sessionIdle'], isTrue);
  });

  testWidgets('signout and hard reset dispose exact accepted native ownership',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    for (final useSignOut in <bool>[true, false]) {
      await manager.forceIdleForTest();
      final suffix = useSignOut ? 'signout' : 'reset';
      final inviteId = 'pending_native_$suffix';
      final channel = 'channel_$inviteId';
      final exactCallkitId = 'exact_native_$suffix';
      final nativeCalls = <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: exactCallkitId,
          inviteId: inviteId,
          channel: channel,
          accepted: true,
        ),
      ];
      final ended = <String>[];
      await seedInvite(inviteId, status: CallInviteStatus.ringing);
      manager.configure(
        navigatorKey: navigatorKey,
        listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
        endNativeCall: (callkitId) async {
          ended.add(callkitId);
          nativeCalls.removeWhere((call) => call.callkitId == callkitId);
        },
        appForegroundProvider: () async => false,
        callScreenOpenRecorderForTest: placeholderCallOpenRecorder(),
        skipActiveInviteBindingForTest: true,
        iosCallkitOnlyIncomingUiForTest: true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
        inviteId: inviteId,
        channel: channel,
        isVideo: false,
        fromName: 'Notify Caller',
        fromUid: callerUid,
        callkitId: exactCallkitId,
      );
      expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isTrue);

      if (useSignOut) {
        await manager.clearForSignedOut();
      } else {
        final reset = manager.hardResetForNewCall(
          reason: 'test_pending_native_reset',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await reset;
      }

      expect(ended, [exactCallkitId]);
      expect(nativeCalls, isEmpty);
      expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isFalse);
      expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
      expect(manager.debugSnapshot()['nativeAcceptedCallActive'], isFalse);
      expect(manager.debugSnapshot()['sessionIdle'], isTrue);
    }
  });

  testWidgets(
      'foreground native CallKit accept opens route without plugin event',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_native_accept_only',
        status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_native_accept_only',
      channel: 'channel_invite_native_accept_only',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await pumpUntilRouteOpened(tester);

    final invite = await firestore
        .collection('callInvites')
        .doc('invite_native_accept_only')
        .get();
    final managerSnapshot = manager.debugSnapshot();
    final notificationSnapshot = notifications.debugSnapshotForTest();
    expect(invite.data()?['status'], CallInviteStatus.accepted.name);
    expect(openedRoutes, ['invite_native_accept_only']);
    expect(managerSnapshot['routeOpenCount'], 1);
    expect(managerSnapshot['rtcSetupOwnerCount'], 1);
    expect(managerSnapshot['flutterIncomingPromptCount'], 0);
    expect(notificationSnapshot['nativeAcceptBridgeReceived'], isTrue);
    expect(notificationSnapshot['acceptedRecoveryRetryScheduled'], isFalse);
    await manager.forceIdleForTest();
  });

  testWidgets('direct native then plugin duplicate accept keeps one route',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_native_then_plugin',
        status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_native_then_plugin',
      channel: 'channel_invite_native_then_plugin',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await pumpUntilRouteOpened(tester);
    await notifications.debugSimulateAcceptedCallkitEventForTest(
      inviteId: 'invite_native_then_plugin',
      channel: 'channel_invite_native_then_plugin',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await tester.pump();

    final managerSnapshot = manager.debugSnapshot();
    final notificationSnapshot = notifications.debugSnapshotForTest();
    expect(openedRoutes, ['invite_native_then_plugin']);
    expect(managerSnapshot['routeOpenCount'], 1);
    expect(managerSnapshot['rtcSetupOwnerCount'], 1);
    expect(notificationSnapshot['acceptedRecoveryRetryScheduled'], isFalse);
    await manager.forceIdleForTest();
  });

  testWidgets('plugin then direct native duplicate accept keeps one route',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_plugin_then_native',
        status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );

    await notifications.debugSimulateAcceptedCallkitEventForTest(
      inviteId: 'invite_plugin_then_native',
      channel: 'channel_invite_plugin_then_native',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_plugin_then_native',
      channel: 'channel_invite_plugin_then_native',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await pumpUntilRouteOpened(tester);

    final managerSnapshot = manager.debugSnapshot();
    final notificationSnapshot = notifications.debugSnapshotForTest();
    expect(openedRoutes, ['invite_plugin_then_native']);
    expect(managerSnapshot['routeOpenCount'], 1);
    expect(managerSnapshot['rtcSetupOwnerCount'], 1);
    expect(notificationSnapshot['acceptedRecoveryRetryScheduled'], isFalse);
    await manager.forceIdleForTest();
  });

  for (final nativeFirst in <bool>[true, false]) {
    testWidgets(
        '${nativeFirst ? 'native then plugin' : 'plugin then native'} pending accepts coalesce through teardown',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final openedRoutes = <String>[];
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ));
      await seedInvite('invite_pending_duplicate',
          status: CallInviteStatus.ringing);
      manager.configure(
        navigatorKey: navigatorKey,
        listNativeCalls: () async => const <NativeCallSnapshot>[],
        endNativeCall: (_) async {},
        appForegroundProvider: () async => true,
        callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
        skipActiveInviteBindingForTest: true,
        iosCallkitOnlyIncomingUiForTest: true,
      );
      await manager.debugCreateHeldCallRouteForTest(
        inviteId: 'invite_previous',
        channel: 'channel_invite_previous',
      );
      await manager.debugMarkHeldRouteTerminalForTest('invite_previous');
      await manager.handleNotificationInviteTap(
        inviteId: 'invite_pending_duplicate',
        channel: 'channel_invite_pending_duplicate',
        isVideo: false,
        fromName: 'Notify Caller',
        fromUid: callerUid,
        source: 'pending_firestore',
      );

      Future<void> nativeAccept() {
        return notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
          inviteId: 'invite_pending_duplicate',
          channel: 'channel_invite_pending_duplicate',
          isVideo: false,
          fromName: 'Notify Caller',
          fromUid: callerUid,
        );
      }

      Future<void> pluginAccept() {
        return notifications.debugSimulateAcceptedCallkitEventForTest(
          inviteId: 'invite_pending_duplicate',
          channel: 'channel_invite_pending_duplicate',
          isVideo: false,
          fromName: 'Notify Caller',
          fromUid: callerUid,
        );
      }

      if (nativeFirst) {
        await nativeAccept();
        await pluginAccept();
      } else {
        await pluginAccept();
        await nativeAccept();
      }

      expect(manager.debugSnapshot()['pendingAcceptedIntent'], isTrue);
      expect(
        notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
        isFalse,
      );
      expect(
        notifications.debugSnapshotForTest()['acceptedRecoveryRetryAttempts'],
        0,
      );
      expect(openedRoutes, isEmpty);

      await manager.debugCloseHeldRouteForTest('invite_previous');
      await tester.pump(const Duration(milliseconds: 300));
      expect(openedRoutes, ['invite_pending_duplicate']);
      expect(manager.debugSnapshot()['routeOpenCount'], 1);
      expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 1);
      expect(
        notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
        isFalse,
      );
      await notifications.debugResumePendingAcceptedRouteForTest();
      await manager.forceIdleForTest();
    });
  }

  testWidgets(
      'native plugin and resumed duplicates preserve one background route owner',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    var appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_background_duplicates',
        status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_previous_background',
      channel: 'channel_invite_previous_background',
    );
    await manager.debugMarkHeldRouteTerminalForTest(
      'invite_previous_background',
    );

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_background_duplicates',
      channel: 'channel_invite_background_duplicates',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await notifications.debugSimulateAcceptedCallkitEventForTest(
      inviteId: 'invite_background_duplicates',
      channel: 'channel_invite_background_duplicates',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );

    appReady = false;
    await tester.pumpWidget(const SizedBox.shrink());
    await manager.debugCloseHeldRouteForTest('invite_previous_background');
    expect(manager.debugSnapshot()['acceptedRoutePending'], isTrue);
    expect(openedRoutes, isEmpty);

    await notifications.debugSimulateAcceptedCallkitEventForTest(
      inviteId: 'invite_background_duplicates',
      channel: 'channel_invite_background_duplicates',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_background_duplicates',
      channel: 'channel_invite_background_duplicates',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isFalse,
    );

    final resumed = List<Future<void>>.generate(
      5,
      (_) => notifications.debugResumePendingAcceptedRouteForTest(),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      notifications.debugSnapshotForTest()['acceptedRouteResumeInFlight'],
      isTrue,
    );
    appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await Future.wait(resumed);

    final snapshot = manager.debugSnapshot();
    expect(openedRoutes, ['invite_background_duplicates']);
    expect(snapshot['acceptedRoutePending'], isFalse);
    expect(snapshot['routeOpenCount'], 1);
    expect(snapshot['rtcSetupOwnerCount'], 1);
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isFalse,
    );
    await manager.forceIdleForTest();
  });

  testWidgets(
      'resumed before teardown spans pending teardown and navigator readiness',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    var appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_resume_before_teardown',
        status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(seconds: 1),
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_previous_resume',
      channel: 'channel_invite_previous_resume',
    );
    await manager.debugMarkHeldRouteTerminalForTest(
      'invite_previous_resume',
    );
    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_resume_before_teardown',
      channel: 'channel_invite_resume_before_teardown',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );

    appReady = false;
    await tester.pumpWidget(const SizedBox.shrink());
    final resumed = notifications.debugResumePendingAcceptedRouteForTest();
    for (var tick = 0; tick < 3; tick += 1) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(
        notifications.debugSnapshotForTest()['acceptedRouteResumeInFlight'],
        isTrue,
      );
      expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
    }

    await manager.debugCloseHeldRouteForTest('invite_previous_resume');
    expect(manager.debugSnapshot()['acceptedRoutePending'], isTrue);
    expect(openedRoutes, isEmpty);
    await tester.pump(const Duration(milliseconds: 10));

    appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await tester.pump(const Duration(milliseconds: 20));
    await resumed;

    final snapshot = manager.debugSnapshot();
    expect(openedRoutes, ['invite_resume_before_teardown']);
    expect(snapshot['routeOpenCount'], 1);
    expect(snapshot['rtcSetupOwnerCount'], 1);
    expect(snapshot['acceptedRoutePending'], isFalse);
    expect(
      notifications.debugSnapshotForTest()['acceptedRouteResumeInFlight'],
      isFalse,
    );
    await manager.forceIdleForTest();
  });

  testWidgets('readiness ownership survives teardown longer than three seconds',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    var appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_long_teardown', status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_previous_long_teardown',
      channel: 'channel_invite_previous_long_teardown',
    );
    await manager.debugMarkHeldRouteTerminalForTest(
      'invite_previous_long_teardown',
    );
    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_long_teardown',
      channel: 'channel_invite_long_teardown',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );

    appReady = false;
    await tester.pumpWidget(const SizedBox.shrink());
    final resumed = notifications.debugResumePendingAcceptedRouteForTest();
    for (var tick = 0; tick < 16; tick += 1) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(
      notifications.debugSnapshotForTest()['acceptedRouteResumeInFlight'],
      isTrue,
    );
    expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);

    await manager.debugCloseHeldRouteForTest(
      'invite_previous_long_teardown',
    );
    await tester.pump(const Duration(milliseconds: 250));
    appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await tester.pump(const Duration(milliseconds: 250));
    await resumed;

    expect(openedRoutes, ['invite_long_teardown']);
    expect(manager.debugSnapshot()['routeOpenCount'], 1);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 1);
    await manager.forceIdleForTest();
  });

  testWidgets('terminal pending call stops pre-teardown readiness probe',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_terminal_during_wait',
        status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 10),
      window: const Duration(seconds: 1),
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_previous_terminal_wait',
      channel: 'channel_invite_previous_terminal_wait',
    );
    await manager.debugMarkHeldRouteTerminalForTest(
      'invite_previous_terminal_wait',
    );
    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_terminal_during_wait',
      channel: 'channel_invite_terminal_during_wait',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );

    final resumed = notifications.debugResumePendingAcceptedRouteForTest();
    await tester.pump(const Duration(milliseconds: 20));
    await firestore
        .collection('callInvites')
        .doc('invite_terminal_during_wait')
        .set({
      'status': CallInviteStatus.cancelled.name,
    }, SetOptions(merge: true));
    await manager.debugCloseHeldRouteForTest(
      'invite_previous_terminal_wait',
    );
    await tester.pump(const Duration(milliseconds: 20));
    await resumed;

    expect(openedRoutes, isEmpty);
    expect(manager.hasPendingAcceptedRouteOwnership, isFalse);
    expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
    expect(manager.debugSnapshot()['sessionIdle'], isTrue);
    expect(
      notifications.debugSnapshotForTest()['acceptedRouteResumeInFlight'],
      isFalse,
    );
  });

  testWidgets('twenty resumed-before-teardown cycles open one route each',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    var appReady = true;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 1),
      window: const Duration(seconds: 1),
    );
    var previousInvite = 'invite_resume_cycle_0';
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: previousInvite,
      channel: 'channel_$previousInvite',
    );

    for (var cycle = 1; cycle <= 20; cycle += 1) {
      final nextInvite = 'invite_resume_cycle_$cycle';
      await seedInvite(nextInvite, status: CallInviteStatus.ringing);
      await manager.debugMarkHeldRouteTerminalForTest(previousInvite);

      appReady = false;
      await tester.pumpWidget(const SizedBox.shrink());
      if (cycle.isOdd) {
        await notifications.debugResumePendingAcceptedRouteForTest();
        expect(manager.hasPendingAcceptedRouteOwnership, isFalse);
      }
      await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
        inviteId: nextInvite,
        channel: 'channel_$nextInvite',
        isVideo: false,
        fromName: 'Notify Caller',
        fromUid: callerUid,
      );
      final resumed = cycle.isEven
          ? notifications.debugResumePendingAcceptedRouteForTest()
          : Future<void>.value();
      await tester.pump(const Duration(milliseconds: 2));
      await manager.debugCloseHeldRouteForTest(previousInvite);
      await tester.pump(const Duration(milliseconds: 2));
      appReady = true;
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home')),
      ));
      await tester.pump(const Duration(milliseconds: 2));
      await resumed;
      await notifications.debugResumePendingAcceptedRouteForTest();

      expect(openedRoutes.length, cycle);
      expect(openedRoutes.last, nextInvite);
      expect(manager.debugSnapshot()['routeOpenCount'], cycle);
      expect(manager.debugSnapshot()['rtcSetupOwnerCount'], cycle);
      previousInvite = nextInvite;
    }
    await manager.forceIdleForTest();
  });

  testWidgets(
      'twenty accepted-native cycles alternate route remote and watchdog outcomes',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    final nativeCalls = <NativeCallSnapshot>[];
    var appReady = false;
    String? previousInvite;
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (callkitId) async {
        nativeCalls.removeWhere((call) => call.callkitId == callkitId);
      },
      appForegroundProvider: () async => appReady,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );
    manager.debugConfigureAcceptedNativeRouteWatchForTest(
      timeout: const Duration(milliseconds: 500),
    );
    notifications.debugConfigureAcceptedRouteReadinessForTest(
      interval: const Duration(milliseconds: 50),
      window: const Duration(seconds: 2),
    );

    var expectedRouteCount = 0;
    for (var cycle = 1; cycle <= 20; cycle += 1) {
      if (previousInvite == null) {
        previousInvite = 'accepted_native_carrier_$cycle';
        await manager.debugCreateHeldCallRouteForTest(
          inviteId: previousInvite,
          channel: 'channel_$previousInvite',
        );
      }
      final endingInvite = previousInvite;
      final nextInvite = 'accepted_native_cycle_$cycle';
      final channel = 'channel_$nextInvite';
      final exactCallkitId = normalizeCallkitId(
        rawId: nextInvite,
        fallback: channel,
      );
      await seedInvite(nextInvite, status: CallInviteStatus.ringing);
      nativeCalls.add(NativeCallSnapshot(
        callkitId: exactCallkitId,
        inviteId: nextInvite,
        channel: channel,
        accepted: true,
      ));
      await manager.debugMarkHeldRouteTerminalForTest(endingInvite);
      appReady = false;
      await tester.pumpWidget(const SizedBox.shrink());

      await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
        inviteId: nextInvite,
        channel: channel,
        isVideo: false,
        fromName: 'Notify Caller',
        fromUid: callerUid,
        callkitId: exactCallkitId,
      );
      expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isTrue);
      await manager.debugCloseHeldRouteForTest(endingInvite);

      final outcome = cycle % 3;
      if (outcome == 1) {
        expectedRouteCount += 1;
        appReady = true;
        await tester.pumpWidget(MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('home')),
        ));
        await pumpUntilRouteOpened(
          tester,
          expectedRoutes: expectedRouteCount,
        );
        await notifications.debugResumePendingAcceptedRouteForTest();
        expect(openedRoutes.last, nextInvite);
        expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isFalse);
        previousInvite = nextInvite;
      } else if (outcome == 2) {
        await firestore.collection('callInvites').doc(nextInvite).set(
          <String, dynamic>{'status': CallInviteStatus.ended.name},
          SetOptions(merge: true),
        );
        await pumpUntilAcceptedNativeWatchSettles(tester);
        expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isFalse);
        expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
        expect(manager.debugSnapshot()['nativeAcceptedCallActive'], isFalse);
        expect(manager.debugSnapshot()['sessionIdle'], isTrue);
        previousInvite = null;
      } else {
        await tester.pump(const Duration(milliseconds: 510));
        await pumpUntilAcceptedNativeWatchSettles(tester);
        final invite =
            await firestore.collection('callInvites').doc(nextInvite).get();
        expect(invite.data()?['status'], CallInviteStatus.failed.name);
        expect(
          manager.debugSnapshot()['acceptedNativeWatchDeadlineReached'],
          isTrue,
        );
        expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isFalse);
        expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
        expect(manager.debugSnapshot()['nativeAcceptedCallActive'], isFalse);
        expect(manager.debugSnapshot()['sessionIdle'], isTrue);
        previousInvite = null;
      }
      expect(manager.debugSnapshot()['routeOpenCount'], expectedRouteCount);
      expect(manager.debugSnapshot()['rtcSetupOwnerCount'], expectedRouteCount);
    }

    expect(openedRoutes.length, 7);
    expect(nativeCalls, isEmpty);
    expect(manager.debugSnapshot()['sessionIdle'], isTrue);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets(
      'native CallKit accept uses recovery coordinator for network retry',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_network_retry');
    var failRead = true;
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: placeholderCallOpenRecorder(),
      skipActiveInviteBindingForTest: true,
      readInviteDataForTest: (inviteId) async {
        if (failRead) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
        return <String, dynamic>{
          'fromUid': callerUid,
          'fromName': 'Notify Caller',
          'toUid': calleeUid,
          'toName': calleeName,
          'channel': 'channel_invite_network_retry',
          'isVideo': false,
          'status': CallInviteStatus.accepted.name,
        };
      },
    );

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_network_retry',
      channel: 'channel_invite_network_retry',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );

    expect(manager.debugSnapshot()['acceptedRecoveryPending'], isTrue);
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isTrue,
    );
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryAttempts'],
      1,
    );

    failRead = false;
    await notifications.debugRunAcceptedRecoveryRetryForTest();
    await tester.pump();

    final snapshot = manager.debugSnapshot();
    expect(snapshot['activeCallRouteCount'], 1);
    expect(snapshot['acceptedRecoveryPending'], isFalse);
    expect(snapshot['acceptedRecoveryAcknowledged'], isTrue);
    await manager.forceIdleForTest();
  });

  testWidgets('accept duplicate while recovery in flight is coalesced',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_concurrent_recovery');
    final firstReadStarted = Completer<void>();
    final releaseFirstRead = Completer<void>();
    var readCount = 0;
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: placeholderCallOpenRecorder(),
      skipActiveInviteBindingForTest: true,
      readInviteDataForTest: (inviteId) async {
        readCount += 1;
        if (readCount == 1) {
          firstReadStarted.complete();
          await releaseFirstRead.future;
        }
        return <String, dynamic>{
          'fromUid': callerUid,
          'fromName': 'Notify Caller',
          'toUid': calleeUid,
          'toName': calleeName,
          'channel': 'channel_invite_concurrent_recovery',
          'isVideo': false,
          'status': CallInviteStatus.accepted.name,
        };
      },
    );

    final firstRecovery =
        notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_concurrent_recovery',
      channel: 'channel_invite_concurrent_recovery',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await firstReadStarted.future;
    await notifications.debugSimulateAcceptedCallkitEventForTest(
      inviteId: 'invite_concurrent_recovery',
      channel: 'channel_invite_concurrent_recovery',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );

    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryCoalesced'],
      isTrue,
    );
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isFalse,
    );
    releaseFirstRead.complete();
    await firstRecovery;
    await tester.pump();

    final snapshot = manager.debugSnapshot();
    expect(snapshot['activeCallRouteCount'], 1);
    expect(snapshot['routeOpenCount'], 1);
    expect(snapshot['rtcSetupOwnerCount'], 1);
    expect(snapshot['acceptedRecoveryPending'], isFalse);
    expect(snapshot['acceptedRecoveryAcknowledged'], isTrue);
    await manager.forceIdleForTest();
  });

  testWidgets('duplicate accept after route open is already open no-op',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final openedRoutes = <String>[];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_already_open', status: CallInviteStatus.ringing);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: recordingCallOpenRecorder(openedRoutes),
      skipActiveInviteBindingForTest: true,
      iosCallkitOnlyIncomingUiForTest: true,
    );

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_already_open',
      channel: 'channel_invite_already_open',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await pumpUntilRouteOpened(tester);
    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_already_open',
      channel: 'channel_invite_already_open',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await notifications.debugSimulateAcceptedCallkitEventForTest(
      inviteId: 'invite_already_open',
      channel: 'channel_invite_already_open',
      isVideo: false,
      fromName: 'Notify Caller',
      fromUid: callerUid,
    );
    await tester.pump();

    final snapshot = manager.debugSnapshot();
    expect(openedRoutes, ['invite_already_open']);
    expect(snapshot['routeOpenCount'], 1);
    expect(snapshot['rtcSetupOwnerCount'], 1);
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isFalse,
    );
    await manager.forceIdleForTest();
  });

  test('signout barrier blocks same-user rebind and late token callbacks',
      () async {
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'venus',
      currentDisplayName: 'Venus',
    );
    notifications.debugBeginPushBindingForTest('venus');
    await notifications.debugRegisterFcmTokenForTest(token: 'venus_initial');
    final releaseLateVenusCompletion = Completer<void>();
    final lateVenusRegistration = notifications.debugRegisterFcmTokenForTest(
      token: 'venus_late',
      beforeWrite: () => releaseLateVenusCompletion.future,
    );
    await Future<void>.delayed(Duration.zero);

    final initialVenusInstallations = await installations('venus');
    expect(initialVenusInstallations.single['active'], isTrue);

    final deactivationReached = Completer<void>();
    final releaseCleanup = Completer<void>();
    notifications.debugAfterSignOutDeactivationForTest(() async {
      deactivationReached.complete();
      await releaseCleanup.future;
    });
    final signOut = notifications.debugPreparePushBindingSignOutForTest();
    await deactivationReached.future;

    final afterDeactivationInstallations = await installations('venus');
    expect(afterDeactivationInstallations.single['active'], isFalse);
    final generationDuringBarrier =
        notifications.debugSnapshotForTest()['pushBindingGeneration'] as int;

    await notifications.debugRebindForCurrentUserForTest(
      forceFcmToken: 'venus_rebind',
    );
    await notifications.debugRegisterFcmTokenForTest(token: 'venus_refresh');
    await notifications.debugRegisterApnsTokenForTest(token: 'venus_apns');
    await notifications.debugRegisterVoipTokenForTest(token: 'venus_voip');

    final barrierSnapshot = notifications.debugSnapshotForTest();
    expect(barrierSnapshot['signOutPreparationInProgress'], isTrue);
    expect(barrierSnapshot['signOutBarrierMatchesCurrentUser'], isTrue);
    expect(barrierSnapshot['pushBindingGeneration'], generationDuringBarrier);
    expect((await userData('venus'))?['fcmToken'], 'venus_initial');
    final duringBarrierInstallations = await installations('venus');
    expect(duringBarrierInstallations.single['active'], isFalse);
    expect(duringBarrierInstallations.single['fcmToken'], 'venus_initial');
    expect(duringBarrierInstallations.single['apnsToken'], isNull);
    expect(duringBarrierInstallations.single['voipToken'], isNull);

    releaseCleanup.complete();
    await signOut;
    final afterSignOutSnapshot = notifications.debugSnapshotForTest();
    expect(afterSignOutSnapshot['signOutPreparationInProgress'], isTrue);
    expect(afterSignOutSnapshot['signOutBarrierMatchesCurrentUser'], isTrue);

    notifications.debugApplyPushAuthTransitionForTest(null);
    expect(
      notifications.debugSnapshotForTest()['signOutPreparationInProgress'],
      isFalse,
    );

    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'baris',
      currentDisplayName: 'Baris',
    );
    await notifications.debugRebindForCurrentUserForTest(
      forceFcmToken: 'baris_fcm',
      skipRealtimeBindings: true,
    );
    releaseLateVenusCompletion.complete();
    await lateVenusRegistration;

    final venusInstallations = await installations('venus');
    final barisInstallations = await installations('baris');
    expect(venusInstallations.single['active'], isFalse);
    expect(venusInstallations.single['fcmToken'], 'venus_initial');
    expect(barisInstallations.single['ownerUid'], 'baris');
    expect(barisInstallations.single['active'], isTrue);
    expect(barisInstallations.single['fcmToken'], 'baris_fcm');
    expect((await userData('baris'))?['fcmToken'], 'baris_fcm');
  });

  test('signout suppresses late FCM token completion', () async {
    final beforeWrite = Completer<void>();
    final registration = notifications.debugRegisterFcmTokenForTest(
      token: 'old_fcm_token',
      beforeWrite: () => beforeWrite.future,
    );
    await Future<void>.delayed(Duration.zero);

    await notifications.debugPreparePushBindingSignOutForTest();
    beforeWrite.complete();
    await registration;

    expect((await userData(calleeUid))?['fcmToken'], isNull);
    final calleeInstallations = await installations(calleeUid);
    expect(calleeInstallations, isNotEmpty);
    expect(calleeInstallations.single['active'], isFalse);
  });

  test('signout suppresses late APNS token completion', () async {
    final beforeWrite = Completer<void>();
    final registration = notifications.debugRegisterApnsTokenForTest(
      token: 'old_apns_token',
      beforeWrite: () => beforeWrite.future,
    );
    await Future<void>.delayed(Duration.zero);

    await notifications.debugPreparePushBindingSignOutForTest();
    beforeWrite.complete();
    await registration;

    expect((await userData(calleeUid))?['apnsToken'], isNull);
    final calleeInstallations = await installations(calleeUid);
    expect(calleeInstallations, isNotEmpty);
    expect(calleeInstallations.single['active'], isFalse);
  });

  test('signout suppresses late VoIP token completion', () async {
    final beforeWrite = Completer<void>();
    final registration = notifications.debugRegisterVoipTokenForTest(
      token: 'old_voip_token',
      beforeWrite: () => beforeWrite.future,
    );
    await Future<void>.delayed(Duration.zero);

    await notifications.debugPreparePushBindingSignOutForTest();
    beforeWrite.complete();
    await registration;

    expect((await userData(calleeUid))?['voipToken'], isNull);
    final calleeInstallations = await installations(calleeUid);
    expect(calleeInstallations, isNotEmpty);
    expect(calleeInstallations.single['active'], isFalse);
  });

  test('new user generation accepts only new owner writes', () async {
    final beforeWrite = Completer<void>();
    final oldRegistration = notifications.debugRegisterFcmTokenForTest(
      token: 'old_fcm_token',
      beforeWrite: () => beforeWrite.future,
    );
    await Future<void>.delayed(Duration.zero);

    await notifications.debugPreparePushBindingSignOutForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'new_owner',
      currentDisplayName: 'New Owner',
    );
    notifications.debugBeginPushBindingForTest('new_owner');
    await notifications.debugRegisterFcmTokenForTest(token: 'new_fcm_token');
    beforeWrite.complete();
    await oldRegistration;

    expect((await userData(calleeUid))?['fcmToken'], isNull);
    expect((await userData('new_owner'))?['fcmToken'], 'new_fcm_token');
    final newInstallations = await installations('new_owner');
    expect(newInstallations.single['ownerUid'], 'new_owner');
    expect(newInstallations.single['active'], isTrue);
  });
}
