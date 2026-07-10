import '../ui/call_v2_production_route_destination.dart';

enum CallV2ProductionRouteSinkError {
  invalidInput,
  staleGeneration,
  disposed,
  adapterDisposed,
  routeFactoryRejected,
  invalidTransition,
  destinationViewModelMismatch,
  routeNameMismatch,
  reservedDestination,
  terminalDescriptor,
  navigationInProgress,
  adapterOperationFailed,
}

sealed class CallV2ProductionRouteSinkResult {
  const CallV2ProductionRouteSinkResult();

  const factory CallV2ProductionRouteSinkResult.pushed({
    required CallV2ProductionRouteDestination destination,
    required int generation,
  }) = CallV2ProductionRouteSinkPushed;

  const factory CallV2ProductionRouteSinkResult.replaced({
    required CallV2ProductionRouteDestination destination,
    required int generation,
  }) = CallV2ProductionRouteSinkReplaced;

  const factory CallV2ProductionRouteSinkResult.popped() =
      CallV2ProductionRouteSinkPopped;

  const factory CallV2ProductionRouteSinkResult.noOp({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = CallV2ProductionRouteSinkNoOp;

  const factory CallV2ProductionRouteSinkResult.rejected(
    CallV2ProductionRouteSinkError error, {
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = CallV2ProductionRouteSinkRejected;

  Map<String, Object?> toSafeDebugMap();
}

final class CallV2ProductionRouteSinkPushed
    extends CallV2ProductionRouteSinkResult {
  const CallV2ProductionRouteSinkPushed({
    required this.destination,
    required this.generation,
  });

  final CallV2ProductionRouteDestination destination;
  final int generation;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'pushed',
      'destination': destination.name,
      'generation': generation,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteSinkPushed(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionRouteSinkReplaced
    extends CallV2ProductionRouteSinkResult {
  const CallV2ProductionRouteSinkReplaced({
    required this.destination,
    required this.generation,
  });

  final CallV2ProductionRouteDestination destination;
  final int generation;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'replaced',
      'destination': destination.name,
      'generation': generation,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteSinkReplaced(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionRouteSinkPopped
    extends CallV2ProductionRouteSinkResult {
  const CallV2ProductionRouteSinkPopped();

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'status': 'popped'};
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteSinkPopped(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionRouteSinkNoOp
    extends CallV2ProductionRouteSinkResult {
  const CallV2ProductionRouteSinkNoOp({
    this.destination,
    this.generation,
  });

  final CallV2ProductionRouteDestination? destination;
  final int? generation;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'noOp',
      if (destination != null) 'destination': destination!.name,
      if (generation != null) 'generation': generation,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteSinkNoOp(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionRouteSinkRejected
    extends CallV2ProductionRouteSinkResult {
  const CallV2ProductionRouteSinkRejected(
    this.error, {
    this.destination,
    this.generation,
  });

  final CallV2ProductionRouteSinkError error;
  final CallV2ProductionRouteDestination? destination;
  final int? generation;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'rejected',
      'error': error.name,
      if (destination != null) 'destination': destination!.name,
      if (generation != null) 'generation': generation,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteSinkRejected(${toSafeDebugMap()})';
  }
}
