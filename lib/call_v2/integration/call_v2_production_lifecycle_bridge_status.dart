import 'call_v2_production_lifecycle_bridge_event.dart';
import 'call_v2_production_lifecycle_bridge_result.dart';

enum CallV2ProductionLifecycleBridgeLifecycle {
  uninitialized,
  initialized,
  disabled,
  delegated,
  closed,
  cleanedUp,
  disposed,
  terminal,
  noOp,
  rejected,
}

final class CallV2ProductionLifecycleBridgeStatus {
  const CallV2ProductionLifecycleBridgeStatus({
    this.lifecycle = CallV2ProductionLifecycleBridgeLifecycle.uninitialized,
    this.currentGeneration,
    this.disposed = false,
    this.terminal = false,
    this.rolloutEnabled = false,
    this.lastEvent,
    this.lastCleanupPolicy,
    this.lastError,
  });

  final CallV2ProductionLifecycleBridgeLifecycle lifecycle;
  final int? currentGeneration;
  final bool disposed;
  final bool terminal;
  final bool rolloutEnabled;
  final CallV2ProductionLifecycleBridgeEventType? lastEvent;
  final CallV2ProductionLifecycleCleanupPolicy? lastCleanupPolicy;
  final CallV2ProductionLifecycleBridgeError? lastError;

  CallV2ProductionLifecycleBridgeStatus copyWith({
    CallV2ProductionLifecycleBridgeLifecycle? lifecycle,
    int? currentGeneration,
    bool clearGeneration = false,
    bool? disposed,
    bool? terminal,
    bool? rolloutEnabled,
    CallV2ProductionLifecycleBridgeEventType? lastEvent,
    CallV2ProductionLifecycleCleanupPolicy? lastCleanupPolicy,
    CallV2ProductionLifecycleBridgeError? lastError,
    bool clearLastError = false,
  }) {
    return CallV2ProductionLifecycleBridgeStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      currentGeneration:
          clearGeneration ? null : currentGeneration ?? this.currentGeneration,
      disposed: disposed ?? this.disposed,
      terminal: terminal ?? this.terminal,
      rolloutEnabled: rolloutEnabled ?? this.rolloutEnabled,
      lastEvent: lastEvent ?? this.lastEvent,
      lastCleanupPolicy: lastCleanupPolicy ?? this.lastCleanupPolicy,
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
      'lastCleanupPolicy': lastCleanupPolicy?.name,
      'lastError': lastError?.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionLifecycleBridgeStatus(${toSafeDebugMap()})';
  }
}
