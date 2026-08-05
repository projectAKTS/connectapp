import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/real_flow/call_v2_call_lifecycle_arbiter.dart';
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

  Future<void> seedInvite(
    String inviteId, {
    CallInviteStatus status = CallInviteStatus.ringing,
  }) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': callerName,
      'toUid': calleeUid,
      'toName': calleeName,
      'channel': 'channel_$inviteId',
      'isVideo': false,
      'status': status.name,
      'createdAt': Timestamp.now(),
      'callerStage': status.name,
      'calleeStage': status.name,
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
    await manager.forceIdleForTest();
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
    for (var attempt = 0;
        attempt < 20 && find.text('Incoming Audio Call').evaluate().isEmpty;
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Incoming Audio Call'), findsOneWidget);
    expect(manager.debugSnapshot()['callLifecycleState'], 'incomingPrompt');
    expect(manager.debugSnapshot()['activePromptCount'], 1);

    navigatorKey.currentState!.pop(false);
    await tester.pump();
    await closeFuture.timeout(const Duration(seconds: 5));
    expect(manager.debugSnapshot()['pendingIncomingCount'], 0);
  });

  testWidgets('matching native CallKit call owns foreground incoming UI',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_callkit');
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: '696e7669-7465-4c61-ac6c-6b6974696e76',
          inviteId: 'invite_callkit',
          channel: 'channel_invite_callkit',
        ),
      ],
    );

    await manager.handleNotificationInviteTap(
      inviteId: 'invite_callkit',
      channel: 'channel_invite_callkit',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'foreground_test',
    );
    await tester.pump(const Duration(milliseconds: 350));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['incomingUiOwner'], IncomingUiOwner.callkit.name);
    expect(snapshot['activePromptCount'], 1);
    expect(find.text('Incoming Audio Call'), findsNothing);
  });

  testWidgets(
      'foreground incoming without native CallKit uses Flutter fallback',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_flutter');
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
    );

    final promptFuture = manager.handleNotificationInviteTap(
      inviteId: 'invite_flutter',
      channel: 'channel_invite_flutter',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
      source: 'foreground_test',
    );
    for (var attempt = 0;
        attempt < 20 && !(navigatorKey.currentState?.canPop() ?? false);
        attempt += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      manager.debugSnapshot()['incomingUiOwner'],
      IncomingUiOwner.flutter.name,
    );
    expect(manager.debugSnapshot()['activePromptCount'], 1);
    expect(navigatorKey.currentState?.canPop(), isTrue);
    navigatorKey.currentState!.pop(false);
    await tester.pump();
    await tester.runAsync(
      () => promptFuture.timeout(const Duration(seconds: 5)),
    );
  });

  testWidgets('Flutter decline closes matching native CallKit call',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_decline');
    final ended = <String>[];
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: '696e7669-7465-4465-a36c-696e65696e76',
          inviteId: 'invite_decline',
          channel: 'channel_invite_decline',
        ),
      ],
      endNativeCall: (callkitId) async {
        ended.add(callkitId);
      },
    );

    await manager.declineInvite(
      inviteId: 'invite_decline',
      source: 'flutter_decline_test',
    );

    final invite =
        await firestore.collection('callInvites').doc('invite_decline').get();
    expect(invite.data()?['status'], CallInviteStatus.declined.name);
    expect(ended, isNotEmpty);
  });

  testWidgets('accepted recovery without navigator remains pending',
      (tester) async {
    var cleared = 0;
    manager.configure(
      clearStoredAcceptedCallRecovery: () async {
        cleared += 1;
      },
    );
    await seedInvite('invite_pending', status: CallInviteStatus.accepted);

    final result = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_pending',
      channel: 'channel_invite_pending',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );

    expect(result, AcceptedCallRecoveryResult.pendingNavigator);
    expect(cleared, 0);
    expect(manager.debugSnapshot()['acceptedRecoveryPending'], isTrue);
    expect(manager.debugSnapshot()['hiddenSessionDetected'], isFalse);
  });

  testWidgets('terminal accepted recovery closes native call and clears record',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_terminal', status: CallInviteStatus.cancelled);
    var cleared = 0;
    final ended = <String>[];
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => true,
      clearStoredAcceptedCallRecovery: () async {
        cleared += 1;
      },
      listNativeCalls: () async => const <NativeCallSnapshot>[
        NativeCallSnapshot(
          callkitId: '696e7669-7465-5465-bd69-6e616c696e76',
          inviteId: 'invite_terminal',
          channel: 'channel_invite_terminal',
        ),
      ],
      endNativeCall: (callkitId) async {
        ended.add(callkitId);
      },
    );

    final result = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'invite_terminal',
      channel: 'channel_invite_terminal',
      isVideo: false,
      fromName: callerName,
      fromUid: callerUid,
    );

    expect(result, AcceptedCallRecoveryResult.terminal);
    expect(cleared, 1);
    expect(ended, isNotEmpty);
    expect(manager.debugSnapshot()['acceptedRecoveryAcknowledged'], isTrue);
    expect(find.text('Incoming Audio Call'), findsNothing);
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

  testWidgets('reportRemoteJoined after terminal cannot resurrect session',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_a', status: CallInviteStatus.connected);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );

    await manager.endCallFromLocalUser(
      inviteId: 'invite_a',
      source: 'test_end',
    );
    await manager.reportRemoteJoined(inviteId: 'invite_a', isCaller: true);

    final invite =
        await firestore.collection('callInvites').doc('invite_a').get();
    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(
      snapshot['callLifecycleState'],
      isIn(<String>[
        CallV2CallLifecycleState.ending.name,
        CallV2CallLifecycleState.teardown.name,
      ]),
    );
    expect(invite.data()?['status'], CallInviteStatus.ended.name);
  });

  testWidgets('reportAgoraJoinSuccess after ending is ignored', (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_a', status: CallInviteStatus.connected);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );

    await manager.endCallFromLocalUser(
      inviteId: 'invite_a',
      source: 'test_end',
    );
    await manager.reportAgoraJoinSuccess(inviteId: 'invite_a', isCaller: true);

    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(
      snapshot['callLifecycleState'],
      isIn(<String>[
        CallV2CallLifecycleState.ending.name,
        CallV2CallLifecycleState.teardown.name,
      ]),
    );
  });

  testWidgets('reportCallScreenBegan after ending does not write joining',
      (tester) async {
    await tester.pumpWidget(buildHarness());
    await seedInvite('invite_a', status: CallInviteStatus.connected);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'invite_a',
      channel: 'channel_invite_a',
    );

    await manager.endCallFromLocalUser(
      inviteId: 'invite_a',
      source: 'test_end',
    );
    await manager.reportCallScreenBegan(inviteId: 'invite_a', isCaller: false);

    final invite =
        await firestore.collection('callInvites').doc('invite_a').get();
    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(
        snapshot['callLifecycleState'], CallV2CallLifecycleState.ending.name);
    expect(invite.data()?['status'], CallInviteStatus.ended.name);
  });

  testWidgets('late Firestore connected snapshot after local end is ignored',
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
    );

    final started = await manager.startOutgoingCall(
      navigatorKey.currentContext!,
      toUid: calleeUid,
      toName: calleeName,
      isVideo: false,
      openScreen: false,
    );
    expect(started, isTrue);
    final inviteId =
        (await firestore.collection('callInvites').get()).docs.single.id;

    await manager.reportRemoteJoined(inviteId: inviteId, isCaller: true);
    await manager.endCallFromLocalUser(inviteId: inviteId, source: 'test_end');
    await firestore.collection('callInvites').doc(inviteId).set({
      'status': CallInviteStatus.connected.name,
      'connectedAt': Timestamp.now(),
    }, SetOptions(merge: true));
    await tester.pump(const Duration(milliseconds: 100));

    final snapshot = manager.debugSnapshot();
    expect(snapshot['phase'], CallSessionPhase.terminal.name);
    expect(snapshot['status'], CallInviteStatus.ended.name);
    expect(
      snapshot['callLifecycleState'],
      isIn(<String>[
        CallV2CallLifecycleState.ending.name,
        CallV2CallLifecycleState.teardown.name,
      ]),
    );
  });

  testWidgets('fifteen rapid manager lifecycles ignore delayed progress',
      (tester) async {
    await tester.pumpWidget(buildHarness());

    var previousGeneration = 0;
    for (var i = 1; i <= 15; i += 1) {
      final inviteId = 'stress_$i';
      await seedInvite(inviteId, status: CallInviteStatus.connected);
      final generation = await manager.debugCreateHeldCallRouteForTest(
        inviteId: inviteId,
        channel: 'channel_$inviteId',
      );
      expect(generation, greaterThan(previousGeneration));
      previousGeneration = generation;

      await manager.endCallFromLocalUser(inviteId: inviteId, source: 'stress');
      await manager.reportAgoraJoinSuccess(inviteId: inviteId, isCaller: true);
      await manager.reportRemoteJoined(inviteId: inviteId, isCaller: true);
      await firestore.collection('callInvites').doc(inviteId).set({
        'status': CallInviteStatus.connected.name,
        'connectedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      await tester.pump(const Duration(milliseconds: 20));

      expect(manager.debugSnapshot()['phase'], CallSessionPhase.terminal.name);
      expect(
        manager.debugSnapshot()['callLifecycleState'],
        CallV2CallLifecycleState.ending.name,
      );
      await manager.debugCloseHeldRouteForTest(inviteId);
      await tester.pump();
      expect(manager.debugSnapshot()['activeSessionPresent'], isFalse);
      expect(manager.debugSnapshot()['callLifecycleState'], 'idle');
    }
  });
}
