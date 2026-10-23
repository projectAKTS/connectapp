import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/screens/call/agora_call_screen.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<int> showOwnedCallScreen(
    WidgetTester tester, {
    required String inviteId,
    required String acceptedCallkitId,
    bool isVideo = false,
    bool isCaller = true,
    GlobalKey<NavigatorState>? navigatorKey,
    Future<void> Function()? beforeFinalNavigatorPop,
  }) async {
    final generation = await manager.debugCreateHeldCallRouteForTest(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      acceptedCallkitId: acceptedCallkitId,
      status: CallInviteStatus.connected,
      isCaller: isCaller,
      isVideo: isVideo,
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-call-screen'),
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => AgoraCallScreen(
                      channelName: 'channel_$inviteId',
                      isVideo: isVideo,
                      otherUserName: 'Owned Route User',
                      inviteId: inviteId,
                      acceptedCallkitId: acceptedCallkitId,
                      lifecycleGeneration: generation,
                      isCaller: isCaller,
                      skipRuntimeSetupForTest: true,
                      startLoadedForTest: true,
                      beforeFinalNavigatorPopForTest: beforeFinalNavigatorPop,
                    ),
                  ),
                );
              },
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-call-screen')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('call-v2-hangup')), findsOne);
    return generation;
  }

  bool terminalRouteIsDisposed() {
    return find
            .byKey(const Key('call-v2-managed-route-exit-scope'))
            .evaluate()
            .isEmpty &&
        find.byKey(const Key('call-v2-hangup')).evaluate().isEmpty &&
        find.text('Call ended').evaluate().isEmpty &&
        find.byKey(const Key('open-call-screen')).evaluate().isNotEmpty;
  }

  Future<int> pumpFramesUntil(
    WidgetTester tester,
    bool Function() condition, {
    int maximumElapsedMs = 2000,
    int frameMs = 16,
    String failure = 'Condition was not reached within the frame budget.',
  }) async {
    var elapsedMs = 0;
    while (!condition() && elapsedMs < maximumElapsedMs) {
      await tester.pump(Duration(milliseconds: frameMs));
      elapsedMs += frameMs;
    }
    if (!condition()) {
      fail('$failure Elapsed simulated time: ${elapsedMs}ms.');
    }
    return elapsedMs;
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

  testWidgets(
      'production hangup pops before delayed authoritative transition completes',
      (tester) async {
    const inviteId = 'prompt_hangup_delayed_transaction';
    const exactId = 'exact_prompt_hangup';
    final transactionEntered = Completer<void>();
    final releaseTransaction = Completer<void>();
    manager.configure(beforeTerminalTransactionForTest: () async {
      if (!transactionEntered.isCompleted) transactionEntered.complete();
      await releaseTransaction.future;
    });
    await seedInvite(inviteId, status: CallInviteStatus.connected);
    await showOwnedCallScreen(
      tester,
      inviteId: inviteId,
      acceptedCallkitId: exactId,
    );

    await tester.tap(find.byKey(const Key('call-v2-hangup')));
    await tester.pump();
    await transactionEntered.future;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(releaseTransaction.isCompleted, isFalse);
    expect(find.byKey(const Key('open-call-screen')), findsOne);
    expect(find.byKey(const Key('call-v2-hangup')), findsNothing);
    expect(manager.debugSnapshot()['callLifecycleState'], 'ending');
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);

    releaseTransaction.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('remote terminal UI pops before delayed cleanup completes',
      (tester) async {
    final cleanupEntered = Completer<void>();
    final releaseCleanup = Completer<void>();
    var cleanupCount = 0;
    await showManagedCallScreen(
      tester,
      isVideo: false,
      loaded: true,
      terminal: true,
      onExit: (terminal) async {
        expect(terminal, isTrue);
        cleanupCount += 1;
        if (!cleanupEntered.isCompleted) cleanupEntered.complete();
        await releaseCleanup.future;
      },
    );

    await tester.tap(find.byKey(const Key('call-v2-route-close')));
    await tester.pump();
    await cleanupEntered.future;
    await tester.pump(const Duration(milliseconds: 400));

    expect(releaseCleanup.isCompleted, isFalse);
    expect(find.byKey(const Key('open-call-screen')), findsOne);
    expect(cleanupCount, 1);

    releaseCleanup.complete();
    await tester.pump();
  });

  testWidgets(
      'remote terminal route returns home after native stale UI reconciliation',
      (tester) async {
    const inviteId = 'remote_terminal_stale_native_reconciliation';
    const exactId = 'exact_remote_terminal_stale_native';
    await seedInvite(inviteId, status: CallInviteStatus.connected);
    await showOwnedCallScreen(
      tester,
      inviteId: inviteId,
      acceptedCallkitId: exactId,
      isCaller: false,
    );

    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: false,
      reason: 'remote_hangup',
    );
    await tester.pump();

    expect(find.text('Call ended'), findsOne);
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);

    // NotificationService invokes this after the exact native CallKit call is
    // gone. The still-mounted terminal route must retain dismissal ownership.
    manager.clearStaleUiFlags();
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Call ended'), findsOne);
    await tester.pump(const Duration(seconds: 40));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-call-screen')), findsOne);
    expect(find.text('Call ended'), findsNothing);
  });

  testWidgets(
      'manager-owned receiver route returns Home within two seconds after immediate stale native reconciliation',
      (tester) async {
    const inviteId = 'fast_terminal_stale_native_reconciliation';
    const exactId = 'exact_fast_terminal_stale_native';
    final endedNativeCalls = <String>[];
    final pluginEndedCalls = <String>[];
    final nativeStates = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_callkit_incoming'),
      (call) async {
        if (call.method == 'endCall') {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          pluginEndedCalls.add((arguments['id'] ?? '').toString());
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_callkit_incoming'),
        null,
      );
    });
    manager.configure(
      endNativeCall: (callkitId) async => endedNativeCalls.add(callkitId),
      markNativeInviteState: ({
        required String inviteId,
        required String channel,
        required String callkitId,
        required String state,
      }) async {
        nativeStates.add('$state:$callkitId');
      },
    );
    await seedInvite(inviteId, status: CallInviteStatus.connected);
    await showOwnedCallScreen(
      tester,
      inviteId: inviteId,
      acceptedCallkitId: exactId,
      isCaller: false,
    );

    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: false,
      reason: 'remote_hangup',
    );
    await tester.pump();

    expect(find.text('Call ended'), findsOne);
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);
    expect(endedNativeCalls, <String>[exactId]);
    expect(nativeStates, contains('terminal:$exactId'));

    // NotificationService._resetStaleIncomingUiIfNeeded invokes this exact
    // manager operation after the iOS plugin reports no active native calls.
    manager.clearStaleUiFlags();
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);

    final elapsedMs = await pumpFramesUntil(
      tester,
      terminalRouteIsDisposed,
      failure: 'The exact terminal route did not dispose and reveal Home.',
    );

    expect(elapsedMs, lessThanOrEqualTo(2000));
    expect(terminalRouteIsDisposed(), isTrue);

    // Late terminal/reconciliation work cannot resurrect the disposed route.
    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: false,
      reason: 'late_remote_hangup',
    );
    manager.clearStaleUiFlags();
    for (var elapsed = 0; elapsed < 2000; elapsed += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(terminalRouteIsDisposed(), isTrue);
    expect(endedNativeCalls, isNotEmpty);
    expect(endedNativeCalls.every((id) => id == exactId), isTrue);
    expect(pluginEndedCalls, <String>[exactId]);
  });

  testWidgets(
      'stale native reconciliation during auto-close keeps exact owner until prompt route disposal',
      (tester) async {
    const inviteId = 'terminal_reconciliation_during_auto_close';
    const exactId = 'exact_terminal_reconciliation_during_auto_close';
    final finalPopBoundaryEntered = Completer<void>();
    final releaseFinalPopBoundary = Completer<void>();
    final endedNativeCalls = <String>[];
    final pluginEndedCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_callkit_incoming'),
      (call) async {
        if (call.method == 'endCall') {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          pluginEndedCalls.add((arguments['id'] ?? '').toString());
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_callkit_incoming'),
        null,
      );
    });
    manager.configure(
      endNativeCall: (callkitId) async => endedNativeCalls.add(callkitId),
    );
    await seedInvite(inviteId, status: CallInviteStatus.connected);
    await showOwnedCallScreen(
      tester,
      inviteId: inviteId,
      acceptedCallkitId: exactId,
      isCaller: false,
      beforeFinalNavigatorPop: () async {
        if (!finalPopBoundaryEntered.isCompleted) {
          finalPopBoundaryEntered.complete();
        }
        await releaseFinalPopBoundary.future;
      },
    );

    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: false,
      reason: 'remote_hangup',
    );
    await tester.pump();
    expect(find.text('Call ended'), findsOne);

    var elapsedMs = await pumpFramesUntil(
      tester,
      () => finalPopBoundaryEntered.isCompleted,
      failure: 'The terminal route never reached the final pop boundary.',
    );
    expect(elapsedMs, lessThanOrEqualTo(2000));

    manager.clearStaleUiFlags();
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);
    releaseFinalPopBoundary.complete();

    elapsedMs += await pumpFramesUntil(
      tester,
      terminalRouteIsDisposed,
      maximumElapsedMs: 2000 - elapsedMs,
      failure: 'The terminal route did not finish its authorized pop.',
    );
    expect(elapsedMs, lessThanOrEqualTo(2000));
    expect(endedNativeCalls, isNotEmpty);
    expect(endedNativeCalls.every((id) => id == exactId), isTrue);
    expect(pluginEndedCalls, <String>[exactId]);
  });

  testWidgets('repeated exit starts one cleanup and one navigation',
      (tester) async {
    final releaseCleanup = Completer<void>();
    var cleanupCount = 0;
    await showManagedCallScreen(
      tester,
      isVideo: false,
      loaded: true,
      onExit: (_) async {
        cleanupCount += 1;
        await releaseCleanup.future;
      },
    );

    await tester.tap(find.byKey(const Key('call-v2-route-close')));
    await tester.tap(find.byKey(const Key('call-v2-route-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(cleanupCount, 1);
    expect(find.byKey(const Key('open-call-screen')), findsOne);
    releaseCleanup.complete();
    await tester.pump();
  });

  testWidgets('stale A screen cannot pop or mutate owned Call B',
      (tester) async {
    final generationA = await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'owned_a',
      channel: 'channel_owned_a',
      acceptedCallkitId: 'exact_owned_a',
    );
    await manager.forceIdleForTest();
    final generationB = await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'owned_b',
      channel: 'channel_owned_b',
      acceptedCallkitId: 'exact_owned_b',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-stale-a'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => AgoraCallScreen(
                    channelName: 'channel_owned_a',
                    isVideo: false,
                    otherUserName: 'Stale A',
                    inviteId: 'owned_a',
                    acceptedCallkitId: 'exact_owned_a',
                    lifecycleGeneration: generationA,
                    isCaller: true,
                    skipRuntimeSetupForTest: true,
                    startLoadedForTest: true,
                  ),
                ),
              ),
              child: const Text('Home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-stale-a')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('call-v2-hangup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const Key('call-v2-hangup')), findsOne);
    expect(manager.activeInviteId, 'owned_b');
    expect(manager.debugSnapshot()['lifecycleGeneration'], generationB);
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);
  });

  testWidgets(
      'final pre-pop guard prevents delayed Call A from dismissing Call B',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final finalBoundaryEntered = Completer<void>();
    final releaseFinalBoundary = Completer<void>();
    await seedInvite('final_pop_a', status: CallInviteStatus.connected);
    await showOwnedCallScreen(
      tester,
      inviteId: 'final_pop_a',
      acceptedCallkitId: 'exact_final_pop_a',
      navigatorKey: navigatorKey,
      beforeFinalNavigatorPop: () async {
        if (!finalBoundaryEntered.isCompleted) {
          finalBoundaryEntered.complete();
        }
        await releaseFinalBoundary.future;
      },
    );

    await tester.tap(find.byKey(const Key('call-v2-hangup')));
    await tester.pump();
    await finalBoundaryEntered.future;

    await manager.forceIdleForTest();
    final generationB = await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'final_pop_b',
      channel: 'channel_final_pop_b',
      acceptedCallkitId: 'exact_final_pop_b',
      status: CallInviteStatus.connected,
    );
    unawaited(navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          key: Key('final-pop-call-b-route'),
          body: Text('Call B'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('final-pop-call-b-route')), findsOne);

    releaseFinalBoundary.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('final-pop-call-b-route')), findsOne);
    expect(manager.activeInviteId, 'final_pop_b');
    expect(manager.debugSnapshot()['lifecycleGeneration'], generationB);
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);
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
