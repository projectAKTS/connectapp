// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtc_engine/src/impl/agora_rtc_engine_impl.dart'
    as agora_internal;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../diagnostics/call_v2_durable_boundary_diagnostics.dart';
import '../call_v2_api.dart';
import '../firebase/call_v2_dev_callable_target.dart';
import '../firebase/call_v2_token_provider.dart';
import '../firebase/real_call_v2_token_provider.dart';
import '../runtime/call_v2_runtime_state.dart';
import '../../services/helperly_test_runtime.dart';
import 'call_v2_engine_cleanup_coordinator.dart';
import 'call_v2_real_call_flow_gate.dart';

const String _agoraFallbackAppId = 'dac900a04a87460c87c3d18b63cac65d';
const String _agoraFlutterPluginVersion = '6.5.2';
const int _agoraLogFileSizeInKB = 512;
const Duration _engineInitializeTimeout = Duration(seconds: 30);
const Duration _joinWatchdogTimeout = Duration(seconds: 35);

/// The one process gate used by route-first and headless physical media.
final CallV2ProcessEngineCleanupGate callV2PhysicalEngineCleanupGate =
    CallV2ProcessEngineCleanupGate();

class AgoraJoinAuth {
  const AgoraJoinAuth({
    required this.token,
    required this.appId,
    required this.channelName,
    required this.uid,
    required this.userAccount,
    required this.tokenVersion,
    required this.identityMode,
  });

  final String token;
  final String appId;
  final String channelName;
  final int uid;
  final String userAccount;
  final String tokenVersion;
  final String identityMode;
}

Future<AgoraJoinAuth> fetchAgoraToken({
  required String channelName,
  required int uid,
  required String userAccount,
  String identityMode = 'uid',
  bool allowUidZero = false,
}) async {
  final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
      .httpsCallable('getAgoraRtcToken');
  final response = await callable.call(<String, Object?>{
    'channelName': channelName,
    'uid': uid,
    'userAccount': userAccount,
    'identityMode': identityMode,
    'allowUidZero': allowUidZero,
    'role': 'publisher',
    'expireSeconds': 3600,
  });
  final data = (response.data as Map?) ?? const <Object?, Object?>{};
  final token = (data['token'] as String?)?.trim();
  final serverAppId = (data['appId'] as String?)?.trim();
  final serverUidRaw = data['uid'];
  final serverUserAccount = (data['userAccount'] as String?)?.trim();
  final tokenVersion = (data['tokenVersion'] as String?)?.trim() ?? '';
  final tokenIdentityMode =
      (data['tokenIdentityMode'] as String?)?.trim() ?? identityMode;
  final serverUid = serverUidRaw is num ? serverUidRaw.toInt() : uid;
  if (token == null || token.isEmpty) {
    throw StateError('Token service returned no access material.');
  }
  return AgoraJoinAuth(
    token: token,
    appId: (serverAppId == null || serverAppId.isEmpty)
        ? _agoraFallbackAppId
        : serverAppId,
    channelName: channelName,
    uid: serverUid,
    userAccount: (serverUserAccount == null || serverUserAccount.isEmpty)
        ? userAccount
        : serverUserAccount,
    tokenVersion: tokenVersion.isNotEmpty
        ? tokenVersion
        : (token.length >= 3 ? token.substring(0, 3) : token),
    identityMode: tokenIdentityMode,
  );
}

Future<AgoraJoinAuth> fetchCallV2DevAgoraToken({
  required String callIdentifier,
  required String participantIdentifier,
  required bool isVideo,
  CallV2DevCallableTarget devCallableTarget =
      const FirebaseCallV2DevCallableTarget(),
}) async {
  final transport = await devCallableTarget.createTransport();
  final provider = RealCallV2TokenProvider(
    allowRequests: true,
    transport: transport,
    defaultRequest: CallV2TokenBackendRequest(
      callId: callIdentifier,
      localParticipantUid: participantIdentifier,
    ),
  );
  final result = await provider.resolveToken(
    CallV2TokenRequest(
      mode: isVideo ? CallV2RuntimeCallMode.video : CallV2RuntimeCallMode.audio,
    ),
  );
  return AgoraJoinAuth(
    token: result.token,
    appId: result.appId,
    channelName: result.channelAlias,
    uid: result.rtcUid,
    userAccount: result.rtcUid.toString(),
    tokenVersion: 'v2',
    identityMode: 'uid',
  );
}

enum CallV2AgoraMediaPhase {
  idle,
  preparing,
  tokenReady,
  engineReady,
  joining,
  joined,
  terminal,
  failed,
}

@immutable
class CallV2AgoraMediaState {
  const CallV2AgoraMediaState({
    required this.phase,
    required this.muted,
    required this.speakerEnabled,
    required this.remoteParticipantPresent,
    required this.remoteUid,
    required this.mediaActive,
    required this.failureCode,
  });

  const CallV2AgoraMediaState.idle()
      : phase = CallV2AgoraMediaPhase.idle,
        muted = false,
        speakerEnabled = true,
        remoteParticipantPresent = false,
        remoteUid = null,
        mediaActive = false,
        failureCode = 'none';

  final CallV2AgoraMediaPhase phase;
  final bool muted;
  final bool speakerEnabled;
  final bool remoteParticipantPresent;
  final int? remoteUid;
  final bool mediaActive;
  final String failureCode;

  bool get joined => phase == CallV2AgoraMediaPhase.joined;
  bool get terminal => phase == CallV2AgoraMediaPhase.terminal;

  CallV2AgoraMediaState copyWith({
    CallV2AgoraMediaPhase? phase,
    bool? muted,
    bool? speakerEnabled,
    bool? remoteParticipantPresent,
    int? remoteUid,
    bool clearRemoteUid = false,
    bool? mediaActive,
    String? failureCode,
  }) {
    return CallV2AgoraMediaState(
      phase: phase ?? this.phase,
      muted: muted ?? this.muted,
      speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      remoteParticipantPresent:
          remoteParticipantPresent ?? this.remoteParticipantPresent,
      remoteUid: clearRemoteUid ? null : remoteUid ?? this.remoteUid,
      mediaActive: mediaActive ?? this.mediaActive,
      failureCode: failureCode ?? this.failureCode,
    );
  }
}

typedef CallV2AgoraDiagnostic = Future<void> Function(
  String stage,
  Map<String, Object?> metadata,
);

class CallV2AgoraMediaRuntimeConfig {
  const CallV2AgoraMediaRuntimeConfig({
    required this.channel,
    required this.inviteId,
    required this.isVideo,
    required this.isCaller,
    required this.connectionSystem,
    required this.onMediaSetupBegan,
    required this.onJoinSuccess,
    required this.onRemoteJoined,
    required this.onRemoteOffline,
    required this.onJoinTimeout,
    required this.onFailure,
    required this.diagnostic,
    this.onLocalConnectionState,
    this.onRemoteAudioFrozen,
  });

  final String channel;
  final String inviteId;
  final bool isVideo;
  final bool isCaller;
  final CallV2RealCallConnectionSystem connectionSystem;
  final Future<void> Function() onMediaSetupBegan;
  final Future<void> Function() onJoinSuccess;
  final Future<void> Function() onRemoteJoined;
  final Future<void> Function(bool wasConnected, String reason) onRemoteOffline;
  final Future<void> Function() onJoinTimeout;
  final Future<void> Function(String code) onFailure;
  final CallV2AgoraDiagnostic diagnostic;

  /// `true` while Agora is reconnecting the local connection.
  final void Function(bool reconnecting)? onLocalConnectionState;

  /// `true` while the remote audio is frozen (no packets arriving).
  final void Function(bool frozen)? onRemoteAudioFrozen;
}

abstract interface class CallV2PhysicalMediaRuntime {
  ValueListenable<CallV2AgoraMediaState> get state;
  RtcEngine? get engine;
  Future<void> start();
  Future<void> setMuted(bool muted);
  Future<void> setSpeakerEnabled(bool enabled);
  Future<void> switchCamera();
  Future<void> cleanup();
}

typedef CallV2PhysicalMediaRuntimeFactory = CallV2PhysicalMediaRuntime Function(
  CallV2AgoraMediaRuntimeConfig config,
);

class CallV2AgoraMediaRuntime implements CallV2PhysicalMediaRuntime {
  CallV2AgoraMediaRuntime(this.config);

  final CallV2AgoraMediaRuntimeConfig config;
  final ValueNotifier<CallV2AgoraMediaState> _state =
      ValueNotifier<CallV2AgoraMediaState>(
    const CallV2AgoraMediaState.idle(),
  );

  static int _nextEngineGeneration = 0;

  RtcEngine? _engine;
  RtcEngineEventHandler? _handler;
  int _engineGeneration = 0;
  int _epoch = 0;
  bool _acceptCallbacks = false;
  bool _remoteEverJoined = false;
  bool _failureReported = false;
  Future<void>? _startFuture;
  Future<void>? _cleanupFuture;
  Timer? _joinWatchdog;

  @override
  ValueListenable<CallV2AgoraMediaState> get state => _state;

  @override
  RtcEngine? get engine => _engine;

  @override
  Future<void> start() {
    final existing = _startFuture;
    if (existing != null) return existing;
    final epoch = ++_epoch;
    final future = _start(epoch);
    _startFuture = future;
    return future;
  }

  Future<void> _start(int epoch) async {
    try {
      CallV2DurableDiagnosticRecorder.instance.record(
        CallV2DurableDiagnosticStage.mediaRuntimeStarted,
        inviteIdentity: config.inviteId,
      );
      _emit(_state.value.copyWith(phase: CallV2AgoraMediaPhase.preparing));
      CallV2DurableDiagnosticRecorder.instance.record(
        CallV2DurableDiagnosticStage.cleanupGateRequested,
        inviteIdentity: config.inviteId,
      );
      final readiness =
          await callV2PhysicalEngineCleanupGate.prepareNextEngine();
      _ensureCurrent(epoch);
      if (!readiness.nextEngineAllowed) {
        CallV2DurableDiagnosticRecorder.instance.record(
          CallV2DurableDiagnosticStage.cleanupGateBlocked,
          inviteIdentity: config.inviteId,
          outcome: CallV2DurableDiagnosticOutcome.blocked,
        );
        throw StateError(readiness.blockerCode);
      }
      CallV2DurableDiagnosticRecorder.instance.record(
        CallV2DurableDiagnosticStage.cleanupGatePermitted,
        inviteIdentity: config.inviteId,
        outcome: CallV2DurableDiagnosticOutcome.allowed,
      );
      await config.onMediaSetupBegan();
      _ensureCurrent(epoch);

      final firebaseUid = HelperlyTestRuntime.currentUid ??
          FirebaseAuth.instance.currentUser?.uid ??
          '';
      final requestedUid = _deriveRtcUid(firebaseUid);
      final requestedAccount = requestedUid.toString();
      CallV2DurableDiagnosticRecorder.instance.record(
        CallV2DurableDiagnosticStage.tokenRequestStarted,
        inviteIdentity: config.inviteId,
      );
      final auth =
          config.connectionSystem == CallV2RealCallConnectionSystem.callV2Dev
              ? await fetchCallV2DevAgoraToken(
                  callIdentifier: config.inviteId.isNotEmpty
                      ? config.inviteId
                      : config.channel,
                  participantIdentifier:
                      firebaseUid.isNotEmpty ? firebaseUid : requestedAccount,
                  isVideo: config.isVideo,
                )
              : await fetchAgoraToken(
                  channelName: config.channel,
                  uid: requestedUid,
                  userAccount: requestedAccount,
                );
      _ensureCurrent(epoch);
      _emit(_state.value.copyWith(phase: CallV2AgoraMediaPhase.tokenReady));
      await _diag('token_ok', <String, Object?>{
        'callV2Selected':
            config.connectionSystem == CallV2RealCallConnectionSystem.callV2Dev,
        'tokenIdentityMode': auth.identityMode,
        'tokenVersion': auth.tokenVersion,
      });

      final created = await _createAndInitializeEngine(
        appId: auth.appId,
        epoch: epoch,
      );
      _ensureCurrent(epoch);
      await created.enableAudio();
      await created.enableLocalAudio(true);
      await created.muteLocalAudioStream(false);
      await created.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioDefault,
      );
      await created.disableVideo();
      await created.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );
      await created.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );
      await created.setDefaultAudioRouteToSpeakerphone(true);
      _ensureCurrent(epoch);
      _emit(_state.value.copyWith(phase: CallV2AgoraMediaPhase.engineReady));

      final generation = _engineGeneration;
      final handler = _buildHandler(created, generation);
      _handler = handler;
      created.registerEventHandler(handler);
      _ensureCurrent(epoch);
      _emit(_state.value.copyWith(phase: CallV2AgoraMediaPhase.joining));
      await _diag('join_attempt', const <String, Object?>{
        'joinMode': 'numeric',
        'publishMicrophoneTrack': true,
        'publishCameraTrack': false,
      });
      await created.joinChannel(
        token: auth.token,
        channelId: auth.channelName,
        uid: auth.uid > 0 ? auth.uid : requestedUid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: false,
          enableAudioRecordingOrPlayout: true,
        ),
      );
      _ensureCurrent(epoch);
      _joinWatchdog = Timer(_joinWatchdogTimeout, () {
        if (!_accepts(generation) || _state.value.joined) return;
        unawaited(config.onJoinTimeout());
      });
      await _diag('begin_done', const <String, Object?>{});
    } catch (error) {
      if (!_isCurrent(epoch)) return;
      _emit(_state.value.copyWith(
        phase: CallV2AgoraMediaPhase.failed,
        failureCode: _safeFailureCode(error),
      ));
      await _reportFailureOnce(_safeFailureCode(error));
      await cleanup();
    }
  }

  RtcEngineEventHandler _buildHandler(RtcEngine ownedEngine, int generation) {
    return RtcEngineEventHandler(
      onError: (error, message) {
        if (!_accepts(generation)) return;
        unawaited(_diag('agora_error', <String, Object?>{
          'errorCategory': error.toString(),
        }));
        unawaited(_reportFailureOnce('agora_error'));
      },
      onConnectionStateChanged: (connection, state, reason) {
        if (!_accepts(generation)) return;
        unawaited(_diag('conn_state_changed', <String, Object?>{
          'state': state.toString(),
          'reason': reason.toString(),
        }));
        if (state == ConnectionStateType.connectionStateReconnecting ||
            state == ConnectionStateType.connectionStateConnected) {
          config.onLocalConnectionState?.call(
            state == ConnectionStateType.connectionStateReconnecting,
          );
        }
      },
      onRemoteAudioStateChanged:
          (connection, remoteUid, state, reason, elapsed) {
        if (!_accepts(generation)) return;
        _emit(_state.value.copyWith(
          mediaActive: state == RemoteAudioState.remoteAudioStateDecoding,
          failureCode: state == RemoteAudioState.remoteAudioStateFailed
              ? 'remote_audio_failed'
              : _state.value.failureCode,
        ));
        unawaited(_diag('remote_audio_state', <String, Object?>{
          'state': state.toString(),
          'reason': reason.toString(),
        }));
        config.onRemoteAudioFrozen?.call(
          state == RemoteAudioState.remoteAudioStateFrozen,
        );
      },
      onJoinChannelSuccess: (connection, elapsed) {
        if (!_accepts(generation)) return;
        _joinWatchdog?.cancel();
        _emit(_state.value.copyWith(phase: CallV2AgoraMediaPhase.joined));
        CallV2DurableDiagnosticRecorder.instance.record(
          CallV2DurableDiagnosticStage.agoraJoinCallbackReceived,
          inviteIdentity: config.inviteId,
          outcome: CallV2DurableDiagnosticOutcome.completed,
        );
        unawaited(_diag('join_success', <String, Object?>{
          'elapsedMs': elapsed,
        }));
        unawaited(config.onJoinSuccess());
      },
      onUserJoined: (connection, uid, elapsed) {
        if (!_accepts(generation)) return;
        _remoteEverJoined = true;
        _emit(_state.value.copyWith(
          remoteParticipantPresent: true,
          remoteUid: uid,
          mediaActive: true,
        ));
        unawaited(config.onRemoteJoined());
      },
      onUserOffline: (connection, uid, reason) {
        if (!_accepts(generation)) return;
        final wasConnected = _remoteEverJoined || _state.value.joined;
        _emit(_state.value.copyWith(
          remoteParticipantPresent: false,
          clearRemoteUid: true,
          mediaActive: false,
        ));
        unawaited(config.onRemoteOffline(wasConnected, reason.toString()));
      },
      onLeaveChannel: (connection, stats) {
        if (!_accepts(generation)) return;
        _joinWatchdog?.cancel();
        _emit(_state.value.copyWith(
          phase: CallV2AgoraMediaPhase.terminal,
          remoteParticipantPresent: false,
          clearRemoteUid: true,
          mediaActive: false,
        ));
      },
    );
  }

  Future<RtcEngine> _createAndInitializeEngine({
    required String appId,
    required int epoch,
    int attempt = 1,
  }) async {
    _ensureCurrent(epoch);
    final engine = createAgoraRtcEngine();
    _engine = engine;
    _engineGeneration = ++_nextEngineGeneration;
    _acceptCallbacks = true;
    String? logPath;
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/agora_logs');
      await directory.create(recursive: true);
      logPath = '${directory.path}/call_v2_audio_attempt_$attempt.log';
    } catch (_) {}
    try {
      await engine
          .initialize(RtcEngineContext(
            appId: appId,
            channelProfile: ChannelProfileType.channelProfileCommunication,
            audioScenario: AudioScenarioType.audioScenarioDefault,
            autoRegisterAgoraExtensions: false,
            logConfig: LogConfig(
              filePath: logPath,
              fileSizeInKB: _agoraLogFileSizeInKB,
              level: LogLevel.logLevelInfo,
            ),
          ))
          .timeout(_engineInitializeTimeout);
      _ensureCurrent(epoch);
      await _diag('engine_initialized', <String, Object?>{
        'attempt': attempt,
        'agoraFlutterPluginVersion': _agoraFlutterPluginVersion,
      });
      return engine;
    } catch (error) {
      await _forceDispose(engine);
      if (identical(_engine, engine)) _engine = null;
      if (attempt < 2 && _isCurrent(epoch)) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        return _createAndInitializeEngine(
          appId: appId,
          epoch: epoch,
          attempt: attempt + 1,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
    _emit(_state.value.copyWith(muted: muted));
  }

  @override
  Future<void> setSpeakerEnabled(bool enabled) async {
    await _engine?.setEnableSpeakerphone(enabled);
    _emit(_state.value.copyWith(speakerEnabled: enabled));
  }

  @override
  Future<void> switchCamera() async {
    if (!config.isVideo) return;
    await _engine?.switchCamera();
  }

  @override
  Future<void> cleanup() {
    final existing = _cleanupFuture;
    if (existing != null) return existing;
    final future = _cleanup();
    _cleanupFuture = future;
    return future;
  }

  Future<void> _cleanup() async {
    CallV2DurableDiagnosticRecorder.instance.record(
      CallV2DurableDiagnosticStage.mediaCleanupStarted,
      inviteIdentity: config.inviteId,
    );
    _epoch += 1;
    _acceptCallbacks = false;
    _joinWatchdog?.cancel();
    _joinWatchdog = null;
    final ownedEngine = _engine;
    final ownedHandler = _handler;
    final generation = _engineGeneration;
    if (ownedEngine == null) {
      _emit(_state.value.copyWith(phase: CallV2AgoraMediaPhase.terminal));
      CallV2DurableDiagnosticRecorder.instance.record(
        CallV2DurableDiagnosticStage.mediaCleanupCompleted,
        inviteIdentity: config.inviteId,
        outcome: CallV2DurableDiagnosticOutcome.completed,
      );
      return;
    }
    bool stillOwns() =>
        identical(_engine, ownedEngine) && _engineGeneration == generation;
    final result = await callV2PhysicalEngineCleanupGate.cleanup(
      CallV2EngineCleanupOperations(
        generation: generation,
        release: true,
        invalidateGeneration: () {
          _acceptCallbacks = false;
        },
        unregisterHandler: () async {
          if (ownedHandler != null) {
            ownedEngine.unregisterEventHandler(ownedHandler);
          }
          if (stillOwns()) _handler = null;
        },
        leaveChannel: () async {
          await ownedEngine.leaveChannel();
        },
        releaseEngine: () async {
          await ownedEngine.release(sync: true);
        },
        forceDispose: () => _forceDispose(ownedEngine),
      ),
    );
    if (stillOwns() && result.succeeded) {
      _engine = null;
      _handler = null;
    }
    _emit(_state.value.copyWith(
      phase: result.succeeded
          ? CallV2AgoraMediaPhase.terminal
          : CallV2AgoraMediaPhase.failed,
      remoteParticipantPresent: false,
      clearRemoteUid: true,
      mediaActive: false,
      failureCode: result.succeeded ? 'none' : 'cleanup_failed',
    ));
    CallV2DurableDiagnosticRecorder.instance.record(
      CallV2DurableDiagnosticStage.mediaCleanupCompleted,
      inviteIdentity: config.inviteId,
      outcome: result.succeeded
          ? CallV2DurableDiagnosticOutcome.completed
          : CallV2DurableDiagnosticOutcome.nonRecoverableFailure,
    );
  }

  Future<bool> _forceDispose(RtcEngine engine) async {
    try {
      await agora_internal.RtcEngineExt(engine)
          .irisMethodChannel
          .dispose()
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isCurrent(int epoch) => epoch == _epoch;

  void _ensureCurrent(int epoch) {
    if (!_isCurrent(epoch)) throw const _StaleMediaRuntime();
  }

  bool _accepts(int generation) =>
      _acceptCallbacks && generation == _engineGeneration;

  void _emit(CallV2AgoraMediaState next) {
    if (_state.value == next) return;
    _state.value = next;
  }

  Future<void> _reportFailureOnce(String code) async {
    if (_failureReported) return;
    _failureReported = true;
    await config.onFailure(code);
  }

  Future<void> _diag(String stage, Map<String, Object?> metadata) {
    return config.diagnostic(stage, metadata);
  }

  int _deriveRtcUid(String value) {
    if (value.isEmpty) return 1;
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return ((hash & 0x7FFFFFFF) % 2147483646) + 1;
  }

  String _safeFailureCode(Object error) {
    if (error is TimeoutException) return 'timeout';
    if (error is CallV2ClientError) return error.code.name;
    if (error is _StaleMediaRuntime) return 'superseded';
    return 'setup_failed';
  }
}

final class _StaleMediaRuntime implements Exception {
  const _StaleMediaRuntime();
}
