import 'dart:async';

import 'call_v2_api.dart';
import 'call_v2_callable_results.dart';
import 'call_v2_feature_gate.dart';
import 'call_v2_firestore_snapshot_adapter.dart';
import 'call_v2_firestore_subscription_coordinator.dart';
import 'call_v2_harness.dart';
import 'call_v2_media_orchestrator.dart';
import 'call_v2_media_session_controller.dart';
import 'call_v2_runtime_configuration.dart';
import 'call_v2_runtime_configuration_validator.dart';
import 'domain/call_snapshot.dart';
import 'rtc/call_v2_rtc_adapter.dart';
import 'rtc/call_v2_rtc_config_provider.dart';
import 'rtc/call_v2_rtc_config_resolver.dart';

enum CallV2RuntimeStatus {
  idle,
  starting,
  running,
  stopping,
  stopped,
  failed,
}

class CallV2RuntimeState {
  const CallV2RuntimeState({
    required this.status,
    this.callId,
    this.errorCode,
  });

  static const idle = CallV2RuntimeState(status: CallV2RuntimeStatus.idle);

  final CallV2RuntimeStatus status;
  final String? callId;
  final CallV2ClientErrorCode? errorCode;

  CallV2RuntimeState copyWith({
    CallV2RuntimeStatus? status,
    String? callId,
    CallV2ClientErrorCode? errorCode,
    bool clearIdentity = false,
    bool clearError = false,
  }) {
    return CallV2RuntimeState(
      status: status ?? this.status,
      callId: clearIdentity ? null : callId ?? this.callId,
      errorCode: clearError ? null : errorCode ?? this.errorCode,
    );
  }

  @override
  String toString() {
    return 'CallV2RuntimeState('
        'status: $status, '
        'callId: $callId, '
        'errorCode: $errorCode'
        ')';
  }
}

class CallV2Runtime {
  CallV2Runtime({
    required CallV2FeatureGate featureGate,
    required this.harness,
    required this.subscriptionCoordinator,
    required this.configResolver,
    required this.mediaController,
    required this.mediaOrchestrator,
  })  : _featureGate = featureGate,
        super();

  final CallV2FeatureGate _featureGate;
  final CallV2Harness harness;
  final CallV2FirestoreSubscriptionCoordinating subscriptionCoordinator;
  final CallV2RtcConfigResolving configResolver;
  final CallV2MediaSessionControlling mediaController;
  final CallV2MediaOrchestrator mediaOrchestrator;

  int _generation = 0;
  CallV2RuntimeState _state = CallV2RuntimeState.idle;
  _RuntimeIdentity? _identity;
  Future<void>? _startFuture;
  Object? _startOperationToken;
  Future<void>? _stopFuture;
  Object? _stopOperationToken;

  CallV2RuntimeState get state => _state;

  Future<void> start({
    required String callId,
    required String callerUid,
    required String calleeUid,
    required String localUid,
  }) {
    return Future<void>.sync(() {
      if (!_featureGate.enabled) {
        _state = const CallV2RuntimeState(
          status: CallV2RuntimeStatus.stopped,
          errorCode: CallV2ClientErrorCode.rejected,
        );
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final identity = _RuntimeIdentity(
        callId: _validateIdentifier(callId),
        callerUid: _validateIdentifier(callerUid),
        calleeUid: _validateIdentifier(calleeUid),
        localUid: _validateIdentifier(localUid),
      );
      if (identity.callerUid == identity.calleeUid ||
          (identity.localUid != identity.callerUid &&
              identity.localUid != identity.calleeUid)) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final currentIdentity = _identity;
      final activeStart = _startFuture;
      if (_isStartActive && currentIdentity != null) {
        if (currentIdentity == identity) {
          return activeStart ?? Future<void>.value();
        }
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      if (_state.status == CallV2RuntimeStatus.stopping) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      _stopFuture = null;
      _stopOperationToken = null;
      final generation = ++_generation;
      final operationToken = Object();
      _identity = identity;
      _startOperationToken = operationToken;
      _state = CallV2RuntimeState(
        status: CallV2RuntimeStatus.starting,
        callId: identity.callId,
      );
      final future = _start(
        generation: generation,
        operationToken: operationToken,
        identity: identity,
      );
      _startFuture = future;
      return future;
    });
  }

  Future<void> handleAuthoritativeSnapshot(
    CallSnapshot snapshot, {
    required bool isVideo,
  }) {
    return Future<void>.sync(() {
      if (!_featureGate.enabled) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      _validateIdentifier(snapshot.callId);
      final identity = _identity;
      if (identity == null ||
          !_isSnapshotAllowed ||
          snapshot.callId != identity.callId) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      return mediaOrchestrator.handleAuthoritativeSnapshot(
        snapshot,
        isVideo: isVideo,
      );
    });
  }

  Future<void> stop() {
    if (!_featureGate.enabled) {
      _state = const CallV2RuntimeState(
        status: CallV2RuntimeStatus.stopped,
        errorCode: CallV2ClientErrorCode.rejected,
      );
      return Future<void>.value();
    }
    final existing = _stopFuture;
    if (existing != null) return existing;
    if (_identity == null &&
        _startFuture == null &&
        (_state.status == CallV2RuntimeStatus.idle ||
            _state.status == CallV2RuntimeStatus.stopped)) {
      _state = const CallV2RuntimeState(status: CallV2RuntimeStatus.stopped);
      return Future<void>.value();
    }

    final generation = ++_generation;
    final operationToken = Object();
    _stopOperationToken = operationToken;
    _startOperationToken = null;
    final identity = _identity;
    _state = CallV2RuntimeState(
      status: CallV2RuntimeStatus.stopping,
      callId: identity?.callId ?? _state.callId,
    );
    final future = _stop(
      generation: generation,
      operationToken: operationToken,
    );
    _stopFuture = future;
    return future;
  }

  bool get _isStartActive {
    return _state.status == CallV2RuntimeStatus.starting ||
        _state.status == CallV2RuntimeStatus.running;
  }

  bool get _isSnapshotAllowed {
    return _state.status == CallV2RuntimeStatus.starting ||
        _state.status == CallV2RuntimeStatus.running;
  }

  Future<void> _start({
    required int generation,
    required Object operationToken,
    required _RuntimeIdentity identity,
  }) async {
    try {
      await subscriptionCoordinator.start(
        callId: identity.callId,
        callerUid: identity.callerUid,
        calleeUid: identity.calleeUid,
      );
      _requireCurrentStart(generation, operationToken, identity);
      _state = CallV2RuntimeState(
        status: CallV2RuntimeStatus.running,
        callId: identity.callId,
      );
    } on CallV2ClientError catch (error) {
      if (_isCurrentStart(generation, operationToken, identity)) {
        _state = CallV2RuntimeState(
          status: CallV2RuntimeStatus.failed,
          callId: identity.callId,
          errorCode: error.code,
        );
        _clearStartOperation(operationToken);
      }
      rethrow;
    } catch (_) {
      if (_isCurrentStart(generation, operationToken, identity)) {
        _state = CallV2RuntimeState(
          status: CallV2RuntimeStatus.failed,
          callId: identity.callId,
          errorCode: CallV2ClientErrorCode.unavailable,
        );
        _clearStartOperation(operationToken);
      }
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    } finally {
      if (identical(_startOperationToken, operationToken)) {
        _startFuture = null;
      }
    }
  }

  Future<void> _stop({
    required int generation,
    required Object operationToken,
  }) async {
    CallV2ClientErrorCode? errorCode;
    try {
      await mediaOrchestrator.stop();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    }

    try {
      await subscriptionCoordinator.stop();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    }

    final isCurrent = identical(_stopOperationToken, operationToken) &&
        generation == _generation;
    if (isCurrent) {
      _identity = null;
      _startFuture = null;
      _startOperationToken = null;
      _stopFuture = null;
      _stopOperationToken = null;
      _state = CallV2RuntimeState(
        status: CallV2RuntimeStatus.stopped,
        errorCode: errorCode,
      );
    }
    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }

  void _requireCurrentStart(
    int generation,
    Object operationToken,
    _RuntimeIdentity identity,
  ) {
    if (!_isCurrentStart(generation, operationToken, identity)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  bool _isCurrentStart(
    int generation,
    Object operationToken,
    _RuntimeIdentity identity,
  ) {
    return generation == _generation &&
        identical(_startOperationToken, operationToken) &&
        _identity == identity;
  }

  void _clearStartOperation(Object operationToken) {
    if (identical(_startOperationToken, operationToken)) {
      _identity = null;
      _startOperationToken = null;
      _startFuture = null;
    }
  }

  String _validateIdentifier(String value) {
    if (value.isEmpty ||
        value.trim() != value ||
        value.length > callV2MaxCallableIdentifierLength ||
        value.contains('/')) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
    return value;
  }
}

CallV2Runtime createCallV2Runtime({
  required CallV2FeatureGate featureGate,
  required CallableCallV2Api api,
  required CallV2CallDocumentStreamFactory callDocumentStream,
  required CallV2ParticipantDocumentStreamFactory participantDocumentStream,
  required CallV2RtcConfigProvider rtcConfigProvider,
  required CallV2RtcAdapter rtcAdapter,
  required String Function() localParticipantUid,
  required CallParticipantRole Function() localParticipantRole,
  required CallV2MediaReportKeyFactory mediaReportKeyFactory,
  required String Function(
    String callId,
    CallV2MediaOrchestrationKeyPurpose purpose,
  ) orchestrationKeyFactory,
}) {
  final callApi = CallV2Api(api);
  final harness = CallV2Harness(
    featureGate: featureGate,
    api: callApi,
    localParticipantRole: localParticipantRole,
  );
  final subscriptionCoordinator = CallV2FirestoreSubscriptionCoordinator(
    featureGate: featureGate,
    harness: harness,
    adapter: const CallV2FirestoreSnapshotAdapter(),
    callDocumentStream: callDocumentStream,
    participantDocumentStream: participantDocumentStream,
  );
  final configResolver = CallV2RtcConfigResolver(
    featureGate: featureGate,
    provider: rtcConfigProvider,
    harness: harness,
    localParticipantUid: localParticipantUid,
  );
  final mediaController = CallV2MediaSessionController(
    featureGate: featureGate,
    rtcAdapter: rtcAdapter,
    harness: harness,
    mediaReportKeyFactory: mediaReportKeyFactory,
  );
  final mediaOrchestrator = CallV2MediaOrchestrator(
    featureGate: featureGate,
    configResolver: configResolver,
    mediaController: mediaController,
    idempotencyKeyFactory: orchestrationKeyFactory,
  );
  return CallV2Runtime(
    featureGate: featureGate,
    harness: harness,
    subscriptionCoordinator: subscriptionCoordinator,
    configResolver: configResolver,
    mediaController: mediaController,
    mediaOrchestrator: mediaOrchestrator,
  );
}

CallV2Runtime createValidatedCallV2Runtime({
  required CallV2RuntimeConfiguration configuration,
  required CallableCallV2Api api,
  required CallV2CallDocumentStreamFactory callDocumentStream,
  required CallV2ParticipantDocumentStreamFactory participantDocumentStream,
  required CallV2RtcConfigProvider rtcConfigProvider,
  required CallV2RtcAdapter rtcAdapter,
  required String Function() localParticipantUid,
  required CallParticipantRole Function() localParticipantRole,
  required CallV2MediaReportKeyFactory mediaReportKeyFactory,
  required String Function(
    String callId,
    CallV2MediaOrchestrationKeyPurpose purpose,
  ) orchestrationKeyFactory,
  CallV2RuntimeConfigurationValidator validator =
      const CallV2RuntimeConfigurationValidator(),
}) {
  final validation = validator.validate(configuration);
  if (!validation.isValid) {
    throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
  }
  return createCallV2Runtime(
    featureGate: CallV2FeatureGate(enabled: configuration.enabled),
    api: api,
    callDocumentStream: callDocumentStream,
    participantDocumentStream: participantDocumentStream,
    rtcConfigProvider: rtcConfigProvider,
    rtcAdapter: rtcAdapter,
    localParticipantUid: localParticipantUid,
    localParticipantRole: localParticipantRole,
    mediaReportKeyFactory: mediaReportKeyFactory,
    orchestrationKeyFactory: orchestrationKeyFactory,
  );
}

class _RuntimeIdentity {
  const _RuntimeIdentity({
    required this.callId,
    required this.callerUid,
    required this.calleeUid,
    required this.localUid,
  });

  final String callId;
  final String callerUid;
  final String calleeUid;
  final String localUid;

  @override
  bool operator ==(Object other) {
    return other is _RuntimeIdentity &&
        other.callId == callId &&
        other.callerUid == callerUid &&
        other.calleeUid == calleeUid &&
        other.localUid == localUid;
  }

  @override
  int get hashCode => Object.hash(callId, callerUid, calleeUid, localUid);
}
