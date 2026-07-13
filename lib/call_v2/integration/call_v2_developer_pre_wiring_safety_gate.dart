import 'call_v2_developer_skeleton_composition_audit.dart';

enum CallV2DeveloperPreWiringGateStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  compositionAuditPassing,
  disabledOwnerInert,
  backupProtected,
  humanApprovalRequired,
  exactScopeRequired,
  allowedFilesRequired,
  rollbackRequired,
  killSwitchRequired,
  developerAllowlistRequired,
  v1SmokeRequired,
  privacyReviewRequired,
  fullValidationRequired,
  deploymentBlocked,
  productionServiceContactBlocked,
  publicExposureBlocked,
}

enum CallV2DeveloperPreWiringScope {
  noneSelected,
  routeRegistrationOnly,
  lifecycleObserverOnly,
  navigatorOwnerOnly,
  runtimeStartupOwnerOnly,
  backendFirebaseOwnerOnly,
  rtcPermissionOwnerOnly,
}

enum CallV2DeveloperPreWiringGateDecision {
  blockedNoScopeSelected,
  blockedMissingApproval,
  blockedAuditFailed,
  allowedForExplicitFutureDeveloperOnlyPhase,
}

enum CallV2DeveloperPreWiringBlockedAction {
  enableRollout,
  exposePublicUsers,
  deploy,
  contactProductionServices,
  registerRoutes,
  startRuntime,
  registerLifecycleObserver,
  wireNavigator,
  accessBackendFirebase,
  initializeRtc,
  requestPermissions,
  modifyPubspecPlatform,
  modifyRulesFunctionsConfig,
}

enum CallV2DeveloperPreWiringValidationRequirement {
  allDesignTests,
  allIntegrationTests,
  allUiTests,
  compositionTests,
  finalReadinessTests,
  allCallV2Tests,
  backendCheck,
  deploymentValidation,
  rulesTests,
  focusedAcceptedEmulatorRaceTest,
  fullFlutterAnalyze,
  gitDiffCheck,
}

enum CallV2DeveloperPreWiringRollbackRequirement {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noRulesFunctionsConfigChanges,
  noPubspecPlatformChanges,
  v1Unaffected,
}

final class CallV2DeveloperPreWiringSafetyGate {
  factory CallV2DeveloperPreWiringSafetyGate({
    required CallV2DeveloperSkeletonCompositionAudit compositionAudit,
    required List<CallV2DeveloperPreWiringGateStatus> statuses,
    required CallV2DeveloperPreWiringScope selectedScope,
    required bool explicitFutureApproval,
    required bool allowedFilesListed,
    required bool oneCommitRollbackConfirmed,
    required List<CallV2DeveloperPreWiringBlockedAction> blockedActions,
    required List<CallV2DeveloperPreWiringValidationRequirement>
        validationRequirements,
    required List<CallV2DeveloperPreWiringRollbackRequirement>
        rollbackRequirements,
  }) {
    return CallV2DeveloperPreWiringSafetyGate._(
      compositionAudit,
      List<CallV2DeveloperPreWiringGateStatus>.unmodifiable(statuses),
      selectedScope,
      explicitFutureApproval,
      allowedFilesListed,
      oneCommitRollbackConfirmed,
      List<CallV2DeveloperPreWiringBlockedAction>.unmodifiable(
        blockedActions,
      ),
      List<CallV2DeveloperPreWiringValidationRequirement>.unmodifiable(
        validationRequirements,
      ),
      List<CallV2DeveloperPreWiringRollbackRequirement>.unmodifiable(
        rollbackRequirements,
      ),
    );
  }

  const CallV2DeveloperPreWiringSafetyGate._(
    this.compositionAudit,
    this.statuses,
    this.selectedScope,
    this.explicitFutureApproval,
    this.allowedFilesListed,
    this.oneCommitRollbackConfirmed,
    this.blockedActions,
    this.validationRequirements,
    this.rollbackRequirements,
  );

  final CallV2DeveloperSkeletonCompositionAudit compositionAudit;
  final List<CallV2DeveloperPreWiringGateStatus> statuses;
  final CallV2DeveloperPreWiringScope selectedScope;
  final bool explicitFutureApproval;
  final bool allowedFilesListed;
  final bool oneCommitRollbackConfirmed;
  final List<CallV2DeveloperPreWiringBlockedAction> blockedActions;
  final List<CallV2DeveloperPreWiringValidationRequirement>
      validationRequirements;
  final List<CallV2DeveloperPreWiringRollbackRequirement> rollbackRequirements;

  bool get isDeveloperOnly =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.developerOnly);

  bool get isHardDisabled =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.hardDisabled);

  bool get isRolloutEnabled =>
      !statuses.contains(CallV2DeveloperPreWiringGateStatus.rolloutFalse);

  bool get isReachable =>
      !statuses.contains(CallV2DeveloperPreWiringGateStatus.unreachable);

  bool get isCompositionAuditPassing =>
      statuses.contains(
        CallV2DeveloperPreWiringGateStatus.compositionAuditPassing,
      ) &&
      compositionAudit.decision ==
          CallV2DeveloperSkeletonCompositionDecision.pass;

  bool get isDisabledOwnerInert =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.disabledOwnerInert);

  bool get isBackupProtected =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.backupProtected);

  bool get requiresHumanApproval => statuses.contains(
        CallV2DeveloperPreWiringGateStatus.humanApprovalRequired,
      );

  bool get requiresExactScope =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.exactScopeRequired);

  bool get requiresAllowedFiles => statuses.contains(
        CallV2DeveloperPreWiringGateStatus.allowedFilesRequired,
      );

  bool get requiresRollback =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.rollbackRequired);

  bool get requiresKillSwitch =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.killSwitchRequired);

  bool get requiresDeveloperAllowlist => statuses.contains(
        CallV2DeveloperPreWiringGateStatus.developerAllowlistRequired,
      );

  bool get requiresV1Smoke =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.v1SmokeRequired);

  bool get requiresPrivacyReview => statuses.contains(
        CallV2DeveloperPreWiringGateStatus.privacyReviewRequired,
      );

  bool get requiresFullValidation => statuses.contains(
        CallV2DeveloperPreWiringGateStatus.fullValidationRequired,
      );

  bool get blocksDeployment =>
      statuses.contains(CallV2DeveloperPreWiringGateStatus.deploymentBlocked) &&
      blockedActions.contains(CallV2DeveloperPreWiringBlockedAction.deploy);

  bool get blocksProductionServiceContact =>
      statuses.contains(
        CallV2DeveloperPreWiringGateStatus.productionServiceContactBlocked,
      ) &&
      blockedActions.contains(
        CallV2DeveloperPreWiringBlockedAction.contactProductionServices,
      );

  bool get blocksPublicExposure =>
      statuses.contains(
        CallV2DeveloperPreWiringGateStatus.publicExposureBlocked,
      ) &&
      blockedActions.contains(
        CallV2DeveloperPreWiringBlockedAction.exposePublicUsers,
      );

  bool get hasSelectedScope =>
      selectedScope != CallV2DeveloperPreWiringScope.noneSelected;

  bool get hasExactlyOneSelectedScope => hasSelectedScope;

  bool get canWireRoutes => false;
  bool get canStartRuntime => false;
  bool get canRegisterLifecycleObserver => false;
  bool get canWireNavigator => false;
  bool get canAccessBackendFirebase => false;
  bool get canInitializeRtc => false;
  bool get canRequestPermissions => false;
  bool get canModifyPubspecPlatform => false;
  bool get canModifyRulesFunctionsConfig => false;
  bool get protectsV1 => rollbackRequirements.contains(
        CallV2DeveloperPreWiringRollbackRequirement.v1Unaffected,
      );

  bool get hasRequiredValidation =>
      validationRequirements.length ==
          CallV2DeveloperPreWiringValidationRequirement.values.length &&
      validationRequirements.toSet().containsAll(
            CallV2DeveloperPreWiringValidationRequirement.values,
          );

  bool get hasRequiredRollback =>
      rollbackRequirements.contains(
        CallV2DeveloperPreWiringRollbackRequirement.oneCommitRevert,
      ) &&
      rollbackRequirements.contains(
        CallV2DeveloperPreWiringRollbackRequirement.keepRolloutFalse,
      ) &&
      rollbackRequirements.contains(
        CallV2DeveloperPreWiringRollbackRequirement.keepRouteRegistryNull,
      ) &&
      rollbackRequirements.contains(
        CallV2DeveloperPreWiringRollbackRequirement.keepDisabledOwnerInert,
      ) &&
      rollbackRequirements.contains(
        CallV2DeveloperPreWiringRollbackRequirement.noDeploymentRequired,
      ) &&
      rollbackRequirements.contains(
        CallV2DeveloperPreWiringRollbackRequirement.v1Unaffected,
      );

  CallV2DeveloperPreWiringGateDecision get decision {
    if (!isCompositionAuditPassing) {
      return CallV2DeveloperPreWiringGateDecision.blockedAuditFailed;
    }
    if (!hasSelectedScope) {
      return CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected;
    }
    if (!explicitFutureApproval ||
        !allowedFilesListed ||
        !oneCommitRollbackConfirmed) {
      return CallV2DeveloperPreWiringGateDecision.blockedMissingApproval;
    }
    return CallV2DeveloperPreWiringGateDecision
        .allowedForExplicitFutureDeveloperOnlyPhase;
  }

  CallV2DeveloperPreWiringSafetyGate evaluateFutureScope({
    required CallV2DeveloperPreWiringScope selectedScope,
    required bool explicitFutureApproval,
    required bool allowedFilesListed,
    required bool oneCommitRollbackConfirmed,
  }) {
    return CallV2DeveloperPreWiringSafetyGate(
      compositionAudit: compositionAudit,
      statuses: statuses,
      selectedScope: selectedScope,
      explicitFutureApproval: explicitFutureApproval,
      allowedFilesListed: allowedFilesListed,
      oneCommitRollbackConfirmed: oneCommitRollbackConfirmed,
      blockedActions: blockedActions,
      validationRequirements: validationRequirements,
      rollbackRequirements: rollbackRequirements,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': statuses.length,
      'blockedActionCount': blockedActions.length,
      'validationRequirementCount': validationRequirements.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'decision': decision.name,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'compositionAuditPassing': isCompositionAuditPassing,
      'disabledOwnerInert': isDisabledOwnerInert,
      'backupProtected': isBackupProtected,
      'scopeSelected': hasSelectedScope,
      'explicitFutureApproval': explicitFutureApproval,
      'allowedFilesListed': allowedFilesListed,
      'oneCommitRollbackConfirmed': oneCommitRollbackConfirmed,
      'blocksDeployment': blocksDeployment,
      'blocksProductionServiceContact': blocksProductionServiceContact,
      'blocksPublicExposure': blocksPublicExposure,
      'canWireRoutes': canWireRoutes,
      'canStartRuntime': canStartRuntime,
      'canRegisterLifecycleObserver': canRegisterLifecycleObserver,
      'canWireNavigator': canWireNavigator,
      'canAccessBackend': canAccessBackendFirebase,
      'canInitializeRtc': canInitializeRtc,
      'canRequestPermissions': canRequestPermissions,
      'canModifyPubspecPlatform': canModifyPubspecPlatform,
      'canModifyServerConfig': canModifyRulesFunctionsConfig,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperPreWiringSafetyGate(${toSafeDebugMap()})';
  }
}

final callV2DeveloperPreWiringSafetyGate = CallV2DeveloperPreWiringSafetyGate(
  compositionAudit: callV2DeveloperSkeletonCompositionAudit,
  statuses: <CallV2DeveloperPreWiringGateStatus>[
    CallV2DeveloperPreWiringGateStatus.developerOnly,
    CallV2DeveloperPreWiringGateStatus.hardDisabled,
    CallV2DeveloperPreWiringGateStatus.rolloutFalse,
    CallV2DeveloperPreWiringGateStatus.unreachable,
    CallV2DeveloperPreWiringGateStatus.compositionAuditPassing,
    CallV2DeveloperPreWiringGateStatus.disabledOwnerInert,
    CallV2DeveloperPreWiringGateStatus.backupProtected,
    CallV2DeveloperPreWiringGateStatus.humanApprovalRequired,
    CallV2DeveloperPreWiringGateStatus.exactScopeRequired,
    CallV2DeveloperPreWiringGateStatus.allowedFilesRequired,
    CallV2DeveloperPreWiringGateStatus.rollbackRequired,
    CallV2DeveloperPreWiringGateStatus.killSwitchRequired,
    CallV2DeveloperPreWiringGateStatus.developerAllowlistRequired,
    CallV2DeveloperPreWiringGateStatus.v1SmokeRequired,
    CallV2DeveloperPreWiringGateStatus.privacyReviewRequired,
    CallV2DeveloperPreWiringGateStatus.fullValidationRequired,
    CallV2DeveloperPreWiringGateStatus.deploymentBlocked,
    CallV2DeveloperPreWiringGateStatus.productionServiceContactBlocked,
    CallV2DeveloperPreWiringGateStatus.publicExposureBlocked,
  ],
  selectedScope: CallV2DeveloperPreWiringScope.noneSelected,
  explicitFutureApproval: false,
  allowedFilesListed: false,
  oneCommitRollbackConfirmed: false,
  blockedActions: <CallV2DeveloperPreWiringBlockedAction>[
    CallV2DeveloperPreWiringBlockedAction.enableRollout,
    CallV2DeveloperPreWiringBlockedAction.exposePublicUsers,
    CallV2DeveloperPreWiringBlockedAction.deploy,
    CallV2DeveloperPreWiringBlockedAction.contactProductionServices,
    CallV2DeveloperPreWiringBlockedAction.registerRoutes,
    CallV2DeveloperPreWiringBlockedAction.startRuntime,
    CallV2DeveloperPreWiringBlockedAction.registerLifecycleObserver,
    CallV2DeveloperPreWiringBlockedAction.wireNavigator,
    CallV2DeveloperPreWiringBlockedAction.accessBackendFirebase,
    CallV2DeveloperPreWiringBlockedAction.initializeRtc,
    CallV2DeveloperPreWiringBlockedAction.requestPermissions,
    CallV2DeveloperPreWiringBlockedAction.modifyPubspecPlatform,
    CallV2DeveloperPreWiringBlockedAction.modifyRulesFunctionsConfig,
  ],
  validationRequirements: <CallV2DeveloperPreWiringValidationRequirement>[
    CallV2DeveloperPreWiringValidationRequirement.allDesignTests,
    CallV2DeveloperPreWiringValidationRequirement.allIntegrationTests,
    CallV2DeveloperPreWiringValidationRequirement.allUiTests,
    CallV2DeveloperPreWiringValidationRequirement.compositionTests,
    CallV2DeveloperPreWiringValidationRequirement.finalReadinessTests,
    CallV2DeveloperPreWiringValidationRequirement.allCallV2Tests,
    CallV2DeveloperPreWiringValidationRequirement.backendCheck,
    CallV2DeveloperPreWiringValidationRequirement.deploymentValidation,
    CallV2DeveloperPreWiringValidationRequirement.rulesTests,
    CallV2DeveloperPreWiringValidationRequirement
        .focusedAcceptedEmulatorRaceTest,
    CallV2DeveloperPreWiringValidationRequirement.fullFlutterAnalyze,
    CallV2DeveloperPreWiringValidationRequirement.gitDiffCheck,
  ],
  rollbackRequirements: <CallV2DeveloperPreWiringRollbackRequirement>[
    CallV2DeveloperPreWiringRollbackRequirement.oneCommitRevert,
    CallV2DeveloperPreWiringRollbackRequirement.keepRolloutFalse,
    CallV2DeveloperPreWiringRollbackRequirement.keepRouteRegistryNull,
    CallV2DeveloperPreWiringRollbackRequirement.keepDisabledOwnerInert,
    CallV2DeveloperPreWiringRollbackRequirement.noDeploymentRequired,
    CallV2DeveloperPreWiringRollbackRequirement.noRulesFunctionsConfigChanges,
    CallV2DeveloperPreWiringRollbackRequirement.noPubspecPlatformChanges,
    CallV2DeveloperPreWiringRollbackRequirement.v1Unaffected,
  ],
);
