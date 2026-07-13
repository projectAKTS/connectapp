enum CallV2DeveloperRuntimeStartupOwnerSkeletonStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  callV2Unreachable,
  noRuntimeConstruction,
  noRuntimeStart,
  noCompositionConstruction,
  noStartupBridgeWiring,
  noMainDartWiring,
  noAppRouterWiring,
  noRouteRegistryMutation,
  noLifecycleHookRegistration,
  noNavigationAccess,
  noServiceAccess,
  noMediaAccess,
  noCapabilityPrompt,
  noAsyncHandles,
  deploymentNotApproved,
  v1Protected,
}

enum CallV2DeveloperRuntimeStartupAction {
  prepareDeveloperStartup,
  requestStartup,
  markStartupReady,
  rejectStartup,
  stopStartup,
  disposeStartup,
}

enum CallV2DeveloperRuntimeStartupOwnershipRule {
  explicitHumanApprovalRequired,
  developerOnlyAllowlistRequired,
  rolloutFalseBlocksStartup,
  noProductionServiceContact,
  noPublicUserExposure,
  idempotentStartup,
  duplicateStartupNoOp,
  staleGenerationIgnored,
  terminalOrDisposedStartupRejected,
  controlledFailureOnly,
}

enum CallV2DeveloperRuntimeStartupDecisionStatus {
  disabledInert,
  rejected,
  duplicateNoOp,
  staleIgnored,
}

enum CallV2DeveloperRuntimeStartupRejection {
  disposed,
  terminal,
  controlledFailure,
}

enum CallV2DeveloperRuntimeStartupRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  v1Unaffected,
}

final class CallV2DeveloperRuntimeStartupDecision {
  const CallV2DeveloperRuntimeStartupDecision._({
    required this.status,
    required this.action,
    required this.generation,
    this.rejection,
  });

  const CallV2DeveloperRuntimeStartupDecision.disabledInert({
    required CallV2DeveloperRuntimeStartupAction action,
    required int generation,
  }) : this._(
          status: CallV2DeveloperRuntimeStartupDecisionStatus.disabledInert,
          action: action,
          generation: generation,
        );

  const CallV2DeveloperRuntimeStartupDecision.rejected({
    required CallV2DeveloperRuntimeStartupAction action,
    required int generation,
    required CallV2DeveloperRuntimeStartupRejection rejection,
  }) : this._(
          status: CallV2DeveloperRuntimeStartupDecisionStatus.rejected,
          action: action,
          generation: generation,
          rejection: rejection,
        );

  const CallV2DeveloperRuntimeStartupDecision.duplicateNoOp({
    required CallV2DeveloperRuntimeStartupAction action,
    required int generation,
  }) : this._(
          status: CallV2DeveloperRuntimeStartupDecisionStatus.duplicateNoOp,
          action: action,
          generation: generation,
        );

  const CallV2DeveloperRuntimeStartupDecision.staleIgnored({
    required CallV2DeveloperRuntimeStartupAction action,
    required int generation,
  }) : this._(
          status: CallV2DeveloperRuntimeStartupDecisionStatus.staleIgnored,
          action: action,
          generation: generation,
        );

  final CallV2DeveloperRuntimeStartupDecisionStatus status;
  final CallV2DeveloperRuntimeStartupAction action;
  final int generation;
  final CallV2DeveloperRuntimeStartupRejection? rejection;

  bool get constructsRuntime => false;
  bool get startsRuntime => false;
  bool get constructsComposition => false;
  bool get wiresStartupBridge => false;
  bool get accessesServices => false;
  bool get accessesMedia => false;
  bool get promptsForCapabilities => false;
  bool get accessesNavigation => false;
  bool get mutatesRouteRegistry => false;
  bool get registersLifecycleHook => false;
  bool get mutatesV1State => false;
  bool get opensAsyncHandles => false;
  bool get exposesPublicUsers => false;
  bool get contactsProductionServices => false;
  bool get controlledFailureOnly => true;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'rejected':
          status == CallV2DeveloperRuntimeStartupDecisionStatus.rejected,
      'duplicate':
          status == CallV2DeveloperRuntimeStartupDecisionStatus.duplicateNoOp,
      'stale':
          status == CallV2DeveloperRuntimeStartupDecisionStatus.staleIgnored,
      'hasReason': rejection != null,
      'generationKnown': generation >= 0,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'constructsComposition': constructsComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'accessesServices': accessesServices,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'accessesNavigation': accessesNavigation,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'registersLifecycleHook': registersLifecycleHook,
      'mutatesV1State': mutatesV1State,
      'opensAsyncHandles': opensAsyncHandles,
      'exposesPublicUsers': exposesPublicUsers,
      'contactsProductionServices': contactsProductionServices,
      'controlledFailureOnly': controlledFailureOnly,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRuntimeStartupDecision(${toSafeDebugMap()})';
  }
}

final class CallV2DeveloperRuntimeStartupOwnerSkeleton {
  factory CallV2DeveloperRuntimeStartupOwnerSkeleton({
    required List<CallV2DeveloperRuntimeStartupOwnerSkeletonStatus> status,
    required List<CallV2DeveloperRuntimeStartupAction> actions,
    required List<CallV2DeveloperRuntimeStartupOwnershipRule> ownershipRules,
    required List<CallV2DeveloperRuntimeStartupRollback> rollbackRequirements,
  }) {
    return CallV2DeveloperRuntimeStartupOwnerSkeleton._(
      List<CallV2DeveloperRuntimeStartupOwnerSkeletonStatus>.unmodifiable(
        status,
      ),
      List<CallV2DeveloperRuntimeStartupAction>.unmodifiable(actions),
      List<CallV2DeveloperRuntimeStartupOwnershipRule>.unmodifiable(
        ownershipRules,
      ),
      List<CallV2DeveloperRuntimeStartupRollback>.unmodifiable(
        rollbackRequirements,
      ),
    );
  }

  const CallV2DeveloperRuntimeStartupOwnerSkeleton._(
    this.status,
    this.actions,
    this.ownershipRules,
    this.rollbackRequirements,
  );

  final List<CallV2DeveloperRuntimeStartupOwnerSkeletonStatus> status;
  final List<CallV2DeveloperRuntimeStartupAction> actions;
  final List<CallV2DeveloperRuntimeStartupOwnershipRule> ownershipRules;
  final List<CallV2DeveloperRuntimeStartupRollback> rollbackRequirements;

  bool get isDeveloperOnly => status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.developerOnly,
      );

  bool get isHardDisabled => status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.rolloutFalse,
      );

  bool get isReachable => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.callV2Unreachable,
      );

  bool get constructsRuntime => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noRuntimeConstruction,
      );

  bool get startsRuntime => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noRuntimeStart,
      );

  bool get constructsComposition => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus
            .noCompositionConstruction,
      );

  bool get wiresStartupBridge => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noStartupBridgeWiring,
      );

  bool get wiresMainDart => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noMainDartWiring,
      );

  bool get wiresAppRouter => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noAppRouterWiring,
      );

  bool get mutatesRouteRegistry => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus
            .noRouteRegistryMutation,
      );

  bool get registersLifecycleHook => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus
            .noLifecycleHookRegistration,
      );

  bool get accessesNavigation => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noNavigationAccess,
      );

  bool get accessesServices => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noServiceAccess,
      );

  bool get accessesMedia => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noMediaAccess,
      );

  bool get promptsForCapabilities => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noCapabilityPrompt,
      );

  bool get opensAsyncHandles => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noAsyncHandles,
      );

  bool get isDeploymentApproved => !status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.deploymentNotApproved,
      );

  bool get protectsV1 => status.contains(
        CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.v1Protected,
      );

  CallV2DeveloperRuntimeStartupDecision decideWhileDisabled({
    required CallV2DeveloperRuntimeStartupAction action,
    required int generation,
    int? latestGeneration,
    bool disposed = false,
    bool terminal = false,
    bool controlledFailure = false,
  }) {
    if (disposed) {
      return CallV2DeveloperRuntimeStartupDecision.rejected(
        action: action,
        generation: generation,
        rejection: CallV2DeveloperRuntimeStartupRejection.disposed,
      );
    }
    if (terminal) {
      return CallV2DeveloperRuntimeStartupDecision.rejected(
        action: action,
        generation: generation,
        rejection: CallV2DeveloperRuntimeStartupRejection.terminal,
      );
    }
    if (controlledFailure) {
      return CallV2DeveloperRuntimeStartupDecision.rejected(
        action: action,
        generation: generation,
        rejection: CallV2DeveloperRuntimeStartupRejection.controlledFailure,
      );
    }
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2DeveloperRuntimeStartupDecision.staleIgnored(
        action: action,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2DeveloperRuntimeStartupDecision.duplicateNoOp(
        action: action,
        generation: generation,
      );
    }
    return CallV2DeveloperRuntimeStartupDecision.disabledInert(
      action: action,
      generation: generation,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': status.length,
      'actionCount': actions.length,
      'ownershipRuleCount': ownershipRules.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'constructsComposition': constructsComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'wiresMainDart': wiresMainDart,
      'wiresAppRouter': wiresAppRouter,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'registersLifecycleHook': registersLifecycleHook,
      'accessesNavigation': accessesNavigation,
      'accessesServices': accessesServices,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'opensAsyncHandles': opensAsyncHandles,
      'deploymentApproved': isDeploymentApproved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRuntimeStartupOwnerSkeleton(${toSafeDebugMap()})';
  }
}

final callV2DeveloperRuntimeStartupOwnerSkeleton =
    CallV2DeveloperRuntimeStartupOwnerSkeleton(
  status: <CallV2DeveloperRuntimeStartupOwnerSkeletonStatus>[
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.developerOnly,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.hardDisabled,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.rolloutFalse,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.callV2Unreachable,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noRuntimeConstruction,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noRuntimeStart,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noCompositionConstruction,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noStartupBridgeWiring,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noMainDartWiring,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noAppRouterWiring,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noRouteRegistryMutation,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus
        .noLifecycleHookRegistration,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noNavigationAccess,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noServiceAccess,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noMediaAccess,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noCapabilityPrompt,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.noAsyncHandles,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.deploymentNotApproved,
    CallV2DeveloperRuntimeStartupOwnerSkeletonStatus.v1Protected,
  ],
  actions: <CallV2DeveloperRuntimeStartupAction>[
    CallV2DeveloperRuntimeStartupAction.prepareDeveloperStartup,
    CallV2DeveloperRuntimeStartupAction.requestStartup,
    CallV2DeveloperRuntimeStartupAction.markStartupReady,
    CallV2DeveloperRuntimeStartupAction.rejectStartup,
    CallV2DeveloperRuntimeStartupAction.stopStartup,
    CallV2DeveloperRuntimeStartupAction.disposeStartup,
  ],
  ownershipRules: <CallV2DeveloperRuntimeStartupOwnershipRule>[
    CallV2DeveloperRuntimeStartupOwnershipRule.explicitHumanApprovalRequired,
    CallV2DeveloperRuntimeStartupOwnershipRule.developerOnlyAllowlistRequired,
    CallV2DeveloperRuntimeStartupOwnershipRule.rolloutFalseBlocksStartup,
    CallV2DeveloperRuntimeStartupOwnershipRule.noProductionServiceContact,
    CallV2DeveloperRuntimeStartupOwnershipRule.noPublicUserExposure,
    CallV2DeveloperRuntimeStartupOwnershipRule.idempotentStartup,
    CallV2DeveloperRuntimeStartupOwnershipRule.duplicateStartupNoOp,
    CallV2DeveloperRuntimeStartupOwnershipRule.staleGenerationIgnored,
    CallV2DeveloperRuntimeStartupOwnershipRule
        .terminalOrDisposedStartupRejected,
    CallV2DeveloperRuntimeStartupOwnershipRule.controlledFailureOnly,
  ],
  rollbackRequirements: <CallV2DeveloperRuntimeStartupRollback>[
    CallV2DeveloperRuntimeStartupRollback.oneCommitRevert,
    CallV2DeveloperRuntimeStartupRollback.keepRolloutFalse,
    CallV2DeveloperRuntimeStartupRollback.keepRouteRegistryNull,
    CallV2DeveloperRuntimeStartupRollback.keepDisabledOwnerInert,
    CallV2DeveloperRuntimeStartupRollback.noDeploymentRequired,
    CallV2DeveloperRuntimeStartupRollback.v1Unaffected,
  ],
);
