enum CallV2ProductionLifecycleBridgeResultStatus {
  initialized,
  disabled,
  delegated,
  closed,
  cleanedUp,
  disposed,
  terminal,
  noOp,
  rejected,
}

enum CallV2ProductionLifecycleBridgeError {
  rolloutDisabled,
  disposed,
  terminal,
  invalidEvent,
  invalidGeneration,
  runtimeBridgeRejected,
  runtimeBridgeUnavailable,
  unsupportedEvent,
  cleanupFailed,
}

final class CallV2ProductionLifecycleBridgeResult {
  const CallV2ProductionLifecycleBridgeResult._({
    required this.status,
    this.error,
    this.generation,
  });

  const factory CallV2ProductionLifecycleBridgeResult.initialized({
    int? generation,
  }) = _InitializedCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.disabled({
    int? generation,
  }) = _DisabledCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.delegated({
    int? generation,
  }) = _DelegatedCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.closed({
    int? generation,
  }) = _ClosedCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.cleanedUp({
    int? generation,
  }) = _CleanedUpCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.disposed() =
      _DisposedCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.terminal({
    int? generation,
  }) = _TerminalCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.noOp({
    int? generation,
  }) = _NoOpCallV2ProductionLifecycleBridgeResult;

  const factory CallV2ProductionLifecycleBridgeResult.rejected(
    CallV2ProductionLifecycleBridgeError error, {
    int? generation,
  }) = _RejectedCallV2ProductionLifecycleBridgeResult;

  final CallV2ProductionLifecycleBridgeResultStatus status;
  final CallV2ProductionLifecycleBridgeError? error;
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
    return 'CallV2ProductionLifecycleBridgeResult(${toSafeDebugMap()})';
  }
}

final class _InitializedCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _InitializedCallV2ProductionLifecycleBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionLifecycleBridgeResultStatus.initialized,
        );
}

final class _DisabledCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _DisabledCallV2ProductionLifecycleBridgeResult({super.generation})
      : super._(status: CallV2ProductionLifecycleBridgeResultStatus.disabled);
}

final class _DelegatedCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _DelegatedCallV2ProductionLifecycleBridgeResult({super.generation})
      : super._(status: CallV2ProductionLifecycleBridgeResultStatus.delegated);
}

final class _ClosedCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _ClosedCallV2ProductionLifecycleBridgeResult({super.generation})
      : super._(status: CallV2ProductionLifecycleBridgeResultStatus.closed);
}

final class _CleanedUpCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _CleanedUpCallV2ProductionLifecycleBridgeResult({super.generation})
      : super._(status: CallV2ProductionLifecycleBridgeResultStatus.cleanedUp);
}

final class _DisposedCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _DisposedCallV2ProductionLifecycleBridgeResult()
      : super._(status: CallV2ProductionLifecycleBridgeResultStatus.disposed);
}

final class _TerminalCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _TerminalCallV2ProductionLifecycleBridgeResult({super.generation})
      : super._(status: CallV2ProductionLifecycleBridgeResultStatus.terminal);
}

final class _NoOpCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _NoOpCallV2ProductionLifecycleBridgeResult({super.generation})
      : super._(status: CallV2ProductionLifecycleBridgeResultStatus.noOp);
}

final class _RejectedCallV2ProductionLifecycleBridgeResult
    extends CallV2ProductionLifecycleBridgeResult {
  const _RejectedCallV2ProductionLifecycleBridgeResult(
    CallV2ProductionLifecycleBridgeError error, {
    super.generation,
  }) : super._(
          status: CallV2ProductionLifecycleBridgeResultStatus.rejected,
          error: error,
        );
}
