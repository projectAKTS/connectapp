import 'dart:async';

import '../../call_v2_api.dart';
import '../../call_v2_callable_results.dart';
import '../../call_v2_feature_gate.dart';
import '../call_v2_rtc_adapter.dart';
import 'call_v2_rtc_engine_transport.dart';

enum ProductionCallV2RtcAdapterState {
  uninitialized,
  initialized,
  joining,
  joined,
  leaving,
  disposed,
}

class ProductionCallV2RtcAdapter implements CallV2RtcAdapter {
  ProductionCallV2RtcAdapter({
    required CallV2FeatureGate featureGate,
    required CallV2RtcEngineTransport transport,
    bool Function()? isFeatureEnabled,
  })  : _featureGate = featureGate,
        _transport = transport,
        _isFeatureEnabled = isFeatureEnabled;

  final CallV2FeatureGate _featureGate;
  final CallV2RtcEngineTransport _transport;
  final bool Function()? _isFeatureEnabled;
  final _events = StreamController<CallV2RtcEvent>.broadcast(sync: true);

  ProductionCallV2RtcAdapterState _state =
      ProductionCallV2RtcAdapterState.uninitialized;
  CallV2RtcSessionConfig? _config;
  Future<void>? _initializeFuture;
  Future<void>? _joinFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;
  StreamSubscription<CallV2RtcEngineEvent>? _transportSubscription;
  int _generation = 0;

  ProductionCallV2RtcAdapterState get state => _state;

  bool get hasRetainedCredentials => _config?.token != null;

  @override
  Stream<CallV2RtcEvent> get events => _events.stream;

  @override
  Future<void> initialize(CallV2RtcSessionConfig config) {
    return Future<void>.sync(() {
      _requireEnabled();
      _requireNotDisposed();
      final sanitizedConfig = _validateConfig(config);
      final inFlight = _initializeFuture;
      final currentConfig = _config;
      if (inFlight != null) {
        if (currentConfig == sanitizedConfig) return inFlight;
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      if (_state != ProductionCallV2RtcAdapterState.uninitialized) {
        if (currentConfig == sanitizedConfig) return Future<void>.value();
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final generation = ++_generation;
      _config = sanitizedConfig;
      _transportSubscription ??=
          _transport.events.listen((event) => _handleTransportEvent(event));
      final future = _initialize(
        generation: generation,
        config: sanitizedConfig,
      );
      _initializeFuture = future;
      return future;
    });
  }

  @override
  Future<void> joinChannel() {
    return Future<void>.sync(() {
      _requireEnabled();
      _requireNotDisposed();
      if (_state == ProductionCallV2RtcAdapterState.joined) {
        return Future<void>.value();
      }
      final inFlight = _joinFuture;
      if (inFlight != null) return inFlight;
      if (_state != ProductionCallV2RtcAdapterState.initialized) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final generation = _generation;
      _state = ProductionCallV2RtcAdapterState.joining;
      _emit(const CallV2RtcJoinStarted());
      final future = _join(generation: generation);
      _joinFuture = future;
      return future;
    });
  }

  @override
  Future<void> leaveChannel() {
    return Future<void>.sync(() {
      if (_state == ProductionCallV2RtcAdapterState.disposed) {
        return Future<void>.value();
      }
      final inFlight = _leaveFuture;
      if (inFlight != null) return inFlight;
      final generation = ++_generation;
      final future = _leave(generation: generation);
      _leaveFuture = future;
      return future;
    });
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _requireEnabled();
    _requireControlsAllowed();
    try {
      await _transport.setMicrophoneEnabled(enabled);
    } catch (_) {
      throw _controlledUnavailable();
    }
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _requireEnabled();
    _requireControlsAllowed();
    final config = _config;
    if (enabled && (config == null || !config.isVideo)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    try {
      await _transport.setCameraEnabled(enabled);
    } catch (_) {
      throw _controlledUnavailable();
    }
  }

  @override
  Future<void> dispose() {
    return Future<void>.sync(() {
      final inFlight = _disposeFuture;
      if (inFlight != null) return inFlight;
      if (_state == ProductionCallV2RtcAdapterState.disposed) {
        return Future<void>.value();
      }
      final generation = ++_generation;
      final future = _dispose(generation: generation);
      _disposeFuture = future;
      return future;
    });
  }

  Future<void> _initialize({
    required int generation,
    required CallV2RtcSessionConfig config,
  }) async {
    try {
      await _transport.initialize(CallV2RtcEngineSession(
        channelName: config.channelName,
        rtcUid: config.rtcUid,
        isVideo: config.isVideo,
        token: config.token,
      ));
      if (_isCurrent(generation) &&
          _state == ProductionCallV2RtcAdapterState.uninitialized) {
        _state = ProductionCallV2RtcAdapterState.initialized;
      }
    } catch (_) {
      if (_isCurrent(generation)) {
        await _cancelTransportSubscription();
        _clearRetainedCredentials();
        _state = ProductionCallV2RtcAdapterState.uninitialized;
      }
      throw _controlledUnavailable();
    } finally {
      if (_isCurrent(generation)) _initializeFuture = null;
    }
  }

  Future<void> _join({required int generation}) async {
    try {
      await _transport.joinChannel();
      if (!_isCurrent(generation) ||
          _state != ProductionCallV2RtcAdapterState.joining) {
        throw const _StaleRtcOperation();
      }
    } on _StaleRtcOperation {
      throw _controlledUnavailable();
    } catch (_) {
      if (_isCurrent(generation) &&
          _state == ProductionCallV2RtcAdapterState.joining) {
        _state = ProductionCallV2RtcAdapterState.initialized;
      }
      throw _controlledUnavailable();
    } finally {
      if (_isCurrent(generation)) _joinFuture = null;
    }
  }

  Future<void> _leave({required int generation}) async {
    final shouldLeave = _state == ProductionCallV2RtcAdapterState.joining ||
        _state == ProductionCallV2RtcAdapterState.joined;
    _state = ProductionCallV2RtcAdapterState.leaving;
    Object? cleanupError;
    try {
      if (shouldLeave) {
        try {
          await _transport.leaveChannel();
        } catch (error) {
          cleanupError ??= error;
        }
      }
      await _cancelTransportSubscription();
    } finally {
      if (_isCurrent(generation)) {
        _clearRetainedCredentials();
        _joinFuture = null;
        _initializeFuture = null;
        _leaveFuture = null;
        if (_state != ProductionCallV2RtcAdapterState.disposed) {
          _state = ProductionCallV2RtcAdapterState.uninitialized;
        }
      }
    }
    if (cleanupError != null) throw _controlledUnavailable();
  }

  Future<void> _dispose({required int generation}) async {
    final shouldLeave = _state == ProductionCallV2RtcAdapterState.joining ||
        _state == ProductionCallV2RtcAdapterState.joined;
    _state = ProductionCallV2RtcAdapterState.disposed;
    Object? cleanupError;
    try {
      if (shouldLeave) {
        try {
          await _transport.leaveChannel();
        } catch (error) {
          cleanupError ??= error;
        }
      }
      try {
        await _cancelTransportSubscription();
      } catch (error) {
        cleanupError ??= error;
      }
      try {
        await _transport.dispose();
      } catch (error) {
        cleanupError ??= error;
      }
    } finally {
      if (_isCurrent(generation)) {
        _clearRetainedCredentials();
        _joinFuture = null;
        _initializeFuture = null;
        _leaveFuture = null;
      }
      await _events.close();
      _disposeFuture = null;
    }
    if (cleanupError != null) throw _controlledUnavailable();
  }

  void _handleTransportEvent(CallV2RtcEngineEvent event) {
    if (_state == ProductionCallV2RtcAdapterState.disposed ||
        _state == ProductionCallV2RtcAdapterState.uninitialized ||
        _events.isClosed) {
      return;
    }
    switch (event) {
      case CallV2RtcEngineJoined():
        if (_state == ProductionCallV2RtcAdapterState.joining ||
            _state == ProductionCallV2RtcAdapterState.initialized) {
          _state = ProductionCallV2RtcAdapterState.joined;
        }
        _emit(const CallV2RtcJoined());
      case CallV2RtcEngineReconnecting():
        _emit(const CallV2RtcReconnecting());
      case CallV2RtcEngineReconnected():
        if (_state != ProductionCallV2RtcAdapterState.leaving) {
          _state = ProductionCallV2RtcAdapterState.joined;
        }
        _emit(const CallV2RtcReconnected());
      case CallV2RtcEngineDisconnected():
        _emit(const CallV2RtcDisconnected());
      case CallV2RtcEngineRemoteParticipantJoined():
        _emit(const CallV2RtcRemoteParticipantJoined());
      case CallV2RtcEngineRemoteParticipantLeft():
        _emit(const CallV2RtcRemoteParticipantLeft());
      case CallV2RtcEngineFailure(:final category):
        _emit(CallV2RtcFatalError(category));
    }
  }

  void _emit(CallV2RtcEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> _cancelTransportSubscription() async {
    final subscription = _transportSubscription;
    _transportSubscription = null;
    await subscription?.cancel();
  }

  void _clearRetainedCredentials() {
    _config = null;
  }

  void _requireEnabled() {
    if (!(_isFeatureEnabled?.call() ?? _featureGate.enabled)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _requireNotDisposed() {
    if (_state == ProductionCallV2RtcAdapterState.disposed) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _requireControlsAllowed() {
    _requireNotDisposed();
    switch (_state) {
      case ProductionCallV2RtcAdapterState.initialized:
      case ProductionCallV2RtcAdapterState.joining:
      case ProductionCallV2RtcAdapterState.joined:
        return;
      case ProductionCallV2RtcAdapterState.uninitialized:
      case ProductionCallV2RtcAdapterState.leaving:
      case ProductionCallV2RtcAdapterState.disposed:
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  bool _isCurrent(int generation) => generation == _generation;

  CallV2RtcSessionConfig _validateConfig(CallV2RtcSessionConfig config) {
    final token = config.token;
    return CallV2RtcSessionConfig(
      callId: _validateIdentifier(config.callId),
      channelName: _validateIdentifier(config.channelName),
      rtcUid: _validateRtcUid(config.rtcUid),
      isVideo: config.isVideo,
      token: token == null ? null : _validateIdentifier(token),
    );
  }

  String _validateIdentifier(String value) {
    if (value.isEmpty ||
        value.trim() != value ||
        value.length > _maximumIdentifierLength ||
        value.contains('/')) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
    return value;
  }

  int _validateRtcUid(int value) {
    if (value <= 0 || value > callV2MaxSafeInteger) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
    return value;
  }

  CallV2ClientError _controlledUnavailable() {
    return const CallV2ClientError(CallV2ClientErrorCode.unavailable);
  }

  @override
  String toString() {
    return 'ProductionCallV2RtcAdapter('
        'state: ${_state.name}, '
        'hasSession: ${_config != null}'
        ')';
  }
}

const _maximumIdentifierLength = 128;

class _StaleRtcOperation implements Exception {
  const _StaleRtcOperation();
}
