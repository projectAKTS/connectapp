enum CallV2DeveloperBackendOwnerSkeletonStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  callV2Unreachable,
  noBackendAttach,
  noServiceImports,
  noDocumentListeners,
  noDocumentReadsWrites,
  noIdentityCallableCalls,
  noAppCheckDebugTokenHandling,
  noRawSnapshotStorage,
  noRuntimeConstruction,
  noRuntimeStart,
  noCompositionConstruction,
  noStartupBridgeWiring,
  noRouteRegistryMutation,
  noNavigationAccess,
  noMediaAccess,
  noCapabilityPrompt,
  noAsyncHandles,
  noServerRulesConfigChanges,
  deploymentNotApproved,
  v1Protected,
}

enum CallV2DeveloperBackendAction {
  prepareBackendOwner,
  requestBackendAttach,
  receiveSanitizedSnapshot,
  rejectSnapshot,
  detachBackendOwner,
  disposeBackendOwner,
}

enum CallV2DeveloperSanitizedBackendEvent {
  sanitizedConnecting,
  sanitizedRinging,
  sanitizedActive,
  sanitizedEnding,
  sanitizedEnded,
  sanitizedFailure,
  sanitizedTimeout,
  sanitizedRemoteDisconnect,
}

enum CallV2DeveloperBackendOwnershipRule {
  explicitHumanApprovalRequired,
  developerOnlyAllowlistRequired,
  rolloutFalseBlocksBackendAttach,
  noServiceImports,
  noDocumentListeners,
  noDocumentReadsWrites,
  noIdentityCallableCalls,
  noRawSnapshotStorage,
  noRawIdentityStorage,
  noRawCallableResultStorage,
  sanitizedEnumBooleanGenerationOnly,
  duplicateSnapshotNoOp,
  staleSnapshotIgnored,
  outOfOrderSnapshotRejected,
  ownershipMismatchRejected,
  terminalSnapshotDetaches,
  signOutIdentityInvalidDetaches,
  controlledFailureOnly,
}

enum CallV2DeveloperBackendDecisionStatus {
  disabledInert,
  rejected,
  duplicateNoOp,
  staleIgnored,
  detached,
}

enum CallV2DeveloperBackendRejection {
  disposed,
  terminal,
  staleGeneration,
  duplicateGeneration,
  outOfOrderState,
  ownershipMismatch,
  rawPayloadRejected,
  controlledFailure,
}

enum CallV2DeveloperBackendRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noServerRulesConfigChanges,
  v1Unaffected,
}

final class CallV2DeveloperBackendDecision {
  const CallV2DeveloperBackendDecision._({
    required this.status,
    required this.action,
    required this.generation,
    this.event,
    this.rejection,
  });

  const CallV2DeveloperBackendDecision.disabledInert({
    required CallV2DeveloperBackendAction action,
    required int generation,
    CallV2DeveloperSanitizedBackendEvent? event,
  }) : this._(
          status: CallV2DeveloperBackendDecisionStatus.disabledInert,
          action: action,
          generation: generation,
          event: event,
        );

  const CallV2DeveloperBackendDecision.rejected({
    required CallV2DeveloperBackendAction action,
    required int generation,
    required CallV2DeveloperBackendRejection rejection,
    CallV2DeveloperSanitizedBackendEvent? event,
  }) : this._(
          status: CallV2DeveloperBackendDecisionStatus.rejected,
          action: action,
          generation: generation,
          event: event,
          rejection: rejection,
        );

  const CallV2DeveloperBackendDecision.duplicateNoOp({
    required CallV2DeveloperBackendAction action,
    required int generation,
    CallV2DeveloperSanitizedBackendEvent? event,
  }) : this._(
          status: CallV2DeveloperBackendDecisionStatus.duplicateNoOp,
          action: action,
          generation: generation,
          event: event,
          rejection: CallV2DeveloperBackendRejection.duplicateGeneration,
        );

  const CallV2DeveloperBackendDecision.staleIgnored({
    required CallV2DeveloperBackendAction action,
    required int generation,
    CallV2DeveloperSanitizedBackendEvent? event,
  }) : this._(
          status: CallV2DeveloperBackendDecisionStatus.staleIgnored,
          action: action,
          generation: generation,
          event: event,
          rejection: CallV2DeveloperBackendRejection.staleGeneration,
        );

  const CallV2DeveloperBackendDecision.detached({
    required CallV2DeveloperBackendAction action,
    required int generation,
    CallV2DeveloperSanitizedBackendEvent? event,
    CallV2DeveloperBackendRejection? rejection,
  }) : this._(
          status: CallV2DeveloperBackendDecisionStatus.detached,
          action: action,
          generation: generation,
          event: event,
          rejection: rejection,
        );

  final CallV2DeveloperBackendDecisionStatus status;
  final CallV2DeveloperBackendAction action;
  final int generation;
  final CallV2DeveloperSanitizedBackendEvent? event;
  final CallV2DeveloperBackendRejection? rejection;

  bool get attachesBackend => false;
  bool get importsServices => false;
  bool get opensDocumentListener => false;
  bool get readsOrWritesDocuments => false;
  bool get callsIdentityOrCallable => false;
  bool get handlesAppCheckDebugToken => false;
  bool get storesRawSnapshot => false;
  bool get constructsRuntime => false;
  bool get startsRuntime => false;
  bool get constructsComposition => false;
  bool get wiresStartupBridge => false;
  bool get mutatesRouteRegistry => false;
  bool get accessesNavigation => false;
  bool get accessesMedia => false;
  bool get promptsForCapabilities => false;
  bool get mutatesV1State => false;
  bool get opensAsyncHandles => false;
  bool get changesServerRulesConfig => false;
  bool get controlledFailureOnly => true;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'rejected': status == CallV2DeveloperBackendDecisionStatus.rejected,
      'duplicate': status == CallV2DeveloperBackendDecisionStatus.duplicateNoOp,
      'stale': status == CallV2DeveloperBackendDecisionStatus.staleIgnored,
      'detached': status == CallV2DeveloperBackendDecisionStatus.detached,
      'hasEvent': event != null,
      'hasReason': rejection != null,
      'generationKnown': generation >= 0,
      'attachesBackend': attachesBackend,
      'importsServices': importsServices,
      'opensDocumentListener': opensDocumentListener,
      'readsOrWritesDocuments': readsOrWritesDocuments,
      'callsIdentityOrCallable': callsIdentityOrCallable,
      'handlesAppCheckDebugToken': handlesAppCheckDebugToken,
      'storesRawSnapshot': storesRawSnapshot,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'constructsComposition': constructsComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'accessesNavigation': accessesNavigation,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'mutatesV1State': mutatesV1State,
      'opensAsyncHandles': opensAsyncHandles,
      'changesServerRulesConfig': changesServerRulesConfig,
      'controlledFailureOnly': controlledFailureOnly,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperBackendDecision(${toSafeDebugMap()})';
  }
}

final class CallV2DeveloperBackendOwnerSkeleton {
  factory CallV2DeveloperBackendOwnerSkeleton({
    required List<CallV2DeveloperBackendOwnerSkeletonStatus> status,
    required List<CallV2DeveloperBackendAction> actions,
    required List<CallV2DeveloperSanitizedBackendEvent> sanitizedEvents,
    required List<CallV2DeveloperBackendOwnershipRule> ownershipRules,
    required List<CallV2DeveloperBackendRollback> rollbackRequirements,
  }) {
    return CallV2DeveloperBackendOwnerSkeleton._(
      List<CallV2DeveloperBackendOwnerSkeletonStatus>.unmodifiable(status),
      List<CallV2DeveloperBackendAction>.unmodifiable(actions),
      List<CallV2DeveloperSanitizedBackendEvent>.unmodifiable(
        sanitizedEvents,
      ),
      List<CallV2DeveloperBackendOwnershipRule>.unmodifiable(ownershipRules),
      List<CallV2DeveloperBackendRollback>.unmodifiable(rollbackRequirements),
    );
  }

  const CallV2DeveloperBackendOwnerSkeleton._(
    this.status,
    this.actions,
    this.sanitizedEvents,
    this.ownershipRules,
    this.rollbackRequirements,
  );

  final List<CallV2DeveloperBackendOwnerSkeletonStatus> status;
  final List<CallV2DeveloperBackendAction> actions;
  final List<CallV2DeveloperSanitizedBackendEvent> sanitizedEvents;
  final List<CallV2DeveloperBackendOwnershipRule> ownershipRules;
  final List<CallV2DeveloperBackendRollback> rollbackRequirements;

  bool get isDeveloperOnly => status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.developerOnly,
      );

  bool get isHardDisabled => status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.rolloutFalse,
      );

  bool get isReachable => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.callV2Unreachable,
      );

  bool get attachesBackend => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noBackendAttach,
      );

  bool get importsServices => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noServiceImports,
      );

  bool get opensDocumentListeners => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noDocumentListeners,
      );

  bool get readsOrWritesDocuments => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noDocumentReadsWrites,
      );

  bool get callsIdentityOrCallable => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noIdentityCallableCalls,
      );

  bool get handlesAppCheckDebugToken => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noAppCheckDebugTokenHandling,
      );

  bool get storesRawSnapshot => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noRawSnapshotStorage,
      );

  bool get constructsRuntime => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noRuntimeConstruction,
      );

  bool get startsRuntime => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noRuntimeStart,
      );

  bool get constructsComposition => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noCompositionConstruction,
      );

  bool get wiresStartupBridge => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noStartupBridgeWiring,
      );

  bool get mutatesRouteRegistry => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noRouteRegistryMutation,
      );

  bool get accessesNavigation => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noNavigationAccess,
      );

  bool get accessesMedia => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noMediaAccess,
      );

  bool get promptsForCapabilities => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noCapabilityPrompt,
      );

  bool get opensAsyncHandles => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noAsyncHandles,
      );

  bool get changesServerRulesConfig => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.noServerRulesConfigChanges,
      );

  bool get isDeploymentApproved => !status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.deploymentNotApproved,
      );

  bool get protectsV1 => status.contains(
        CallV2DeveloperBackendOwnerSkeletonStatus.v1Protected,
      );

  CallV2DeveloperBackendDecision decideWhileDisabled({
    required CallV2DeveloperBackendAction action,
    required int generation,
    int? latestGeneration,
    CallV2DeveloperSanitizedBackendEvent? event,
    CallV2DeveloperSanitizedBackendEvent? previousEvent,
    bool ownershipMatches = true,
    bool rawPayloadProvided = false,
    bool disposed = false,
    bool terminal = false,
    bool signOutOrIdentityInvalid = false,
    bool controlledFailure = false,
  }) {
    if (disposed) {
      return CallV2DeveloperBackendDecision.rejected(
        action: action,
        generation: generation,
        event: event,
        rejection: CallV2DeveloperBackendRejection.disposed,
      );
    }
    if (rawPayloadProvided) {
      return CallV2DeveloperBackendDecision.rejected(
        action: action,
        generation: generation,
        event: event,
        rejection: CallV2DeveloperBackendRejection.rawPayloadRejected,
      );
    }
    if (!ownershipMatches) {
      return CallV2DeveloperBackendDecision.rejected(
        action: action,
        generation: generation,
        event: event,
        rejection: CallV2DeveloperBackendRejection.ownershipMismatch,
      );
    }
    if (controlledFailure) {
      return CallV2DeveloperBackendDecision.rejected(
        action: action,
        generation: generation,
        event: event,
        rejection: CallV2DeveloperBackendRejection.controlledFailure,
      );
    }
    if (_isOutOfOrder(event: event, previousEvent: previousEvent)) {
      return CallV2DeveloperBackendDecision.rejected(
        action: action,
        generation: generation,
        event: event,
        rejection: CallV2DeveloperBackendRejection.outOfOrderState,
      );
    }
    if (terminal || signOutOrIdentityInvalid || _isTerminalEvent(event)) {
      return CallV2DeveloperBackendDecision.detached(
        action: action,
        generation: generation,
        event: event,
        rejection: terminal ? CallV2DeveloperBackendRejection.terminal : null,
      );
    }
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2DeveloperBackendDecision.staleIgnored(
        action: action,
        generation: generation,
        event: event,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2DeveloperBackendDecision.duplicateNoOp(
        action: action,
        generation: generation,
        event: event,
      );
    }
    return CallV2DeveloperBackendDecision.disabledInert(
      action: action,
      generation: generation,
      event: event,
    );
  }

  bool _isTerminalEvent(CallV2DeveloperSanitizedBackendEvent? event) {
    return event == CallV2DeveloperSanitizedBackendEvent.sanitizedEnded ||
        event == CallV2DeveloperSanitizedBackendEvent.sanitizedFailure ||
        event == CallV2DeveloperSanitizedBackendEvent.sanitizedTimeout;
  }

  bool _isOutOfOrder({
    required CallV2DeveloperSanitizedBackendEvent? event,
    required CallV2DeveloperSanitizedBackendEvent? previousEvent,
  }) {
    if (event == null || previousEvent == null) return false;
    return _eventRank(event) < _eventRank(previousEvent);
  }

  int _eventRank(CallV2DeveloperSanitizedBackendEvent event) {
    switch (event) {
      case CallV2DeveloperSanitizedBackendEvent.sanitizedConnecting:
        return 0;
      case CallV2DeveloperSanitizedBackendEvent.sanitizedRinging:
        return 1;
      case CallV2DeveloperSanitizedBackendEvent.sanitizedActive:
      case CallV2DeveloperSanitizedBackendEvent.sanitizedRemoteDisconnect:
        return 2;
      case CallV2DeveloperSanitizedBackendEvent.sanitizedEnding:
        return 3;
      case CallV2DeveloperSanitizedBackendEvent.sanitizedEnded:
      case CallV2DeveloperSanitizedBackendEvent.sanitizedFailure:
      case CallV2DeveloperSanitizedBackendEvent.sanitizedTimeout:
        return 4;
    }
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': status.length,
      'actionCount': actions.length,
      'sanitizedEventCount': sanitizedEvents.length,
      'ownershipRuleCount': ownershipRules.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'attachesBackend': attachesBackend,
      'importsServices': importsServices,
      'opensDocumentListeners': opensDocumentListeners,
      'readsOrWritesDocuments': readsOrWritesDocuments,
      'callsIdentityOrCallable': callsIdentityOrCallable,
      'handlesAppCheckDebugToken': handlesAppCheckDebugToken,
      'storesRawSnapshot': storesRawSnapshot,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'constructsComposition': constructsComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'accessesNavigation': accessesNavigation,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'opensAsyncHandles': opensAsyncHandles,
      'changesServerRulesConfig': changesServerRulesConfig,
      'deploymentApproved': isDeploymentApproved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperBackendOwnerSkeleton(${toSafeDebugMap()})';
  }
}

final callV2DeveloperBackendOwnerSkeleton = CallV2DeveloperBackendOwnerSkeleton(
  status: <CallV2DeveloperBackendOwnerSkeletonStatus>[
    CallV2DeveloperBackendOwnerSkeletonStatus.developerOnly,
    CallV2DeveloperBackendOwnerSkeletonStatus.hardDisabled,
    CallV2DeveloperBackendOwnerSkeletonStatus.rolloutFalse,
    CallV2DeveloperBackendOwnerSkeletonStatus.callV2Unreachable,
    CallV2DeveloperBackendOwnerSkeletonStatus.noBackendAttach,
    CallV2DeveloperBackendOwnerSkeletonStatus.noServiceImports,
    CallV2DeveloperBackendOwnerSkeletonStatus.noDocumentListeners,
    CallV2DeveloperBackendOwnerSkeletonStatus.noDocumentReadsWrites,
    CallV2DeveloperBackendOwnerSkeletonStatus.noIdentityCallableCalls,
    CallV2DeveloperBackendOwnerSkeletonStatus.noAppCheckDebugTokenHandling,
    CallV2DeveloperBackendOwnerSkeletonStatus.noRawSnapshotStorage,
    CallV2DeveloperBackendOwnerSkeletonStatus.noRuntimeConstruction,
    CallV2DeveloperBackendOwnerSkeletonStatus.noRuntimeStart,
    CallV2DeveloperBackendOwnerSkeletonStatus.noCompositionConstruction,
    CallV2DeveloperBackendOwnerSkeletonStatus.noStartupBridgeWiring,
    CallV2DeveloperBackendOwnerSkeletonStatus.noRouteRegistryMutation,
    CallV2DeveloperBackendOwnerSkeletonStatus.noNavigationAccess,
    CallV2DeveloperBackendOwnerSkeletonStatus.noMediaAccess,
    CallV2DeveloperBackendOwnerSkeletonStatus.noCapabilityPrompt,
    CallV2DeveloperBackendOwnerSkeletonStatus.noAsyncHandles,
    CallV2DeveloperBackendOwnerSkeletonStatus.noServerRulesConfigChanges,
    CallV2DeveloperBackendOwnerSkeletonStatus.deploymentNotApproved,
    CallV2DeveloperBackendOwnerSkeletonStatus.v1Protected,
  ],
  actions: <CallV2DeveloperBackendAction>[
    CallV2DeveloperBackendAction.prepareBackendOwner,
    CallV2DeveloperBackendAction.requestBackendAttach,
    CallV2DeveloperBackendAction.receiveSanitizedSnapshot,
    CallV2DeveloperBackendAction.rejectSnapshot,
    CallV2DeveloperBackendAction.detachBackendOwner,
    CallV2DeveloperBackendAction.disposeBackendOwner,
  ],
  sanitizedEvents: <CallV2DeveloperSanitizedBackendEvent>[
    CallV2DeveloperSanitizedBackendEvent.sanitizedConnecting,
    CallV2DeveloperSanitizedBackendEvent.sanitizedRinging,
    CallV2DeveloperSanitizedBackendEvent.sanitizedActive,
    CallV2DeveloperSanitizedBackendEvent.sanitizedEnding,
    CallV2DeveloperSanitizedBackendEvent.sanitizedEnded,
    CallV2DeveloperSanitizedBackendEvent.sanitizedFailure,
    CallV2DeveloperSanitizedBackendEvent.sanitizedTimeout,
    CallV2DeveloperSanitizedBackendEvent.sanitizedRemoteDisconnect,
  ],
  ownershipRules: <CallV2DeveloperBackendOwnershipRule>[
    CallV2DeveloperBackendOwnershipRule.explicitHumanApprovalRequired,
    CallV2DeveloperBackendOwnershipRule.developerOnlyAllowlistRequired,
    CallV2DeveloperBackendOwnershipRule.rolloutFalseBlocksBackendAttach,
    CallV2DeveloperBackendOwnershipRule.noServiceImports,
    CallV2DeveloperBackendOwnershipRule.noDocumentListeners,
    CallV2DeveloperBackendOwnershipRule.noDocumentReadsWrites,
    CallV2DeveloperBackendOwnershipRule.noIdentityCallableCalls,
    CallV2DeveloperBackendOwnershipRule.noRawSnapshotStorage,
    CallV2DeveloperBackendOwnershipRule.noRawIdentityStorage,
    CallV2DeveloperBackendOwnershipRule.noRawCallableResultStorage,
    CallV2DeveloperBackendOwnershipRule.sanitizedEnumBooleanGenerationOnly,
    CallV2DeveloperBackendOwnershipRule.duplicateSnapshotNoOp,
    CallV2DeveloperBackendOwnershipRule.staleSnapshotIgnored,
    CallV2DeveloperBackendOwnershipRule.outOfOrderSnapshotRejected,
    CallV2DeveloperBackendOwnershipRule.ownershipMismatchRejected,
    CallV2DeveloperBackendOwnershipRule.terminalSnapshotDetaches,
    CallV2DeveloperBackendOwnershipRule.signOutIdentityInvalidDetaches,
    CallV2DeveloperBackendOwnershipRule.controlledFailureOnly,
  ],
  rollbackRequirements: <CallV2DeveloperBackendRollback>[
    CallV2DeveloperBackendRollback.oneCommitRevert,
    CallV2DeveloperBackendRollback.keepRolloutFalse,
    CallV2DeveloperBackendRollback.keepRouteRegistryNull,
    CallV2DeveloperBackendRollback.keepDisabledOwnerInert,
    CallV2DeveloperBackendRollback.noDeploymentRequired,
    CallV2DeveloperBackendRollback.noServerRulesConfigChanges,
    CallV2DeveloperBackendRollback.v1Unaffected,
  ],
);
