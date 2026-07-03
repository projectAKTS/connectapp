import 'dart:async';

import '../call_v2_api.dart';
import '../call_v2_contract_manifest.dart';
import '../call_v2_feature_gate.dart';
import '../call_v2_production_capabilities.dart';
import '../call_v2_production_readiness.dart';
import '../call_v2_runtime_configuration.dart';
import '../startup/call_v2_startup_bridge.dart';
import 'call_v2_route_intent.dart';
import 'call_v2_ui_capabilities.dart';
import 'call_v2_ui_integration.dart';

class ProductionCallV2UiCoordinator implements CallV2UiCoordinator {
  ProductionCallV2UiCoordinator({
    required CallV2FeatureGate featureGate,
    required CallV2StartupBridge startupBridge,
    required CallV2RuntimeConfiguration configuration,
    CallV2ProductionCapabilities capabilities =
        callV2IsolatedUiRouteIntegrationCapabilities,
    CallV2ProductionReadinessAuditor auditor =
        const CallV2ProductionReadinessAuditor(),
    bool ownsStartupBridge = false,
  })  : _featureGate = featureGate,
        _startupBridge = startupBridge,
        _configuration = configuration,
        _capabilities = capabilities,
        _auditor = auditor,
        _ownsStartupBridge = ownsStartupBridge;

  final CallV2FeatureGate _featureGate;
  final CallV2StartupBridge _startupBridge;
  final CallV2RuntimeConfiguration _configuration;
  final CallV2ProductionCapabilities _capabilities;
  final CallV2ProductionReadinessAuditor _auditor;
  final bool _ownsStartupBridge;

  final StreamController<CallV2UiState> _states =
      StreamController<CallV2UiState>.broadcast(sync: true);
  final StreamController<CallV2RouteIntent> _routeIntents =
      StreamController<CallV2RouteIntent>.broadcast(sync: true);

  int _generation = 0;
  bool _disposed = false;
  bool _closeIntentEmitted = false;
  CallV2UiState _state = CallV2UiState.idle;
  CallV2UiLaunchRequest? _activeLaunchRequest;
  Future<void>? _launchFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;

  @override
  CallV2UiState get state => _state;

  @override
  Stream<CallV2UiState> get states => _states.stream;

  @override
  Stream<CallV2RouteIntent> get routeIntents => _routeIntents.stream;

  @override
  Future<void> launch(CallV2UiLaunchRequest request) {
    try {
      _requireNotDisposed();
      if (!_featureGate.enabled) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      _verifyReadiness();
      if (_state.status == CallV2UiStatus.leaving) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final inFlight = _launchFuture;
      final activeRequest = _activeLaunchRequest;
      if (inFlight != null && activeRequest != null) {
        if (activeRequest.matches(request)) return inFlight;
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      if (_state.status == CallV2UiStatus.ready && activeRequest != null) {
        if (activeRequest.matches(request)) return Future<void>.value();
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      if (_state.status == CallV2UiStatus.connecting ||
          _state.status == CallV2UiStatus.launching) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final generation = ++_generation;
      _activeLaunchRequest = request;
      _closeIntentEmitted = false;
      _emitState(const CallV2UiState(status: CallV2UiStatus.connecting));
      _emitRouteIntent(const CallV2OpenConnectingRoute());
      final future = _launch(
        generation: generation,
        request: request,
      );
      _launchFuture = future;
      return future;
    } on CallV2ClientError catch (error) {
      return Future<void>.error(error);
    } catch (_) {
      return Future<void>.error(
        const CallV2ClientError(CallV2ClientErrorCode.unavailable),
      );
    }
  }

  Future<void> _launch({
    required int generation,
    required CallV2UiLaunchRequest request,
  }) async {
    try {
      await _startupBridge.start(request.toStartupRequest());
      _requireCurrentLaunch(generation, request);
      _emitState(const CallV2UiState(status: CallV2UiStatus.ready));
      _emitRouteIntent(const CallV2OpenReadyCallRoute());
    } on CallV2ClientError catch (error) {
      if (_isCurrentLaunch(generation, request)) {
        _activeLaunchRequest = null;
        _emitState(CallV2UiState(
          status: CallV2UiStatus.failed,
          errorCode: error.code,
        ));
        _emitRouteIntent(CallV2ShowControlledFailure(errorCode: error.code));
      }
      rethrow;
    } catch (_) {
      if (_isCurrentLaunch(generation, request)) {
        _activeLaunchRequest = null;
        _emitState(const CallV2UiState(
          status: CallV2UiStatus.failed,
          errorCode: CallV2ClientErrorCode.unavailable,
        ));
        _emitRouteIntent(const CallV2ShowControlledFailure(
          errorCode: CallV2ClientErrorCode.unavailable,
        ));
      }
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    } finally {
      if (_isCurrentLaunch(generation, request)) {
        _launchFuture = null;
      }
    }
  }

  @override
  Future<void> leave() {
    final existing = _leaveFuture;
    if (existing != null) return existing;
    if (_disposed || _state.status == CallV2UiStatus.disposed) {
      return Future<void>.value();
    }
    if (_state.status == CallV2UiStatus.closed && _closeIntentEmitted) {
      return Future<void>.value();
    }

    final generation = ++_generation;
    _launchFuture = null;
    _activeLaunchRequest = null;
    _emitState(const CallV2UiState(status: CallV2UiStatus.leaving));
    final future = _leave(generation: generation);
    _leaveFuture = future;
    return future;
  }

  Future<void> _leave({required int generation}) async {
    CallV2ClientErrorCode? errorCode;
    try {
      await _startupBridge.stop();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    } finally {
      if (generation == _generation && !_disposed) {
        _leaveFuture = null;
        _emitState(CallV2UiState(
          status: CallV2UiStatus.closed,
          errorCode: errorCode,
        ));
        _emitCloseRouteOnce();
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
    _launchFuture = null;
    _activeLaunchRequest = null;
    CallV2ClientErrorCode? errorCode;

    _emitState(const CallV2UiState(status: CallV2UiStatus.leaving));
    try {
      await _startupBridge.stop();
    } on CallV2ClientError catch (error) {
      errorCode ??= error.code;
    } catch (_) {
      errorCode ??= CallV2ClientErrorCode.unavailable;
    }

    if (_ownsStartupBridge) {
      try {
        await _startupBridge.dispose();
      } on CallV2ClientError catch (error) {
        errorCode ??= error.code;
      } catch (_) {
        errorCode ??= CallV2ClientErrorCode.unavailable;
      }
    }

    if (generation == _generation) {
      _disposed = true;
      _leaveFuture = null;
      _disposeFuture = null;
      _state = CallV2UiState(
        status: CallV2UiStatus.disposed,
        errorCode: errorCode,
      );
      if (!_states.isClosed) {
        _states.add(_state);
      }
      await _states.close();
      await _routeIntents.close();
    }

    if (errorCode != null) {
      throw CallV2ClientError(errorCode);
    }
  }

  void _verifyReadiness() {
    if (_configuration.enabled &&
        _configuration.environment == CallV2Environment.production) {
      final readiness = _auditor.audit(
        manifest: callV2Phase3ContractManifest,
        configuration: _configuration,
        capabilities: _capabilities,
      );
      if (!readiness.readyForProductionEnablement) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
    }
  }

  bool _isCurrentLaunch(
    int generation,
    CallV2UiLaunchRequest request,
  ) {
    return generation == _generation &&
        _activeLaunchRequest != null &&
        _activeLaunchRequest!.matches(request) &&
        !_disposed &&
        _state.status == CallV2UiStatus.connecting;
  }

  void _requireCurrentLaunch(
    int generation,
    CallV2UiLaunchRequest request,
  ) {
    if (!_isCurrentLaunch(generation, request)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _emitState(CallV2UiState state) {
    if (_disposed || _states.isClosed) return;
    _state = state;
    _states.add(state);
  }

  void _emitRouteIntent(CallV2RouteIntent intent) {
    if (_disposed || _routeIntents.isClosed) return;
    _routeIntents.add(intent);
  }

  void _emitCloseRouteOnce() {
    if (_closeIntentEmitted) return;
    _closeIntentEmitted = true;
    _emitRouteIntent(const CallV2CloseCallFlow());
  }

  void _requireNotDisposed() {
    if (_disposed || _state.status == CallV2UiStatus.disposed) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }
}
