enum CallV2ProductionPermissionDeviceBridgeResultStatus {
  initialized,
  disabled,
  delegated,
  closed,
  noOp,
  rejected,
  disposed,
  terminal,
}

enum CallV2ProductionPermissionDeviceBridgeError {
  rolloutDisabled,
  disposed,
  terminal,
  invalidEvent,
  invalidGeneration,
  staleGeneration,
  runtimeBridgeRejected,
  runtimeBridgeUnavailable,
  userActionRequired,
  unsupportedEvent,
}

final class CallV2ProductionPermissionDeviceBridgeResult {
  const CallV2ProductionPermissionDeviceBridgeResult._({
    required this.status,
    this.error,
    this.generation,
  });

  const factory CallV2ProductionPermissionDeviceBridgeResult.initialized({
    int? generation,
  }) = _InitializedCallV2ProductionPermissionDeviceBridgeResult;

  const factory CallV2ProductionPermissionDeviceBridgeResult.disabled({
    int? generation,
  }) = _DisabledCallV2ProductionPermissionDeviceBridgeResult;

  const factory CallV2ProductionPermissionDeviceBridgeResult.delegated({
    int? generation,
  }) = _DelegatedCallV2ProductionPermissionDeviceBridgeResult;

  const factory CallV2ProductionPermissionDeviceBridgeResult.closed({
    int? generation,
  }) = _ClosedCallV2ProductionPermissionDeviceBridgeResult;

  const factory CallV2ProductionPermissionDeviceBridgeResult.noOp({
    int? generation,
  }) = _NoOpCallV2ProductionPermissionDeviceBridgeResult;

  const factory CallV2ProductionPermissionDeviceBridgeResult.rejected(
    CallV2ProductionPermissionDeviceBridgeError error, {
    int? generation,
  }) = _RejectedCallV2ProductionPermissionDeviceBridgeResult;

  const factory CallV2ProductionPermissionDeviceBridgeResult.disposed() =
      _DisposedCallV2ProductionPermissionDeviceBridgeResult;

  const factory CallV2ProductionPermissionDeviceBridgeResult.terminal({
    int? generation,
  }) = _TerminalCallV2ProductionPermissionDeviceBridgeResult;

  final CallV2ProductionPermissionDeviceBridgeResultStatus status;
  final CallV2ProductionPermissionDeviceBridgeError? error;
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
    return 'CallV2ProductionPermissionDeviceBridgeResult(${toSafeDebugMap()})';
  }
}

final class _InitializedCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _InitializedCallV2ProductionPermissionDeviceBridgeResult({
    super.generation,
  }) : super._(
          status:
              CallV2ProductionPermissionDeviceBridgeResultStatus.initialized,
        );
}

final class _DisabledCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _DisabledCallV2ProductionPermissionDeviceBridgeResult({
    super.generation,
  }) : super._(
          status: CallV2ProductionPermissionDeviceBridgeResultStatus.disabled,
        );
}

final class _DelegatedCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _DelegatedCallV2ProductionPermissionDeviceBridgeResult({
    super.generation,
  }) : super._(
          status: CallV2ProductionPermissionDeviceBridgeResultStatus.delegated,
        );
}

final class _ClosedCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _ClosedCallV2ProductionPermissionDeviceBridgeResult({
    super.generation,
  }) : super._(
          status: CallV2ProductionPermissionDeviceBridgeResultStatus.closed,
        );
}

final class _NoOpCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _NoOpCallV2ProductionPermissionDeviceBridgeResult({super.generation})
      : super._(
          status: CallV2ProductionPermissionDeviceBridgeResultStatus.noOp,
        );
}

final class _RejectedCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _RejectedCallV2ProductionPermissionDeviceBridgeResult(
    CallV2ProductionPermissionDeviceBridgeError error, {
    super.generation,
  }) : super._(
          status: CallV2ProductionPermissionDeviceBridgeResultStatus.rejected,
          error: error,
        );
}

final class _DisposedCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _DisposedCallV2ProductionPermissionDeviceBridgeResult()
      : super._(
          status: CallV2ProductionPermissionDeviceBridgeResultStatus.disposed,
        );
}

final class _TerminalCallV2ProductionPermissionDeviceBridgeResult
    extends CallV2ProductionPermissionDeviceBridgeResult {
  const _TerminalCallV2ProductionPermissionDeviceBridgeResult({
    super.generation,
  }) : super._(
          status: CallV2ProductionPermissionDeviceBridgeResultStatus.terminal,
        );
}
