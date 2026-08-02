import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'rapid_caller';
  const calleeUid = 'rapid_callee';
  const callerName = 'Rapid Caller';
  const calleeName = 'Rapid Callee';

  late FakeFirebaseFirestore firestore;
  late GlobalKey<NavigatorState> navigatorKey;
  late CallSessionManager manager;

  Widget buildHarness() {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    );
  }

  Future<void> seedInvite(String inviteId) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': callerName,
      'toUid': calleeUid,
      'toName': calleeName,
      'channel': 'channel_$inviteId',
      'isVideo': false,
      'status': CallInviteStatus.ringing.name,
      'createdAt': Timestamp.now(),
      'callerStage': 'ringing',
      'calleeStage': 'idle',
    });
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    navigatorKey = GlobalKey<NavigatorState>();
    manager = CallSessionManager.instance;
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
    await manager.clearForSignedOut();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: calleeName,
    );
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      appForegroundProvider: () async => true,
    );
  });

  tearDown(() async {
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
  });

  testWidgets('notification during terminal route teardown stays pending',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'notification_test',
    );
    await manager.debugRunPreflightForTest('notification_terminal_teardown');
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['callLifecycleState'], 'teardown');
    expect(snapshot['pendingIncomingPresent'], isTrue);
    expect(snapshot['pendingIncomingCount'], 1);
    expect(snapshot['activePromptCount'], 0);
    expect(find.text('Incoming Audio Call'), findsNothing);
    await manager.clearForSignedOut();
    await tester.pump();
  });

  testWidgets('CallKit recovery during terminal route teardown stays pending',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_b');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');

    await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );
    await manager.debugRunPreflightForTest('callkit_terminal_teardown');
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['callLifecycleState'], 'teardown');
    expect(snapshot['pendingIncomingPresent'], isTrue);
    expect(snapshot['activePromptCount'], 0);
    expect(find.text('Incoming Audio Call'), findsNothing);
    await manager.clearForSignedOut();
    await tester.pump();
  });

  testWidgets('newer pending invite supersedes older and owns after teardown',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_b');
    await seedInvite('invite_c');
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_a',
    );
    await manager.debugMarkHeldRouteTerminalForTest('invite_a');
    await manager.debugRunPreflightForTest('held_route_teardown');

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pending_b',
    );
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_c',
      channel: 'channel_c',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'pending_c',
    );

    final inviteB =
        await firestore.collection('callInvites').doc('invite_b').get();
    expect(inviteB.data()?['status'], CallInviteStatus.declined.name);
    expect(manager.debugSnapshot()['pendingIncomingCount'], 1);
    expect(
      manager.debugSnapshot()['displacedPendingSupersededCount'],
      1,
    );

    final closeFuture = manager.debugCloseHeldRouteForTest('invite_a');
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (manager.debugSnapshot()['callLifecycleState'] == 'incomingPrompt') {
        break;
      }
    }
    await manager.handleNotificationInviteTap(
      inviteId: 'invite_b',
      channel: 'channel_b',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'old_b_between_handoff',
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Incoming Audio Call'), findsOneWidget);
    expect(manager.debugSnapshot()['callLifecycleState'], 'incomingPrompt');
    expect(manager.debugSnapshot()['activePromptCount'], 1);

    navigatorKey.currentState!.pop(false);
    await tester.pump();
    await closeFuture.timeout(const Duration(seconds: 5));
    expect(manager.debugSnapshot()['pendingIncomingCount'], 0);
  });

  testWidgets('outgoing reservation lost during preflight writes no invite',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: callerName,
    );
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async {
        manager.debugInvalidateLifecycleForTest();
        return const <NativeCallSnapshot>[];
      },
    );

    final started = await manager.startOutgoingCall(
      navigatorKey.currentContext!,
      toUid: calleeUid,
      toName: calleeName,
      isVideo: false,
      openScreen: false,
    );

    final invites = await firestore.collection('callInvites').get();
    expect(started, isFalse);
    expect(invites.docs, isEmpty);
  });

  testWidgets('outgoing reservation lost after invite write cancels orphan',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: callerName,
    );
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      afterOutgoingInviteWriteForTest: () async {
        manager.debugInvalidateLifecycleForTest();
      },
    );

    final started = await manager.startOutgoingCall(
      navigatorKey.currentContext!,
      toUid: calleeUid,
      toName: calleeName,
      isVideo: false,
      openScreen: false,
    );

    final invites = await firestore.collection('callInvites').get();
    expect(started, isFalse);
    expect(invites.docs, hasLength(1));
    expect(
      invites.docs.single.data()['status'],
      CallInviteStatus.cancelled.name,
    );
    expect(manager.debugSnapshot()['activeSessionPresent'], isFalse);
    expect(manager.debugSnapshot()['orphanInviteCancelledCount'], 1);
  });
}
