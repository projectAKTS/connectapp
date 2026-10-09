import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/screens/call/agora_call_screen.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'route_owner_caller';
  const calleeUid = 'route_owner_callee';
  late FakeFirebaseFirestore firestore;
  late CallSessionManager manager;

  Future<void> seedInvite(
    String inviteId, {
    required CallInviteStatus status,
    String endReason = '',
  }) async {
    await firestore.collection('callInvites').doc(inviteId).set(
      <String, dynamic>{
        'fromUid': callerUid,
        'toUid': calleeUid,
        'fromName': 'Route Owner Caller',
        'toName': 'Route Owner Callee',
        'channel': 'channel_$inviteId',
        'isVideo': false,
        'status': status.name,
        'callerStage': status.name,
        'calleeStage': status.name,
        'createdAt': Timestamp.now(),
        if (endReason.isNotEmpty) 'endReason': endReason,
      },
    );
  }

  Future<Map<String, dynamic>> closeStaleRingingRoute(
    String inviteId, {
    required CallInviteStatus serverStatus,
    String endReason = '',
  }) async {
    await seedInvite(
      inviteId,
      status: serverStatus,
      endReason: endReason,
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      acceptedCallkitId: 'exact_$inviteId',
      status: CallInviteStatus.ringing,
      isCaller: true,
    );
    final completeRoute = manager.debugCaptureHeldRouteCompletionForTest();
    await completeRoute();
    final snapshot =
        await firestore.collection('callInvites').doc(inviteId).get();
    return snapshot.data()!;
  }

  Future<void> showManagedCallScreen(
    WidgetTester tester, {
    required bool isVideo,
    required bool loaded,
    bool terminal = false,
    required Future<void> Function(bool terminal) onExit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-call-screen'),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => AgoraCallScreen(
                      channelName: 'managed_exit_channel',
                      isVideo: isVideo,
                      otherUserName: 'Managed Exit User',
                      inviteId: 'managed_exit_invite',
                      skipRuntimeSetupForTest: true,
                      startLoadedForTest: loaded,
                      startTerminalForTest: terminal,
                      managedRouteExitForTest: onExit,
                    ),
                  ),
                );
              },
              child: const Text('Open call'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-call-screen')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call-v2-managed-route-exit-scope')), findsOne);
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: 'Route Owner Caller',
    );
    manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: 'Route Owner Caller',
    );
    manager.configure(
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      markNativeInviteState: ({
        required String inviteId,
        required String channel,
        required String callkitId,
        required String state,
      }) async {},
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {},
      appForegroundProvider: () async => true,
    );
  });

  tearDown(() async {
    await manager.forceIdleForTest();
    HelperlyTestRuntime.clear();
  });

  test('authoritative accepted wins over stale local ringing on route close',
      () async {
    final data = await closeStaleRingingRoute(
      'accepted_stale_local',
      serverStatus: CallInviteStatus.accepted,
    );

    expect(data['status'], CallInviteStatus.ended.name);
    expect(data['status'], isNot(CallInviteStatus.cancelled.name));
    expect(data['endReason'], 'screen_closed');
    expect(manager.debugSnapshot()['authoritativeTerminalWriteCount'], 1);
  });

  test('authoritative joining wins over stale local ringing on route close',
      () async {
    final data = await closeStaleRingingRoute(
      'joining_stale_local',
      serverStatus: CallInviteStatus.joining,
    );

    expect(data['status'], CallInviteStatus.ended.name);
    expect(data['status'], isNot(CallInviteStatus.cancelled.name));
  });

  test('authoritative connected wins over stale local ringing on route close',
      () async {
    final data = await closeStaleRingingRoute(
      'connected_stale_local',
      serverStatus: CallInviteStatus.connected,
    );

    expect(data['status'], CallInviteStatus.ended.name);
    expect(data['status'], isNot(CallInviteStatus.cancelled.name));
  });

  test('authoritative ringing still permits caller cancellation', () async {
    final data = await closeStaleRingingRoute(
      'true_ringing_cancel',
      serverStatus: CallInviteStatus.ringing,
    );

    expect(data['status'], CallInviteStatus.cancelled.name);
    expect(manager.debugSnapshot()['authoritativeTerminalWriteCount'], 1);
  });

  test('already-terminal authoritative states and reasons are preserved',
      () async {
    for (final status in <CallInviteStatus>[
      CallInviteStatus.declined,
      CallInviteStatus.missed,
      CallInviteStatus.cancelled,
      CallInviteStatus.ended,
      CallInviteStatus.failed,
    ]) {
      await manager.forceIdleForTest();
      final reason = 'existing_${status.name}_reason';
      final data = await closeStaleRingingRoute(
        'preserve_${status.name}',
        serverStatus: status,
        endReason: reason,
      );
      expect(data['status'], status.name);
      expect(data['endReason'], reason);
      expect(manager.debugSnapshot()['authoritativeTerminalWriteCount'], 0);
    }
  });

  test('Agora failure reason survives a stale route completion', () async {
    final data = await closeStaleRingingRoute(
      'preserve_agora_failure',
      serverStatus: CallInviteStatus.failed,
      endReason: 'agora_failure',
    );

    expect(data['status'], CallInviteStatus.failed.name);
    expect(data['endReason'], 'agora_failure');
    expect(manager.debugSnapshot()['authoritativeTerminalWriteCount'], 0);
  });

  testWidgets('active Audio AppBar Close uses one managed exit',
      (tester) async {
    final terminalFlags = <bool>[];
    await showManagedCallScreen(
      tester,
      isVideo: false,
      loaded: true,
      onExit: (terminal) async => terminalFlags.add(terminal),
    );

    await tester.tap(find.byKey(const Key('call-v2-route-close')));
    await tester.pumpAndSettle();

    expect(terminalFlags, <bool>[false]);
    expect(find.byKey(const Key('open-call-screen')), findsOne);
  });

  testWidgets('loading Close uses one managed exit', (tester) async {
    final terminalFlags = <bool>[];
    await showManagedCallScreen(
      tester,
      isVideo: true,
      loaded: false,
      onExit: (terminal) async => terminalFlags.add(terminal),
    );

    await tester.tap(find.byKey(const Key('call-v2-route-close')));
    await tester.pumpAndSettle();

    expect(terminalFlags, <bool>[false]);
  });

  testWidgets('system back executes one managed exit without duplicate work',
      (tester) async {
    final terminalFlags = <bool>[];
    await showManagedCallScreen(
      tester,
      isVideo: false,
      loaded: true,
      onExit: (terminal) async => terminalFlags.add(terminal),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(terminalFlags, <bool>[false]);
    expect(find.byKey(const Key('open-call-screen')), findsOne);
  });

  testWidgets('terminal screen close is identified as UI-only terminal exit',
      (tester) async {
    final terminalFlags = <bool>[];
    await showManagedCallScreen(
      tester,
      isVideo: false,
      loaded: true,
      terminal: true,
      onExit: (terminal) async => terminalFlags.add(terminal),
    );

    await tester.tap(find.byKey(const Key('call-v2-route-close')));
    await tester.pumpAndSettle();

    expect(terminalFlags, <bool>[true]);
  });

  testWidgets('Audio and Video system exits share managed ownership parity',
      (tester) async {
    for (final isVideo in <bool>[false, true]) {
      final terminalFlags = <bool>[];
      await showManagedCallScreen(
        tester,
        isVideo: isVideo,
        loaded: true,
        onExit: (terminal) async => terminalFlags.add(terminal),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(terminalFlags, <bool>[false]);
    }
  });

  test('delayed Call A route completion cannot mutate current Call B',
      () async {
    const sharedInvite = 'shared_route_identity';
    await seedInvite(sharedInvite, status: CallInviteStatus.connected);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: sharedInvite,
      channel: 'channel_a',
      acceptedCallkitId: 'exact_a',
      status: CallInviteStatus.connected,
    );
    final completeA = manager.debugCaptureHeldRouteCompletionForTest();

    await manager.forceIdleForTest();
    await seedInvite(sharedInvite, status: CallInviteStatus.connected);
    final generationB = await manager.debugCreateHeldCallRouteForTest(
      inviteId: sharedInvite,
      channel: 'channel_b',
      acceptedCallkitId: 'exact_b',
      status: CallInviteStatus.connected,
    );

    await completeA();

    final snapshot = manager.debugSnapshot();
    final server =
        await firestore.collection('callInvites').doc(sharedInvite).get();
    expect(manager.activeInviteId, sharedInvite);
    expect(snapshot['lifecycleGeneration'], generationB);
    expect(snapshot['callRouteActive'], isTrue);
    expect(snapshot['callRouteOwnerMatchesCurrent'], isTrue);
    expect(snapshot['staleRouteCompletionIgnoredCount'], 1);
    expect(server.data()?['status'], CallInviteStatus.connected.name);
  });

  test('duplicate route completion performs one authoritative transition',
      () async {
    const inviteId = 'duplicate_route_completion';
    await seedInvite(inviteId, status: CallInviteStatus.accepted);
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      acceptedCallkitId: 'exact_duplicate',
      status: CallInviteStatus.ringing,
    );
    final completeRoute = manager.debugCaptureHeldRouteCompletionForTest();

    await Future.wait<void>(<Future<void>>[
      completeRoute(),
      completeRoute(),
    ]);

    final data = await firestore.collection('callInvites').doc(inviteId).get();
    expect(data.data()?['status'], CallInviteStatus.ended.name);
    expect(manager.debugSnapshot()['authoritativeTerminalWriteCount'], 1);
    expect(manager.debugSnapshot()['staleRouteCompletionIgnoredCount'], 1);
  });

  testWidgets('chat navigation waits for safe call lifecycle idle',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final notifications = NotificationService(navigatorKey: navigatorKey);
    addTearDown(notifications.dispose);
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      markNativeInviteState: ({
        required String inviteId,
        required String channel,
        required String callkitId,
        required String state,
      }) async {},
      clearStoredAcceptedCallRecovery: ({
        required String inviteId,
        required String callkitId,
      }) async {},
      appForegroundProvider: () async => true,
    );
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'chat_defer_call',
      channel: 'channel_chat_defer_call',
      acceptedCallkitId: 'exact_chat_defer',
      status: CallInviteStatus.connected,
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home-screen')),
        routes: <String, WidgetBuilder>{
          '/chat': (_) => const Scaffold(body: Text('chat-screen')),
        },
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    unawaited(notifications.debugOpenChatFromTapForTest(
      otherUserId: 'chat_peer',
      chatId: 'chat_deferred',
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('home-screen'), findsOne);
    expect(find.text('chat-screen'), findsNothing);
    expect(
      notifications.debugSnapshotForTest()['chatNavigationDeferredForCall'],
      isTrue,
    );

    await manager.debugMarkHeldRouteTerminalForTest('chat_defer_call');
    await manager.debugCloseHeldRouteForTest('chat_defer_call');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('chat-screen'), findsOne);
    expect(notifications.debugSnapshotForTest()['pendingChatOpen'], isFalse);
    expect(
      notifications.debugSnapshotForTest()['chatNavigationDeferredForCall'],
      isFalse,
    );
  });
}
