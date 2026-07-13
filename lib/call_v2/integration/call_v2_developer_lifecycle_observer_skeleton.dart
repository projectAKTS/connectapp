enum CallV2DeveloperLifecycleObserverSkeletonStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  callV2Unreachable,
  noFrameworkLifecycleHook,
  noBindingLifecycleHook,
  noRuntimeStart,
  noServiceAccess,
  noMediaAccess,
  noCapabilityPrompt,
  noNavigationAccess,
  noRoutePop,
  noContextAccess,
  noAsyncHandles,
  v1Protected,
}

enum CallV2DeveloperLifecycleEvent {
  resumed,
  inactive,
  paused,
  hidden,
  detached,
  signOut,
  authInvalid,
  dispose,
}

enum CallV2DeveloperLifecycleDecisionStatus {
  disabledInert,
  duplicateNoOp,
  staleIgnored,
}

enum CallV2DeveloperLifecycleCleanupPolicy {
  noCleanupWhileDisabled,
  futureApprovalRequired,
  callV2ScopedOnly,
  duplicateEventsNoOp,
  staleGenerationIgnored,
  terminalEventsDoNotStartRuntime,
}

enum CallV2DeveloperLifecycleRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  noDeploymentRequired,
  v1Unaffected,
}

final class CallV2DeveloperLifecycleObserverDecision {
  const CallV2DeveloperLifecycleObserverDecision._({
    required this.status,
    required this.event,
    required this.generation,
    required this.terminalEvent,
  });

  const CallV2DeveloperLifecycleObserverDecision.disabledInert({
    required CallV2DeveloperLifecycleEvent event,
    required int generation,
    required bool terminalEvent,
  }) : this._(
          status: CallV2DeveloperLifecycleDecisionStatus.disabledInert,
          event: event,
          generation: generation,
          terminalEvent: terminalEvent,
        );

  const CallV2DeveloperLifecycleObserverDecision.duplicateNoOp({
    required CallV2DeveloperLifecycleEvent event,
    required int generation,
    required bool terminalEvent,
  }) : this._(
          status: CallV2DeveloperLifecycleDecisionStatus.duplicateNoOp,
          event: event,
          generation: generation,
          terminalEvent: terminalEvent,
        );

  const CallV2DeveloperLifecycleObserverDecision.staleIgnored({
    required CallV2DeveloperLifecycleEvent event,
    required int generation,
    required bool terminalEvent,
  }) : this._(
          status: CallV2DeveloperLifecycleDecisionStatus.staleIgnored,
          event: event,
          generation: generation,
          terminalEvent: terminalEvent,
        );

  final CallV2DeveloperLifecycleDecisionStatus status;
  final CallV2DeveloperLifecycleEvent event;
  final int generation;
  final bool terminalEvent;

  bool get startsRuntime => false;
  bool get accessesServices => false;
  bool get accessesMedia => false;
  bool get promptsForCapabilities => false;
  bool get accessesNavigation => false;
  bool get popsRoutes => false;
  bool get accessesContext => false;
  bool get registersFrameworkHook => false;
  bool get registersBindingHook => false;
  bool get mutatesV1State => false;
  bool get opensAsyncHandles => false;
  bool get changesRouteRegistry => false;
  bool get requiresFutureApprovalForCleanup => terminalEvent;
  bool get scopedToCallV2 => true;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'terminalEvent': terminalEvent,
      'duplicate':
          status == CallV2DeveloperLifecycleDecisionStatus.duplicateNoOp,
      'stale': status == CallV2DeveloperLifecycleDecisionStatus.staleIgnored,
      'generationKnown': generation >= 0,
      'startsRuntime': startsRuntime,
      'accessesServices': accessesServices,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'accessesNavigation': accessesNavigation,
      'popsRoutes': popsRoutes,
      'accessesContext': accessesContext,
      'registersFrameworkHook': registersFrameworkHook,
      'registersBindingHook': registersBindingHook,
      'mutatesV1State': mutatesV1State,
      'opensAsyncHandles': opensAsyncHandles,
      'changesRouteRegistry': changesRouteRegistry,
      'requiresFutureApprovalForCleanup': requiresFutureApprovalForCleanup,
      'scopedToCallV2': scopedToCallV2,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperLifecycleObserverDecision(${toSafeDebugMap()})';
  }
}

final class CallV2DeveloperLifecycleObserverSkeleton {
  factory CallV2DeveloperLifecycleObserverSkeleton({
    required List<CallV2DeveloperLifecycleObserverSkeletonStatus> status,
    required List<CallV2DeveloperLifecycleEvent> lifecycleEvents,
    required List<CallV2DeveloperLifecycleCleanupPolicy> cleanupPolicies,
    required List<CallV2DeveloperLifecycleRollback> rollbackRequirements,
  }) {
    return CallV2DeveloperLifecycleObserverSkeleton._(
      List<CallV2DeveloperLifecycleObserverSkeletonStatus>.unmodifiable(
        status,
      ),
      List<CallV2DeveloperLifecycleEvent>.unmodifiable(lifecycleEvents),
      List<CallV2DeveloperLifecycleCleanupPolicy>.unmodifiable(
        cleanupPolicies,
      ),
      List<CallV2DeveloperLifecycleRollback>.unmodifiable(
        rollbackRequirements,
      ),
    );
  }

  const CallV2DeveloperLifecycleObserverSkeleton._(
    this.status,
    this.lifecycleEvents,
    this.cleanupPolicies,
    this.rollbackRequirements,
  );

  final List<CallV2DeveloperLifecycleObserverSkeletonStatus> status;
  final List<CallV2DeveloperLifecycleEvent> lifecycleEvents;
  final List<CallV2DeveloperLifecycleCleanupPolicy> cleanupPolicies;
  final List<CallV2DeveloperLifecycleRollback> rollbackRequirements;

  bool get isDeveloperOnly => status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.developerOnly,
      );

  bool get isHardDisabled => status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.rolloutFalse,
      );

  bool get isReachable => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.callV2Unreachable,
      );

  bool get registersFrameworkHook => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noFrameworkLifecycleHook,
      );

  bool get registersBindingHook => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noBindingLifecycleHook,
      );

  bool get startsRuntime => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noRuntimeStart,
      );

  bool get accessesServices => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noServiceAccess,
      );

  bool get accessesMedia => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noMediaAccess,
      );

  bool get promptsForCapabilities => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noCapabilityPrompt,
      );

  bool get accessesNavigation => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noNavigationAccess,
      );

  bool get popsRoutes => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noRoutePop,
      );

  bool get accessesContext => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noContextAccess,
      );

  bool get opensAsyncHandles => !status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.noAsyncHandles,
      );

  bool get protectsV1 => status.contains(
        CallV2DeveloperLifecycleObserverSkeletonStatus.v1Protected,
      );

  CallV2DeveloperLifecycleObserverDecision decideWhileDisabled({
    required CallV2DeveloperLifecycleEvent event,
    required int generation,
    int? latestGeneration,
  }) {
    final terminalEvent = isTerminalEvent(event);
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2DeveloperLifecycleObserverDecision.staleIgnored(
        event: event,
        generation: generation,
        terminalEvent: terminalEvent,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2DeveloperLifecycleObserverDecision.duplicateNoOp(
        event: event,
        generation: generation,
        terminalEvent: terminalEvent,
      );
    }
    return CallV2DeveloperLifecycleObserverDecision.disabledInert(
      event: event,
      generation: generation,
      terminalEvent: terminalEvent,
    );
  }

  bool isTerminalEvent(CallV2DeveloperLifecycleEvent event) {
    return switch (event) {
      CallV2DeveloperLifecycleEvent.detached ||
      CallV2DeveloperLifecycleEvent.signOut ||
      CallV2DeveloperLifecycleEvent.authInvalid ||
      CallV2DeveloperLifecycleEvent.dispose =>
        true,
      CallV2DeveloperLifecycleEvent.resumed ||
      CallV2DeveloperLifecycleEvent.inactive ||
      CallV2DeveloperLifecycleEvent.paused ||
      CallV2DeveloperLifecycleEvent.hidden =>
        false,
    };
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': status.length,
      'eventCount': lifecycleEvents.length,
      'cleanupPolicyCount': cleanupPolicies.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'registersFrameworkHook': registersFrameworkHook,
      'registersBindingHook': registersBindingHook,
      'startsRuntime': startsRuntime,
      'accessesServices': accessesServices,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'accessesNavigation': accessesNavigation,
      'popsRoutes': popsRoutes,
      'accessesContext': accessesContext,
      'opensAsyncHandles': opensAsyncHandles,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperLifecycleObserverSkeleton(${toSafeDebugMap()})';
  }
}

final callV2DeveloperLifecycleObserverSkeleton =
    CallV2DeveloperLifecycleObserverSkeleton(
  status: <CallV2DeveloperLifecycleObserverSkeletonStatus>[
    CallV2DeveloperLifecycleObserverSkeletonStatus.developerOnly,
    CallV2DeveloperLifecycleObserverSkeletonStatus.hardDisabled,
    CallV2DeveloperLifecycleObserverSkeletonStatus.rolloutFalse,
    CallV2DeveloperLifecycleObserverSkeletonStatus.callV2Unreachable,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noFrameworkLifecycleHook,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noBindingLifecycleHook,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noRuntimeStart,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noServiceAccess,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noMediaAccess,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noCapabilityPrompt,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noNavigationAccess,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noRoutePop,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noContextAccess,
    CallV2DeveloperLifecycleObserverSkeletonStatus.noAsyncHandles,
    CallV2DeveloperLifecycleObserverSkeletonStatus.v1Protected,
  ],
  lifecycleEvents: <CallV2DeveloperLifecycleEvent>[
    CallV2DeveloperLifecycleEvent.resumed,
    CallV2DeveloperLifecycleEvent.inactive,
    CallV2DeveloperLifecycleEvent.paused,
    CallV2DeveloperLifecycleEvent.hidden,
    CallV2DeveloperLifecycleEvent.detached,
    CallV2DeveloperLifecycleEvent.signOut,
    CallV2DeveloperLifecycleEvent.authInvalid,
    CallV2DeveloperLifecycleEvent.dispose,
  ],
  cleanupPolicies: <CallV2DeveloperLifecycleCleanupPolicy>[
    CallV2DeveloperLifecycleCleanupPolicy.noCleanupWhileDisabled,
    CallV2DeveloperLifecycleCleanupPolicy.futureApprovalRequired,
    CallV2DeveloperLifecycleCleanupPolicy.callV2ScopedOnly,
    CallV2DeveloperLifecycleCleanupPolicy.duplicateEventsNoOp,
    CallV2DeveloperLifecycleCleanupPolicy.staleGenerationIgnored,
    CallV2DeveloperLifecycleCleanupPolicy.terminalEventsDoNotStartRuntime,
  ],
  rollbackRequirements: <CallV2DeveloperLifecycleRollback>[
    CallV2DeveloperLifecycleRollback.oneCommitRevert,
    CallV2DeveloperLifecycleRollback.keepRolloutFalse,
    CallV2DeveloperLifecycleRollback.keepRouteRegistryNull,
    CallV2DeveloperLifecycleRollback.noDeploymentRequired,
    CallV2DeveloperLifecycleRollback.v1Unaffected,
  ],
);
