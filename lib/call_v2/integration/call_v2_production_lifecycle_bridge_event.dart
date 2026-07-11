enum CallV2ProductionLifecycleBridgeEventType {
  initialize,
  appPaused,
  appResumed,
  appInactive,
  appDetached,
  appHidden,
  signOutStarted,
  authChanged,
  cleanupRequested,
  closeRequested,
  dispose,
  invalid,
}

enum CallV2ProductionLifecycleAuthChangeReason {
  noChange,
  stillSignedIn,
  signedOut,
  authInvalid,
}

enum CallV2ProductionLifecycleCleanupReason {
  appLifecycle,
  signOut,
  authChanged,
  explicitUserRequest,
  ownerDisposal,
}

enum CallV2ProductionLifecycleCleanupPolicy {
  noOp,
  closeOnly,
  closeAndDispose,
  terminalCloseAndDispose,
}

final class CallV2ProductionLifecycleBridgeEvent {
  const CallV2ProductionLifecycleBridgeEvent._({
    required this.type,
    this.generation,
    this.authChangeReason,
    this.cleanupReason,
    this.cleanupPolicy,
  });

  const factory CallV2ProductionLifecycleBridgeEvent.initialize() =
      _InitializeCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.appPaused({
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy cleanupPolicy,
  }) = _AppPausedCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.appResumed({
    int? generation,
  }) = _AppResumedCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.appInactive({
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy cleanupPolicy,
  }) = _AppInactiveCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.appDetached({
    int? generation,
  }) = _AppDetachedCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.appHidden({
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy cleanupPolicy,
  }) = _AppHiddenCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.signOutStarted({
    int? generation,
  }) = _SignOutStartedCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.authChanged({
    required CallV2ProductionLifecycleAuthChangeReason reason,
    int? generation,
  }) = _AuthChangedCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.cleanupRequested({
    required CallV2ProductionLifecycleCleanupReason reason,
    required CallV2ProductionLifecycleCleanupPolicy cleanupPolicy,
    int? generation,
  }) = _CleanupRequestedCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.closeRequested({
    int? generation,
  }) = _CloseRequestedCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.dispose() =
      _DisposeCallV2ProductionLifecycleBridgeEvent;

  const factory CallV2ProductionLifecycleBridgeEvent.invalid({
    int? generation,
  }) = _InvalidCallV2ProductionLifecycleBridgeEvent;

  final CallV2ProductionLifecycleBridgeEventType type;
  final int? generation;
  final CallV2ProductionLifecycleAuthChangeReason? authChangeReason;
  final CallV2ProductionLifecycleCleanupReason? cleanupReason;
  final CallV2ProductionLifecycleCleanupPolicy? cleanupPolicy;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'type': type.name,
      if (generation != null) 'generation': generation,
      if (authChangeReason != null) 'authChangeReason': authChangeReason!.name,
      if (cleanupReason != null) 'cleanupReason': cleanupReason!.name,
      if (cleanupPolicy != null) 'cleanupPolicy': cleanupPolicy!.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionLifecycleBridgeEvent(${toSafeDebugMap()})';
  }
}

final class _InitializeCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _InitializeCallV2ProductionLifecycleBridgeEvent()
      : super._(type: CallV2ProductionLifecycleBridgeEventType.initialize);
}

final class _AppPausedCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _AppPausedCallV2ProductionLifecycleBridgeEvent({
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy cleanupPolicy =
        CallV2ProductionLifecycleCleanupPolicy.noOp,
  }) : super._(
          type: CallV2ProductionLifecycleBridgeEventType.appPaused,
          generation: generation,
          cleanupReason: CallV2ProductionLifecycleCleanupReason.appLifecycle,
          cleanupPolicy: cleanupPolicy,
        );
}

final class _AppResumedCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _AppResumedCallV2ProductionLifecycleBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionLifecycleBridgeEventType.appResumed,
          generation: generation,
          cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.noOp,
        );
}

final class _AppInactiveCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _AppInactiveCallV2ProductionLifecycleBridgeEvent({
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy cleanupPolicy =
        CallV2ProductionLifecycleCleanupPolicy.noOp,
  }) : super._(
          type: CallV2ProductionLifecycleBridgeEventType.appInactive,
          generation: generation,
          cleanupReason: CallV2ProductionLifecycleCleanupReason.appLifecycle,
          cleanupPolicy: cleanupPolicy,
        );
}

final class _AppDetachedCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _AppDetachedCallV2ProductionLifecycleBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionLifecycleBridgeEventType.appDetached,
          generation: generation,
          cleanupReason: CallV2ProductionLifecycleCleanupReason.appLifecycle,
          cleanupPolicy:
              CallV2ProductionLifecycleCleanupPolicy.terminalCloseAndDispose,
        );
}

final class _AppHiddenCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _AppHiddenCallV2ProductionLifecycleBridgeEvent({
    int? generation,
    CallV2ProductionLifecycleCleanupPolicy cleanupPolicy =
        CallV2ProductionLifecycleCleanupPolicy.noOp,
  }) : super._(
          type: CallV2ProductionLifecycleBridgeEventType.appHidden,
          generation: generation,
          cleanupReason: CallV2ProductionLifecycleCleanupReason.appLifecycle,
          cleanupPolicy: cleanupPolicy,
        );
}

final class _SignOutStartedCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _SignOutStartedCallV2ProductionLifecycleBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionLifecycleBridgeEventType.signOutStarted,
          generation: generation,
          cleanupReason: CallV2ProductionLifecycleCleanupReason.signOut,
          cleanupPolicy:
              CallV2ProductionLifecycleCleanupPolicy.terminalCloseAndDispose,
        );
}

final class _AuthChangedCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _AuthChangedCallV2ProductionLifecycleBridgeEvent({
    required CallV2ProductionLifecycleAuthChangeReason reason,
    int? generation,
  }) : super._(
          type: CallV2ProductionLifecycleBridgeEventType.authChanged,
          generation: generation,
          authChangeReason: reason,
          cleanupReason: CallV2ProductionLifecycleCleanupReason.authChanged,
          cleanupPolicy: reason ==
                      CallV2ProductionLifecycleAuthChangeReason.signedOut ||
                  reason ==
                      CallV2ProductionLifecycleAuthChangeReason.authInvalid
              ? CallV2ProductionLifecycleCleanupPolicy.terminalCloseAndDispose
              : CallV2ProductionLifecycleCleanupPolicy.noOp,
        );
}

final class _CleanupRequestedCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _CleanupRequestedCallV2ProductionLifecycleBridgeEvent({
    required CallV2ProductionLifecycleCleanupReason reason,
    required CallV2ProductionLifecycleCleanupPolicy cleanupPolicy,
    int? generation,
  }) : super._(
          type: CallV2ProductionLifecycleBridgeEventType.cleanupRequested,
          generation: generation,
          cleanupReason: reason,
          cleanupPolicy: cleanupPolicy,
        );
}

final class _CloseRequestedCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _CloseRequestedCallV2ProductionLifecycleBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionLifecycleBridgeEventType.closeRequested,
          generation: generation,
          cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeOnly,
        );
}

final class _DisposeCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _DisposeCallV2ProductionLifecycleBridgeEvent()
      : super._(
          type: CallV2ProductionLifecycleBridgeEventType.dispose,
          cleanupReason: CallV2ProductionLifecycleCleanupReason.ownerDisposal,
        );
}

final class _InvalidCallV2ProductionLifecycleBridgeEvent
    extends CallV2ProductionLifecycleBridgeEvent {
  const _InvalidCallV2ProductionLifecycleBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionLifecycleBridgeEventType.invalid,
          generation: generation,
        );
}
