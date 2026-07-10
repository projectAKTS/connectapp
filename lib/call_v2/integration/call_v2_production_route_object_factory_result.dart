import 'package:flutter/widgets.dart';

enum CallV2ProductionRouteObjectFactoryError {
  invalidInput,
  screenFactoryRejected,
  staleGeneration,
  routeNameMismatch,
  reservedDestination,
  destinationViewModelMismatch,
  terminalDescriptor,
  unsupportedDestination,
}

sealed class CallV2ProductionRouteObjectFactoryResult<T> {
  const CallV2ProductionRouteObjectFactoryResult();

  const factory CallV2ProductionRouteObjectFactoryResult.route(Route<T> value) =
      CallV2ProductionRouteObjectFactoryRoute<T>;

  const factory CallV2ProductionRouteObjectFactoryResult.noRoute() =
      CallV2ProductionRouteObjectFactoryNoRoute<T>;

  const factory CallV2ProductionRouteObjectFactoryResult.rejected(
    CallV2ProductionRouteObjectFactoryError error, {
    String? destination,
    int? generation,
  }) = CallV2ProductionRouteObjectFactoryRejected<T>;

  Map<String, Object?> toSafeDebugMap();
}

final class CallV2ProductionRouteObjectFactoryRoute<T>
    extends CallV2ProductionRouteObjectFactoryResult<T> {
  const CallV2ProductionRouteObjectFactoryRoute(this.value);

  final Route<T> value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'status': 'route'};
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteObjectFactoryRoute(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionRouteObjectFactoryNoRoute<T>
    extends CallV2ProductionRouteObjectFactoryResult<T> {
  const CallV2ProductionRouteObjectFactoryNoRoute();

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'status': 'noRoute'};
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteObjectFactoryNoRoute(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionRouteObjectFactoryRejected<T>
    extends CallV2ProductionRouteObjectFactoryResult<T> {
  const CallV2ProductionRouteObjectFactoryRejected(
    this.error, {
    this.destination,
    this.generation,
  });

  final CallV2ProductionRouteObjectFactoryError error;
  final String? destination;
  final int? generation;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'rejected',
      'error': error.name,
      if (destination != null) 'destination': destination,
      if (generation != null) 'generation': generation,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteObjectFactoryRejected(${toSafeDebugMap()})';
  }
}
