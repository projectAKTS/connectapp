import 'dart:async';

import 'call_v2_api.dart';
import 'call_v2_feature_gate.dart';
import 'call_v2_media_session_controller.dart';
import 'domain/call_lifecycle.dart';
import 'domain/call_snapshot.dart';
import 'rtc/call_v2_rtc_config_resolver.dart';

enum CallV2MediaOrchestrationStatus {
  idle,
  awaitingEligibility,
  resolvingConfig,
  startingMedia,
  active,
  stopping,
  stopped,
  failed,
}

enum CallV2MediaOrchestrationKeyPurpose {
  resolveConfig,
  preparing,
  joining,
  leaving,
}

class CallV2MediaOrchestrationState {
  const CallV2MediaOrchestrationState({
    required this.status,
    this.callId,
    this.isVideo,
    this.errorCode,
  });

  static const idle = CallV2MediaOrchestrationState(
    status: CallV2MediaOrchestrationStatus.idle,
  );

  final CallV2MediaOrchestrationStatus status;
  final String? callId;
  final bool? isVideo;
  final CallV2ClientErrorCode? errorCode;

  CallV2MediaOrchestrationState copyWith({
    CallV2MediaOrchestrationStatus? status,
    String? callId,
    bool? isVideo,
    CallV2ClientErrorCode? errorCode,
    bool clearIdentity = false,
    bool clearError = false,
  }) {
    return CallV2MediaOrchestrationState(
      status: status ?? this.status,
      callId: clearIdentity ? null : callId ?? this.callId,
      isVideo: clearIdentity ? null : isVideo ?? this.isVideo,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }

  @override
  String toString() {
    return 'CallV2MediaOrchestrationState('
        'status: $status, '
        'callId: $callId, '
        'isVideo: $isVideo, '
        'errorCode: $errorCode'
        ')';
  }
}

class CallV2MediaOrchestrator {
  CallV2MediaOrchestrator({
    required CallV2FeatureGate featureGate,
    required CallV2RtcConfigResolving configResolver,
    required CallV2MediaSessionControlling mediaController,
    required String Function(
      String callId,
      CallV2MediaOrchestrationKeyPurpose purpose,
    ) idempotencyKeyFactory,
  })  : _featureGate = featureGate,
        _configResolver = configResolver,
        _mediaController = mediaController,
        _idempotencyKeyFactory = idempotencyKeyFactory;

  final CallV2FeatureGate _featureGate;
  final CallV2RtcConfigResolving _configResolver;
  final CallV2MediaSessionControlling _mediaController;
  final String Function(String, CallV2MediaOrchestrationKeyPurpose)
      _idempotencyKeyFactory;

  int _generation = 0;
  CallV2MediaOrchestrationState _state = CallV2MediaOrchestrationState.idle;
  _OrchestrationIdentity? _activeIdentity;
  Future<void>? _activeFuture;
  Object? _activeOperationToken;
  Future<void>? _stopFuture;
  Object? _stopOperationToken;

  CallV2MediaOrchestrationState get state => _state;

  Future<void> handleAuthoritativeSnapshot(
    CallSnapshot snapshot, {
    required bool isVideo,
  }) {
    return Future<void>.sync(() {
      if (!_featureGate.enabled) {
        _state = const CallV2MediaOrchestrationState(
          status: CallV2MediaOrchestrationStatus.stopped,
          errorCode: CallV2ClientErrorCode.rejected,
        );
        return null;
      }

      _validateSnapshot(snapshot);
      _forwardSnapshot(snapshot);

      if (snapshot.lifecycle.isTerminal) {
        return _handleTerminal(snapshot);
      }

      final incomingIdentity = _OrchestrationIdentity(
        callId: snapshot.callId,
        isVideo: isVideo,
      );
      final activeIdentity = _activeIdentity;
      if (activeIdentity != null && activeIdentity != incomingIdentity) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      switch (snapshot.lifecycle) {
        case CallLifecycle.ringing:
          if (_activeIdentity == null) {
            _state = CallV2MediaOrchestrationState(
              status: CallV2MediaOrchestrationStatus.awaitingEligibility,
              callId: snapshot.callId,
              isVideo: isVideo,
            );
          }
          return null;
        case CallLifecycle.accepted:
        case CallLifecycle.active:
          return _ensureStarted(incomingIdentity);
        case CallLifecycle.completed:
        case CallLifecycle.declined:
        case CallLifecycle.cancelled:
        case CallLifecycle.missed:
        case CallLifecycle.failed:
          return null;
      }
    });
  }

  Future<void> stop() {
    if (!_featureGate.enabled) {
      _state = const CallV2MediaOrchestrationState(
        status: CallV2MediaOrchestrationStatus.stopped,
        errorCode: CallV2ClientErrorCode.rejected,
      );
      return Future<void>.value();
    }
    final existing = _stopFuture;
    if (existing != null) return existing;
    if (_activeIdentity == null &&
        _activeFuture == null &&
        _state.status == CallV2MediaOrchestrationStatus.stopped) {
      return Future<void>.value();
    }
    final generation = ++_generation;
    final operationToken = Object();
    _stopOperationToken = operationToken;
    final identity = _activeIdentity;
    final leaveKey = identity == null
        ? null
        : _key(identity.callId, CallV2MediaOrchestrationKeyPurpose.leaving);
    _state = _state.copyWith(
      status: CallV2MediaOrchestrationStatus.stopping,
      clearError: true,
    );
    _configResolver.invalidate();
    final stopFuture = _stop(
      generation: generation,
      operationToken: operationToken,
      leaveKey: leaveKey,
    );
    _stopFuture = stopFuture;
    return stopFuture;
  }

  Future<void> _ensureStarted(_OrchestrationIdentity identity) {
    final stateStatus = _state.status;
    if (_activeIdentity == identity &&
        stateStatus == CallV2MediaOrchestrationStatus.active) {
      return Future<void>.value();
    }
    final activeFuture = _activeFuture;
    if (_activeIdentity == identity && activeFuture != null) {
      return activeFuture;
    }

    _stopFuture = null;
    _stopOperationToken = null;
    final generation = ++_generation;
    final operationToken = Object();
    final resolveKey = _key(
      identity.callId,
      CallV2MediaOrchestrationKeyPurpose.resolveConfig,
    );
    final preparingKey = _key(
      identity.callId,
      CallV2MediaOrchestrationKeyPurpose.preparing,
    );
    final joiningKey = _key(
      identity.callId,
      CallV2MediaOrchestrationKeyPurpose.joining,
    );
    _activeIdentity = identity;
    _activeOperationToken = operationToken;
    _state = CallV2MediaOrchestrationState(
      status: CallV2MediaOrchestrationStatus.resolvingConfig,
      callId: identity.callId,
      isVideo: identity.isVideo,
    );
    final future = _start(
      generation: generation,
      operationToken: operationToken,
      identity: identity,
      resolveKey: resolveKey,
      preparingKey: preparingKey,
      joiningKey: joiningKey,
    );
    _activeFuture = future;
    return future;
  }

  Future<void> _start({
    required int generation,
    required Object operationToken,
    required _OrchestrationIdentity identity,
    required String resolveKey,
    required String preparingKey,
    required String joiningKey,
  }) async {
    try {
      final resolved = await _configResolver.resolve(
        isVideo: identity.isVideo,
        idempotencyKey: resolveKey,
      );
      _requireCurrent(generation, operationToken, identity);
      final config = resolved.toSessionConfig();
      _requireCurrent(generation, operationToken, identity);
      _state = CallV2MediaOrchestrationState(
        status: CallV2MediaOrchestrationStatus.startingMedia,
        callId: identity.callId,
        isVideo: identity.isVideo,
      );
      await _mediaController.start(
        config: config,
        preparingIdempotencyKey: preparingKey,
        joiningIdempotencyKey: joiningKey,
      );
      _requireCurrent(generation, operationToken, identity);
      _state = CallV2MediaOrchestrationState(
        status: CallV2MediaOrchestrationStatus.active,
        callId: identity.callId,
        isVideo: identity.isVideo,
      );
    } on CallV2ClientError catch (error) {
      if (_isCurrent(generation, operationToken, identity)) {
        _state = CallV2MediaOrchestrationState(
          status: CallV2MediaOrchestrationStatus.failed,
          callId: identity.callId,
          isVideo: identity.isVideo,
          errorCode: error.code,
        );
        _configResolver.invalidate();
        _clearActiveOperation(operationToken);
      }
      rethrow;
    } catch (_) {
      if (_isCurrent(generation, operationToken, identity)) {
        _state = CallV2MediaOrchestrationState(
          status: CallV2MediaOrchestrationStatus.failed,
          callId: identity.callId,
          isVideo: identity.isVideo,
          errorCode: CallV2ClientErrorCode.unavailable,
        );
        _configResolver.invalidate();
        _clearActiveOperation(operationToken);
      }
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    } finally {
      if (identical(_activeOperationToken, operationToken)) {
        _activeFuture = null;
      }
    }
  }

  Future<void> _handleTerminal(CallSnapshot snapshot) {
    final identity = _activeIdentity;
    if (identity != null && identity.callId != snapshot.callId) {
      return Future<void>.value();
    }
    if (identity == null &&
        _activeFuture == null &&
        _state.status != CallV2MediaOrchestrationStatus.active &&
        _state.status != CallV2MediaOrchestrationStatus.startingMedia) {
      _configResolver.handleAuthoritativeSnapshot(snapshot);
      _state = CallV2MediaOrchestrationState(
        status: CallV2MediaOrchestrationStatus.stopped,
        callId: snapshot.callId,
      );
      return Future<void>.value();
    }
    return stop();
  }

  Future<void> _stop({
    required int generation,
    required Object operationToken,
    required String? leaveKey,
  }) async {
    CallV2ClientError? leaveError;
    try {
      _clearActiveOperation(_activeOperationToken);
      if (leaveKey != null) {
        try {
          await _mediaController.leave(idempotencyKey: leaveKey);
        } on CallV2ClientError catch (error) {
          leaveError = error;
        } catch (_) {
          leaveError =
              const CallV2ClientError(CallV2ClientErrorCode.unavailable);
        }
      }
    } finally {
      if (_isCurrentStop(generation, operationToken)) {
        _activeIdentity = null;
        _state = CallV2MediaOrchestrationState(
          status: CallV2MediaOrchestrationStatus.stopped,
          errorCode: leaveError?.code,
        );
        _stopFuture = null;
        _stopOperationToken = null;
      }
    }
    if (leaveError != null) throw leaveError;
  }

  void _forwardSnapshot(CallSnapshot snapshot) {
    _configResolver.handleAuthoritativeSnapshot(snapshot);
    unawaited(
      _mediaController.handleAuthoritativeSnapshot(snapshot).catchError((_) {}),
    );
  }

  String _key(String callId, CallV2MediaOrchestrationKeyPurpose purpose) {
    try {
      final key = _idempotencyKeyFactory(callId, purpose);
      _validateIdentifier(key);
      return key;
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
  }

  void _requireCurrent(
    int generation,
    Object operationToken,
    _OrchestrationIdentity identity,
  ) {
    if (!_isCurrent(generation, operationToken, identity)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  bool _isCurrent(
    int generation,
    Object operationToken,
    _OrchestrationIdentity identity,
  ) {
    return generation == _generation &&
        _activeIdentity == identity &&
        identical(_activeOperationToken, operationToken);
  }

  bool _isCurrentStop(int generation, Object operationToken) {
    return generation == _generation &&
        identical(_stopOperationToken, operationToken);
  }

  void _clearActiveOperation(Object? operationToken) {
    if (operationToken == null ||
        identical(_activeOperationToken, operationToken)) {
      _activeIdentity = null;
      _activeFuture = null;
      _activeOperationToken = null;
    }
  }

  void _validateSnapshot(CallSnapshot snapshot) {
    _validateIdentifier(snapshot.callId);
  }

  void _validateIdentifier(String value) {
    if (value.isEmpty ||
        value.trim() != value ||
        value.length > 128 ||
        value.contains('/')) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
  }
}

class _OrchestrationIdentity {
  const _OrchestrationIdentity({
    required this.callId,
    required this.isVideo,
  });

  final String callId;
  final bool isVideo;

  @override
  bool operator ==(Object other) {
    return other is _OrchestrationIdentity &&
        other.callId == callId &&
        other.isVideo == isVideo;
  }

  @override
  int get hashCode => Object.hash(callId, isVideo);
}
