enum CallV2ProductionMappingError {
  invalidInput,
  staleGeneration,
  reservedDestination,
  invalidRouteName,
}

sealed class CallV2ProductionMappingResult<T extends Object> {
  const CallV2ProductionMappingResult();

  const factory CallV2ProductionMappingResult.success(T value) =
      CallV2ProductionMappingSuccess<T>;

  const factory CallV2ProductionMappingResult.noRoute(T? value) =
      CallV2ProductionMappingNoRoute<T>;

  const factory CallV2ProductionMappingResult.rejected(
    CallV2ProductionMappingError error,
  ) = CallV2ProductionMappingRejected<T>;

  Map<String, Object?> toSafeDebugMap();
}

final class CallV2ProductionMappingSuccess<T extends Object>
    extends CallV2ProductionMappingResult<T> {
  const CallV2ProductionMappingSuccess(this.value);

  final T value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'success',
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionMappingSuccess(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionMappingNoRoute<T extends Object>
    extends CallV2ProductionMappingResult<T> {
  const CallV2ProductionMappingNoRoute(this.value);

  final T? value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'noRoute',
      'hasValue': value != null,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionMappingNoRoute(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionMappingRejected<T extends Object>
    extends CallV2ProductionMappingResult<T> {
  const CallV2ProductionMappingRejected(this.error);

  final CallV2ProductionMappingError error;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'rejected',
      'error': error.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionMappingRejected(${toSafeDebugMap()})';
  }
}
