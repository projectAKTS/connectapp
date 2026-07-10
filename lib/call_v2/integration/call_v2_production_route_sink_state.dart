import '../ui/call_v2_production_route_destination.dart';

final class CallV2ProductionRouteSinkState {
  const CallV2ProductionRouteSinkState({
    this.currentDestination,
    this.currentGeneration,
    this.disposed = false,
    this.navigationInProgress = false,
  });

  final CallV2ProductionRouteDestination? currentDestination;
  final int? currentGeneration;
  final bool disposed;
  final bool navigationInProgress;

  CallV2ProductionRouteSinkState copyWith({
    CallV2ProductionRouteDestination? currentDestination,
    int? currentGeneration,
    bool clearCurrent = false,
    bool? disposed,
    bool? navigationInProgress,
  }) {
    return CallV2ProductionRouteSinkState(
      currentDestination:
          clearCurrent ? null : currentDestination ?? this.currentDestination,
      currentGeneration:
          clearCurrent ? null : currentGeneration ?? this.currentGeneration,
      disposed: disposed ?? this.disposed,
      navigationInProgress: navigationInProgress ?? this.navigationInProgress,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentDestination': currentDestination?.name,
      'currentGeneration': currentGeneration,
      'disposed': disposed,
      'navigationInProgress': navigationInProgress,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteSinkState(${toSafeDebugMap()})';
  }
}
