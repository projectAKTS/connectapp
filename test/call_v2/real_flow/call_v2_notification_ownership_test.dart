import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/call_session_manager.dart';
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
      'native CallKit accept uses recovery coordinator for navigator retry',
      (tester) async {
    await seedInvite('invite_nav_retry');

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: 'invite_nav_retry',
      channel: 'channel_invite_nav_retry',
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

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: placeholderCallOpenRecorder(),
      skipActiveInviteBindingForTest: true,
    );
    await notifications.debugRunAcceptedRecoveryRetryForTest();
    await tester.pump();

    final snapshot = manager.debugSnapshot();
    expect(snapshot['activeCallRouteCount'], 1);
    expect(snapshot['acceptedRecoveryPending'], isFalse);
    expect(snapshot['acceptedRecoveryAcknowledged'], isTrue);
    expect(
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isFalse,
    );
    await manager.forceIdleForTest();
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
