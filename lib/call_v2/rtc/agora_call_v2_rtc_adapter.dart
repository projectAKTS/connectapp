import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../call_v2_api.dart';
import '../call_v2_feature_gate.dart';
import 'call_v2_rtc_adapter.dart';
import 'internal_call_v2_rtc_adapter_gate.dart';

class AgoraCallV2RtcAdapterGate {
  const AgoraCallV2RtcAdapterGate({
    required this.featureGate,
    this.internalGate = const InternalCallV2RtcAdapterGate(),
  });

  final CallV2FeatureGate featureGate;
  final InternalCallV2RtcAdapterGate internalGate;

  bool get allowsConstruction {
    return featureGate.enabled && internalGate.canConstructAdapter;
  }

  bool get allowsInitialization {
    return allowsConstruction && internalGate.canInitialize;
  }

  bool get allowsJoin {
    return allowsInitialization && internalGate.canJoin;
  }

  bool get productionJoinDisabled => !featureGate.enabled;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'constructionAllowed': allowsConstruction,
      'setupAllowed': allowsInitialization,
      'joinAllowed': allowsJoin,
      'featureEnabled': featureGate.enabled,
    };
  }
}

abstract interface class AgoraCallV2RtcEngineClient {
  Future<void> initialize({
    required CallV2RtcSessionConfig config,
    required void Function(CallV2RtcEvent event) emit,
  });

  Future<void> join();

  Future<void> leave();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<void> dispose();
}

class AgoraSdkCallV2RtcEngineClient implements AgoraCallV2RtcEngineClient {
  AgoraSdkCallV2RtcEngineClient({
    required this.applicationIdentifier,
  });

  final String applicationIdentifier;
  RtcEngine? _engine;
  bool _initialized = false;

  @override
  Future<void> initialize({
    required CallV2RtcSessionConfig config,
    required void Function(CallV2RtcEvent event) emit,
  }) async {
    if (applicationIdentifier.isEmpty) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    final engine = _engine ?? createAgoraRtcEngine();
    _engine = engine;
    await engine.initialize(RtcEngineContext(appId: applicationIdentifier));
    await engine.setChannelProfile(
      ChannelProfileType.channelProfileCommunication,
    );
    await engine.enableAudio();
    if (config.isVideo) {
      await engine.enableVideo();
    }
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          emit(const CallV2RtcJoined());
        },
        onRejoinChannelSuccess: (connection, elapsed) {
          emit(const CallV2RtcReconnected());
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          emit(const CallV2RtcRemoteParticipantJoined());
        },
        onUserOffline: (connection, remoteUid, reason) {
          emit(const CallV2RtcRemoteParticipantLeft());
        },
        onError: (error, message) {
          emit(const CallV2RtcFatalError(CallV2RtcErrorCategory.unavailable));
        },
      ),
    );
    _initialized = true;
  }

  @override
  Future<void> join() async {
    final engine = _engine;
    if (!_initialized || engine == null) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  Future<void> joinWithConfig(CallV2RtcSessionConfig config) async {
    final engine = _engine;
    if (!_initialized || engine == null) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    await engine.joinChannel(
      token: config.token ?? '',
      channelId: config.channelName,
      uid: config.rtcUid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  Future<void> leave() async {
    await _engine?.leaveChannel();
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _engine?.muteLocalAudioStream(!enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    await _engine?.muteLocalVideoStream(!enabled);
  }

  @override
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _initialized = false;
    if (engine == null) return;
    await engine.leaveChannel();
    await engine.release();
  }
}

class AgoraCallV2RtcAdapter implements CallV2RtcAdapter {
  AgoraCallV2RtcAdapter({
    required this.gate,
    required this.client,
  });

  final AgoraCallV2RtcAdapterGate gate;
  final AgoraCallV2RtcEngineClient client;
  final _events = StreamController<CallV2RtcEvent>.broadcast(sync: true);
  CallV2RtcSessionConfig? _config;
  bool _initialized = false;
  bool _joined = false;
  bool _disposed = false;

  @override
  Stream<CallV2RtcEvent> get events => _events.stream;

  @override
  Future<void> initialize(CallV2RtcSessionConfig config) async {
    _requireUsable();
    if (!gate.allowsInitialization) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    _config = config;
    try {
      await client.initialize(config: config, emit: _emit);
      _initialized = true;
    } catch (error) {
      _emit(const CallV2RtcFatalError(CallV2RtcErrorCategory.unavailable));
      if (error is CallV2ClientError) rethrow;
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  Future<void> joinChannel() async {
    _requireUsable();
    final config = _config;
    if (!gate.allowsJoin || !_initialized || config == null) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    _emit(const CallV2RtcJoinStarted());
    try {
      final client = this.client;
      if (client is AgoraSdkCallV2RtcEngineClient) {
        await client.joinWithConfig(config);
      } else {
        await client.join();
      }
      _joined = true;
    } catch (error) {
      _emit(const CallV2RtcFatalError(CallV2RtcErrorCategory.unavailable));
      if (error is CallV2ClientError) rethrow;
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  Future<void> leaveChannel() async {
    if (_disposed || !_joined) return;
    await client.leave();
    _joined = false;
    _emit(const CallV2RtcRemoteParticipantLeft());
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _requireUsable();
    await client.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _requireUsable();
    await client.setCameraEnabled(enabled);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await client.dispose();
    await _events.close();
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'gate': gate.toSafeDebugMap(),
      'setupReady': _initialized,
      'joined': _joined,
      'disposed': _disposed,
    };
  }

  void _emit(CallV2RtcEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _requireUsable() {
    if (_disposed) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }
}
