enum CallV2ProductionViewModelError {
  invalidInput,
  staleGeneration,
  reservedDestination,
  incompatibleState,
  invalidActions,
}

sealed class CallV2ProductionViewModelResult<T extends Object> {
  const CallV2ProductionViewModelResult();

  const factory CallV2ProductionViewModelResult.success(T value) =
      CallV2ProductionViewModelSuccess<T>;

  const factory CallV2ProductionViewModelResult.noView() =
      CallV2ProductionViewModelNoView<T>;

  const factory CallV2ProductionViewModelResult.rejected(
    CallV2ProductionViewModelError error,
  ) = CallV2ProductionViewModelRejected<T>;

  Map<String, Object?> toSafeDebugMap();
}

final class CallV2ProductionViewModelSuccess<T extends Object>
    extends CallV2ProductionViewModelResult<T> {
  const CallV2ProductionViewModelSuccess(this.value);

  final T value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'status': 'success'};
  }

  @override
  String toString() {
    return 'CallV2ProductionViewModelSuccess(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionViewModelNoView<T extends Object>
    extends CallV2ProductionViewModelResult<T> {
  const CallV2ProductionViewModelNoView();

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{'status': 'noView'};
  }

  @override
  String toString() {
    return 'CallV2ProductionViewModelNoView(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionViewModelRejected<T extends Object>
    extends CallV2ProductionViewModelResult<T> {
  const CallV2ProductionViewModelRejected(this.error);

  final CallV2ProductionViewModelError error;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': 'rejected',
      'error': error.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionViewModelRejected(${toSafeDebugMap()})';
  }
}
