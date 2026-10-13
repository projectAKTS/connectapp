import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/real_flow/call_v2_agora_media_runtime.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_physical_media_owner.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_real_call_flow_gate.dart';

void main() {
  const exactA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const exactB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  late List<_FakeMediaRuntime> runtimes;
  late List<String> terminalReasons;
  late int permissionStatusCount;
  late int permissionRequestCount;
  late bool permissionGranted;
  late Completer<void>? startGate;
  late CallV2PhysicalMediaOwner owner;

  CallV2PhysicalMediaKey key({
    String inviteId = 'invite_a',
    String callkitId = exactA,
    int generation = 1,
    bool isCaller = false,
  }) {
    return CallV2PhysicalMediaKey(
      inviteId: inviteId,
      acceptedCallkitId: callkitId,
      lifecycleGeneration: generation,
      channel: 'channel_$inviteId',
      isVideo: false,
      isCaller: isCaller,
      connectionSystem: CallV2RealCallConnectionSystem.callV2Dev,
    );
  }

  CallV2PhysicalMediaClaim claim(
    CallV2PhysicalMediaKey mediaKey, {
    bool authorityReady = true,
    bool requiresExactAudioSession = true,
    bool allowPermissionRequest = false,
  }) {
    return CallV2PhysicalMediaClaim(
      key: mediaKey,
      authorityReady: authorityReady,
      requiresExactAudioSession: requiresExactAudioSession,
      allowPermissionRequest: allowPermissionRequest,
      runtimeConfig: CallV2AgoraMediaRuntimeConfig(
        channel: mediaKey.channel,
        inviteId: mediaKey.inviteId,
        isVideo: false,
        isCaller: mediaKey.isCaller,
        connectionSystem: mediaKey.connectionSystem,
        onMediaSetupBegan: () async {},
        onJoinSuccess: () async {},
        onRemoteJoined: () async {},
        onRemoteOffline: (_, __) async {},
        onJoinTimeout: () async {},
        onFailure: (_) async {},
        diagnostic: (_, __) async {},
      ),
      onPermissionUnavailable: (reason) async {
        terminalReasons.add(reason);
      },
      onEndRequested: () async {},
    );
  }

  Future<void> flush() async {
    for (var i = 0; i < 6; i += 1) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    runtimes = <_FakeMediaRuntime>[];
    terminalReasons = <String>[];
    permissionStatusCount = 0;
    permissionRequestCount = 0;
    permissionGranted = true;
    startGate = null;
    owner = CallV2PhysicalMediaOwner(
      runtimeFactory: (config) {
        final runtime = _FakeMediaRuntime(config, startGate: startGate);
        runtimes.add(runtime);
        return runtime;
      },
      microphonePermissionStatus: () async {
        permissionStatusCount += 1;
        return permissionGranted;
      },
      microphonePermissionRequest: () async {
        permissionRequestCount += 1;
        return permissionGranted;
      },
    );
  });

  tearDown(() async {
    await owner.resetForTest();
  });

  test('activation before authority converges to one physical media start',
      () async {
    final mediaKey = key();
    expect(owner.markAudioSessionReady(exactA), isFalse);
    owner.claim(claim(mediaKey, authorityReady: false));
    await flush();
    expect(runtimes, isEmpty);

    owner.claim(claim(mediaKey));
    await flush();

    expect(runtimes, hasLength(1));
    expect(runtimes.single.startCount, 1);
    expect(permissionStatusCount, 1);
    expect(owner.hasOwner, isTrue);
  });

  test('authority before activation waits then starts once', () async {
    final mediaKey = key();
    owner.claim(claim(mediaKey));
    await flush();
    expect(runtimes, isEmpty);

    expect(owner.markAudioSessionReady(exactA), isTrue);
    expect(owner.markAudioSessionReady(exactA), isTrue);
    await flush();

    expect(runtimes, hasLength(1));
    expect(runtimes.single.startCount, 1);
  });

  test('duplicate claims and activation keep one token engine and join owner',
      () async {
    final mediaKey = key();
    owner.markAudioSessionReady(exactA);
    final first = owner.claim(claim(mediaKey));
    final second = owner.claim(claim(mediaKey));
    owner.markAudioSessionReady(exactA);
    await flush();

    expect(first.key.matches(second.key), isTrue);
    expect(runtimes, hasLength(1));
    expect(runtimes.single.startCount, 1);
    expect(runtimes.single.tokenCount, 1);
    expect(runtimes.single.engineCount, 1);
    expect(runtimes.single.joinCount, 1);
  });

  test('foreground attachment during token wait reuses in-flight runtime',
      () async {
    startGate = Completer<void>();
    final mediaKey = key();
    owner.markAudioSessionReady(exactA);
    final background = owner.claim(claim(mediaKey));
    await flush();
    expect(runtimes, hasLength(1));
    expect(runtimes.single.tokenCount, 1);

    final foreground = owner.attach(mediaKey);
    expect(foreground, isNotNull);
    expect(foreground!.key.matches(background.key), isTrue);
    expect(runtimes, hasLength(1));

    startGate!.complete();
    await flush();
    expect(runtimes.single.engineCount, 1);
    expect(runtimes.single.joinCount, 1);
  });

  test('detaching screen observation does not clean lifecycle-owned media',
      () async {
    final mediaKey = key();
    owner.markAudioSessionReady(exactA);
    owner.claim(claim(mediaKey));
    await flush();
    final attachment = owner.attach(mediaKey)!;

    attachment.detach();
    await flush();

    expect(owner.hasOwner, isTrue);
    expect(runtimes.single.cleanupCount, 0);
    await owner.terminate(mediaKey, reason: 'managed_terminal');
    expect(runtimes.single.cleanupCount, 1);
    expect(owner.hasOwner, isFalse);
  });

  test('background permission denial never prompts or creates runtime',
      () async {
    permissionGranted = false;
    final mediaKey = key();
    owner.markAudioSessionReady(exactA);
    owner.claim(claim(mediaKey));
    await flush();

    expect(permissionStatusCount, 1);
    expect(permissionRequestCount, 0);
    expect(runtimes, isEmpty);
    expect(
      terminalReasons,
      <String>['background_microphone_permission_unavailable'],
    );
  });

  test('terminal before readiness prevents startup', () async {
    final mediaKey = key();
    owner.claim(claim(mediaKey));
    await owner.terminate(mediaKey, reason: 'remote_terminal');
    owner.markAudioSessionReady(exactA);
    await flush();

    expect(runtimes, isEmpty);
    expect(owner.hasOwner, isFalse);
  });

  test('terminal during token wait prevents late engine and join', () async {
    startGate = Completer<void>();
    final mediaKey = key();
    owner.markAudioSessionReady(exactA);
    owner.claim(claim(mediaKey));
    await flush();
    expect(runtimes.single.tokenCount, 1);

    final terminal = owner.terminate(mediaKey, reason: 'remote_terminal');
    startGate!.complete();
    await terminal;
    await flush();

    expect(runtimes.single.engineCount, 0);
    expect(runtimes.single.joinCount, 0);
    expect(runtimes.single.cleanupCount, 1);
    expect(owner.hasOwner, isFalse);
  });

  test('late A attachment and cleanup cannot affect exact B owner', () async {
    final keyA = key();
    owner.markAudioSessionReady(exactA);
    final attachmentA = owner.claim(claim(keyA));
    await flush();
    await owner.terminate(keyA, reason: 'a_terminal');

    final keyB = key(
      inviteId: 'invite_b',
      callkitId: exactB,
      generation: 2,
    );
    owner.markAudioSessionReady(exactB);
    owner.claim(claim(keyB));
    await flush();
    attachmentA.detach();
    await owner.terminate(keyA, reason: 'late_a_cleanup');

    expect(owner.activeKey?.matches(keyB), isTrue);
    expect(runtimes, hasLength(2));
    expect(runtimes[1].cleanupCount, 0);
  });

  test('route-first outgoing audio starts only after explicit route claim',
      () async {
    final outgoingKey = key(
      inviteId: 'outgoing',
      callkitId: '',
      isCaller: true,
    );
    await flush();
    expect(runtimes, isEmpty);

    owner.claim(claim(
      outgoingKey,
      requiresExactAudioSession: false,
      allowPermissionRequest: true,
    ));
    await flush();

    expect(runtimes, hasLength(1));
    expect(runtimes.single.joinCount, 1);
  });

  test('audio A then audio B keeps one process owner at a time', () async {
    final keyA = key();
    owner.markAudioSessionReady(exactA);
    owner.claim(claim(keyA));
    await flush();
    await owner.terminate(keyA, reason: 'a_terminal');

    final keyB = key(
      inviteId: 'invite_b',
      callkitId: exactB,
      generation: 2,
    );
    owner.markAudioSessionReady(exactB);
    owner.claim(claim(keyB));
    await flush();

    expect(runtimes, hasLength(2));
    expect(runtimes[0].cleanupCount, 1);
    expect(runtimes[1].startCount, 1);
    expect(owner.activeKey?.matches(keyB), isTrue);
  });
}

class _FakeMediaRuntime implements CallV2PhysicalMediaRuntime {
  _FakeMediaRuntime(this.config, {this.startGate});

  final CallV2AgoraMediaRuntimeConfig config;
  final Completer<void>? startGate;
  final ValueNotifier<CallV2AgoraMediaState> _state =
      ValueNotifier<CallV2AgoraMediaState>(
    const CallV2AgoraMediaState.idle(),
  );

  int startCount = 0;
  int tokenCount = 0;
  int engineCount = 0;
  int joinCount = 0;
  int cleanupCount = 0;
  bool _cleaned = false;

  @override
  RtcEngine? get engine => null;

  @override
  ValueListenable<CallV2AgoraMediaState> get state => _state;

  @override
  Future<void> start() async {
    startCount += 1;
    tokenCount += 1;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.preparing,
    );
    if (startGate != null) await startGate!.future;
    if (_cleaned) return;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.tokenReady,
    );
    engineCount += 1;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.engineReady,
    );
    joinCount += 1;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.joined,
    );
  }

  @override
  Future<void> cleanup() async {
    if (_cleaned) return;
    _cleaned = true;
    cleanupCount += 1;
    _state.value = _state.value.copyWith(
      phase: CallV2AgoraMediaPhase.terminal,
      mediaActive: false,
      remoteParticipantPresent: false,
      clearRemoteUid: true,
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
