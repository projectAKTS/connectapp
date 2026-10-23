import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/real_flow/call_v2_agora_media_runtime.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_physical_media_owner.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_real_call_flow_gate.dart';
import 'package:connect_app/screens/call/agora_call_screen.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const callerUid = 'background_audio_caller';
  const calleeUid = 'background_audio_callee';
  const exactId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  late FakeFirebaseFirestore firestore;
  late CallSessionManager manager;
  late GlobalKey<NavigatorState> navigatorKey;
  late List<_ManagerFakeMediaRuntime> runtimes;
  late CallV2PhysicalMediaOwner mediaOwner;
  late List<String> mediaAcks;
  late List<String> routeAcks;
  late List<String> routes;
  late List<NativeCallSnapshot> nativeCalls;
  late bool appForeground;
  late bool autoJoinSuccess;
  late int readinessCancelCount;

  Future<void> seedInvite(String inviteId, {bool isVideo = false}) async {
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': callerUid,
      'fromName': 'Background Caller',
      'toUid': calleeUid,
      'toName': 'Background Callee',
      'channel': 'channel_$inviteId',
      'isVideo': isVideo,
      'status': CallInviteStatus.ringing.name,
      'createdAt': Timestamp.now(),
      'callerStage': CallInviteStatus.ringing.name,
      'calleeStage': CallInviteStatus.ringing.name,
      'callSystem': callV2DevInviteSystemValue,
    });
  }

  Future<void> waitUntil(
    WidgetTester tester,
    bool Function() condition,
  ) async {
    for (var i = 0; i < 100; i += 1) {
      if (condition()) return;
      await tester.pump(const Duration(milliseconds: 5));
    }
    fail('Condition was not reached.');
  }

  void configureManager() {
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => appForeground,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (id) async {
        nativeCalls.removeWhere((call) => call.callkitId == id);
      },
      markNativeInviteState: ({
        required String inviteId,
        required String channel,
        required String callkitId,
        required String state,
      }) async {},
      acknowledgeNativeMediaOwnership: (id) async {
        mediaAcks.add(id);
        return true;
      },
      acknowledgeNativeRouteOwnership: (id) async {
        routeAcks.add(id);
        return true;
      },
      cancelAcceptedRouteReadiness: () {
        readinessCancelCount += 1;
      },
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
        routes.add(inviteId);
      },
      skipActiveInviteBindingForTest: true,
      skipAcceptedNativeWatchBindingForTest: true,
      physicalMediaOwnerForTest: mediaOwner,
    );
  }

  void configureManagerForProductionRoute({
    required Future<void> Function() beforeProductionRoutePush,
  }) {
    manager.configure(
      navigatorKey: navigatorKey,
      appForegroundProvider: () async => appForeground,
      listNativeCalls: () async => List<NativeCallSnapshot>.of(nativeCalls),
      endNativeCall: (id) async {
        nativeCalls.removeWhere((call) => call.callkitId == id);
      },
      markNativeInviteState: ({
        required String inviteId,
        required String channel,
        required String callkitId,
        required String state,
      }) async {},
      acknowledgeNativeMediaOwnership: (id) async {
        mediaAcks.add(id);
        return true;
      },
      acknowledgeNativeRouteOwnership: (id) async {
        routeAcks.add(id);
        return true;
      },
      cancelAcceptedRouteReadiness: () {
        readinessCancelCount += 1;
      },
      beforeProductionRoutePushForTest: beforeProductionRoutePush,
      skipActiveInviteBindingForTest: true,
      skipAcceptedNativeWatchBindingForTest: true,
      physicalMediaOwnerForTest: mediaOwner,
    );
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Background Callee',
    );
    manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Background Callee',
    );
    navigatorKey = GlobalKey<NavigatorState>();
    runtimes = <_ManagerFakeMediaRuntime>[];
    mediaAcks = <String>[];
    routeAcks = <String>[];
    routes = <String>[];
    nativeCalls = <NativeCallSnapshot>[];
    appForeground = false;
    autoJoinSuccess = true;
    readinessCancelCount = 0;
    mediaOwner = CallV2PhysicalMediaOwner(
      runtimeFactory: (config) {
        final runtime = _ManagerFakeMediaRuntime(
          config,
          autoJoinSuccess: autoJoinSuccess,
        );
        runtimes.add(runtime);
        return runtime;
      },
      microphonePermissionStatus: () async => true,
      microphonePermissionRequest: () async => true,
    );
    configureManager();
  });

  tearDown(() async {
    await manager.forceIdleForTest().timeout(const Duration(seconds: 2),
        onTimeout: () {
      fail('forceIdleForTest did not complete');
    });
    HelperlyTestRuntime.clear();
  });

  testWidgets(
      'background accepted audio joins without Navigator and sends media ACK only',
      (tester) async {
    await seedInvite('headless_audio');
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactId,
      inviteId: 'headless_audio',
      channel: 'channel_headless_audio',
      accepted: true,
    ));
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );

    final result = await manager
        .handleRecoveredAcceptedInvite(
          inviteId: 'headless_audio',
          channel: 'channel_headless_audio',
          isVideo: false,
          fromName: 'Background Caller',
          fromUid: callerUid,
          callkitId: exactId,
        )
        .timeout(const Duration(seconds: 2));
    await waitUntil(tester, () => mediaAcks.isNotEmpty);

    expect(result, AcceptedCallRecoveryResult.pendingNavigator);
    expect(runtimes, hasLength(1));
    expect(runtimes.single.startCount, 1);
    expect(runtimes.single.joinCount, 1);
    expect(routes, isEmpty);
    expect(mediaAcks, <String>[exactId]);
    expect(routeAcks, isEmpty);
    expect(manager.debugSnapshot()['acceptedNativeWatchActive'], isTrue);
    await manager.forceIdleForTest();
    await tester.pump();
  });

  testWidgets(
      'media ACK and watch transfer precede blocked Firestore join progress',
      (tester) async {
    final progressEntered = Completer<void>();
    final releaseProgress = Completer<void>();
    manager.debugConfigureAcceptedNativeRouteWatchForTest(
      timeout: const Duration(milliseconds: 20),
    );
    manager.configure(
      beforeAgoraJoinProgressForTest: () async {
        if (!progressEntered.isCompleted) progressEntered.complete();
        await releaseProgress.future;
      },
    );
    await seedInvite('blocked_join_progress');
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactId,
      inviteId: 'blocked_join_progress',
      channel: 'channel_blocked_join_progress',
      accepted: true,
    ));
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );

    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: 'blocked_join_progress',
        channel: 'channel_blocked_join_progress',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await progressEntered.future.timeout(const Duration(seconds: 1));

    expect(mediaAcks, <String>[exactId]);
    expect(routeAcks, isEmpty);
    expect(
      manager.debugSnapshot()['acceptedNativeWatchMediaOwned'],
      isTrue,
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      manager.debugSnapshot()['acceptedNativeWatchDeadlineReached'],
      isFalse,
    );

    releaseProgress.complete();
    for (var i = 0; i < 100; i += 1) {
      await tester.pump(const Duration(milliseconds: 5));
      final invite = await firestore
          .collection('callInvites')
          .doc('blocked_join_progress')
          .get();
      if (invite.data()?['calleeStage'] == 'joined_local') break;
    }
    final invite = await firestore
        .collection('callInvites')
        .doc('blocked_join_progress')
        .get();
    expect(invite.data()?['calleeStage'], 'joined_local');
    expect(mediaAcks, <String>[exactId]);
    expect(routeAcks, isEmpty);
    await manager.forceIdleForTest();
    await tester.pump();
  });

  testWidgets('stale media key before join success sends no media ACK',
      (tester) async {
    autoJoinSuccess = false;
    await seedInvite('stale_before_join');
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );
    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: 'stale_before_join',
        channel: 'channel_stale_before_join',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => runtimes.isNotEmpty);
    final staleRuntime = runtimes.single;

    await manager.forceIdleForTest();
    configureManager();
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'newer_call',
      channel: 'channel_newer_call',
      acceptedCallkitId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      status: CallInviteStatus.connected,
      isCaller: false,
    );
    await staleRuntime.fireJoinSuccess();

    expect(mediaAcks, isEmpty);
    expect(manager.activeInviteId, 'newer_call');
    expect(manager.debugSnapshot()['phase'], CallSessionPhase.connected.name);
    await manager.forceIdleForTest();
    await tester.pump();
  });

  testWidgets('late media ACK completion cannot transfer or mutate newer call',
      (tester) async {
    autoJoinSuccess = false;
    final ackEntered = Completer<void>();
    final releaseAck = Completer<bool>();
    manager.configure(
      acknowledgeNativeMediaOwnership: (id) async {
        mediaAcks.add(id);
        if (!ackEntered.isCompleted) ackEntered.complete();
        return releaseAck.future;
      },
    );
    await seedInvite('late_ack_call_a');
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );
    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: 'late_ack_call_a',
        channel: 'channel_late_ack_call_a',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => runtimes.isNotEmpty);
    final lateJoin = runtimes.single.fireJoinSuccess();
    await ackEntered.future.timeout(const Duration(seconds: 1));

    await manager.forceIdleForTest();
    configureManager();
    await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'late_ack_call_b',
      channel: 'channel_late_ack_call_b',
      acceptedCallkitId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      status: CallInviteStatus.connected,
      isCaller: false,
    );
    releaseAck.complete(true);
    await lateJoin;

    expect(mediaAcks, <String>[exactId]);
    expect(routeAcks, isEmpty);
    expect(manager.activeInviteId, 'late_ack_call_b');
    expect(manager.debugSnapshot()['phase'], CallSessionPhase.connected.name);
    expect(
      manager.debugSnapshot()['acceptedNativeWatchMediaOwned'],
      isFalse,
    );
    final callA =
        await firestore.collection('callInvites').doc('late_ack_call_a').get();
    expect(callA.data()?['calleeStage'], isNot('joined_local'));
    await manager.forceIdleForTest();
    await tester.pump();
  });

  testWidgets(
      'background accepted audio terminalizes before foreground and never restarts media',
      (tester) async {
    const inviteId = 'terminal_before_foreground';
    await seedInvite(inviteId);
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactId,
      inviteId: inviteId,
      channel: 'channel_terminal_before_foreground',
      accepted: true,
    ));
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );

    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: inviteId,
        channel: 'channel_terminal_before_foreground',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => mediaAcks.isNotEmpty);
    expect(
      manager.debugSnapshot()['acceptedNativeWatchMediaOwned'],
      isTrue,
    );

    await manager.endCallFromLocalUser(
      inviteId: inviteId,
      source: 'test_terminal_before_foreground',
      acceptedCallkitId: exactId,
    );

    expect(manager.debugSnapshot()['callLifecycleState'], 'idle');
    expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
    expect(manager.debugSnapshot()['sessionIdle'], isTrue);
    expect(readinessCancelCount, 1);
    expect(runtimes, hasLength(1));
    expect(runtimes.single.cleaned, isTrue);

    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    appForeground = true;
    final resumed = await manager.resumePendingAcceptedRouteIfReady(
      source: 'test_late_foreground_after_terminal',
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(resumed, AcceptedCallRecoveryResult.invalid);
    expect(routes, isEmpty);
    expect(runtimes, hasLength(1));
    expect(manager.debugSnapshot()['routeOpenCount'], 0);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 0);
  });

  testWidgets(
      'terminal during awaited foreground readiness cannot reopen the call',
      (tester) async {
    const inviteId = 'terminal_during_foreground_wait';
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite(inviteId);
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );
    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: inviteId,
        channel: 'channel_terminal_during_foreground_wait',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => mediaAcks.isNotEmpty);

    final readinessEntered = Completer<void>();
    final releaseReadiness = Completer<bool>();
    var foregroundChecks = 0;
    manager.configure(appForegroundProvider: () {
      foregroundChecks += 1;
      // resumePendingAcceptedRouteIfReady and _activateSession consume the
      // first two checks. Hold the third check inside _openCallScreen.
      if (foregroundChecks == 3) {
        readinessEntered.complete();
        return releaseReadiness.future;
      }
      return Future<bool>.value(true);
    });

    final resume = manager.resumePendingAcceptedRouteIfReady(
      source: 'test_terminal_during_wait',
    );
    await readinessEntered.future.timeout(const Duration(seconds: 1));
    await manager.endCallFromLocalUser(
      inviteId: inviteId,
      source: 'test_terminal_while_awaited',
      acceptedCallkitId: exactId,
    );
    releaseReadiness.complete(true);

    expect(
      await resume.timeout(const Duration(seconds: 1)),
      AcceptedCallRecoveryResult.invalid,
    );
    expect(routes, isEmpty);
    expect(runtimes, hasLength(1));
    expect(runtimes.single.cleaned, isTrue);
    expect(manager.debugSnapshot()['acceptedRoutePending'], isFalse);
    expect(manager.debugSnapshot()['sessionIdle'], isTrue);
  });

  testWidgets('late Call A readiness cannot mutate active Call B',
      (tester) async {
    const inviteA = 'late_continuation_call_a';
    const inviteB = 'active_call_b';
    const exactB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite(inviteA);
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );
    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: inviteA,
        channel: 'channel_late_continuation_call_a',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => mediaAcks.isNotEmpty);

    final readinessEntered = Completer<void>();
    final releaseReadiness = Completer<bool>();
    var foregroundChecks = 0;
    manager.configure(appForegroundProvider: () {
      foregroundChecks += 1;
      if (foregroundChecks == 2) {
        readinessEntered.complete();
        return releaseReadiness.future;
      }
      return Future<bool>.value(true);
    });
    final staleResume = manager.resumePendingAcceptedRouteIfReady(
      source: 'test_late_call_a',
    );
    await readinessEntered.future.timeout(const Duration(seconds: 1));

    await manager.endCallFromLocalUser(
      inviteId: inviteA,
      source: 'test_end_call_a',
      acceptedCallkitId: exactId,
    );
    final generationB = await manager.debugCreateHeldCallRouteForTest(
      inviteId: inviteB,
      channel: 'channel_active_call_b',
      acceptedCallkitId: exactB,
      status: CallInviteStatus.connected,
      isCaller: false,
    );
    releaseReadiness.complete(true);

    expect(
      await staleResume.timeout(const Duration(seconds: 1)),
      AcceptedCallRecoveryResult.invalid,
    );
    expect(manager.activeInviteId, inviteB);
    expect(manager.debugSnapshot()['lifecycleGeneration'], generationB);
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
    expect(manager.debugSnapshot()['phase'], CallSessionPhase.connected.name);
    expect(routes, isEmpty);
    expect(runtimes, hasLength(1));
  });

  testWidgets(
      'production push revalidates ownership after diagnostics before Navigator push',
      (tester) async {
    const inviteA = 'production_push_call_a';
    const inviteB = 'production_push_call_b';
    const exactB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    final pushBarrierEntered = Completer<void>();
    final releasePushBarrier = Completer<void>();
    final observer = _RoutePushObserver();

    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Background Callee',
    );
    configureManagerForProductionRoute(
      beforeProductionRoutePush: () async {
        if (!pushBarrierEntered.isCompleted) {
          pushBarrierEntered.complete();
        }
        await releasePushBarrier.future;
      },
    );
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[observer],
      home: const Scaffold(body: Text('home')),
    ));
    await tester.pump();
    final baselinePushes = observer.pushCount;

    await seedInvite(inviteA);
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );
    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: inviteA,
        channel: 'channel_production_push_call_a',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => mediaAcks.isNotEmpty);

    appForeground = true;
    final staleResume = manager.resumePendingAcceptedRouteIfReady(
      source: 'test_production_pre_push_race',
    );
    await pushBarrierEntered.future.timeout(const Duration(seconds: 1));

    await manager.endCallFromLocalUser(
      inviteId: inviteA,
      source: 'test_terminal_at_production_push_boundary',
      acceptedCallkitId: exactId,
    );
    await manager.handleCallScreenClosed(
      inviteA,
      acceptedCallkitId: exactId,
    );
    final generationB = await manager.debugCreateHeldCallRouteForTest(
      inviteId: inviteB,
      channel: 'channel_production_push_call_b',
      acceptedCallkitId: exactB,
      status: CallInviteStatus.connected,
      isCaller: false,
    );

    releasePushBarrier.complete();
    expect(
      await staleResume.timeout(const Duration(seconds: 1)),
      AcceptedCallRecoveryResult.invalid,
    );
    await tester.pump();

    expect(observer.pushCount, baselinePushes);
    expect(find.byType(AgoraCallScreen), findsNothing);
    expect(manager.activeInviteId, inviteB);
    expect(manager.debugSnapshot()['lifecycleGeneration'], generationB);
    expect(manager.debugSnapshot()['callRouteActive'], isTrue);
    expect(manager.debugSnapshot()['phase'], CallSessionPhase.connected.name);
    expect(manager.debugSnapshot()['routeOpenCount'], 0);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 0);
    expect(runtimes, hasLength(1));
    expect(runtimes.single.cleaned, isTrue);
  });

  testWidgets(
      'production manager-owned receiver route returns Home within two seconds after stale native reconciliation',
      (tester) async {
    const inviteId = 'production_fast_terminal_receiver';
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: calleeUid,
      currentDisplayName: 'Background Callee',
    );
    configureManagerForProductionRoute(
      beforeProductionRoutePush: () async {},
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_callkit_incoming'),
      (_) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter_callkit_incoming'),
        null,
      );
    });
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite(inviteId);
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactId,
      inviteId: inviteId,
      channel: 'channel_production_fast_terminal_receiver',
      accepted: true,
    ));
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );

    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: inviteId,
        channel: 'channel_$inviteId',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => mediaAcks.contains(exactId));

    appForeground = true;
    expect(
      await manager.resumePendingAcceptedRouteIfReady(
        source: 'test_fast_terminal_foreground',
      ),
      AcceptedCallRecoveryResult.opened,
    );
    await waitUntil(
      tester,
      () => find.byKey(const Key('call-v2-hangup')).evaluate().isNotEmpty,
    );
    expect(
      find.byKey(const Key('call-v2-managed-route-exit-scope')),
      findsOne,
    );
    expect(runtimes, hasLength(1));
    expect(runtimes.single.startCount, 1);
    expect(runtimes.single.joinCount, 1);

    await manager.reportRemoteJoined(
      inviteId: inviteId,
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

    // This is the exact manager call made by
    // NotificationService._resetStaleIncomingUiIfNeeded after iOS reports no
    // active native calls. The private service entry is Platform.isIOS-gated,
    // so the widget test verifies its production manager boundary directly.
    manager.clearStaleUiFlags();
    expect(manager.debugSnapshot()['callRouteOwnerMatchesCurrent'], isTrue);

    var elapsedMs = 0;
    bool routeDisposed() =>
        find.byType(AgoraCallScreen).evaluate().isEmpty &&
        find
            .byKey(const Key('call-v2-managed-route-exit-scope'))
            .evaluate()
            .isEmpty &&
        find.text('home').evaluate().isNotEmpty;
    while (!routeDisposed() && elapsedMs < 2000) {
      await tester.pump(const Duration(milliseconds: 16));
      elapsedMs += 16;
    }

    expect(elapsedMs, lessThanOrEqualTo(2000));
    expect(routeDisposed(), isTrue);
    expect(find.text('Call ended'), findsNothing);

    await waitUntil(
        tester, () => manager.debugSnapshot()['sessionIdle'] == true);
    expect(nativeCalls, isEmpty);
    expect(mediaOwner.hasOwner, isFalse);
    expect(runtimes.single.cleaned, isTrue);
    expect(manager.debugSnapshot()['callRouteActive'], isFalse);
    expect(manager.debugSnapshot()['routeOpenCount'], 1);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 1);

    await manager.reportRemoteOffline(
      inviteId: inviteId,
      wasConnected: true,
      isCaller: false,
      reason: 'late_remote_hangup',
    );
    manager.clearStaleUiFlags();
    for (var laterMs = 0; laterMs < 2000; laterMs += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(routeDisposed(), isTrue);
    expect(find.byType(AgoraCallScreen), findsNothing);
  });

  testWidgets(
      'foreground route attaches after headless join without second RTC',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    await seedInvite('attach_audio');
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactId,
      inviteId: 'attach_audio',
      channel: 'channel_attach_audio',
      accepted: true,
    ));
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );
    expect(
      await manager.handleRecoveredAcceptedInvite(
        inviteId: 'attach_audio',
        channel: 'channel_attach_audio',
        isVideo: false,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: exactId,
      ),
      AcceptedCallRecoveryResult.pendingNavigator,
    );
    await waitUntil(tester, () => mediaAcks.isNotEmpty);

    appForeground = true;
    final resumed = await manager.resumePendingAcceptedRouteIfReady(
      source: 'test_foreground',
    );
    await tester.pump();

    expect(resumed, AcceptedCallRecoveryResult.opened);
    expect(routes, <String>['attach_audio']);
    expect(routeAcks, <String>[exactId]);
    expect(mediaAcks, <String>[exactId]);
    expect(runtimes, hasLength(1));
    expect(runtimes.single.startCount, 1);
    expect(runtimes.single.joinCount, 1);
    expect(manager.debugSnapshot()['phase'], CallSessionPhase.joining.name);
    await manager.forceIdleForTest();
    await tester.pump();
  });

  testWidgets(
      'audio then audio then video stay single-owner across terminal cleanup',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));

    Future<void> runAcceptedCall({
      required String inviteId,
      required String callkitId,
      required bool isVideo,
    }) async {
      await seedInvite(inviteId, isVideo: isVideo);
      nativeCalls.add(NativeCallSnapshot(
        callkitId: callkitId,
        inviteId: inviteId,
        channel: 'channel_$inviteId',
        accepted: true,
      ));
      await manager.handleCallkitAudioSessionChanged(
        callkitId: callkitId,
        active: true,
      );
      appForeground = isVideo;
      final accepted = await manager.handleRecoveredAcceptedInvite(
        inviteId: inviteId,
        channel: 'channel_$inviteId',
        isVideo: isVideo,
        fromName: 'Background Caller',
        fromUid: callerUid,
        callkitId: callkitId,
      );
      if (isVideo) {
        expect(accepted, AcceptedCallRecoveryResult.opened);
      } else {
        expect(accepted, AcceptedCallRecoveryResult.pendingNavigator);
        await waitUntil(tester, () => mediaAcks.contains(callkitId));
        appForeground = true;
        expect(
          await manager.resumePendingAcceptedRouteIfReady(
            source: 'test_sequential_foreground',
          ),
          AcceptedCallRecoveryResult.opened,
        );
      }

      await manager.endCallFromLocalUser(
        inviteId: inviteId,
        source: 'test_sequential_end',
        acceptedCallkitId: callkitId,
      );
      await manager.handleCallScreenClosed(
        inviteId,
        acceptedCallkitId: callkitId,
      );
      expect(manager.debugSnapshot()['sessionIdle'], isTrue);
    }

    await runAcceptedCall(
      inviteId: 'sequential_audio_a',
      callkitId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
      isVideo: false,
    );
    await runAcceptedCall(
      inviteId: 'sequential_audio_b',
      callkitId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
      isVideo: false,
    );
    await runAcceptedCall(
      inviteId: 'sequential_video_c',
      callkitId: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
      isVideo: true,
    );

    expect(routes, <String>[
      'sequential_audio_a',
      'sequential_audio_b',
      'sequential_video_c',
    ]);
    expect(runtimes, hasLength(2));
    expect(runtimes.every((runtime) => runtime.startCount == 1), isTrue);
    expect(runtimes.every((runtime) => runtime.joinCount == 1), isTrue);
    expect(runtimes.every((runtime) => runtime.cleaned), isTrue);
    expect(manager.debugSnapshot()['routeOpenCount'], 3);
    expect(manager.debugSnapshot()['rtcSetupOwnerCount'], 3);
  });

  testWidgets(
      'audio screen attaches and detaches without cleaning shared media owner',
      (tester) async {
    await seedInvite('screen_attachment');
    final generation = await manager.debugCreateHeldCallRouteForTest(
      inviteId: 'screen_attachment',
      channel: 'channel_screen_attachment',
      acceptedCallkitId: exactId,
      status: CallInviteStatus.connected,
      isCaller: true,
    );
    final initialAttachment = await manager.attachOrStartRouteFirstAudio(
      inviteId: 'screen_attachment',
      channel: 'channel_screen_attachment',
      isCaller: true,
      acceptedCallkitId: exactId,
      lifecycleGeneration: generation,
      connectionSystem: CallV2RealCallConnectionSystem.legacyV1,
    );
    expect(initialAttachment, isNotNull);
    await waitUntil(tester, () => runtimes.isNotEmpty);
    initialAttachment!.detach();

    await tester.pumpWidget(MaterialApp(
      home: AgoraCallScreen(
        channelName: 'channel_screen_attachment',
        isVideo: false,
        otherUserName: 'Background Caller',
        inviteId: 'screen_attachment',
        acceptedCallkitId: exactId,
        lifecycleGeneration: generation,
        isCaller: true,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(runtimes, hasLength(1));
    expect(runtimes.single.startCount, 1);
    expect(runtimes.single.joinCount, 1);
    expect(runtimes.single.cleaned, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(runtimes.single.cleaned, isFalse);

    await manager.forceIdleForTest();
    await tester.pump();
    expect(runtimes.single.cleaned, isTrue);
  });

  testWidgets(
      'hangup starts exact audio teardown while Firestore terminal write waits',
      (tester) async {
    const inviteId = 'hangup_media_before_firestore';
    final transactionEntered = Completer<void>();
    final releaseTransaction = Completer<void>();
    final cleanupStarted = Completer<void>();
    final releaseCleanup = Completer<void>();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: callerUid,
      currentDisplayName: 'Background Caller',
    );
    mediaOwner = CallV2PhysicalMediaOwner(
      runtimeFactory: (config) {
        final runtime = _ManagerFakeMediaRuntime(
          config,
          autoJoinSuccess: true,
          cleanupStarted: cleanupStarted,
          cleanupRelease: releaseCleanup,
        );
        runtimes.add(runtime);
        return runtime;
      },
      microphonePermissionStatus: () async => true,
      microphonePermissionRequest: () async => true,
    );
    configureManager();
    manager.configure(beforeTerminalTransactionForTest: () async {
      if (!transactionEntered.isCompleted) transactionEntered.complete();
      await releaseTransaction.future;
    });
    await seedInvite(inviteId);
    await firestore.collection('callInvites').doc(inviteId).update({
      'status': CallInviteStatus.connected.name,
      'callerStage': CallInviteStatus.connected.name,
      'calleeStage': CallInviteStatus.connected.name,
    });
    final seededInvite =
        await firestore.collection('callInvites').doc(inviteId).get();
    expect(seededInvite.data()?['status'], CallInviteStatus.connected.name);
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactId,
      inviteId: inviteId,
      channel: 'channel_hangup_media_before_firestore',
      accepted: true,
    ));
    final generation = await manager.debugCreateHeldCallRouteForTest(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      acceptedCallkitId: exactId,
      status: CallInviteStatus.connected,
      isCaller: true,
    );
    final initialAttachment = await manager.attachOrStartRouteFirstAudio(
      inviteId: inviteId,
      channel: 'channel_$inviteId',
      isCaller: true,
      acceptedCallkitId: exactId,
      lifecycleGeneration: generation,
      connectionSystem: CallV2RealCallConnectionSystem.legacyV1,
    );
    expect(initialAttachment, isNotNull);
    await waitUntil(tester, () => runtimes.isNotEmpty);
    initialAttachment!.detach();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const Key('open-owned-audio'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => AgoraCallScreen(
                  channelName: 'channel_$inviteId',
                  isVideo: false,
                  otherUserName: 'Background Callee',
                  inviteId: inviteId,
                  acceptedCallkitId: exactId,
                  lifecycleGeneration: generation,
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
    ));
    await tester.tap(find.byKey(const Key('open-owned-audio')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    try {
      await tester.tap(find.byKey(const Key('call-v2-hangup')));
      await tester.pump();

      await transactionEntered.future;
      await cleanupStarted.future;
      await waitUntil(
        tester,
        () => find.byKey(const Key('call-v2-hangup')).evaluate().isEmpty,
      );

      expect(find.byKey(const Key('open-owned-audio')), findsOne);
      expect(releaseTransaction.isCompleted, isFalse);
      expect(releaseCleanup.isCompleted, isFalse);
      expect(runtimes.single.state.value.mediaActive, isFalse);
      expect(runtimes.single.cleaned, isFalse);
      expect(mediaOwner.hasOwner, isTrue);
      expect(nativeCalls, hasLength(1));
      expect(
        manager.debugSnapshot()['authoritativeTerminalWriteCount'],
        0,
      );

      releaseCleanup.complete();
      await waitUntil(tester, () => !mediaOwner.hasOwner);
      expect(runtimes.single.cleaned, isTrue);
      expect(releaseTransaction.isCompleted, isFalse);

      releaseTransaction.complete();
      await waitUntil(tester, () => nativeCalls.isEmpty);
      expect(manager.debugSnapshot()['phase'], CallSessionPhase.terminal.name);
    } finally {
      if (!releaseCleanup.isCompleted) releaseCleanup.complete();
      if (!releaseTransaction.isCompleted) releaseTransaction.complete();
    }
  });

  testWidgets('background accepted video remains route-first', (tester) async {
    await seedInvite('background_video', isVideo: true);
    nativeCalls.add(const NativeCallSnapshot(
      callkitId: exactId,
      inviteId: 'background_video',
      channel: 'channel_background_video',
      accepted: true,
    ));
    await manager.handleCallkitAudioSessionChanged(
      callkitId: exactId,
      active: true,
    );

    final result = await manager.handleRecoveredAcceptedInvite(
      inviteId: 'background_video',
      channel: 'channel_background_video',
      isVideo: true,
      fromName: 'Background Caller',
      fromUid: callerUid,
      callkitId: exactId,
    );

    expect(result, AcceptedCallRecoveryResult.pendingNavigator);
    expect(runtimes, isEmpty);
    expect(mediaOwner.hasOwner, isFalse);
    expect(mediaAcks, isEmpty);
    expect(routes, isEmpty);
    await manager.forceIdleForTest();
    await tester.pump();
  });
}

final class _RoutePushObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

class _ManagerFakeMediaRuntime implements CallV2PhysicalMediaRuntime {
  _ManagerFakeMediaRuntime(
    this.config, {
    required this.autoJoinSuccess,
    this.cleanupStarted,
    this.cleanupRelease,
  });

  final CallV2AgoraMediaRuntimeConfig config;
  final bool autoJoinSuccess;
  final Completer<void>? cleanupStarted;
  final Completer<void>? cleanupRelease;
  final ValueNotifier<CallV2AgoraMediaState> _state =
      ValueNotifier<CallV2AgoraMediaState>(
    const CallV2AgoraMediaState.idle(),
  );
  int startCount = 0;
  int joinCount = 0;
  bool cleaned = false;
  Future<void>? _cleanupFuture;

  @override
  RtcEngine? get engine => null;

  @override
  ValueListenable<CallV2AgoraMediaState> get state => _state;

  @override
  Future<void> start() async {
    startCount += 1;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.preparing,
    );
    await config.onMediaSetupBegan();
    if (cleaned) return;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.tokenReady,
    );
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.engineReady,
    );
    joinCount += 1;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.joining,
    );
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.joined,
      mediaActive: true,
    );
    if (autoJoinSuccess) await fireJoinSuccess();
  }

  Future<void> fireJoinSuccess() => config.onJoinSuccess();

  @override
  Future<void> cleanup() {
    return _cleanupFuture ??= _cleanup();
  }

  Future<void> _cleanup() async {
    if (!(cleanupStarted?.isCompleted ?? true)) {
      cleanupStarted!.complete();
    }
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.terminal,
      mediaActive: false,
    );
    final release = cleanupRelease;
    if (release != null) await release.future;
    cleaned = true;
  }

  @override
  Future<void> setMuted(bool muted) async {
    _state.value = _state.value.copyWith(muted: muted);
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    _state.value = _state.value.copyWith(speakerEnabled: enabled);
  }

  @override
  Future<void> switchCamera() async {}
}
