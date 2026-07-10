import '../ui/call_v2_production_route_destination.dart';

enum CallV2ProductionRuntimeUiBridgeResultStatus {
  initialized,
  disabled,
  delegated,
  closed,
  noOp,
  rejected,
  disposed,
  terminal,
}

enum CallV2ProductionRuntimeUiBridgeError {
  rolloutDisabled,
  disposed,
  terminal,
  invalidEvent,
  invalidSnapshot,
  staleGeneration,
  ownerRejected,
  ownerUnavailable,
  unsupportedEvent,
  controlledRuntimeFailure,
}

final class CallV2ProductionRuntimeUiBridgeResult {
  const CallV2ProductionRuntimeUiBridgeResult._({
    required this.status,
    this.error,
    this.destination,
    this.generation,
  });

  const factory CallV2ProductionRuntimeUiBridgeResult.initialized({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _InitializedCallV2ProductionRuntimeUiBridgeResult;

  const factory CallV2ProductionRuntimeUiBridgeResult.disabled({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _DisabledCallV2ProductionRuntimeUiBridgeResult;

  const factory CallV2ProductionRuntimeUiBridgeResult.delegated({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _DelegatedCallV2ProductionRuntimeUiBridgeResult;

  const factory CallV2ProductionRuntimeUiBridgeResult.closed({
    int? generation,
  }) = _ClosedCallV2ProductionRuntimeUiBridgeResult;

  const factory CallV2ProductionRuntimeUiBridgeResult.noOp({
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _NoOpCallV2ProductionRuntimeUiBridgeResult;

  const factory CallV2ProductionRuntimeUiBridgeResult.rejected(
    CallV2ProductionRuntimeUiBridgeError error, {
    CallV2ProductionRouteDestination? destination,
    int? generation,
  }) = _RejectedCallV2ProductionRuntimeUiBridgeResult;

  const factory CallV2ProductionRuntimeUiBridgeResult.disposed() =
      _DisposedCallV2ProductionRuntimeUiBridgeResult;

  const factory CallV2ProductionRuntimeUiBridgeResult.terminal({
    int? generation,
  }) = _TerminalCallV2ProductionRuntimeUiBridgeResult;

  final CallV2ProductionRuntimeUiBridgeResultStatus status;
  final CallV2ProductionRuntimeUiBridgeError? error;
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
    return 'CallV2ProductionRuntimeUiBridgeResult(${toSafeDebugMap()})';
  }
}

final class _InitializedCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _InitializedCallV2ProductionRuntimeUiBridgeResult({
    super.destination,
    super.generation,
  }) : super._(
          status: CallV2ProductionRuntimeUiBridgeResultStatus.initialized,
        );
}

final class _DisabledCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _DisabledCallV2ProductionRuntimeUiBridgeResult({
    super.destination,
    super.generation,
  }) : super._(status: CallV2ProductionRuntimeUiBridgeResultStatus.disabled);
}

final class _DelegatedCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _DelegatedCallV2ProductionRuntimeUiBridgeResult({
    super.destination,
    super.generation,
  }) : super._(status: CallV2ProductionRuntimeUiBridgeResultStatus.delegated);
}

final class _ClosedCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _ClosedCallV2ProductionRuntimeUiBridgeResult({
    super.generation,
  }) : super._(status: CallV2ProductionRuntimeUiBridgeResultStatus.closed);
}

final class _NoOpCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _NoOpCallV2ProductionRuntimeUiBridgeResult({
    super.destination,
    super.generation,
  }) : super._(status: CallV2ProductionRuntimeUiBridgeResultStatus.noOp);
}

final class _RejectedCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _RejectedCallV2ProductionRuntimeUiBridgeResult(
    CallV2ProductionRuntimeUiBridgeError error, {
    super.destination,
    super.generation,
  }) : super._(
          status: CallV2ProductionRuntimeUiBridgeResultStatus.rejected,
          error: error,
        );
}

final class _DisposedCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _DisposedCallV2ProductionRuntimeUiBridgeResult()
      : super._(status: CallV2ProductionRuntimeUiBridgeResultStatus.disposed);
}

final class _TerminalCallV2ProductionRuntimeUiBridgeResult
    extends CallV2ProductionRuntimeUiBridgeResult {
  const _TerminalCallV2ProductionRuntimeUiBridgeResult({
    super.generation,
  }) : super._(status: CallV2ProductionRuntimeUiBridgeResultStatus.terminal);
}
