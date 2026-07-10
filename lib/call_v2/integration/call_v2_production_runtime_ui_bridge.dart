import '../ui/call_v2_production_presentation_snapshot.dart';
import '../ui/call_v2_production_route_destination.dart';
import 'call_v2_production_runtime_ui_bridge_event.dart';
import 'call_v2_production_runtime_ui_bridge_result.dart';
import 'call_v2_production_runtime_ui_bridge_status.dart';
import 'call_v2_production_ui_composition_owner.dart';
import 'call_v2_production_ui_composition_result.dart';

typedef CallV2ProductionRuntimeUiBridgeRolloutReader = bool Function();

final class CallV2ProductionRuntimeUiBridge {
  CallV2ProductionRuntimeUiBridge({
    required CallV2ProductionUiCompositionOwner owner,
    CallV2ProductionRuntimeUiBridgeRolloutReader? rolloutEnabled,
    bool disposeOwner = true,
  })  : _owner = owner,
        _rolloutEnabled = rolloutEnabled ?? (() => false),
        _disposeOwner = disposeOwner;

  final CallV2ProductionUiCompositionOwner _owner;
  final CallV2ProductionRuntimeUiBridgeRolloutReader _rolloutEnabled;
  final bool _disposeOwner;

  CallV2ProductionRuntimeUiBridgeStatus _status =
      const CallV2ProductionRuntimeUiBridgeStatus();

  CallV2ProductionRuntimeUiBridgeStatus get status => _status;

  CallV2ProductionRuntimeUiBridgeResult initialize() {
    final guard = _guard();
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) return _disabled();
    return _mapOwnerResult(_owner.initialize());
  }

  Future<CallV2ProductionRuntimeUiBridgeResult> handleEvent(
    CallV2ProductionRuntimeUiBridgeEvent event,
  ) async {
    final guard = _guard(generation: event.generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) return _disabled(generation: event.generation);

    return switch (event.type) {
      CallV2ProductionRuntimeUiBridgeEventType.initialize => initialize(),
      CallV2ProductionRuntimeUiBridgeEventType.presentationSnapshot =>
        _handlePresentationSnapshot(event.snapshot),
      CallV2ProductionRuntimeUiBridgeEventType.close =>
        close(generation: event.generation),
      CallV2ProductionRuntimeUiBridgeEventType.dispose => dispose(),
      CallV2ProductionRuntimeUiBridgeEventType.runtimeTerminated =>
        _handleRuntimeTerminated(event.generation),
      CallV2ProductionRuntimeUiBridgeEventType.runtimeFailedControlled =>
        _handleControlledFailure(event),
      CallV2ProductionRuntimeUiBridgeEventType.invalid =>
        _rejected(CallV2ProductionRuntimeUiBridgeError.invalidEvent),
    };
  }

  Future<CallV2ProductionRuntimeUiBridgeResult> close({int? generation}) async {
    final guard = _guard(generation: generation);
    if (guard != null) return guard;
    if (!_safeRolloutEnabled()) return _disabled(generation: generation);
    return _mapOwnerResult(await _safeCloseOwner(generation));
  }

  CallV2ProductionRuntimeUiBridgeResult dispose() {
    if (_status.disposed) {
      return const CallV2ProductionRuntimeUiBridgeResult.disposed();
    }
    if (_disposeOwner) {
      _owner.dispose();
    }
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.disposed,
      clearCurrent: true,
      disposed: true,
      terminal: _status.terminal,
      rolloutEnabled: _safeRolloutEnabled(),
      clearLastError: true,
    );
    return const CallV2ProductionRuntimeUiBridgeResult.disposed();
  }

  Future<CallV2ProductionRuntimeUiBridgeResult> _handlePresentationSnapshot(
    CallV2ProductionPresentationSnapshot? snapshot,
  ) async {
    if (!_isValidSnapshot(snapshot)) {
      return _rejected(CallV2ProductionRuntimeUiBridgeError.invalidSnapshot);
    }
    if (_isStale(snapshot!.generation)) {
      return _rejected(
        CallV2ProductionRuntimeUiBridgeError.staleGeneration,
        destination: snapshot.destination,
        generation: snapshot.generation,
      );
    }
    return _mapOwnerResult(await _safeRenderOwner(snapshot));
  }

  Future<CallV2ProductionRuntimeUiBridgeResult> _handleRuntimeTerminated(
    int? generation,
  ) async {
    final closeResult = await close(generation: generation);
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.terminal,
      clearCurrent: true,
      terminal: true,
      rolloutEnabled: _safeRolloutEnabled(),
      clearLastError: true,
    );
    if (closeResult.status ==
        CallV2ProductionRuntimeUiBridgeResultStatus.rejected) {
      return closeResult;
    }
    return CallV2ProductionRuntimeUiBridgeResult.terminal(
      generation: generation,
    );
  }

  Future<CallV2ProductionRuntimeUiBridgeResult> _handleControlledFailure(
    CallV2ProductionRuntimeUiBridgeEvent event,
  ) async {
    final snapshot = event.toControlledFailureSnapshot();
    if (snapshot == null) {
      return _rejected(
        CallV2ProductionRuntimeUiBridgeError.controlledRuntimeFailure,
        generation: event.generation,
      );
    }
    return _handlePresentationSnapshot(snapshot);
  }

  Future<CallV2ProductionUiCompositionResult> _safeRenderOwner(
    CallV2ProductionPresentationSnapshot snapshot,
  ) async {
    try {
      return await _owner.renderSnapshot(snapshot);
    } catch (_) {
      return CallV2ProductionUiCompositionResult.rejected(
        CallV2ProductionUiCompositionError.routeSinkRejected,
        destination: snapshot.destination,
        generation: snapshot.generation,
      );
    }
  }

  Future<CallV2ProductionUiCompositionResult> _safeCloseOwner(
    int? generation,
  ) async {
    try {
      return await _owner.close(generation: generation);
    } catch (_) {
      return CallV2ProductionUiCompositionResult.rejected(
        CallV2ProductionUiCompositionError.routeSinkRejected,
        generation: generation,
      );
    }
  }

  CallV2ProductionRuntimeUiBridgeResult _mapOwnerResult(
    CallV2ProductionUiCompositionResult result,
  ) {
    return switch (result.status) {
      CallV2ProductionUiCompositionResultStatus.initialized => _initialized(
          destination: result.destination,
          generation: result.generation,
        ),
      CallV2ProductionUiCompositionResultStatus.disabled => _disabled(
          destination: result.destination,
          generation: result.generation,
        ),
      CallV2ProductionUiCompositionResultStatus.rendered => _delegated(
          destination: result.destination,
          generation: result.generation,
        ),
      CallV2ProductionUiCompositionResultStatus.closed =>
        _closed(result.generation),
      CallV2ProductionUiCompositionResultStatus.noOp => _noOp(
          destination: result.destination,
          generation: result.generation,
        ),
      CallV2ProductionUiCompositionResultStatus.rejected => _rejected(
          _mapOwnerError(result.error),
          destination: result.destination,
          generation: result.generation,
        ),
      CallV2ProductionUiCompositionResultStatus.disposed => dispose(),
    };
  }

  CallV2ProductionRuntimeUiBridgeError _mapOwnerError(
    CallV2ProductionUiCompositionError? error,
  ) {
    return switch (error) {
      CallV2ProductionUiCompositionError.rolloutDisabled =>
        CallV2ProductionRuntimeUiBridgeError.rolloutDisabled,
      CallV2ProductionUiCompositionError.disposed =>
        CallV2ProductionRuntimeUiBridgeError.disposed,
      CallV2ProductionUiCompositionError.invalidSnapshot =>
        CallV2ProductionRuntimeUiBridgeError.invalidSnapshot,
      CallV2ProductionUiCompositionError.staleGeneration =>
        CallV2ProductionRuntimeUiBridgeError.staleGeneration,
      CallV2ProductionUiCompositionError.terminal =>
        CallV2ProductionRuntimeUiBridgeError.terminal,
      null => CallV2ProductionRuntimeUiBridgeError.ownerUnavailable,
      _ => CallV2ProductionRuntimeUiBridgeError.ownerRejected,
    };
  }

  CallV2ProductionRuntimeUiBridgeResult? _guard({int? generation}) {
    if (_status.disposed) {
      return const CallV2ProductionRuntimeUiBridgeResult.disposed();
    }
    if (_status.terminal) {
      return CallV2ProductionRuntimeUiBridgeResult.terminal(
        generation: generation,
      );
    }
    if (generation != null && generation < 0) {
      return _rejected(
        CallV2ProductionRuntimeUiBridgeError.invalidEvent,
        generation: generation,
      );
    }
    if (_isStale(generation)) {
      return _rejected(
        CallV2ProductionRuntimeUiBridgeError.staleGeneration,
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

  bool _isValidSnapshot(CallV2ProductionPresentationSnapshot? snapshot) {
    if (snapshot == null || snapshot.generation < 0) return false;
    final destination = snapshot.destination;
    return destination == null || destination.isAvailable;
  }

  bool _isStale(int? generation) {
    final currentGeneration = _status.currentGeneration;
    return generation != null &&
        currentGeneration != null &&
        generation < currentGeneration;
  }

  CallV2ProductionRuntimeUiBridgeResult _initialized({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.initialized,
      currentDestination: destination,
      currentGeneration: generation,
      rolloutEnabled: true,
      clearLastError: true,
    );
    return CallV2ProductionRuntimeUiBridgeResult.initialized(
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionRuntimeUiBridgeResult _disabled({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.disabled,
      currentDestination: destination,
      currentGeneration: generation,
      rolloutEnabled: false,
      lastError: CallV2ProductionRuntimeUiBridgeError.rolloutDisabled,
    );
    return CallV2ProductionRuntimeUiBridgeResult.disabled(
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionRuntimeUiBridgeResult _delegated({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.delegated,
      currentDestination: destination,
      currentGeneration: generation,
      rolloutEnabled: true,
      clearLastError: true,
    );
    return CallV2ProductionRuntimeUiBridgeResult.delegated(
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionRuntimeUiBridgeResult _closed(int? generation) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.closed,
      clearCurrent: true,
      currentGeneration: generation,
      rolloutEnabled: true,
      clearLastError: true,
    );
    return CallV2ProductionRuntimeUiBridgeResult.closed(
      generation: generation,
    );
  }

  CallV2ProductionRuntimeUiBridgeResult _noOp({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.initialized,
      currentDestination: destination,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      clearLastError: true,
    );
    return CallV2ProductionRuntimeUiBridgeResult.noOp(
      destination: destination,
      generation: generation,
    );
  }

  CallV2ProductionRuntimeUiBridgeResult _rejected(
    CallV2ProductionRuntimeUiBridgeError error, {
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) {
    _status = _status.copyWith(
      lifecycle: CallV2ProductionRuntimeUiBridgeLifecycle.rejected,
      currentDestination: destination,
      currentGeneration: generation,
      rolloutEnabled: _safeRolloutEnabled(),
      lastError: error,
    );
    return CallV2ProductionRuntimeUiBridgeResult.rejected(
      error,
      destination: destination,
      generation: generation,
    );
  }
}
