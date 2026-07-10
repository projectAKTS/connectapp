import '../ui/call_v2_production_route_destination.dart';

enum CallV2ProductionUiCompositionResultStatus {
  initialized,
  disabled,
  rendered,
  closed,
  noOp,
  rejected,
  disposed,
}

enum CallV2ProductionUiCompositionError {
  rolloutDisabled,
  disposed,
  invalidSnapshot,
  routeMappingRejected,
  viewModelMappingRejected,
  routeSinkRejected,
  staleGeneration,
  duplicate,
  terminal,
  invalidTransition,
  reservedDestination,
}

final class CallV2ProductionUiCompositionResult {
  const CallV2ProductionUiCompositionResult._({
    required this.status,
    this.error,
    this.destination,
    this.generation,
  });

  const factory CallV2ProductionUiCompositionResult.initialized({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _InitializedCallV2ProductionUiCompositionResult;

  const factory CallV2ProductionUiCompositionResult.disabled({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _DisabledCallV2ProductionUiCompositionResult;

  const factory CallV2ProductionUiCompositionResult.rendered({
    required CallV2ProductionRouteDestination destination,
    required int generation,
  }) = _RenderedCallV2ProductionUiCompositionResult;

  const factory CallV2ProductionUiCompositionResult.closed({
    int? generation,
  }) = _ClosedCallV2ProductionUiCompositionResult;

  const factory CallV2ProductionUiCompositionResult.noOp({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _NoOpCallV2ProductionUiCompositionResult;

  const factory CallV2ProductionUiCompositionResult.rejected(
    CallV2ProductionUiCompositionError error, {
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _RejectedCallV2ProductionUiCompositionResult;

  const factory CallV2ProductionUiCompositionResult.disposed() =
      _DisposedCallV2ProductionUiCompositionResult;

  final CallV2ProductionUiCompositionResultStatus status;
  final CallV2ProductionUiCompositionError? error;
  final CallV2ProductionRouteDestination? destination;
  final int? generation;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      if (error != null) 'error': error!.name,
      if (destination != null) 'destination': destination!.name,
      if (generation != null) 'generation': generation,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionUiCompositionResult(${toSafeDebugMap()})';
  }
}

final class _InitializedCallV2ProductionUiCompositionResult
    extends CallV2ProductionUiCompositionResult {
  const _InitializedCallV2ProductionUiCompositionResult({
    super.destination,
    super.generation,
  }) : super._(status: CallV2ProductionUiCompositionResultStatus.initialized);
}

final class _DisabledCallV2ProductionUiCompositionResult
    extends CallV2ProductionUiCompositionResult {
  const _DisabledCallV2ProductionUiCompositionResult({
    super.destination,
    super.generation,
  }) : super._(status: CallV2ProductionUiCompositionResultStatus.disabled);
}

final class _RenderedCallV2ProductionUiCompositionResult
    extends CallV2ProductionUiCompositionResult {
  const _RenderedCallV2ProductionUiCompositionResult({
    required CallV2ProductionRouteDestination destination,
    required int generation,
  }) : super._(
          status: CallV2ProductionUiCompositionResultStatus.rendered,
          destination: destination,
          generation: generation,
        );
}

final class _ClosedCallV2ProductionUiCompositionResult
    extends CallV2ProductionUiCompositionResult {
  const _ClosedCallV2ProductionUiCompositionResult({
    super.generation,
  }) : super._(status: CallV2ProductionUiCompositionResultStatus.closed);
}

final class _NoOpCallV2ProductionUiCompositionResult
    extends CallV2ProductionUiCompositionResult {
  const _NoOpCallV2ProductionUiCompositionResult({
    super.destination,
    super.generation,
  }) : super._(status: CallV2ProductionUiCompositionResultStatus.noOp);
}

final class _RejectedCallV2ProductionUiCompositionResult
    extends CallV2ProductionUiCompositionResult {
  const _RejectedCallV2ProductionUiCompositionResult(
    CallV2ProductionUiCompositionError error, {
    super.destination,
    super.generation,
  }) : super._(
          status: CallV2ProductionUiCompositionResultStatus.rejected,
          error: error,
        );
}

final class _DisposedCallV2ProductionUiCompositionResult
    extends CallV2ProductionUiCompositionResult {
  const _DisposedCallV2ProductionUiCompositionResult()
      : super._(status: CallV2ProductionUiCompositionResultStatus.disposed);
}
