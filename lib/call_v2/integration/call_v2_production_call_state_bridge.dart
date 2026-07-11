import '../ui/call_v2_production_presentation_snapshot.dart';
import '../ui/call_v2_production_view_state.dart';
import '../ui/call_v2_ui_session_reference.dart';
import 'call_v2_production_call_state_bridge_event.dart';
import 'call_v2_production_call_state_bridge_result.dart';
import 'call_v2_production_call_state_bridge_status.dart';
import 'call_v2_production_runtime_ui_bridge.dart';
import 'call_v2_production_runtime_ui_bridge_event.dart';
import 'call_v2_production_runtime_ui_bridge_result.dart';

typedef CallV2ProductionCallStateBridgeRolloutReader = bool Function();

final class CallV2ProductionCallStateBridge {
  CallV2ProductionCallStateBridge({
    CallV2ProductionRuntimeUiBridge? runtimeUiBridge,
    CallV2ProductionCallStateBridgeRolloutReader? rolloutEnabled,
    bool disposeRuntimeUiBridge = false,
  })  : _runtimeUiBridge = runtimeUiBridge,
        _rolloutEnabled = rolloutEnabled ?? (() => false),
        _disposeRuntimeUiBridge = disposeRuntimeUiBridge;

  final CallV2ProductionRuntimeUiBridge? _runtimeUiBridge;
  final CallV2ProductionCallStateBridgeRolloutReader _rolloutEnabled;
  final bool _disposeRuntimeUiBridge;

  CallV2ProductionCallStateBridgeStatus _status =
      const CallV2ProductionCallStateBridgeStatus();

  CallV2ProductionCallStateBridgeStatus get status => _status;

  Future<CallV2ProductionCallStateBridgeResult> initialize({
    int? generation,
  }) async {
    final guard = _guard(generation: generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(
        event: CallV2ProductionCallStateBridgeEventType.initialize,
        generation: generation,
      );
    }
    final runtimeUiBridge = _runtimeUiBridge;
    if (runtimeUiBridge == null) {
      return _initialized(generation: generation);
    }
    return _mapRuntimeResult(
      runtimeUiBridge.initialize(),
      event: CallV2ProductionCallStateBridgeEventType.initialize,
      policy: CallV2ProductionCallStateConsistencyPolicy.noOp,
    );
  }

  Future<CallV2ProductionCallStateBridgeResult> handleEvent(
    CallV2ProductionCallStateBridgeEvent event,
  ) async {
    final guard = _guard(generation: event.generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) {
      return _disabled(
        event: event.type,
        generation: event.generation,
        policy: event.consistencyPolicy,
      );
    }

    return switch (event.type) {
      CallV2ProductionCallStateBridgeEventType.initialize =>
        initialize(generation: event.generation),
      CallV2ProductionCallStateBridgeEventType.dispose =>
        Future<CallV2ProductionCallStateBridgeResult>.value(dispose()),
      CallV2ProductionCallStateBridgeEventType.invalid => Future.value(
          _rejected(
            CallV2ProductionCallStateBridgeError.invalidEvent,
            event: event.type,
            generation: event.generation,
            policy: event.consistencyPolicy,
          ),
        ),
      CallV2ProductionCallStateBridgeEventType.ownershipMismatch =>
        Future.value(
          _rejected(
            CallV2ProductionCallStateBridgeError.ownershipMismatch,
            event: event.type,
            generation: event.generation,
            policy: event.consistencyPolicy,
          ),
        ),
      CallV2ProductionCallStateBridgeEventType.staleSnapshot => Future.value(
          _rejected(
            CallV2ProductionCallStateBridgeError.staleGeneration,
            event: event.type,
            generation: event.generation,
            policy: event.consistencyPolicy,
          ),
        ),
      CallV2ProductionCallStateBridgeEventType.duplicateSnapshot =>
        Future.value(
          _noOp(
            event: event.type,
            generation: event.generation,
            policy: event.consistencyPolicy,
          ),
        ),
      _ => _applyPolicy(event),
    };
  }

  Future<CallV2ProductionCallStateBridgeResult> close({
    int? generation,
    CallV2ProductionCallStateBridgeEventType event =
        CallV2ProductionCallStateBridgeEventType.closeRequested,
    CallV2ProductionCallStateConsistencyPolicy policy =
        CallV2ProductionCallStateConsistencyPolicy.closeCall,
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

  CallV2ProductionCallStateBridgeResult dispose() {
    if (_status.disposed) {
      return const CallV2ProductionCallStateBridgeResult.disposed();
    }
    if (_disposeRuntimeUiBridge) {
      _runtimeUiBridge?.dispose();
    }
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.disposed,
      disposed: true,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: CallV2ProductionCallStateBridgeEventType.dispose,
      lastConsistencyPolicy: CallV2ProductionCallStateConsistencyPolicy.noOp,
      clearLastError: true,
    );
    return const CallV2ProductionCallStateBridgeResult.disposed();
  }

  Future<CallV2ProductionCallStateBridgeResult> _applyPolicy(
    CallV2ProductionCallStateBridgeEvent event,
  ) async {
    return switch (event.consistencyPolicy) {
      CallV2ProductionCallStateConsistencyPolicy.noOp || null => _noOp(
          event: event.type,
          generation: event.generation,
          policy: event.consistencyPolicy,
        ),
      CallV2ProductionCallStateConsistencyPolicy.delegateSnapshot =>
        _delegateSnapshot(event),
      CallV2ProductionCallStateConsistencyPolicy.closeCall => close(
          generation: event.generation,
          event: event.type,
          policy: CallV2ProductionCallStateConsistencyPolicy.closeCall,
        ),
      CallV2ProductionCallStateConsistencyPolicy.terminalClose =>
        _terminalClose(event),
      CallV2ProductionCallStateConsistencyPolicy.controlledFailure =>
        _delegateControlledFailure(event),
      CallV2ProductionCallStateConsistencyPolicy.rejectStale => _rejected(
          CallV2ProductionCallStateBridgeError.staleGeneration,
          event: event.type,
          generation: event.generation,
          policy: event.consistencyPolicy,
        ),
      CallV2ProductionCallStateConsistencyPolicy.rejectOwnershipMismatch =>
        _rejected(
          CallV2ProductionCallStateBridgeError.ownershipMismatch,
          event: event.type,
          generation: event.generation,
          policy: event.consistencyPolicy,
        ),
      CallV2ProductionCallStateConsistencyPolicy.requireCredentialRefresh =>
        _rejected(
          CallV2ProductionCallStateBridgeError.credentialRefreshRequired,
          event: event.type,
          generation: event.generation,
          policy: event.consistencyPolicy,
        ),
      CallV2ProductionCallStateConsistencyPolicy.blockDuplicate => _noOp(
          event: event.type,
          generation: event.generation,
          policy: event.consistencyPolicy,
        ),
    };
  }

  Future<CallV2ProductionCallStateBridgeResult> _delegateSnapshot(
    CallV2ProductionCallStateBridgeEvent event,
  ) async {
    final runtimeUiBridge = _runtimeUiBridge;
    if (runtimeUiBridge == null) {
      return _noOp(
        event: event.type,
        generation: event.generation,
        policy: event.consistencyPolicy,
      );
    }
    final snapshot = _snapshotFor(event);
    if (snapshot == null) {
      return _rejected(
        CallV2ProductionCallStateBridgeError.unsupportedEvent,
        event: event.type,
        generation: event.generation,
        policy: event.consistencyPolicy,
      );
    }
    return _mapRuntimeResult(
      await runtimeUiBridge.handleEvent(
        CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(snapshot),
      ),
      event: event.type,
      policy: event.consistencyPolicy,
    );
  }

  Future<CallV2ProductionCallStateBridgeResult> _delegateControlledFailure(
    CallV2ProductionCallStateBridgeEvent event,
  ) async {
    final runtimeUiBridge = _runtimeUiBridge;
    final generation = event.generation;
    if (runtimeUiBridge == null) {
      return _rejected(
        CallV2ProductionCallStateBridgeError.runtimeBridgeUnavailable,
        event: event.type,
        generation: generation,
        policy: event.consistencyPolicy,
      );
    }
    if (generation == null) {
      return _rejected(
        CallV2ProductionCallStateBridgeError.invalidGeneration,
        event: event.type,
        policy: event.consistencyPolicy,
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
      policy: event.consistencyPolicy,
    );
  }

  Future<CallV2ProductionCallStateBridgeResult> _terminalClose(
    CallV2ProductionCallStateBridgeEvent event,
  ) async {
    final runtimeUiBridge = _runtimeUiBridge;
    final generation = event.generation;
    if (runtimeUiBridge == null) {
      _status = _status.copyWith(
        lifecycle: CallV2ProductionCallStateBridgeLifecycle.terminal,
        currentGeneration: generation,
        disposed: true,
        terminal: true,
        rolloutEnabled: true,
        lastEvent: event.type,
        lastConsistencyPolicy: event.consistencyPolicy,
        clearLastError: true,
      );
      return CallV2ProductionCallStateBridgeResult.terminal(
        generation: generation,
      );
    }
    if (generation == null) {
      return _rejected(
        CallV2ProductionCallStateBridgeError.invalidGeneration,
        event: event.type,
        policy: event.consistencyPolicy,
      );
    }
    return _mapRuntimeResult(
      await runtimeUiBridge.handleEvent(
        CallV2ProductionRuntimeUiBridgeEvent.runtimeTerminated(
          generation: generation,
        ),
      ),
      event: event.type,
      policy: event.consistencyPolicy,
    );
  }

  CallV2ProductionPresentationSnapshot? _snapshotFor(
    CallV2ProductionCallStateBridgeEvent event,
  ) {
    final generation = event.generation;
    if (generation == null || generation < 0) return null;
    return switch (event.type) {
      CallV2ProductionCallStateBridgeEventType.localJoinRequested ||
      CallV2ProductionCallStateBridgeEventType.backendRinging ||
      CallV2ProductionCallStateBridgeEventType.backendAccepted =>
        CallV2ProductionPresentationSnapshot.connecting(
          sessionReference: _sessionReference(
            generation: generation,
            localLifecycleStatus:
                CallV2ProductionLocalLifecycleStatus.connecting,
            connectionPhase: CallV2ProductionConnectionPhase.connecting,
          ),
          screenState: const CallV2ProductionConnectingScreenState(
            mediaMode: CallV2ProductionMediaMode.audio,
            cancelAvailable: false,
            connectionPhase: CallV2ProductionConnectionPhase.connecting,
          ),
        ),
      CallV2ProductionCallStateBridgeEventType.backendConnected ||
      CallV2ProductionCallStateBridgeEventType.remoteReconnected =>
        CallV2ProductionPresentationSnapshot.activeAudio(
          sessionReference: _sessionReference(
            generation: generation,
            localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
            connectionPhase: CallV2ProductionConnectionPhase.connected,
          ),
          screenState: const CallV2ProductionActiveAudioScreenState(
            muted: false,
            speakerEnabled: false,
            leaveEnabled: true,
            connectionPhase: CallV2ProductionConnectionPhase.connected,
            elapsedSeconds: 0,
            reconnecting: false,
          ),
        ),
      _ => null,
    };
  }

  CallV2UiSessionReference _sessionReference({
    required int generation,
    required CallV2ProductionLocalLifecycleStatus localLifecycleStatus,
    required CallV2ProductionConnectionPhase connectionPhase,
  }) {
    return CallV2UiSessionReference(
      generation: generation,
      mediaMode: CallV2ProductionMediaMode.audio,
      localLifecycleStatus: localLifecycleStatus,
      connectionPhase: connectionPhase,
    );
  }

  CallV2ProductionCallStateBridgeResult _mapRuntimeResult(
    CallV2ProductionRuntimeUiBridgeResult result, {
    required CallV2ProductionCallStateBridgeEventType event,
    CallV2ProductionCallStateConsistencyPolicy? policy,
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

  CallV2ProductionCallStateBridgeError _mapRuntimeError(
    CallV2ProductionRuntimeUiBridgeError? error,
  ) {
    return switch (error) {
      CallV2ProductionRuntimeUiBridgeError.rolloutDisabled =>
        CallV2ProductionCallStateBridgeError.rolloutDisabled,
      CallV2ProductionRuntimeUiBridgeError.disposed =>
        CallV2ProductionCallStateBridgeError.disposed,
      CallV2ProductionRuntimeUiBridgeError.terminal =>
        CallV2ProductionCallStateBridgeError.terminal,
      CallV2ProductionRuntimeUiBridgeError.staleGeneration =>
        CallV2ProductionCallStateBridgeError.staleGeneration,
      null => CallV2ProductionCallStateBridgeError.runtimeBridgeRejected,
      _ => CallV2ProductionCallStateBridgeError.runtimeBridgeRejected,
    };
  }

  CallV2ProductionCallStateBridgeResult? _guard({int? generation}) {
    if (_status.terminal) {
      return CallV2ProductionCallStateBridgeResult.terminal(
        generation: generation,
      );
    }
    if (_status.disposed) {
      return const CallV2ProductionCallStateBridgeResult.disposed();
    }
    if (generation != null && generation < 0) {
      return _rejected(
        CallV2ProductionCallStateBridgeError.invalidGeneration,
        generation: generation,
      );
    }
    if (_isStale(generation)) {
      return _rejected(
        CallV2ProductionCallStateBridgeError.staleGeneration,
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

  CallV2ProductionCallStateBridgeResult _initialized({
    CallV2ProductionCallStateBridgeEventType? event,
    int? generation,
    CallV2ProductionCallStateConsistencyPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.initialized,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastConsistencyPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionCallStateBridgeResult.initialized(
      generation: generation,
    );
  }

  CallV2ProductionCallStateBridgeResult _disabled({
    CallV2ProductionCallStateBridgeEventType? event,
    int? generation,
    CallV2ProductionCallStateConsistencyPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.disabled,
      currentGeneration: generation,
      rolloutEnabled: false,
      lastEvent: event,
      lastConsistencyPolicy: policy,
      lastError: CallV2ProductionCallStateBridgeError.rolloutDisabled,
    );
    return CallV2ProductionCallStateBridgeResult.disabled(
      generation: generation,
    );
  }

  CallV2ProductionCallStateBridgeResult _delegated({
    required CallV2ProductionCallStateBridgeEventType event,
    int? generation,
    CallV2ProductionCallStateConsistencyPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.delegated,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastConsistencyPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionCallStateBridgeResult.delegated(
      generation: generation,
    );
  }

  CallV2ProductionCallStateBridgeResult _closed({
    required CallV2ProductionCallStateBridgeEventType event,
    int? generation,
    CallV2ProductionCallStateConsistencyPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.closed,
      currentGeneration: generation,
      rolloutEnabled: true,
      lastEvent: event,
      lastConsistencyPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionCallStateBridgeResult.closed(
      generation: generation,
    );
  }

  CallV2ProductionCallStateBridgeResult _noOp({
    required CallV2ProductionCallStateBridgeEventType event,
    int? generation,
    CallV2ProductionCallStateConsistencyPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.noOp,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastConsistencyPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionCallStateBridgeResult.noOp(
      generation: generation,
    );
  }

  CallV2ProductionCallStateBridgeResult _rejected(
    CallV2ProductionCallStateBridgeError error, {
    CallV2ProductionCallStateBridgeEventType? event,
    int? generation,
    CallV2ProductionCallStateConsistencyPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.rejected,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      lastEvent: event,
      lastConsistencyPolicy: policy,
      lastError: error,
    );
    return CallV2ProductionCallStateBridgeResult.rejected(
      error,
      generation: generation,
    );
  }

  CallV2ProductionCallStateBridgeResult _terminal({
    required CallV2ProductionCallStateBridgeEventType event,
    int? generation,
    CallV2ProductionCallStateConsistencyPolicy? policy,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionCallStateBridgeLifecycle.terminal,
      currentGeneration: generation,
      disposed: true,
      terminal: true,
      rolloutEnabled: true,
      lastEvent: event,
      lastConsistencyPolicy: policy,
      clearLastError: true,
    );
    return CallV2ProductionCallStateBridgeResult.terminal(
      generation: generation,
    );
  }
}
