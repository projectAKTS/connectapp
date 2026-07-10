import '../ui/call_v2_production_route_destination.dart';
import 'call_v2_production_runtime_ui_bridge_result.dart';

enum CallV2ProductionRuntimeUiBridgeLifecycle {
  uninitialized,
  initialized,
  disabled,
  delegated,
  closed,
  rejected,
  disposed,
  terminal,
}

final class CallV2ProductionRuntimeUiBridgeStatus {
  const CallV2ProductionRuntimeUiBridgeStatus({
    this.lifecycle = CallV2ProductionRuntimeUiBridgeLifecycle.uninitialized,
    this.currentDestination,
    this.currentGeneration,
    this.disposed = false,
    this.terminal = false,
    this.rolloutEnabled = false,
    this.lastError,
  });

  final CallV2ProductionRuntimeUiBridgeLifecycle lifecycle;
  final CallV2ProductionRouteDestination? currentDestination;
  final int? currentGeneration;
  final bool disposed;
  final bool terminal;
  final bool rolloutEnabled;
  final CallV2ProductionRuntimeUiBridgeError? lastError;

  CallV2ProductionRuntimeUiBridgeStatus copyWith({
    CallV2ProductionRuntimeUiBridgeLifecycle? lifecycle,
    CallV2ProductionRouteDestination? currentDestination,
    int? currentGeneration,
    bool clearCurrent = false,
    bool? disposed,
    bool? terminal,
    bool? rolloutEnabled,
    CallV2ProductionRuntimeUiBridgeError? lastError,
    bool clearLastError = false,
  }) {
    return CallV2ProductionRuntimeUiBridgeStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      currentDestination:
          clearCurrent ? null : currentDestination ?? this.currentDestination,
      currentGeneration:
          clearCurrent ? null : currentGeneration ?? this.currentGeneration,
      disposed: disposed ?? this.disposed,
      terminal: terminal ?? this.terminal,
      rolloutEnabled: rolloutEnabled ?? this.rolloutEnabled,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'lifecycle': lifecycle.name,
      'currentDestination': currentDestination?.name,
      'currentGeneration': currentGeneration,
      'disposed': disposed,
      'terminal': terminal,
      'rolloutEnabled': rolloutEnabled,
      'lastError': lastError?.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRuntimeUiBridgeStatus(${toSafeDebugMap()})';
  }
}
