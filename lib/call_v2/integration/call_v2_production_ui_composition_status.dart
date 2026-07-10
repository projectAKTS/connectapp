import '../ui/call_v2_production_route_destination.dart';

enum CallV2ProductionUiCompositionLifecycle {
  uninitialized,
  initialized,
  disabled,
  rendered,
  closed,
  rejected,
  disposed,
}

final class CallV2ProductionUiCompositionStatus {
  const CallV2ProductionUiCompositionStatus({
    this.lifecycle = CallV2ProductionUiCompositionLifecycle.uninitialized,
    this.currentDestination,
    this.currentGeneration,
    this.disposed = false,
    this.rolloutEnabled = false,
  });

  final CallV2ProductionUiCompositionLifecycle lifecycle;
  final CallV2ProductionRouteDestination? currentDestination;
  final int? currentGeneration;
  final bool disposed;
  final bool rolloutEnabled;

  CallV2ProductionUiCompositionStatus copyWith({
    CallV2ProductionUiCompositionLifecycle? lifecycle,
    CallV2ProductionRouteDestination? currentDestination,
    int? currentGeneration,
    bool clearCurrent = false,
    bool? disposed,
    bool? rolloutEnabled,
  }) {
    return CallV2ProductionUiCompositionStatus(
      lifecycle: lifecycle ?? this.lifecycle,
      currentDestination:
          clearCurrent ? null : currentDestination ?? this.currentDestination,
      currentGeneration:
          clearCurrent ? null : currentGeneration ?? this.currentGeneration,
      disposed: disposed ?? this.disposed,
      rolloutEnabled: rolloutEnabled ?? this.rolloutEnabled,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'lifecycle': lifecycle.name,
      'currentDestination': currentDestination?.name,
      'currentGeneration': currentGeneration,
      'disposed': disposed,
      'rolloutEnabled': rolloutEnabled,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionUiCompositionStatus(${toSafeDebugMap()})';
  }
}
