import 'dart:async';

import 'call_v2_api.dart';
import 'call_v2_callable_results.dart';
import 'call_v2_feature_gate.dart';
import 'call_v2_harness.dart';
import 'domain/call_lifecycle.dart';
import 'domain/call_snapshot.dart';
import 'domain/participant_media_state.dart';
import 'rtc/call_v2_rtc_adapter.dart';

enum CallV2MediaSessionStatus {
  idle,
  preparing,
  joining,
  joined,
  reconnecting,
  disconnected,
  leaving,
  left,
  failed,
}

class CallV2MediaSessionState {
  const CallV2MediaSessionState({
    required this.status,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.remoteParticipantPresent,
    this.errorCode,
  });

  static const idle = CallV2MediaSessionState(
    status: CallV2MediaSessionStatus.idle,
    microphoneEnabled: true,
    cameraEnabled: false,
    remoteParticipantPresent: false,
  );

  final CallV2MediaSessionStatus status;
  final bool microphoneEnabled;
  final bool cameraEnabled;
  final bool remoteParticipantPresent;
  final CallV2ClientErrorCode? errorCode;

  CallV2MediaSessionState copyWith({
    CallV2MediaSessionStatus? status,
    bool? microphoneEnabled,
    bool? cameraEnabled,
    bool? remoteParticipantPresent,
    CallV2ClientErrorCode? errorCode,
    bool clearError = false,
  }) {
    return CallV2MediaSessionState(
      status: status ?? this.status,
      microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      remoteParticipantPresent:
          remoteParticipantPresent ?? this.remoteParticipantPresent,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }
}

abstract interface class CallV2MediaSessionControlling {
  Future<void> start({
    required CallV2RtcSessionConfig config,
    required String preparingIdempotencyKey,
    required String joiningIdempotencyKey,
  });

  Future<void> handleAuthoritativeSnapshot(CallSnapshot snapshot);

  Future<void> leave({required String idempotencyKey});
}

class CallV2MediaSessionController implements CallV2MediaSessionControlling {
  CallV2MediaSessionController({
    required CallV2FeatureGate featureGate,
    required CallV2RtcAdapter rtcAdapter,
    required CallV2Harness harness,
    CallV2MediaReportKeyFactory? mediaReportKeyFactory,
  })  : _featureGate = featureGate,
        _rtcAdapter = rtcAdapter,
        _harness = harness,
        _mediaReportKeyFactory =
            mediaReportKeyFactory ?? _defaultMediaReportKey;

  final CallV2FeatureGate _featureGate;
  final CallV2RtcAdapter _rtcAdapter;
  final CallV2Harness _harness;
  final CallV2MediaReportKeyFactory _mediaReportKeyFactory;

  int _generation = 0;
  CallV2MediaSessionState _state = CallV2MediaSessionState.idle;
  CallV2RtcSessionConfig? _config;
  StreamSubscription<CallV2RtcEvent>? _eventSubscription;
  Future<void>? _startFuture;
  Future<void>? _leaveFuture;
  bool _joinStarted = false;
  bool _disposed = false;
  bool _leftReported = false;
  bool _mediaFailedReported = false;
  ParticipantMediaState? _lastReportedState;

  CallV2MediaSessionState get state => _state;

  @override
  Future<void> start({
    required CallV2RtcSessionConfig config,
    required String preparingIdempotencyKey,
    required String joiningIdempotencyKey,
  }) {
    return Future<void>.sync(() {
      if (!_featureGate.enabled) return null;
      final preparedConfig = _validateConfig(config);
      _validateIdentifier(preparingIdempotencyKey);
      _validateIdentifier(joiningIdempotencyKey);
      final snapshot = _harness.snapshot;
      if (snapshot == null ||
          snapshot.callId != preparedConfig.callId ||
          !_canStartFrom(snapshot.lifecycle)) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final existingStart = _startFuture;
      final activeConfig = _config;
      if (existingStart != null) {
        if (activeConfig == preparedConfig) return existingStart;
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      if (_hasActiveSession) {
        if (activeConfig == preparedConfig) return Future<void>.value();
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final generation = ++_generation;
      _config = preparedConfig;
      _joinStarted = false;
      _disposed = false;
      _leftReported = false;
      _mediaFailedReported = false;
      _lastReportedState = null;
      _state = CallV2MediaSessionState(
        status: CallV2MediaSessionStatus.preparing,
        microphoneEnabled: true,
        cameraEnabled: false,
        remoteParticipantPresent: false,
      );
      final startFuture = _start(
        generation: generation,
        config: preparedConfig,
        preparingIdempotencyKey: preparingIdempotencyKey,
        joiningIdempotencyKey: joiningIdempotencyKey,
      );
      _startFuture = startFuture;
      return startFuture;
    });
  }

  @override
  Future<void> handleAuthoritativeSnapshot(CallSnapshot snapshot) async {
    if (!_featureGate.enabled) return;
    final config = _config;
    if (config != null && snapshot.callId != config.callId) return;
    _harness.injectPublicSnapshot(snapshot);
    if (config == null) return;
    if (snapshot.lifecycle.isTerminal) {
      await leave(idempotencyKey: _mediaReportKey(ParticipantMediaState.left));
    }
  }

  @override
  Future<void> leave({required String idempotencyKey}) {
    if (!_featureGate.enabled) return Future<void>.value();
    _validateIdentifier(idempotencyKey);
    final existing = _leaveFuture;
    if (existing != null) return existing;
    if (!_hasActiveSession && _state.status == CallV2MediaSessionStatus.left) {
      return Future<void>.value();
    }
    final generation = ++_generation;
    final leaveFuture = _leave(
      generation: generation,
      idempotencyKey: idempotencyKey,
    );
    _leaveFuture = leaveFuture;
    return leaveFuture;
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (!_featureGate.enabled) return;
    _requireToggleAllowed();
    if (_state.microphoneEnabled == enabled) return;
    try {
      await _rtcAdapter.setMicrophoneEnabled(enabled);
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    _state = _state.copyWith(microphoneEnabled: enabled, clearError: true);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (!_featureGate.enabled) return;
    _requireToggleAllowed();
    final config = _config;
    if (enabled && (config == null || !config.isVideo)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    if (_state.cameraEnabled == enabled) return;
    try {
      await _rtcAdapter.setCameraEnabled(enabled);
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    _state = _state.copyWith(cameraEnabled: enabled, clearError: true);
  }

  Future<void> _start({
    required int generation,
    required CallV2RtcSessionConfig config,
    required String preparingIdempotencyKey,
    required String joiningIdempotencyKey,
  }) async {
    try {
      await _reportMedia(
        generation,
        ParticipantMediaState.preparing,
        preparingIdempotencyKey,
      );
      if (!_isCurrent(generation)) throw const _StaleSession();
      await _rtcAdapter.initialize(config);
      if (!_isCurrent(generation)) throw const _StaleSession();
      _state = _state.copyWith(
        status: CallV2MediaSessionStatus.joining,
        clearError: true,
      );
      await _reportMedia(
        generation,
        ParticipantMediaState.joining,
        joiningIdempotencyKey,
      );
      if (!_isCurrent(generation)) throw const _StaleSession();
      _eventSubscription = _rtcAdapter.events.listen(
        (event) => _handleRtcEvent(generation, event),
      );
      _joinStarted = true;
      await _rtcAdapter.joinChannel();
      if (!_isCurrent(generation)) throw const _StaleSession();
    } on _StaleSession {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    } catch (_) {
      if (_isCurrent(generation)) {
        await _failSession(
          generation,
          CallV2ClientErrorCode.unavailable,
        );
      }
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    } finally {
      if (_isCurrent(generation)) _startFuture = null;
    }
  }

  Future<void> _leave({
    required int generation,
    required String idempotencyKey,
  }) async {
    final previousStatus = _state.status;
    _state = _state.copyWith(status: CallV2MediaSessionStatus.leaving);
    CallV2ClientError? reportError;
    try {
      await _safeCancelEventSubscription();
      if (_joinStarted || previousStatus != CallV2MediaSessionStatus.idle) {
        await _safeLeaveAdapter();
      }
      try {
        await _reportLeft(generation, idempotencyKey);
      } catch (_) {
        reportError =
            const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      }
    } finally {
      await _disposeOnce();
      if (_isCurrent(generation)) {
        _config = null;
        _joinStarted = false;
        _state = _state.copyWith(
          status: CallV2MediaSessionStatus.left,
          remoteParticipantPresent: false,
          errorCode: reportError?.code,
          clearError: reportError == null,
        );
        _leaveFuture = null;
        _startFuture = null;
      }
    }
    if (reportError != null) throw reportError;
  }

  void _handleRtcEvent(int generation, CallV2RtcEvent event) {
    if (!_isCurrent(generation) ||
        _state.status == CallV2MediaSessionStatus.left) {
      return;
    }
    switch (event) {
      case CallV2RtcJoinStarted():
        return;
      case CallV2RtcJoined():
        _transitionAndReport(
          generation,
          CallV2MediaSessionStatus.joined,
          ParticipantMediaState.joined,
        );
      case CallV2RtcReconnecting():
        _transitionAndReport(
          generation,
          CallV2MediaSessionStatus.reconnecting,
          ParticipantMediaState.reconnecting,
        );
      case CallV2RtcReconnected():
        _transitionAndReport(
          generation,
          CallV2MediaSessionStatus.joined,
          ParticipantMediaState.joined,
        );
      case CallV2RtcDisconnected():
        _transitionAndReport(
          generation,
          CallV2MediaSessionStatus.disconnected,
          ParticipantMediaState.disconnected,
        );
      case CallV2RtcRemoteParticipantJoined():
        _state = _state.copyWith(remoteParticipantPresent: true);
      case CallV2RtcRemoteParticipantLeft():
        _state = _state.copyWith(remoteParticipantPresent: false);
      case CallV2RtcFatalError(:final category):
        unawaited(_failSession(generation, category.clientErrorCode));
    }
  }

  void _transitionAndReport(
    int generation,
    CallV2MediaSessionStatus status,
    ParticipantMediaState mediaState,
  ) {
    if (!_isCurrent(generation) || _state.status == status) return;
    _state = _state.copyWith(status: status, clearError: true);
    unawaited(_reportTransitionSafely(generation, mediaState));
  }

  Future<void> _failSession(
    int generation,
    CallV2ClientErrorCode errorCode,
  ) async {
    if (!_isCurrent(generation)) return;
    _state = _state.copyWith(
      status: CallV2MediaSessionStatus.failed,
      errorCode: errorCode,
    );
    await _safeCancelEventSubscription();
    try {
      await _reportMediaFailed(generation);
    } catch (_) {
      // Failure cleanup preserves the original RTC/client error category.
    }
    await _safeLeaveAdapter();
    await _disposeOnce();
    if (_isCurrent(generation)) {
      _config = null;
      _joinStarted = false;
      _startFuture = null;
      _leaveFuture = null;
    }
  }

  Future<void> _reportTransitionSafely(
    int generation,
    ParticipantMediaState mediaState,
  ) async {
    try {
      await _reportMedia(generation, mediaState, _mediaReportKey(mediaState));
    } catch (_) {
      if (_isCurrent(generation)) {
        _state = _state.copyWith(
          errorCode: CallV2ClientErrorCode.unavailable,
        );
      }
    }
  }

  Future<void> _reportMedia(
    int generation,
    ParticipantMediaState mediaState,
    String idempotencyKey,
  ) async {
    if (!_isCurrent(generation)) return;
    if (_lastReportedState == mediaState) return;
    final callId = _config?.callId;
    if (callId == null) return;
    await _harness.reportMedia(CallV2MediaReportRequest(
      callId: callId,
      mediaState: mediaState,
      idempotencyKey: idempotencyKey,
    ));
    if (_isCurrent(generation)) {
      _lastReportedState = mediaState;
    }
  }

  Future<void> _reportLeft(int generation, String idempotencyKey) async {
    if (_leftReported || !_isCurrent(generation)) return;
    await _reportMedia(generation, ParticipantMediaState.left, idempotencyKey);
    if (_isCurrent(generation)) _leftReported = true;
  }

  Future<void> _reportMediaFailed(int generation) async {
    if (_mediaFailedReported || !_isCurrent(generation)) return;
    await _reportMedia(
      generation,
      ParticipantMediaState.mediaFailed,
      _mediaReportKey(ParticipantMediaState.mediaFailed),
    );
    if (_isCurrent(generation)) _mediaFailedReported = true;
  }

  Future<void> _safeLeaveAdapter() async {
    if (!_joinStarted) return;
    try {
      await _rtcAdapter.leaveChannel();
    } catch (_) {
      // Cleanup remains deterministic and does not expose provider details.
    }
    _joinStarted = false;
  }

  Future<void> _safeCancelEventSubscription() async {
    final subscription = _eventSubscription;
    _eventSubscription = null;
    try {
      await subscription?.cancel();
    } catch (_) {
      // Cleanup remains deterministic and does not expose provider details.
    }
  }

  Future<void> _disposeOnce() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await _rtcAdapter.dispose();
    } catch (_) {
      // Cleanup remains deterministic and does not expose provider details.
    }
  }

  bool _isCurrent(int generation) => generation == _generation;

  bool get _hasActiveSession {
    switch (_state.status) {
      case CallV2MediaSessionStatus.preparing:
      case CallV2MediaSessionStatus.joining:
      case CallV2MediaSessionStatus.joined:
      case CallV2MediaSessionStatus.reconnecting:
      case CallV2MediaSessionStatus.disconnected:
      case CallV2MediaSessionStatus.leaving:
        return true;
      case CallV2MediaSessionStatus.idle:
      case CallV2MediaSessionStatus.left:
      case CallV2MediaSessionStatus.failed:
        return false;
    }
  }

  bool _canStartFrom(CallLifecycle lifecycle) {
    return lifecycle == CallLifecycle.accepted ||
        lifecycle == CallLifecycle.active;
  }

  void _requireToggleAllowed() {
    switch (_state.status) {
      case CallV2MediaSessionStatus.preparing:
      case CallV2MediaSessionStatus.joining:
      case CallV2MediaSessionStatus.joined:
      case CallV2MediaSessionStatus.reconnecting:
        return;
      case CallV2MediaSessionStatus.idle:
      case CallV2MediaSessionStatus.disconnected:
      case CallV2MediaSessionStatus.leaving:
      case CallV2MediaSessionStatus.left:
      case CallV2MediaSessionStatus.failed:
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

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
        value.length > 128 ||
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

  String _mediaReportKey(ParticipantMediaState mediaState) {
    final callId = _config?.callId ?? 'no_call';
    return _mediaReportKeyFactory(callId, mediaState);
  }
}

typedef CallV2MediaReportKeyFactory = String Function(
  String callId,
  ParticipantMediaState mediaState,
);

String _defaultMediaReportKey(
  String callId,
  ParticipantMediaState mediaState,
) {
  return 'rtc_${callId}_${mediaState.name}';
}

class _StaleSession implements Exception {
  const _StaleSession();
}
