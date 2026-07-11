import 'call_v2_production_call_state_bridge_event.dart';
import 'call_v2_production_call_state_bridge_result.dart';

enum CallV2ProductionCallStateBridgeLifecycle {
  uninitialized,
  initialized,
  disabled,
  delegated,
  closed,
  noOp,
  rejected,
  disposed,
  terminal,
}

final class CallV2ProductionCallStateBridgeStatus {
  const CallV2ProductionCallStateBridgeStatus({
    this.lifecycle = CallV2ProductionCallStateBridgeLifecycle.uninitialized,
    this.currentGeneration,
    this.disposed = false,
    this.terminal = false,
    this.rolloutEnabled = false,
    this.lastEvent,
    this.lastConsistencyPolicy,
    this.lastError,
  });

  final CallV2ProductionCallStateBridgeLifecycle lifecycle;
  final int? currentGeneration;
  final bool disposed;
  final bool terminal;
  final bool rolloutEnabled;
  final CallV2ProductionCallStateBridgeEventType? lastEvent;
  final CallV2ProductionCallStateConsistencyPolicy? lastConsistencyPolicy;
  final CallV2ProductionCallStateBridgeError? lastError;

  CallV2ProductionCallStateBridgeStatus copyWith({
    CallV2ProductionCallStateBridgeLifecycle? lifecycle,
    int? currentGeneration,
    bool clearGeneration = false,
    bool? disposed,
    bool? terminal,
    bool? rolloutEnabled,
    CallV2ProductionCallStateBridgeEventType? lastEvent,
    CallV2ProductionCallStateConsistencyPolicy? lastConsistencyPolicy,
    CallV2ProductionCallStateBridgeError? lastError,
    bool clearLastError = false,
  }) {
    return CallV2ProductionCallStateBridgeStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      currentGeneration:
          clearGeneration ? null : currentGeneration ?? this.currentGeneration,
      disposed: disposed ?? this.disposed,
      terminal: terminal ?? this.terminal,
      rolloutEnabled: rolloutEnabled ?? this.rolloutEnabled,
      lastEvent: lastEvent ?? this.lastEvent,
      lastConsistencyPolicy:
          lastConsistencyPolicy ?? this.lastConsistencyPolicy,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'lifecycle': lifecycle.name,
      'currentGeneration': currentGeneration,
      'disposed': disposed,
      'terminal': terminal,
      'rolloutEnabled': rolloutEnabled,
      'lastEvent': lastEvent?.name,
      'lastConsistencyPolicy': lastConsistencyPolicy?.name,
      'lastError': lastError?.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionCallStateBridgeStatus(${toSafeDebugMap()})';
  }
}
