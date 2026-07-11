enum CallV2ProductionCallStateBridgeResultStatus {
  initialized,
  disabled,
  delegated,
  closed,
  noOp,
  rejected,
  disposed,
  terminal,
}

enum CallV2ProductionCallStateBridgeError {
  rolloutDisabled,
  disposed,
  terminal,
  invalidEvent,
  invalidGeneration,
  staleGeneration,
  ownershipMismatch,
  duplicateSnapshot,
  credentialRefreshRequired,
  runtimeBridgeRejected,
  runtimeBridgeUnavailable,
  unsupportedEvent,
}

final class CallV2ProductionCallStateBridgeResult {
  const CallV2ProductionCallStateBridgeResult._({
    required this.status,
    this.error,
    this.generation,
  });

  const factory CallV2ProductionCallStateBridgeResult.initialized({
    int? generation,
  }) = _InitializedCallV2ProductionCallStateBridgeResult;

  const factory CallV2ProductionCallStateBridgeResult.disabled({
    int? generation,
  }) = _DisabledCallV2ProductionCallStateBridgeResult;

  const factory CallV2ProductionCallStateBridgeResult.delegated({
    int? generation,
  }) = _DelegatedCallV2ProductionCallStateBridgeResult;

  const factory CallV2ProductionCallStateBridgeResult.closed({
    int? generation,
  }) = _ClosedCallV2ProductionCallStateBridgeResult;

  const factory CallV2ProductionCallStateBridgeResult.noOp({
    int? generation,
  }) = _NoOpCallV2ProductionCallStateBridgeResult;

  const factory CallV2ProductionCallStateBridgeResult.rejected(
    CallV2ProductionCallStateBridgeError error, {
    int? generation,
  }) = _RejectedCallV2ProductionCallStateBridgeResult;

  const factory CallV2ProductionCallStateBridgeResult.disposed() =
      _DisposedCallV2ProductionCallStateBridgeResult;

  const factory CallV2ProductionCallStateBridgeResult.terminal({
    int? generation,
  }) = _TerminalCallV2ProductionCallStateBridgeResult;

  final CallV2ProductionCallStateBridgeResultStatus status;
  final CallV2ProductionCallStateBridgeError? error;
  final int? generation;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      if (error != null) 'error': error!.name,
      if (generation != null) 'generation': generation,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionCallStateBridgeResult(${toSafeDebugMap()})';
  }
}

final class _InitializedCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _InitializedCallV2ProductionCallStateBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.initialized,
        );
}

final class _DisabledCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _DisabledCallV2ProductionCallStateBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.disabled,
        );
}

final class _DelegatedCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _DelegatedCallV2ProductionCallStateBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.delegated,
        );
}

final class _ClosedCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _ClosedCallV2ProductionCallStateBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.closed,
        );
}

final class _NoOpCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _NoOpCallV2ProductionCallStateBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.noOp,
        );
}

final class _RejectedCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _RejectedCallV2ProductionCallStateBridgeResult(
    CallV2ProductionCallStateBridgeError error, {
    super.generation,
  }) : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.rejected,
          error: error,
        );
}

final class _DisposedCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _DisposedCallV2ProductionCallStateBridgeResult()
      : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.disposed,
        );
}

final class _TerminalCallV2ProductionCallStateBridgeResult
    extends CallV2ProductionCallStateBridgeResult {
  const _TerminalCallV2ProductionCallStateBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionCallStateBridgeResultStatus.terminal,
        );
}
