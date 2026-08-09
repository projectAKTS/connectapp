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

  testWidgets('CallKit accept uses recovery coordinator for navigator retry',
      (tester) async {
    await seedInvite('invite_nav_retry');

    await notifications.debugSimulateAcceptedCallkitEventForTest(
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
  });

  testWidgets('CallKit accept uses recovery coordinator for network retry',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_network_retry');
    manager.configure(
      navigatorKey: navigatorKey,
      readInviteDataForTest: (inviteId) async {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      },
    );

    await notifications.debugSimulateAcceptedCallkitEventForTest(
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
  });

  testWidgets('simultaneous CallKit accept recoveries keep one route',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('invite_concurrent_recovery');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_concurrent_recovery',
      channel: 'channel_invite_concurrent_recovery',
      status: CallInviteStatus.accepted,
    );
    final firstReadStarted = Completer<void>();
    final releaseFirstRead = Completer<void>();
    var readCount = 0;
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
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
        notifications.debugSimulateAcceptedCallkitEventForTest(
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
      notifications.debugSnapshotForTest()['acceptedRecoveryRetryScheduled'],
      isTrue,
    );
    releaseFirstRead.complete();
    await firstRecovery;
    await tester.pump();

    final snapshot = manager.debugSnapshot();
    expect(snapshot['activeCallRouteCount'], 1);
    expect(snapshot['acceptedRecoveryPending'], isFalse);
    expect(snapshot['acceptedRecoveryAcknowledged'], isTrue);
    await manager.clearForSignedOut();
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
