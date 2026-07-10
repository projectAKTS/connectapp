enum CallV2ProductionScreenFactoryError {
  invalidInput,
  staleGeneration,
  routeNameMismatch,
  reservedDestination,
  destinationViewModelMismatch,
  terminalDescriptor,
  unsupportedDestination,
}

sealed class CallV2ProductionScreenFactoryResult<T extends Object> {
  const CallV2ProductionScreenFactoryResult();

  const factory CallV2ProductionScreenFactoryResult.rendered(T value) =
      CallV2ProductionScreenFactoryRendered<T>;

  const factory CallV2ProductionScreenFactoryResult.noScreen() =
      CallV2ProductionScreenFactoryNoScreen<T>;

  const factory CallV2ProductionScreenFactoryResult.rejected(
    CallV2ProductionScreenFactoryError error, {
    String? destination,
    int? generation,
  }) = CallV2ProductionScreenFactoryRejected<T>;

  Map<String, Object?> toSafeDebugMap();
}

final class CallV2ProductionScreenFactoryRendered<T extends Object>
    extends CallV2ProductionScreenFactoryResult<T> {
  const CallV2ProductionScreenFactoryRendered(this.value);

  final T value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'status': 'rendered'};
  }

  @override
  String toString() {
    return 'CallV2ProductionScreenFactoryRendered(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionScreenFactoryNoScreen<T extends Object>
    extends CallV2ProductionScreenFactoryResult<T> {
  const CallV2ProductionScreenFactoryNoScreen();

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'status': 'noScreen'};
  }

  @override
  String toString() {
    return 'CallV2ProductionScreenFactoryNoScreen(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionScreenFactoryRejected<T extends Object>
    extends CallV2ProductionScreenFactoryResult<T> {
  const CallV2ProductionScreenFactoryRejected(
    this.error, {
    this.destination,
    this.generation,
  });

  final CallV2ProductionScreenFactoryError error;
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
    return 'CallV2ProductionScreenFactoryRejected(${toSafeDebugMap()})';
  }
}
