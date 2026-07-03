import '../call_v2_api.dart';
import '../call_v2_contract_manifest.dart';
import '../call_v2_production_capabilities.dart';
import '../call_v2_production_readiness.dart';
import '../call_v2_runtime_configuration.dart';
import '../permissions/call_v2_media_permission_gateway.dart';
import '../production/call_v2_production_composition.dart';
import 'call_v2_startup_bridge.dart';

typedef CallV2ProductionCompositionBuilder = CallV2ProductionComposition
    Function();

class ProductionCallV2StartupBridge implements CallV2StartupBridge {
  ProductionCallV2StartupBridge({
    CallV2ProductionComposition? composition,
    CallV2ProductionCompositionBuilder? compositionBuilder,
    CallV2ProductionReadinessAuditor auditor =
        const CallV2ProductionReadinessAuditor(),
  })  : _composition = composition,
        _compositionBuilder = compositionBuilder,
        _auditor = auditor {
    if ((composition == null) == (compositionBuilder == null)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
  }

  CallV2ProductionComposition? _composition;
  final CallV2ProductionCompositionBuilder? _compositionBuilder;
  final CallV2ProductionReadinessAuditor _auditor;

  int _generation = 0;
  bool _disposed = false;
  CallV2StartupBridgeState _state = CallV2StartupBridgeState.idle;
  CallV2StartupRequest? _activeRequest;
  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;

  @override
  CallV2StartupBridgeState get state => _state;

  CallV2ProductionComposition get _requireComposition {
    final existing = _composition;
    if (existing != null) return existing;
    final builder = _compositionBuilder;
    if (builder == null) {
      throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
    }
    try {
      final created = builder();
      _composition = created;
      return created;
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  Future<void> start(CallV2StartupRequest request) {
    return Future<void>.sync(() {
      _requireNotDisposed();

      if (_state.status == CallV2StartupBridgeStatus.stopping) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final inFlight = _startFuture;
      final currentRequest = _activeRequest;
      if (inFlight != null && currentRequest != null) {
        if (currentRequest.matches(request)) return inFlight;
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      if (_state.status == CallV2StartupBridgeStatus.running &&
          currentRequest != null &&
          currentRequest.matches(request)) {
        return Future<void>.value();
      }
      if (_state.status == CallV2StartupBridgeStatus.running) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final composition = _requireComposition;
      if (!composition.configuration.enabled) {
        _state = const CallV2StartupBridgeState(
          status: CallV2StartupBridgeStatus.stopped,
          errorCode: CallV2ClientErrorCode.rejected,
        );
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      _verifyReadiness(composition);

      final generation = ++_generation;
      _activeRequest = request;
      _state = const CallV2StartupBridgeState(
        status: CallV2StartupBridgeStatus.starting,
      );
      final future = _start(
        generation: generation,
        composition: composition,
        request: request,
      );
      _startFuture = future;
      return future;
    });
  }

  Future<void> _start({
    required int generation,
    required CallV2ProductionComposition composition,
    required CallV2StartupRequest request,
  }) async {
    try {
      final identity =
          await composition.authIdentityProvider.requireAuthenticatedIdentity();
      _requireCurrentStart(generation, request);
      final participants = _deriveParticipants(
        authenticatedUid: identity.uid,
        request: request,
      );

      await composition.appCheckBoundary.assertAvailable();
      _requireCurrentStart(generation, request);

      final permission = await composition.permissionGateway.request(
        CallV2MediaPermissionRequest(
          requiresMicrophone: true,
          requiresCamera: request.isVideo,
        ),
      );
      _requireCurrentStart(generation, request);

      if (!permission.allRequiredGranted) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      await composition.runtime.start(
        callId: request.callId,
        callerUid: participants.callerUid,
        calleeUid: participants.calleeUid,
        localUid: identity.uid,
      );
      _requireCurrentStart(generation, request);

      _state = const CallV2StartupBridgeState(
        status: CallV2StartupBridgeStatus.running,
      );
    } on CallV2ClientError catch (error) {
      if (_isCurrentStart(generation, request)) {
        _state = CallV2StartupBridgeState(
          status: CallV2StartupBridgeStatus.failed,
          errorCode: error.code,
        );
        _activeRequest = null;
      }
      rethrow;
    } catch (_) {
      if (_isCurrentStart(generation, request)) {
        _state = const CallV2StartupBridgeState(
          status: CallV2StartupBridgeStatus.failed,
          errorCode: CallV2ClientErrorCode.unavailable,
        );
        _activeRequest = null;
      }
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    } finally {
      if (_isCurrentStart(generation, request)) {
        _startFuture = null;
      }
    }
  }

  @override
  Future<void> stop() {
    final existing = _stopFuture;
    if (existing != null) return existing;
    if (_disposed || _state.status == CallV2StartupBridgeStatus.disposed) {
      return Future<void>.value();
    }

    final composition = _composition;
    if (composition == null &&
        (_state.status == CallV2StartupBridgeStatus.idle ||
            _state.status == CallV2StartupBridgeStatus.stopped)) {
      _state = const CallV2StartupBridgeState(
        status: CallV2StartupBridgeStatus.stopped,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    _startFuture = null;
    _activeRequest = null;
    _state = const CallV2StartupBridgeState(
      status: CallV2StartupBridgeStatus.stopping,
    );
    final future = _stop(generation: generation, composition: composition);
    _stopFuture = future;
    return future;
  }

  Future<void> _stop({
    required int generation,
    required CallV2ProductionComposition? composition,
  }) async {
    CallV2ClientErrorCode? errorCode;
    try {
      await composition?.runtime.stop();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    } finally {
      if (generation == _generation) {
        _stopFuture = null;
        _state = CallV2StartupBridgeState(
          status: CallV2StartupBridgeStatus.stopped,
          errorCode: errorCode,
        );
      }
    }

    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }

  @override
  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    if (_disposed) return Future<void>.value();
    final future = _dispose();
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose() async {
    final generation = ++_generation;
    _startFuture = null;
    _activeRequest = null;

    CallV2ClientErrorCode? errorCode;
    try {
      await _stop(generation: generation, composition: _composition);
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    }

    try {
      await _composition?.dispose();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    } finally {
      _disposed = true;
      _disposeFuture = null;
      _state = CallV2StartupBridgeState(
        status: CallV2StartupBridgeStatus.disposed,
        errorCode: errorCode,
      );
    }

    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }

  void _verifyReadiness(CallV2ProductionComposition composition) {
    final readiness = _auditor.audit(
      manifest: callV2Phase3ContractManifest,
      configuration: composition.configuration,
      capabilities: callV2IsolatedStartupBridgeCapabilities,
    );
    if (!readiness.readyForAdapterImplementation) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    if (composition.configuration.environment == CallV2Environment.production &&
        !readiness.readyForProductionEnablement) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  bool _isCurrentStart(int generation, CallV2StartupRequest request) {
    return generation == _generation &&
        _activeRequest != null &&
        _activeRequest!.matches(request) &&
        _state.status == CallV2StartupBridgeStatus.starting;
  }

  void _requireCurrentStart(int generation, CallV2StartupRequest request) {
    if (!_isCurrentStart(generation, request)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _requireNotDisposed() {
    if (_disposed || _state.status == CallV2StartupBridgeStatus.disposed) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }
}

_DerivedCallParticipants _deriveParticipants({
  required String authenticatedUid,
  required CallV2StartupRequest request,
}) {
  if (authenticatedUid == request.remoteParticipantUid) {
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }

  switch (request.localRole) {
    case CallV2LocalParticipantRole.caller:
      return _DerivedCallParticipants(
        callerUid: authenticatedUid,
        calleeUid: request.remoteParticipantUid,
      );
    case CallV2LocalParticipantRole.callee:
      return _DerivedCallParticipants(
        callerUid: request.remoteParticipantUid,
        calleeUid: authenticatedUid,
      );
  }
}

class _DerivedCallParticipants {
  const _DerivedCallParticipants({
    required this.callerUid,
    required this.calleeUid,
  });

  final String callerUid;
  final String calleeUid;
}

const callV2IsolatedStartupBridgeCapabilities = CallV2ProductionCapabilities(
  callableApiAdapterAvailable: true,
  firestoreSnapshotSourceAvailable: true,
  rtcConfigProviderAvailable: true,
  rtcAdapterAvailable: true,
  authIdentitySourceAvailable: true,
  appCheckAvailable: true,
  permissionGatewayAvailable: true,
  runtimeStartupBridgeAvailable: true,
  uiRouteIntegrationAvailable: false,
  nativeCallIntegrationAvailable: false,
  observabilityAvailable: false,
);
