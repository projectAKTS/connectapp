import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

class _ManagerFakeMediaRuntime implements CallV2PhysicalMediaRuntime {
  _ManagerFakeMediaRuntime(
    this.config, {
    required this.autoJoinSuccess,
  });

  final CallV2AgoraMediaRuntimeConfig config;
  final bool autoJoinSuccess;
  final ValueNotifier<CallV2AgoraMediaState> _state =
      ValueNotifier<CallV2AgoraMediaState>(
    const CallV2AgoraMediaState.idle(),
  );
  int startCount = 0;
  int joinCount = 0;
  bool cleaned = false;

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
  Future<void> cleanup() async {
    if (cleaned) return;
    cleaned = true;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.terminal,
      mediaActive: false,
    );
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
