enum CallV2LifecycleObserverBoundaryStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noFrameworkLifecycleObserver,
  noBindingLifecycleObserver,
  noObserverRegistration,
  noRuntimeStart,
  noBackendFirebaseAccess,
  noRtcPermissionAccess,
  noNavigatorAccess,
  noRouteRegistryMutation,
  noAsyncHandles,
  v1Protected,
}

enum CallV2LifecycleObserverEvent {
  resumed,
  inactive,
  paused,
  hidden,
  detached,
}

enum CallV2LifecycleObserverDecisionStatus {
  disabledInert,
  duplicateNoOp,
  staleIgnored,
  terminalIgnored,
}

final class CallV2LifecycleObserverDecision {
  const CallV2LifecycleObserverDecision._({
    required this.status,
    required this.event,
    required this.generation,
  });

  const CallV2LifecycleObserverDecision.disabledInert({
    required CallV2LifecycleObserverEvent event,
    required int generation,
  }) : this._(
          status: CallV2LifecycleObserverDecisionStatus.disabledInert,
          event: event,
          generation: generation,
        );

  const CallV2LifecycleObserverDecision.duplicateNoOp({
    required CallV2LifecycleObserverEvent event,
    required int generation,
  }) : this._(
          status: CallV2LifecycleObserverDecisionStatus.duplicateNoOp,
          event: event,
          generation: generation,
        );

  const CallV2LifecycleObserverDecision.staleIgnored({
    required CallV2LifecycleObserverEvent event,
    required int generation,
  }) : this._(
          status: CallV2LifecycleObserverDecisionStatus.staleIgnored,
          event: event,
          generation: generation,
        );

  const CallV2LifecycleObserverDecision.terminalIgnored({
    required CallV2LifecycleObserverEvent event,
    required int generation,
  }) : this._(
          status: CallV2LifecycleObserverDecisionStatus.terminalIgnored,
          event: event,
          generation: generation,
        );

  final CallV2LifecycleObserverDecisionStatus status;
  final CallV2LifecycleObserverEvent event;
  final int generation;

  bool get registersObserver => false;
  bool get startsRuntime => false;
  bool get accessesBackendFirebase => false;
  bool get accessesRtcPermissions => false;
  bool get accessesNavigator => false;
  bool get mutatesRouteRegistry => false;
  bool get opensAsyncHandles => false;
  bool get mutatesV1State => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'event': event.name,
      'generationKnown': generation >= 0,
      'registersObserver': registersObserver,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'accessesNavigator': accessesNavigator,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'mutatesV1State': mutatesV1State,
    };
  }

  @override
  String toString() {
    return 'CallV2LifecycleObserverDecision(${toSafeDebugMap()})';
  }
}

final class CallV2LifecycleObserverBoundary {
  factory CallV2LifecycleObserverBoundary({
    required List<CallV2LifecycleObserverBoundaryStatus> statuses,
    required List<CallV2LifecycleObserverEvent> events,
  }) {
    return CallV2LifecycleObserverBoundary._(
      List<CallV2LifecycleObserverBoundaryStatus>.unmodifiable(statuses),
      List<CallV2LifecycleObserverEvent>.unmodifiable(events),
    );
  }

  const CallV2LifecycleObserverBoundary._(
    this.statuses,
    this.events,
  );

  final List<CallV2LifecycleObserverBoundaryStatus> statuses;
  final List<CallV2LifecycleObserverEvent> events;

  bool get isDeveloperOnly => statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.developerOnly,
      );

  bool get isHardDisabled => statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.rolloutFalse,
      );

  bool get isReachable => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.unreachable,
      );

  bool get registersFrameworkLifecycleObserver => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noFrameworkLifecycleObserver,
      );

  bool get registersBindingLifecycleObserver => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noBindingLifecycleObserver,
      );

  bool get registersObserver => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noObserverRegistration,
      );

  bool get startsRuntime => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noRuntimeStart,
      );

  bool get accessesBackendFirebase => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noBackendFirebaseAccess,
      );

  bool get accessesRtcPermissions => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noRtcPermissionAccess,
      );

  bool get accessesNavigator => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noNavigatorAccess,
      );

  bool get mutatesRouteRegistry => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noRouteRegistryMutation,
      );

  bool get opensAsyncHandles => !statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.noAsyncHandles,
      );

  bool get protectsV1 => statuses.contains(
        CallV2LifecycleObserverBoundaryStatus.v1Protected,
      );

  CallV2LifecycleObserverDecision decideWhileDisabled({
    required CallV2LifecycleObserverEvent event,
    required int generation,
    int? latestGeneration,
    bool terminal = false,
  }) {
    if (terminal) {
      return CallV2LifecycleObserverDecision.terminalIgnored(
        event: event,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2LifecycleObserverDecision.staleIgnored(
        event: event,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2LifecycleObserverDecision.duplicateNoOp(
        event: event,
        generation: generation,
      );
    }
    return CallV2LifecycleObserverDecision.disabledInert(
      event: event,
      generation: generation,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': statuses.length,
      'eventCount': events.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'registersFrameworkLifecycleObserver':
          registersFrameworkLifecycleObserver,
      'registersBindingLifecycleObserver': registersBindingLifecycleObserver,
      'registersObserver': registersObserver,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'accessesNavigator': accessesNavigator,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2LifecycleObserverBoundary(${toSafeDebugMap()})';
  }
}

final callV2LifecycleObserverBoundary = CallV2LifecycleObserverBoundary(
  statuses: <CallV2LifecycleObserverBoundaryStatus>[
    CallV2LifecycleObserverBoundaryStatus.developerOnly,
    CallV2LifecycleObserverBoundaryStatus.hardDisabled,
    CallV2LifecycleObserverBoundaryStatus.rolloutFalse,
    CallV2LifecycleObserverBoundaryStatus.unreachable,
    CallV2LifecycleObserverBoundaryStatus.noFrameworkLifecycleObserver,
    CallV2LifecycleObserverBoundaryStatus.noBindingLifecycleObserver,
    CallV2LifecycleObserverBoundaryStatus.noObserverRegistration,
    CallV2LifecycleObserverBoundaryStatus.noRuntimeStart,
    CallV2LifecycleObserverBoundaryStatus.noBackendFirebaseAccess,
    CallV2LifecycleObserverBoundaryStatus.noRtcPermissionAccess,
    CallV2LifecycleObserverBoundaryStatus.noNavigatorAccess,
    CallV2LifecycleObserverBoundaryStatus.noRouteRegistryMutation,
    CallV2LifecycleObserverBoundaryStatus.noAsyncHandles,
    CallV2LifecycleObserverBoundaryStatus.v1Protected,
  ],
  events: <CallV2LifecycleObserverEvent>[
    CallV2LifecycleObserverEvent.resumed,
    CallV2LifecycleObserverEvent.inactive,
    CallV2LifecycleObserverEvent.paused,
    CallV2LifecycleObserverEvent.hidden,
    CallV2LifecycleObserverEvent.detached,
  ],
);
