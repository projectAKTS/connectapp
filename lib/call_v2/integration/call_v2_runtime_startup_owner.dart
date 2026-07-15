enum CallV2RuntimeStartupOwnerStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noRuntimeConstruction,
  noRuntimeStart,
  noProductionCompositionConstruction,
  noStartupBridgeWiring,
  noMainDartWiring,
  noAppRouterWiring,
  noBackendAccess,
  noMediaCapabilityAccess,
  noNavigationAccess,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noAsyncHandles,
  noDeployment,
  v1Protected,
}

enum CallV2RuntimeStartupOwnerAction {
  requestStartup,
  requestShutdown,
  markReady,
  markFailure,
  retryStartup,
}

enum CallV2RuntimeStartupOwnerDecisionStatus {
  disabledInert,
  duplicateNoOp,
  staleIgnored,
  rejected,
  terminalIgnored,
}

enum CallV2RuntimeStartupOwnerRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RuntimeStartupOwnerDecision {
  const CallV2RuntimeStartupOwnerDecision._({
    required this.status,
    required this.action,
    required this.generation,
  });

  const CallV2RuntimeStartupOwnerDecision.disabledInert({
    required CallV2RuntimeStartupOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2RuntimeStartupOwnerDecisionStatus.disabledInert,
          action: action,
          generation: generation,
        );

  const CallV2RuntimeStartupOwnerDecision.duplicateNoOp({
    required CallV2RuntimeStartupOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2RuntimeStartupOwnerDecisionStatus.duplicateNoOp,
          action: action,
          generation: generation,
        );

  const CallV2RuntimeStartupOwnerDecision.staleIgnored({
    required CallV2RuntimeStartupOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2RuntimeStartupOwnerDecisionStatus.staleIgnored,
          action: action,
          generation: generation,
        );

  const CallV2RuntimeStartupOwnerDecision.rejected({
    required CallV2RuntimeStartupOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2RuntimeStartupOwnerDecisionStatus.rejected,
          action: action,
          generation: generation,
        );

  const CallV2RuntimeStartupOwnerDecision.terminalIgnored({
    required CallV2RuntimeStartupOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2RuntimeStartupOwnerDecisionStatus.terminalIgnored,
          action: action,
          generation: generation,
        );

  final CallV2RuntimeStartupOwnerDecisionStatus status;
  final CallV2RuntimeStartupOwnerAction action;
  final int generation;

  bool get constructsRuntime => false;
  bool get startsRuntime => false;
  bool get constructsProductionComposition => false;
  bool get wiresStartupBridge => false;
  bool get accessesBackend => false;
  bool get accessesMediaCapabilities => false;
  bool get accessesNavigation => false;
  bool get registersLifecycle => false;
  bool get mutatesRouteRegistry => false;
  bool get opensAsyncHandles => false;
  bool get mutatesV1State => false;
  bool get exposesPublicUsers => false;
  bool get contactsProductionServices => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'action': action.name,
      'generationKnown': generation >= 0,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'constructsProductionComposition': constructsProductionComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'accessesBackend': accessesBackend,
      'accessesMediaCapabilities': accessesMediaCapabilities,
      'accessesNavigation': accessesNavigation,
      'registersLifecycle': registersLifecycle,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'mutatesV1State': mutatesV1State,
      'exposesPublicUsers': exposesPublicUsers,
      'contactsProductionServices': contactsProductionServices,
    };
  }

  @override
  String toString() {
    return 'CallV2RuntimeStartupOwnerDecision(${toSafeDebugMap()})';
  }
}

final class CallV2RuntimeStartupOwnerBoundary {
  factory CallV2RuntimeStartupOwnerBoundary({
    required List<CallV2RuntimeStartupOwnerStatus> statuses,
    required List<CallV2RuntimeStartupOwnerAction> actions,
    required List<CallV2RuntimeStartupOwnerRollback> rollback,
  }) {
    return CallV2RuntimeStartupOwnerBoundary._(
      List<CallV2RuntimeStartupOwnerStatus>.unmodifiable(statuses),
      List<CallV2RuntimeStartupOwnerAction>.unmodifiable(actions),
      List<CallV2RuntimeStartupOwnerRollback>.unmodifiable(rollback),
    );
  }

  const CallV2RuntimeStartupOwnerBoundary._(
    this.statuses,
    this.actions,
    this.rollback,
  );

  final List<CallV2RuntimeStartupOwnerStatus> statuses;
  final List<CallV2RuntimeStartupOwnerAction> actions;
  final List<CallV2RuntimeStartupOwnerRollback> rollback;

  bool get isDeveloperOnly => statuses.contains(
        CallV2RuntimeStartupOwnerStatus.developerOnly,
      );

  bool get isHardDisabled => statuses.contains(
        CallV2RuntimeStartupOwnerStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.rolloutFalse,
      );

  bool get isReachable => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.unreachable,
      );

  bool get constructsRuntime => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noRuntimeConstruction,
      );

  bool get startsRuntime => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noRuntimeStart,
      );

  bool get constructsProductionComposition => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noProductionCompositionConstruction,
      );

  bool get wiresStartupBridge => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noStartupBridgeWiring,
      );

  bool get wiresMainDart => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noMainDartWiring,
      );

  bool get wiresAppRouter => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noAppRouterWiring,
      );

  bool get accessesBackend => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noBackendAccess,
      );

  bool get accessesMediaCapabilities => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noMediaCapabilityAccess,
      );

  bool get accessesNavigation => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noNavigationAccess,
      );

  bool get registersLifecycle => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noLifecycleRegistration,
      );

  bool get mutatesRouteRegistry => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noRouteRegistryMutation,
      );

  bool get opensAsyncHandles => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noAsyncHandles,
      );

  bool get isDeploymentApproved => !statuses.contains(
        CallV2RuntimeStartupOwnerStatus.noDeployment,
      );

  bool get protectsV1 => statuses.contains(
        CallV2RuntimeStartupOwnerStatus.v1Protected,
      );

  bool get rollbackPreserved =>
      rollback.contains(CallV2RuntimeStartupOwnerRollback.oneCommitRevert) &&
      rollback.contains(CallV2RuntimeStartupOwnerRollback.keepRolloutFalse) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRollback.noDeploymentRequired,
      ) &&
      rollback.contains(CallV2RuntimeStartupOwnerRollback.noConfigChanges) &&
      rollback.contains(CallV2RuntimeStartupOwnerRollback.v1Unaffected);

  CallV2RuntimeStartupOwnerDecision decideWhileDisabled({
    required CallV2RuntimeStartupOwnerAction action,
    required int generation,
    int? latestGeneration,
    bool disposed = false,
    bool terminal = false,
  }) {
    if (disposed) {
      return CallV2RuntimeStartupOwnerDecision.rejected(
        action: action,
        generation: generation,
      );
    }
    if (terminal) {
      return CallV2RuntimeStartupOwnerDecision.terminalIgnored(
        action: action,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2RuntimeStartupOwnerDecision.staleIgnored(
        action: action,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2RuntimeStartupOwnerDecision.duplicateNoOp(
        action: action,
        generation: generation,
      );
    }
    return CallV2RuntimeStartupOwnerDecision.disabledInert(
      action: action,
      generation: generation,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': statuses.length,
      'actionCount': actions.length,
      'rollbackCount': rollback.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'constructsProductionComposition': constructsProductionComposition,
      'wiresStartupBridge': wiresStartupBridge,
      'wiresMainDart': wiresMainDart,
      'wiresAppRouter': wiresAppRouter,
      'accessesBackend': accessesBackend,
      'accessesMediaCapabilities': accessesMediaCapabilities,
      'accessesNavigation': accessesNavigation,
      'registersLifecycle': registersLifecycle,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'deploymentApproved': isDeploymentApproved,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2RuntimeStartupOwnerBoundary(${toSafeDebugMap()})';
  }
}

final callV2RuntimeStartupOwnerBoundary = CallV2RuntimeStartupOwnerBoundary(
  statuses: <CallV2RuntimeStartupOwnerStatus>[
    CallV2RuntimeStartupOwnerStatus.developerOnly,
    CallV2RuntimeStartupOwnerStatus.hardDisabled,
    CallV2RuntimeStartupOwnerStatus.rolloutFalse,
    CallV2RuntimeStartupOwnerStatus.unreachable,
    CallV2RuntimeStartupOwnerStatus.noRuntimeConstruction,
    CallV2RuntimeStartupOwnerStatus.noRuntimeStart,
    CallV2RuntimeStartupOwnerStatus.noProductionCompositionConstruction,
    CallV2RuntimeStartupOwnerStatus.noStartupBridgeWiring,
    CallV2RuntimeStartupOwnerStatus.noMainDartWiring,
    CallV2RuntimeStartupOwnerStatus.noAppRouterWiring,
    CallV2RuntimeStartupOwnerStatus.noBackendAccess,
    CallV2RuntimeStartupOwnerStatus.noMediaCapabilityAccess,
    CallV2RuntimeStartupOwnerStatus.noNavigationAccess,
    CallV2RuntimeStartupOwnerStatus.noLifecycleRegistration,
    CallV2RuntimeStartupOwnerStatus.noRouteRegistryMutation,
    CallV2RuntimeStartupOwnerStatus.noAsyncHandles,
    CallV2RuntimeStartupOwnerStatus.noDeployment,
    CallV2RuntimeStartupOwnerStatus.v1Protected,
  ],
  actions: <CallV2RuntimeStartupOwnerAction>[
    CallV2RuntimeStartupOwnerAction.requestStartup,
    CallV2RuntimeStartupOwnerAction.requestShutdown,
    CallV2RuntimeStartupOwnerAction.markReady,
    CallV2RuntimeStartupOwnerAction.markFailure,
    CallV2RuntimeStartupOwnerAction.retryStartup,
  ],
  rollback: <CallV2RuntimeStartupOwnerRollback>[
    CallV2RuntimeStartupOwnerRollback.oneCommitRevert,
    CallV2RuntimeStartupOwnerRollback.keepRolloutFalse,
    CallV2RuntimeStartupOwnerRollback.keepRouteRegistryNull,
    CallV2RuntimeStartupOwnerRollback.keepDisabledOwnerInert,
    CallV2RuntimeStartupOwnerRollback.noDeploymentRequired,
    CallV2RuntimeStartupOwnerRollback.noConfigChanges,
    CallV2RuntimeStartupOwnerRollback.v1Unaffected,
  ],
);
