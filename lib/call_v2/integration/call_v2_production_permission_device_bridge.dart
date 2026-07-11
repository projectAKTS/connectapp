import 'call_v2_production_permission_device_bridge_event.dart';
import 'call_v2_production_permission_device_bridge_result.dart';
import 'call_v2_production_permission_device_bridge_status.dart';
import 'call_v2_production_runtime_ui_bridge.dart';
import 'call_v2_production_runtime_ui_bridge_event.dart';
import 'call_v2_production_runtime_ui_bridge_result.dart';

typedef CallV2ProductionPermissionDeviceBridgeRolloutReader = bool Function();

final class CallV2ProductionPermissionDeviceBridge {
  CallV2ProductionPermissionDeviceBridge({
    CallV2ProductionRuntimeUiBridge? runtimeUiBridge,
    CallV2ProductionPermissionDeviceBridgeRolloutReader? rolloutEnabled,
    bool disposeRuntimeUiBridge = false,
  })  : _runtimeUiBridge = runtimeUiBridge,
        _rolloutEnabled = rolloutEnabled ?? (() => false),
        _disposeRuntimeUiBridge = disposeRuntimeUiBridge;

  final CallV2ProductionRuntimeUiBridge? _runtimeUiBridge;
  final CallV2ProductionPermissionDeviceBridgeRolloutReader _rolloutEnabled;
  final bool _disposeRuntimeUiBridge;

  CallV2ProductionPermissionDeviceBridgeStatus _status =
      const CallV2ProductionPermissionDeviceBridgeStatus();

  CallV2ProductionPermissionDeviceBridgeStatus get status => _status;

  Future<CallV2ProductionPermissionDeviceBridgeResult> initialize({
    int? generation,
  }) async {
    final guard = _guard(generation: generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(
        event: CallV2ProductionPermissionDeviceBridgeEventType.initialize,
        generation: generation,
      );
    }
    final runtimeUiBridge = _runtimeUiBridge;
    if (runtimeUiBridge == null) {
      return _initialized(generation: generation);
    }
    return _mapRuntimeResult(
      runtimeUiBridge.initialize(),
      event: CallV2ProductionPermissionDeviceBridgeEventType.initialize,
      policy: CallV2ProductionPermissionDeviceRecoveryPolicy.noOp,
    );
  }

  Future<CallV2ProductionPermissionDeviceBridgeResult> handleEvent(
    CallV2ProductionPermissionDeviceBridgeEvent event,
  ) async {
    final guard = _guard(generation: event.generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(
        event: event.type,
        generation: event.generation,
        policy: event.recoveryPolicy,
      );
    }

    return switch (event.type) {
      CallV2ProductionPermissionDeviceBridgeEventType.initialize =>
        initialize(generation: event.generation),
      CallV2ProductionPermissionDeviceBridgeEventType.dispose =>
        Future<CallV2ProductionPermissionDeviceBridgeResult>.value(dispose()),
      CallV2ProductionPermissionDeviceBridgeEventType.invalid => Future.value(
          _rejected(
            CallV2ProductionPermissionDeviceBridgeError.invalidEvent,
            event: event.type,
            generation: event.generation,
            policy: event.recoveryPolicy,
          ),
        ),
      _ => _applyPolicy(event),
    };
  }

  Future<CallV2ProductionPermissionDeviceBridgeResult> close({
    int? generation,
    CallV2ProductionPermissionDeviceBridgeEventType event =
        CallV2ProductionPermissionDeviceBridgeEventType.closeRequested,
    CallV2ProductionPermissionDeviceRecoveryPolicy policy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.closeCall,
  }) async {
    final guard = _guard(generation: generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(event: event, generation: generation, policy: policy);
    }
    final runtimeUiBridge = _runtimeUiBridge;
    if (runtimeUiBridge == null) {
      return _closed(event: event, generation: generation, policy: policy);
    }
    return _mapRuntimeResult(
      await runtimeUiBridge.close(generation: generation),
      event: event,
      policy: policy,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult dispose() {
    if (_status.disposed) {
      return const CallV2ProductionPermissionDeviceBridgeResult.disposed();
    }
    if (_disposeRuntimeUiBridge) {
      _runtimeUiBridge?.dispose();
    }
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.disposed,
      disposed: true,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: CallV2ProductionPermissionDeviceBridgeEventType.dispose,
      lastRecoveryPolicy:
          CallV2ProductionPermissionDeviceRecoveryPolicy.terminalClose,
      clearLastError: true,
    );
    return const CallV2ProductionPermissionDeviceBridgeResult.disposed();
  }

  Future<CallV2ProductionPermissionDeviceBridgeResult> _applyPolicy(
    CallV2ProductionPermissionDeviceBridgeEvent event,
  ) async {
    return switch (event.recoveryPolicy) {
      CallV2ProductionPermissionDeviceRecoveryPolicy.noOp || null => _noOp(
          event: event.type,
          generation: event.generation,
          policy: event.recoveryPolicy,
        ),
      CallV2ProductionPermissionDeviceRecoveryPolicy.showControlledFailure =>
        _delegateControlledFailure(event),
      CallV2ProductionPermissionDeviceRecoveryPolicy.closeCall => close(
          generation: event.generation,
          event: event.type,
          policy: CallV2ProductionPermissionDeviceRecoveryPolicy.closeCall,
        ),
      CallV2ProductionPermissionDeviceRecoveryPolicy.terminalClose =>
        _terminalClose(event),
      CallV2ProductionPermissionDeviceRecoveryPolicy.retryAllowed => _noOp(
          event: event.type,
          generation: event.generation,
          policy: event.recoveryPolicy,
        ),
      CallV2ProductionPermissionDeviceRecoveryPolicy
            .retryBlockedUntilUserAction =>
        _rejected(
          CallV2ProductionPermissionDeviceBridgeError.userActionRequired,
          event: event.type,
          generation: event.generation,
          policy: event.recoveryPolicy,
        ),
    };
  }

  Future<CallV2ProductionPermissionDeviceBridgeResult>
      _delegateControlledFailure(
    CallV2ProductionPermissionDeviceBridgeEvent event,
  ) async {
    final runtimeUiBridge = _runtimeUiBridge;
    if (runtimeUiBridge == null) {
      return _rejected(
        CallV2ProductionPermissionDeviceBridgeError.runtimeBridgeUnavailable,
        event: event.type,
        generation: event.generation,
        policy: event.recoveryPolicy,
      );
    }
    final generation = event.generation;
    if (generation == null) {
      return _rejected(
        CallV2ProductionPermissionDeviceBridgeError.invalidGeneration,
        event: event.type,
        policy: event.recoveryPolicy,
      );
    }
    return _mapRuntimeResult(
      await runtimeUiBridge.handleEvent(
        CallV2ProductionRuntimeUiBridgeEvent.runtimeFailedControlled(
          failure: CallV2ProductionRuntimeUiBridgeControlledFailure.unavailable,
          generation: generation,
        ),
      ),
      event: event.type,
      policy: event.recoveryPolicy,
    );
  }

  Future<CallV2ProductionPermissionDeviceBridgeResult> _terminalClose(
    CallV2ProductionPermissionDeviceBridgeEvent event,
  ) async {
    final runtimeUiBridge = _runtimeUiBridge;
    final generation = event.generation;
    if (runtimeUiBridge == null) {
      _status = _status.copyWith(
        lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.terminal,
        currentGeneration: generation,
        disposed: true,
        terminal: true,
        rolloutEnabled: true,
        lastEvent: event.type,
        lastRecoveryPolicy: event.recoveryPolicy,
        clearLastError: true,
      );
      return CallV2ProductionPermissionDeviceBridgeResult.terminal(
        generation: generation,
      );
    }
    if (generation == null) {
      return _rejected(
        CallV2ProductionPermissionDeviceBridgeError.invalidGeneration,
        event: event.type,
        policy: event.recoveryPolicy,
      );
    }
    return _mapRuntimeResult(
      await runtimeUiBridge.handleEvent(
        CallV2ProductionRuntimeUiBridgeEvent.runtimeTerminated(
          generation: generation,
        ),
      ),
      event: event.type,
      policy: event.recoveryPolicy,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult _mapRuntimeResult(
    CallV2ProductionRuntimeUiBridgeResult result, {
    required CallV2ProductionPermissionDeviceBridgeEventType event,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    return switch (result.status) {
      CallV2ProductionRuntimeUiBridgeResultStatus.initialized => _initialized(
          event: event,
          generation: result.generation,
          policy: policy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.disabled => _disabled(
          event: event,
          generation: result.generation,
          policy: policy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.delegated => _delegated(
          event: event,
          generation: result.generation,
          policy: policy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.closed => _closed(
          event: event,
          generation: result.generation,
          policy: policy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.noOp => _noOp(
          event: event,
          generation: result.generation,
          policy: policy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.rejected => _rejected(
          _mapRuntimeError(result.error),
          event: event,
          generation: result.generation,
          policy: policy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.disposed => dispose(),
      CallV2ProductionRuntimeUiBridgeResultStatus.terminal => _terminal(
          event: event,
          generation: result.generation,
          policy: policy,
        ),
    };
  }

  CallV2ProductionPermissionDeviceBridgeError _mapRuntimeError(
    CallV2ProductionRuntimeUiBridgeError? error,
  ) {
    return switch (error) {
      CallV2ProductionRuntimeUiBridgeError.rolloutDisabled =>
        CallV2ProductionPermissionDeviceBridgeError.rolloutDisabled,
      CallV2ProductionRuntimeUiBridgeError.disposed =>
        CallV2ProductionPermissionDeviceBridgeError.disposed,
      CallV2ProductionRuntimeUiBridgeError.terminal =>
        CallV2ProductionPermissionDeviceBridgeError.terminal,
      CallV2ProductionRuntimeUiBridgeError.staleGeneration =>
        CallV2ProductionPermissionDeviceBridgeError.staleGeneration,
      null => CallV2ProductionPermissionDeviceBridgeError.runtimeBridgeRejected,
      _ => CallV2ProductionPermissionDeviceBridgeError.runtimeBridgeRejected,
    };
  }

  CallV2ProductionPermissionDeviceBridgeResult? _guard({int? generation}) {
    if (_status.disposed) {
      return const CallV2ProductionPermissionDeviceBridgeResult.disposed();
    }
    if (_status.terminal) {
      return CallV2ProductionPermissionDeviceBridgeResult.terminal(
        generation: generation,
      );
    }
    if (generation != null && generation < 0) {
      return _rejected(
        CallV2ProductionPermissionDeviceBridgeError.invalidGeneration,
        generation: generation,
      );
    }
    if (_isStale(generation)) {
      return _rejected(
        CallV2ProductionPermissionDeviceBridgeError.staleGeneration,
        generation: generation,
      );
    }
    return null;
  }

  bool _safeRolloutEnabled() {
    try {
      return _rolloutEnabled();
    } catch (_) {
      return false;
    }
  }

  bool _isStale(int? generation) {
    final currentGeneration = _status.currentGeneration;
    return generation != null &&
        currentGeneration != null &&
        generation < currentGeneration;
  }

  CallV2ProductionPermissionDeviceBridgeResult _initialized({
    CallV2ProductionPermissionDeviceBridgeEventType? event,
    int? generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.initialized,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastRecoveryPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionPermissionDeviceBridgeResult.initialized(
      generation: generation,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult _disabled({
    CallV2ProductionPermissionDeviceBridgeEventType? event,
    int? generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.disabled,
      currentGeneration: generation,
      rolloutEnabled: false,
      lastEvent: event,
      lastRecoveryPolicy: policy,
      lastError: CallV2ProductionPermissionDeviceBridgeError.rolloutDisabled,
    );
    return CallV2ProductionPermissionDeviceBridgeResult.disabled(
      generation: generation,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult _delegated({
    required CallV2ProductionPermissionDeviceBridgeEventType event,
    int? generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.delegated,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastRecoveryPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionPermissionDeviceBridgeResult.delegated(
      generation: generation,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult _closed({
    required CallV2ProductionPermissionDeviceBridgeEventType event,
    int? generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.closed,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastRecoveryPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionPermissionDeviceBridgeResult.closed(
      generation: generation,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult _noOp({
    required CallV2ProductionPermissionDeviceBridgeEventType event,
    int? generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.noOp,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastRecoveryPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionPermissionDeviceBridgeResult.noOp(
      generation: generation,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult _rejected(
    CallV2ProductionPermissionDeviceBridgeError error, {
    CallV2ProductionPermissionDeviceBridgeEventType? event,
    int? generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.rejected,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastRecoveryPolicy: policy,
      lastError: error,
    );
    return CallV2ProductionPermissionDeviceBridgeResult.rejected(
      error,
      generation: generation,
    );
  }

  CallV2ProductionPermissionDeviceBridgeResult _terminal({
    required CallV2ProductionPermissionDeviceBridgeEventType event,
    int? generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionPermissionDeviceBridgeLifecycle.terminal,
      currentGeneration: generation,
      disposed: true,
      terminal: true,
      rolloutEnabled: true,
      lastEvent: event,
      lastRecoveryPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionPermissionDeviceBridgeResult.terminal(
      generation: generation,
    );
  }
}
