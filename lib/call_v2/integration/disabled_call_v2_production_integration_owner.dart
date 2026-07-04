import '../call_v2_api.dart';
import '../production/call_v2_pre_integration_gate.dart';
import '../production/call_v2_production_integration_approval.dart';
import 'call_v2_production_integration_owner.dart';
import 'call_v2_production_integration_status.dart';
import 'call_v2_rollout_policy.dart';

typedef CallV2RolloutEnabledReader = bool Function();

class DisabledCallV2ProductionIntegrationOwner
    implements CallV2ProductionIntegrationOwner {
  DisabledCallV2ProductionIntegrationOwner({
    CallV2RolloutEnabledReader? rolloutEnabled,
    CallV2PreIntegrationGate preIntegrationGate =
        const CallV2PreIntegrationGate(),
    CallV2ProductionIntegrationApproval approval =
        const CallV2ProductionIntegrationApproval(),
    CallV2ProductionIntegrationCompositionFactory? compositionFactory,
  })  : _rolloutEnabled =
            rolloutEnabled ?? (() => CallV2RolloutPolicy.productionEnabled),
        _preIntegrationGate = preIntegrationGate,
        _approval = approval,
        _compositionFactory = compositionFactory;

  final CallV2RolloutEnabledReader _rolloutEnabled;
  final CallV2PreIntegrationGate _preIntegrationGate;
  final CallV2ProductionIntegrationApproval _approval;
  final CallV2ProductionIntegrationCompositionFactory? _compositionFactory;

  var _status = CallV2ProductionIntegrationStatus.uninitialized;
  var _generation = 0;
  var _disposed = false;
  Future<void>? _initializeFuture;
  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  Future<void>? _disposeFuture;

  @override
  CallV2ProductionIntegrationStatus get status => _status;

  @override
  Future<void> initialize() {
    return Future<void>.sync(() {
      _requireNotDisposed();
      final inFlight = _initializeFuture;
      if (inFlight != null) return inFlight;
      if (_status.lifecycle == CallV2ProductionIntegrationLifecycle.disabled) {
        return Future<void>.value();
      }

      final generation = ++_generation;
      final future = _initialize(generation).whenComplete(() {
        if (generation == _generation) {
          _initializeFuture = null;
        }
      });
      _initializeFuture = future;
      return future;
    });
  }

  Future<void> _initialize(int generation) async {
    try {
      await Future<void>.value();
      _requireCurrent(generation);
      final rolloutEnabled = _safeRolloutEnabled();
      final gate = _preIntegrationGate.evaluate(approval: _approval);
      _requireCurrent(generation);

      if (!rolloutEnabled || !gate.actualIntegrationAuthorized) {
        _status = CallV2ProductionIntegrationStatus(
          lifecycle: CallV2ProductionIntegrationLifecycle.disabled,
          rolloutEnabled: rolloutEnabled,
          compositionConstructed: false,
          runtimeStarted: false,
          routesRegistered: false,
          screensAvailable: false,
        );
        return;
      }

      _status = CallV2ProductionIntegrationStatus(
        lifecycle: CallV2ProductionIntegrationLifecycle.initialized,
        rolloutEnabled: rolloutEnabled,
        compositionConstructed: false,
        runtimeStarted: false,
        routesRegistered: false,
        screensAvailable: false,
      );
    } on CallV2ClientError catch (error) {
      _failIfCurrent(generation, error.code);
      rethrow;
    } catch (_) {
      _failIfCurrent(generation, CallV2ClientErrorCode.unavailable);
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  Future<void> start() {
    return Future<void>.sync(() {
      _requireNotDisposed();
      final inFlight = _startFuture;
      if (inFlight != null) return inFlight;
      final generation = _generation;
      final future = _rejectStart(generation).whenComplete(() {
        if (generation == _generation) {
          _startFuture = null;
        }
      });
      _startFuture = future;
      return future;
    });
  }

  Future<void> _rejectStart(int generation) async {
    try {
      await Future<void>.value();
      _requireCurrent(generation);
      final rolloutEnabled = _safeRolloutEnabled();
      _requireCurrent(generation);
      _status = CallV2ProductionIntegrationStatus(
        lifecycle: rolloutEnabled
            ? CallV2ProductionIntegrationLifecycle.initialized
            : CallV2ProductionIntegrationLifecycle.disabled,
        errorCode: CallV2ClientErrorCode.rejected,
        rolloutEnabled: rolloutEnabled,
        compositionConstructed: false,
        runtimeStarted: false,
        routesRegistered: false,
        screensAvailable: false,
      );
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      _failIfCurrent(generation, CallV2ClientErrorCode.unavailable);
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  Future<void> stop() {
    return Future<void>.sync(() {
      if (_disposed ||
          _status.lifecycle == CallV2ProductionIntegrationLifecycle.disposed) {
        return Future<void>.value();
      }
      final inFlight = _stopFuture;
      if (inFlight != null) return inFlight;

      final generation = ++_generation;
      _initializeFuture = null;
      _startFuture = null;
      final future = _stop(generation).whenComplete(() {
        if (generation == _generation) {
          _stopFuture = null;
        }
      });
      _stopFuture = future;
      return future;
    });
  }

  Future<void> _stop(int generation) async {
    try {
      await Future<void>.value();
      _requireCurrent(generation);
      final rolloutEnabled = _safeRolloutEnabled();
      _requireCurrent(generation);
      _status = CallV2ProductionIntegrationStatus(
        lifecycle: rolloutEnabled
            ? CallV2ProductionIntegrationLifecycle.stopped
            : CallV2ProductionIntegrationLifecycle.disabled,
        rolloutEnabled: rolloutEnabled,
        compositionConstructed: false,
        runtimeStarted: false,
        routesRegistered: false,
        screensAvailable: false,
      );
    } catch (_) {
      _failIfCurrent(generation, CallV2ClientErrorCode.unavailable);
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  Future<void> dispose() {
    final inFlight = _disposeFuture;
    if (inFlight != null) return inFlight;
    if (_disposed ||
        _status.lifecycle == CallV2ProductionIntegrationLifecycle.disposed) {
      return Future<void>.value();
    }

    final generation = ++_generation;
    _initializeFuture = null;
    _startFuture = null;
    _stopFuture = null;
    final future = _dispose(generation).whenComplete(() {
      _disposeFuture = null;
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose(int generation) async {
    _disposed = true;
    if (generation == _generation) {
      _status = CallV2ProductionIntegrationStatus(
        lifecycle: CallV2ProductionIntegrationLifecycle.disposed,
        rolloutEnabled: _safeRolloutEnabled(),
        compositionConstructed: false,
        runtimeStarted: false,
        routesRegistered: false,
        screensAvailable: false,
      );
    }
  }

  bool _safeRolloutEnabled() {
    try {
      return _rolloutEnabled();
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  void _requireNotDisposed() {
    if (_disposed ||
        _status.lifecycle == CallV2ProductionIntegrationLifecycle.disposed) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _requireCurrent(int generation) {
    if (_disposed || generation != _generation) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _failIfCurrent(int generation, CallV2ClientErrorCode errorCode) {
    if (_disposed || generation != _generation) return;
    _status = CallV2ProductionIntegrationStatus(
      lifecycle: CallV2ProductionIntegrationLifecycle.failed,
      errorCode: errorCode,
      rolloutEnabled: false,
      compositionConstructed: false,
      runtimeStarted: false,
      routesRegistered: false,
      screensAvailable: false,
    );
  }

  // Kept only to make the eventual production boundary explicit and injectable.
  // The disabled implementation must not invoke it while rollout is closed.
  CallV2ProductionIntegrationCompositionFactory?
      get compositionFactoryForTest => _compositionFactory;
}
