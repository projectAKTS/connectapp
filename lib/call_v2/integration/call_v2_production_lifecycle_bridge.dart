import 'call_v2_production_lifecycle_bridge_event.dart';
import 'call_v2_production_lifecycle_bridge_result.dart';
import 'call_v2_production_lifecycle_bridge_status.dart';
import 'call_v2_production_runtime_ui_bridge.dart';
import 'call_v2_production_runtime_ui_bridge_result.dart';

typedef CallV2ProductionLifecycleBridgeRolloutReader = bool Function();

final class CallV2ProductionLifecycleBridge {
  CallV2ProductionLifecycleBridge({
    required CallV2ProductionRuntimeUiBridge runtimeUiBridge,
    CallV2ProductionLifecycleBridgeRolloutReader? rolloutEnabled,
    bool disposeRuntimeUiBridge = true,
  })  : _runtimeUiBridge = runtimeUiBridge,
        _rolloutEnabled = rolloutEnabled ?? (() => false),
        _disposeRuntimeUiBridge = disposeRuntimeUiBridge;

  final CallV2ProductionRuntimeUiBridge _runtimeUiBridge;
  final CallV2ProductionLifecycleBridgeRolloutReader _rolloutEnabled;
  final bool _disposeRuntimeUiBridge;

  CallV2ProductionLifecycleBridgeStatus _status =
      const CallV2ProductionLifecycleBridgeStatus();

  CallV2ProductionLifecycleBridgeStatus get status => _status;

  CallV2ProductionLifecycleBridgeResult initialize() {
    final guard = _guard();
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(
        event: CallV2ProductionLifecycleBridgeEventType.initialize,
      );
    }
    return _mapRuntimeResult(
      _runtimeUiBridge.initialize(),
      event: CallV2ProductionLifecycleBridgeEventType.initialize,
    );
  }

  Future<CallV2ProductionLifecycleBridgeResult> handleEvent(
    CallV2ProductionLifecycleBridgeEvent event,
  ) async {
    final guard = _guard(generation: event.generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(
        event: event.type,
        generation: event.generation,
        cleanupPolicy: event.cleanupPolicy,
      );
    }

    return switch (event.type) {
      CallV2ProductionLifecycleBridgeEventType.initialize => initialize(),
      CallV2ProductionLifecycleBridgeEventType.appResumed => _noOp(
          event: event.type,
          generation: event.generation,
          cleanupPolicy: event.cleanupPolicy,
        ),
      CallV2ProductionLifecycleBridgeEventType.appPaused ||
      CallV2ProductionLifecycleBridgeEventType.appInactive ||
      CallV2ProductionLifecycleBridgeEventType.appHidden =>
        _applyPolicy(event),
      CallV2ProductionLifecycleBridgeEventType.appDetached =>
        _terminalCleanup(event),
      CallV2ProductionLifecycleBridgeEventType.signOutStarted =>
        _terminalCleanup(event),
      CallV2ProductionLifecycleBridgeEventType.authChanged =>
        _handleAuthChanged(event),
      CallV2ProductionLifecycleBridgeEventType.cleanupRequested =>
        _applyPolicy(event),
      CallV2ProductionLifecycleBridgeEventType.closeRequested =>
        close(generation: event.generation, event: event.type),
      CallV2ProductionLifecycleBridgeEventType.dispose => dispose(),
      CallV2ProductionLifecycleBridgeEventType.invalid => _rejected(
          CallV2ProductionLifecycleBridgeError.invalidEvent,
          event: event.type,
          generation: event.generation,
          cleanupPolicy: event.cleanupPolicy,
        ),
    };
  }

  Future<CallV2ProductionLifecycleBridgeResult> close({
    int? generation,
    CallV2ProductionLifecycleBridgeEventType event =
        CallV2ProductionLifecycleBridgeEventType.closeRequested,
  }) async {
    final guard = _guard(generation: generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(event: event, generation: generation);
    }
    return _mapRuntimeResult(
      await _runtimeUiBridge.close(generation: generation),
      event: event,
      cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeOnly,
    );
  }

  CallV2ProductionLifecycleBridgeResult dispose() {
    if (_status.disposed) {
      return const CallV2ProductionLifecycleBridgeResult.disposed();
    }
    if (_disposeRuntimeUiBridge) {
      _runtimeUiBridge.dispose();
    }
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.disposed,
      clearGeneration: true,
      disposed: true,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: CallV2ProductionLifecycleBridgeEventType.dispose,
      lastCleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeAndDispose,
      clearLastError: true,
    );
    return const CallV2ProductionLifecycleBridgeResult.disposed();
  }

  Future<CallV2ProductionLifecycleBridgeResult> _handleAuthChanged(
    CallV2ProductionLifecycleBridgeEvent event,
  ) async {
    return switch (event.authChangeReason) {
      CallV2ProductionLifecycleAuthChangeReason.signedOut ||
      CallV2ProductionLifecycleAuthChangeReason.authInvalid =>
        _terminalCleanup(event),
      CallV2ProductionLifecycleAuthChangeReason.noChange ||
      CallV2ProductionLifecycleAuthChangeReason.stillSignedIn =>
        _noOp(
          event: event.type,
          generation: event.generation,
          cleanupPolicy: event.cleanupPolicy,
        ),
      null => _rejected(
          CallV2ProductionLifecycleBridgeError.invalidEvent,
          event: event.type,
          generation: event.generation,
          cleanupPolicy: event.cleanupPolicy,
        ),
    };
  }

  Future<CallV2ProductionLifecycleBridgeResult> _applyPolicy(
    CallV2ProductionLifecycleBridgeEvent event,
  ) async {
    return switch (event.cleanupPolicy) {
      CallV2ProductionLifecycleCleanupPolicy.noOp || null => _noOp(
          event: event.type,
          generation: event.generation,
          cleanupPolicy: event.cleanupPolicy,
        ),
      CallV2ProductionLifecycleCleanupPolicy.closeOnly => close(
          generation: event.generation,
          event: event.type,
        ),
      CallV2ProductionLifecycleCleanupPolicy.closeAndDispose =>
        _closeAndDispose(event),
      CallV2ProductionLifecycleCleanupPolicy.terminalCloseAndDispose =>
        _terminalCleanup(event),
    };
  }

  Future<CallV2ProductionLifecycleBridgeResult> _closeAndDispose(
    CallV2ProductionLifecycleBridgeEvent event,
  ) async {
    final closeResult =
        await close(generation: event.generation, event: event.type);
    if (closeResult.status ==
        CallV2ProductionLifecycleBridgeResultStatus.rejected) {
      return closeResult;
    }
    if (_disposeRuntimeUiBridge) {
      _runtimeUiBridge.dispose();
    }
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.cleanedUp,
      currentGeneration: event.generation,
      disposed: true,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event.type,
      lastCleanupPolicy: event.cleanupPolicy,
      clearLastError: true,
    );
    return CallV2ProductionLifecycleBridgeResult.cleanedUp(
      generation: event.generation,
    );
  }

  Future<CallV2ProductionLifecycleBridgeResult> _terminalCleanup(
    CallV2ProductionLifecycleBridgeEvent event,
  ) async {
    final closeResult =
        await close(generation: event.generation, event: event.type);
    if (closeResult.status ==
        CallV2ProductionLifecycleBridgeResultStatus.rejected) {
      return closeResult;
    }
    if (_disposeRuntimeUiBridge) {
      _runtimeUiBridge.dispose();
    }
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.terminal,
      currentGeneration: event.generation,
      disposed: true,
      terminal: true,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event.type,
      lastCleanupPolicy: event.cleanupPolicy,
      clearLastError: true,
    );
    return CallV2ProductionLifecycleBridgeResult.terminal(
      generation: event.generation,
    );
  }

  CallV2ProductionLifecycleBridgeResult _mapRuntimeResult(
    CallV2ProductionRuntimeUiBridgeResult result, {
    required CallV2ProductionLifecycleBridgeEventType event,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    return switch (result.status) {
      CallV2ProductionRuntimeUiBridgeResultStatus.initialized => _initialized(
          event: event,
          generation: result.generation,
          cleanupPolicy: cleanupPolicy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.disabled => _disabled(
          event: event,
          generation: result.generation,
          cleanupPolicy: cleanupPolicy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.delegated => _delegated(
          event: event,
          generation: result.generation,
          cleanupPolicy: cleanupPolicy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.closed => _closed(
          event: event,
          generation: result.generation,
          cleanupPolicy: cleanupPolicy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.noOp => _noOp(
          event: event,
          generation: result.generation,
          cleanupPolicy: cleanupPolicy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.rejected => _rejected(
          _mapRuntimeError(result.error),
          event: event,
          generation: result.generation,
          cleanupPolicy: cleanupPolicy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.disposed => _disposed(
          event: event,
          cleanupPolicy: cleanupPolicy,
        ),
      CallV2ProductionRuntimeUiBridgeResultStatus.terminal => _terminal(
          event: event,
          generation: result.generation,
          cleanupPolicy: cleanupPolicy,
        ),
    };
  }

  CallV2ProductionLifecycleBridgeError _mapRuntimeError(
    CallV2ProductionRuntimeUiBridgeError? error,
  ) {
    return switch (error) {
      CallV2ProductionRuntimeUiBridgeError.rolloutDisabled =>
        CallV2ProductionLifecycleBridgeError.rolloutDisabled,
      CallV2ProductionRuntimeUiBridgeError.disposed =>
        CallV2ProductionLifecycleBridgeError.disposed,
      CallV2ProductionRuntimeUiBridgeError.terminal =>
        CallV2ProductionLifecycleBridgeError.terminal,
      null => CallV2ProductionLifecycleBridgeError.runtimeBridgeUnavailable,
      _ => CallV2ProductionLifecycleBridgeError.runtimeBridgeRejected,
    };
  }

  CallV2ProductionLifecycleBridgeResult? _guard({int? generation}) {
    if (_status.disposed) {
      return const CallV2ProductionLifecycleBridgeResult.disposed();
    }
    if (_status.terminal) {
      return CallV2ProductionLifecycleBridgeResult.terminal(
        generation: generation,
      );
    }
    if (generation != null && generation < 0) {
      return _rejected(
        CallV2ProductionLifecycleBridgeError.invalidGeneration,
        event: CallV2ProductionLifecycleBridgeEventType.invalid,
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

  CallV2ProductionLifecycleBridgeResult _initialized({
    required CallV2ProductionLifecycleBridgeEventType event,
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.initialized,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      clearLastError: true,
    );
    return CallV2ProductionLifecycleBridgeResult.initialized(
      generation: generation,
    );
  }

  CallV2ProductionLifecycleBridgeResult _disabled({
    required CallV2ProductionLifecycleBridgeEventType event,
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.disabled,
      currentGeneration: generation,
      rolloutEnabled: false,
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      lastError: CallV2ProductionLifecycleBridgeError.rolloutDisabled,
    );
    return CallV2ProductionLifecycleBridgeResult.disabled(
      generation: generation,
    );
  }

  CallV2ProductionLifecycleBridgeResult _delegated({
    required CallV2ProductionLifecycleBridgeEventType event,
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.delegated,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      clearLastError: true,
    );
    return CallV2ProductionLifecycleBridgeResult.delegated(
      generation: generation,
    );
  }

  CallV2ProductionLifecycleBridgeResult _closed({
    required CallV2ProductionLifecycleBridgeEventType event,
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.closed,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      clearLastError: true,
    );
    return CallV2ProductionLifecycleBridgeResult.closed(generation: generation);
  }

  CallV2ProductionLifecycleBridgeResult _disposed({
    required CallV2ProductionLifecycleBridgeEventType event,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.disposed,
      clearGeneration: true,
      disposed: true,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      clearLastError: true,
    );
    return const CallV2ProductionLifecycleBridgeResult.disposed();
  }

  CallV2ProductionLifecycleBridgeResult _terminal({
    required CallV2ProductionLifecycleBridgeEventType event,
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.terminal,
      currentGeneration: generation,
      terminal: true,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      clearLastError: true,
    );
    return CallV2ProductionLifecycleBridgeResult.terminal(
      generation: generation,
    );
  }

  CallV2ProductionLifecycleBridgeResult _noOp({
    required CallV2ProductionLifecycleBridgeEventType event,
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.noOp,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      clearLastError: true,
    );
    return CallV2ProductionLifecycleBridgeResult.noOp(generation: generation);
  }

  CallV2ProductionLifecycleBridgeResult _rejected(
    CallV2ProductionLifecycleBridgeError error, {
    required CallV2ProductionLifecycleBridgeEventType event,
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionLifecycleBridgeLifecycle.rejected,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastCleanupPolicy: cleanupPolicy,
      lastError: error,
    );
    return CallV2ProductionLifecycleBridgeResult.rejected(
      error,
      generation: generation,
    );
  }
}
