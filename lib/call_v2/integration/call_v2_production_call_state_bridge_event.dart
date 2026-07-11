enum CallV2ProductionCallStateBridgeEventType {
  initialize,
  localJoinRequested,
  backendRinging,
  backendAccepted,
  backendConnected,
  backendEnded,
  backendRejected,
  backendExpired,
  backendCancelled,
  backendFailedControlled,
  remoteDisconnected,
  remoteReconnected,
  credentialExpired,
  credentialRefreshFailed,
  ownershipMismatch,
  staleSnapshot,
  duplicateSnapshot,
  closeRequested,
  dispose,
  invalid,
}

enum CallV2ProductionCallStateBackendState {
  ringing,
  accepted,
  connected,
  ended,
  rejected,
  expired,
  cancelled,
  failed,
  unknown,
}

enum CallV2ProductionCallStateLocalRole {
  caller,
  callee,
  unknown,
}

enum CallV2ProductionCallStateReason {
  backendSnapshot,
  localRequest,
  terminalBackend,
  remoteConnectivity,
  credentialBoundary,
  consistencyRejected,
  duplicate,
  explicitClose,
  lifecycle,
  unknown,
}

enum CallV2ProductionCallStateConsistencyPolicy {
  noOp,
  delegateSnapshot,
  closeCall,
  terminalClose,
  controlledFailure,
  rejectStale,
  rejectOwnershipMismatch,
  requireCredentialRefresh,
  blockDuplicate,
}

final class CallV2ProductionCallStateBridgeEvent {
  const CallV2ProductionCallStateBridgeEvent._({
    required this.type,
    this.generation,
    this.backendState,
    this.localRole,
    this.reason,
    this.consistencyPolicy,
    this.remoteAvailable = false,
    this.credentialRefreshRequired = false,
  });

  const factory CallV2ProductionCallStateBridgeEvent.initialize({
    int? generation,
  }) = _InitializeCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.localJoinRequested({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _LocalJoinRequestedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendRinging({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendRingingCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendAccepted({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendAcceptedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendConnected({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendConnectedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendEnded({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendEndedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendRejected({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendRejectedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendExpired({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendExpiredCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendCancelled({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendCancelledCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.backendFailedControlled({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _BackendFailedControlledCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.remoteDisconnected({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _RemoteDisconnectedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.remoteReconnected({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _RemoteReconnectedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.credentialExpired({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _CredentialExpiredCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.credentialRefreshFailed({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _CredentialRefreshFailedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.ownershipMismatch({
    required int generation,
  }) = _OwnershipMismatchCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.staleSnapshot({
    required int generation,
  }) = _StaleSnapshotCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.duplicateSnapshot({
    required int generation,
  }) = _DuplicateSnapshotCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.closeRequested({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy,
  }) = _CloseRequestedCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.dispose() =
      _DisposeCallV2ProductionCallStateBridgeEvent;

  const factory CallV2ProductionCallStateBridgeEvent.invalid({
    int? generation,
  }) = _InvalidCallV2ProductionCallStateBridgeEvent;

  final CallV2ProductionCallStateBridgeEventType type;
  final int? generation;
  final CallV2ProductionCallStateBackendState? backendState;
  final CallV2ProductionCallStateLocalRole? localRole;
  final CallV2ProductionCallStateReason? reason;
  final CallV2ProductionCallStateConsistencyPolicy? consistencyPolicy;
  final bool remoteAvailable;
  final bool credentialRefreshRequired;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'type': type.name,
      if (generation != null) 'generation': generation,
      if (backendState != null) 'backendState': backendState!.name,
      if (localRole != null) 'localRole': localRole!.name,
      if (reason != null) 'reason': reason!.name,
      if (consistencyPolicy != null)
        'consistencyPolicy': consistencyPolicy!.name,
      'remoteAvailable': remoteAvailable,
      'credentialRefreshRequired': credentialRefreshRequired,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionCallStateBridgeEvent(${toSafeDebugMap()})';
  }
}

final class _InitializeCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _InitializeCallV2ProductionCallStateBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionCallStateBridgeEventType.initialize,
          generation: generation,
          reason: CallV2ProductionCallStateReason.lifecycle,
          consistencyPolicy: CallV2ProductionCallStateConsistencyPolicy.noOp,
        );
}

final class _LocalJoinRequestedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _LocalJoinRequestedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole =
        CallV2ProductionCallStateLocalRole.unknown,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.delegateSnapshot,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.localJoinRequested,
          generation: generation,
          localRole: localRole,
          reason: CallV2ProductionCallStateReason.localRequest,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _BackendRingingCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendRingingCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole =
        CallV2ProductionCallStateLocalRole.unknown,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.delegateSnapshot,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.backendRinging,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.ringing,
          localRole: localRole,
          reason: CallV2ProductionCallStateReason.backendSnapshot,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _BackendAcceptedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendAcceptedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole =
        CallV2ProductionCallStateLocalRole.unknown,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.delegateSnapshot,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.backendAccepted,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.accepted,
          localRole: localRole,
          reason: CallV2ProductionCallStateReason.backendSnapshot,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _BackendConnectedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendConnectedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateLocalRole localRole =
        CallV2ProductionCallStateLocalRole.unknown,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.delegateSnapshot,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.backendConnected,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.connected,
          localRole: localRole,
          reason: CallV2ProductionCallStateReason.backendSnapshot,
          consistencyPolicy: consistencyPolicy,
          remoteAvailable: true,
        );
}

final class _BackendEndedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendEndedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.terminalClose,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.backendEnded,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.ended,
          reason: CallV2ProductionCallStateReason.terminalBackend,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _BackendRejectedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendRejectedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.terminalClose,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.backendRejected,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.rejected,
          reason: CallV2ProductionCallStateReason.terminalBackend,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _BackendExpiredCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendExpiredCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.terminalClose,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.backendExpired,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.expired,
          reason: CallV2ProductionCallStateReason.terminalBackend,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _BackendCancelledCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendCancelledCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.terminalClose,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.backendCancelled,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.cancelled,
          reason: CallV2ProductionCallStateReason.terminalBackend,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _BackendFailedControlledCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _BackendFailedControlledCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.controlledFailure,
  }) : super._(
          type:
              CallV2ProductionCallStateBridgeEventType.backendFailedControlled,
          generation: generation,
          backendState: CallV2ProductionCallStateBackendState.failed,
          reason: CallV2ProductionCallStateReason.backendSnapshot,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _RemoteDisconnectedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _RemoteDisconnectedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.noOp,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.remoteDisconnected,
          generation: generation,
          reason: CallV2ProductionCallStateReason.remoteConnectivity,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _RemoteReconnectedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _RemoteReconnectedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.noOp,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.remoteReconnected,
          generation: generation,
          reason: CallV2ProductionCallStateReason.remoteConnectivity,
          consistencyPolicy: consistencyPolicy,
          remoteAvailable: true,
        );
}

final class _CredentialExpiredCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _CredentialExpiredCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.requireCredentialRefresh,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.credentialExpired,
          generation: generation,
          reason: CallV2ProductionCallStateReason.credentialBoundary,
          consistencyPolicy: consistencyPolicy,
          credentialRefreshRequired: true,
        );
}

final class _CredentialRefreshFailedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _CredentialRefreshFailedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.controlledFailure,
  }) : super._(
          type:
              CallV2ProductionCallStateBridgeEventType.credentialRefreshFailed,
          generation: generation,
          reason: CallV2ProductionCallStateReason.credentialBoundary,
          consistencyPolicy: consistencyPolicy,
          credentialRefreshRequired: true,
        );
}

final class _OwnershipMismatchCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _OwnershipMismatchCallV2ProductionCallStateBridgeEvent({
    required int generation,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.ownershipMismatch,
          generation: generation,
          reason: CallV2ProductionCallStateReason.consistencyRejected,
          consistencyPolicy: CallV2ProductionCallStateConsistencyPolicy
              .rejectOwnershipMismatch,
        );
}

final class _StaleSnapshotCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _StaleSnapshotCallV2ProductionCallStateBridgeEvent({
    required int generation,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.staleSnapshot,
          generation: generation,
          reason: CallV2ProductionCallStateReason.consistencyRejected,
          consistencyPolicy:
              CallV2ProductionCallStateConsistencyPolicy.rejectStale,
        );
}

final class _DuplicateSnapshotCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _DuplicateSnapshotCallV2ProductionCallStateBridgeEvent({
    required int generation,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.duplicateSnapshot,
          generation: generation,
          reason: CallV2ProductionCallStateReason.duplicate,
          consistencyPolicy:
              CallV2ProductionCallStateConsistencyPolicy.blockDuplicate,
        );
}

final class _CloseRequestedCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _CloseRequestedCallV2ProductionCallStateBridgeEvent({
    required int generation,
    CallV2ProductionCallStateConsistencyPolicy consistencyPolicy =
        CallV2ProductionCallStateConsistencyPolicy.closeCall,
  }) : super._(
          type: CallV2ProductionCallStateBridgeEventType.closeRequested,
          generation: generation,
          reason: CallV2ProductionCallStateReason.explicitClose,
          consistencyPolicy: consistencyPolicy,
        );
}

final class _DisposeCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _DisposeCallV2ProductionCallStateBridgeEvent()
      : super._(
          type: CallV2ProductionCallStateBridgeEventType.dispose,
          reason: CallV2ProductionCallStateReason.lifecycle,
          consistencyPolicy: CallV2ProductionCallStateConsistencyPolicy.noOp,
        );
}

final class _InvalidCallV2ProductionCallStateBridgeEvent
    extends CallV2ProductionCallStateBridgeEvent {
  const _InvalidCallV2ProductionCallStateBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionCallStateBridgeEventType.invalid,
          generation: generation,
          reason: CallV2ProductionCallStateReason.unknown,
          consistencyPolicy: CallV2ProductionCallStateConsistencyPolicy.noOp,
        );
}
