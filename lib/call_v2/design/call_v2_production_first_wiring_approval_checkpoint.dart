enum CallV2ProductionFirstWiringCheckpointStatus {
  phase6DesignWallAccepted,
  rolloutFalse,
  callV2Unreachable,
  routeRegistryDisabled,
  disabledOwnerInert,
  runtimeNotStarted,
  backendFirebaseDisconnected,
  rtcPermissionDisconnected,
  appRouterDisconnected,
  mainStartupDisconnected,
  noDeploymentAuthorized,
  backupProtected,
  firstRealWiringNotApprovedYet,
}

enum CallV2ProductionAcceptedDesignPackage {
  humanApprovalPackage,
  preRolloutReadinessAudit,
  securityPrivacyAudit,
  stagedRolloutDesign,
  routeRegistrationDesign,
  lifecycleObserverDesign,
  navigatorWiringDesign,
  runtimeStartupDesign,
  backendFirebaseDesign,
  rtcPermissionDesign,
}

enum CallV2ProductionFirstWiringOption {
  noWiringKeepIsolated,
  developerOnlyRouteRegistrationSkeleton,
  developerOnlyLifecycleObserverSkeleton,
  developerOnlyNavigatorOwnerSkeleton,
  developerOnlyRuntimeStartupOwnerSkeleton,
  developerOnlyBackendFirebaseOwnerSkeleton,
  developerOnlyRtcPermissionOwnerSkeleton,
}

enum CallV2ProductionFirstWiringBlockedAction {
  enableRollout,
  exposePublicUsers,
  contactProductionServices,
  deploy,
  makeRoutesReachable,
  directAppRouterRegistration,
  directMainDartWiring,
  constructStartupRuntime,
  registerLifecycleObserver,
  wireNavigatorOrAppKey,
  openBackendFirebaseListeners,
  initializeRtcEngine,
  promptPermissions,
  changePlatformOrPubspec,
}

enum CallV2ProductionFirstWiringApprovalRequirement {
  exactFirstWiringOptionSelectedByHuman,
  exactAllowedFilesListed,
  exactRollbackCommandOrRevertPlanListed,
  killSwitchBehaviorDefined,
  developerOnlyAllowlistBehaviorDefined,
  noProductionServiceContact,
  noPublicUserExposure,
  noSensitiveLogs,
  v1SmokePlanAccepted,
  acceptedBackendEmulatorFlakeRecorded,
  oneCommitOnly,
  backupBranchVerifiedUnchanged,
}

enum CallV2ProductionFirstWiringKillSwitchRequirement {
  rolloutFalseByDefault,
  routeRegistryNullWhileFalse,
  disabledOwnerInertWhileFalse,
  noRuntimeStartWhileFalse,
  noBackendFirebaseRtcPermissionAccessWhileFalse,
  oneCommitRollback,
  emergencyDisablePathDocumented,
}

enum CallV2ProductionFirstWiringRollbackRequirement {
  oneCommitRevert,
  preserveRolloutFalse,
  preserveRouteRegistryDisabledNull,
  preserveDisabledOwnerInert,
  removeSelectedDeveloperOnlyWiring,
  verifyBackupBranchUnchanged,
  noDeploymentRequiredForRollback,
}

enum CallV2ProductionFirstWiringValidationRequirement {
  focusedTestsForSelectedWiring,
  allCallV2DesignTests,
  allCallV2IntegrationTests,
  allCallV2UiTests,
  productionCompositionTests,
  finalReadinessTests,
  allCallV2Tests,
  backendCheck,
  deploymentValidation,
  rulesTests,
  focusedAcceptedEmulatorRaceTest,
  fullEmulatorSuitePassesOrAcceptedFlakeRecorded,
  fullFlutterAnalyze,
  gitDiffCheck,
}

enum CallV2ProductionFirstWiringAcceptedFlake {
  fullBackendEmulatorSuiteRaceAcceptedByHumanForPhase6Z,
  timeoutLifecycleRacesProduceOneAuthoritativeOutcome,
  focusedIsolatedRaceTestPassed,
  noBackendRulesFunctionsConfigDiff,
  noPhase6ZBackendRuntimeReferences,
  retryFullEmulatorInFutureRealWiringPhases,
}

final class CallV2ProductionFirstWiringApprovalCheckpoint {
  factory CallV2ProductionFirstWiringApprovalCheckpoint({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionFirstWiringCheckpointStatus> currentStatus,
    required List<CallV2ProductionAcceptedDesignPackage> acceptedDesignPackages,
    required List<CallV2ProductionFirstWiringOption> firstWiringOptions,
    required List<CallV2ProductionFirstWiringOption>
        recommendedFirstWiringOptions,
    required List<CallV2ProductionFirstWiringBlockedAction> blockedActions,
    required List<CallV2ProductionFirstWiringApprovalRequirement>
        approvalRequirements,
    required List<CallV2ProductionFirstWiringKillSwitchRequirement>
        killSwitchRequirements,
    required List<CallV2ProductionFirstWiringRollbackRequirement>
        rollbackRequirements,
    required List<CallV2ProductionFirstWiringValidationRequirement>
        validationRequirements,
    required List<CallV2ProductionFirstWiringAcceptedFlake> acceptedFlakes,
  }) {
    return CallV2ProductionFirstWiringApprovalCheckpoint._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionFirstWiringCheckpointStatus>.unmodifiable(
        currentStatus,
      ),
      List<CallV2ProductionAcceptedDesignPackage>.unmodifiable(
        acceptedDesignPackages,
      ),
      List<CallV2ProductionFirstWiringOption>.unmodifiable(
        firstWiringOptions,
      ),
      List<CallV2ProductionFirstWiringOption>.unmodifiable(
        recommendedFirstWiringOptions,
      ),
      List<CallV2ProductionFirstWiringBlockedAction>.unmodifiable(
        blockedActions,
      ),
      List<CallV2ProductionFirstWiringApprovalRequirement>.unmodifiable(
        approvalRequirements,
      ),
      List<CallV2ProductionFirstWiringKillSwitchRequirement>.unmodifiable(
        killSwitchRequirements,
      ),
      List<CallV2ProductionFirstWiringRollbackRequirement>.unmodifiable(
        rollbackRequirements,
      ),
      List<CallV2ProductionFirstWiringValidationRequirement>.unmodifiable(
        validationRequirements,
      ),
      List<CallV2ProductionFirstWiringAcceptedFlake>.unmodifiable(
        acceptedFlakes,
      ),
    );
  }

  const CallV2ProductionFirstWiringApprovalCheckpoint._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.acceptedDesignPackages,
    this.firstWiringOptions,
    this.recommendedFirstWiringOptions,
    this.blockedActions,
    this.approvalRequirements,
    this.killSwitchRequirements,
    this.rollbackRequirements,
    this.validationRequirements,
    this.acceptedFlakes,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionFirstWiringCheckpointStatus> currentStatus;
  final List<CallV2ProductionAcceptedDesignPackage> acceptedDesignPackages;
  final List<CallV2ProductionFirstWiringOption> firstWiringOptions;
  final List<CallV2ProductionFirstWiringOption> recommendedFirstWiringOptions;
  final List<CallV2ProductionFirstWiringBlockedAction> blockedActions;
  final List<CallV2ProductionFirstWiringApprovalRequirement>
      approvalRequirements;
  final List<CallV2ProductionFirstWiringKillSwitchRequirement>
      killSwitchRequirements;
  final List<CallV2ProductionFirstWiringRollbackRequirement>
      rollbackRequirements;
  final List<CallV2ProductionFirstWiringValidationRequirement>
      validationRequirements;
  final List<CallV2ProductionFirstWiringAcceptedFlake> acceptedFlakes;

  bool get isPhase6DesignWallAccepted => currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.phase6DesignWallAccepted,
      );

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.rolloutFalse,
      );

  bool get isCallV2Reachable => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.callV2Unreachable,
      );

  bool get isRouteRegistryEnabled => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.routeRegistryDisabled,
      );

  bool get isDisabledOwnerActive => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.disabledOwnerInert,
      );

  bool get isRuntimeStarted => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.runtimeNotStarted,
      );

  bool get hasBackendFirebaseConnection => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.backendFirebaseDisconnected,
      );

  bool get hasRtcPermissionConnection => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.rtcPermissionDisconnected,
      );

  bool get hasAppRouterConnection => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.appRouterDisconnected,
      );

  bool get hasMainStartupConnection => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.mainStartupDisconnected,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.noDeploymentAuthorized,
      );

  bool get isBackupProtected => currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus.backupProtected,
      );

  bool get isFirstRealWiringApproved => !currentStatus.contains(
        CallV2ProductionFirstWiringCheckpointStatus
            .firstRealWiringNotApprovedYet,
      );

  bool get requiresExplicitHumanChoice {
    return approvalRequirements.contains(
      CallV2ProductionFirstWiringApprovalRequirement
          .exactFirstWiringOptionSelectedByHuman,
    );
  }

  bool get blocksAutomaticWiring {
    return !isFirstRealWiringApproved ||
        blockedActions.contains(
          CallV2ProductionFirstWiringBlockedAction.enableRollout,
        ) ||
        blockedActions.contains(
          CallV2ProductionFirstWiringBlockedAction.makeRoutesReachable,
        );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'acceptedDesignPackageCount': acceptedDesignPackages.length,
      'firstWiringOptionCount': firstWiringOptions.length,
      'recommendedFirstWiringOptionCount': recommendedFirstWiringOptions.length,
      'blockedActionCount': blockedActions.length,
      'approvalRequirementCount': approvalRequirements.length,
      'killSwitchRequirementCount': killSwitchRequirements.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'validationRequirementCount': validationRequirements.length,
      'acceptedFlakeCount': acceptedFlakes.length,
      'phase6DesignWallAccepted': isPhase6DesignWallAccepted,
      'rolloutEnabled': isRolloutEnabled,
      'callV2Reachable': isCallV2Reachable,
      'deploymentAuthorized': isDeploymentAuthorized,
      'firstRealWiringApproved': isFirstRealWiringApproved,
      'blocksAutomaticWiring': blocksAutomaticWiring,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionFirstWiringApprovalCheckpoint('
        '${toSafeDebugMap()})';
  }
}

final callV2ProductionFirstWiringApprovalCheckpoint =
    CallV2ProductionFirstWiringApprovalCheckpoint(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionFirstWiringCheckpointStatus>[
    CallV2ProductionFirstWiringCheckpointStatus.phase6DesignWallAccepted,
    CallV2ProductionFirstWiringCheckpointStatus.rolloutFalse,
    CallV2ProductionFirstWiringCheckpointStatus.callV2Unreachable,
    CallV2ProductionFirstWiringCheckpointStatus.routeRegistryDisabled,
    CallV2ProductionFirstWiringCheckpointStatus.disabledOwnerInert,
    CallV2ProductionFirstWiringCheckpointStatus.runtimeNotStarted,
    CallV2ProductionFirstWiringCheckpointStatus.backendFirebaseDisconnected,
    CallV2ProductionFirstWiringCheckpointStatus.rtcPermissionDisconnected,
    CallV2ProductionFirstWiringCheckpointStatus.appRouterDisconnected,
    CallV2ProductionFirstWiringCheckpointStatus.mainStartupDisconnected,
    CallV2ProductionFirstWiringCheckpointStatus.noDeploymentAuthorized,
    CallV2ProductionFirstWiringCheckpointStatus.backupProtected,
    CallV2ProductionFirstWiringCheckpointStatus.firstRealWiringNotApprovedYet,
  ],
  acceptedDesignPackages: <CallV2ProductionAcceptedDesignPackage>[
    CallV2ProductionAcceptedDesignPackage.humanApprovalPackage,
    CallV2ProductionAcceptedDesignPackage.preRolloutReadinessAudit,
    CallV2ProductionAcceptedDesignPackage.securityPrivacyAudit,
    CallV2ProductionAcceptedDesignPackage.stagedRolloutDesign,
    CallV2ProductionAcceptedDesignPackage.routeRegistrationDesign,
    CallV2ProductionAcceptedDesignPackage.lifecycleObserverDesign,
    CallV2ProductionAcceptedDesignPackage.navigatorWiringDesign,
    CallV2ProductionAcceptedDesignPackage.runtimeStartupDesign,
    CallV2ProductionAcceptedDesignPackage.backendFirebaseDesign,
    CallV2ProductionAcceptedDesignPackage.rtcPermissionDesign,
  ],
  firstWiringOptions: <CallV2ProductionFirstWiringOption>[
    CallV2ProductionFirstWiringOption.noWiringKeepIsolated,
    CallV2ProductionFirstWiringOption.developerOnlyRouteRegistrationSkeleton,
    CallV2ProductionFirstWiringOption.developerOnlyLifecycleObserverSkeleton,
    CallV2ProductionFirstWiringOption.developerOnlyNavigatorOwnerSkeleton,
    CallV2ProductionFirstWiringOption.developerOnlyRuntimeStartupOwnerSkeleton,
    CallV2ProductionFirstWiringOption.developerOnlyBackendFirebaseOwnerSkeleton,
    CallV2ProductionFirstWiringOption.developerOnlyRtcPermissionOwnerSkeleton,
  ],
  recommendedFirstWiringOptions: <CallV2ProductionFirstWiringOption>[
    CallV2ProductionFirstWiringOption.developerOnlyRouteRegistrationSkeleton,
    CallV2ProductionFirstWiringOption.noWiringKeepIsolated,
  ],
  blockedActions: <CallV2ProductionFirstWiringBlockedAction>[
    CallV2ProductionFirstWiringBlockedAction.enableRollout,
    CallV2ProductionFirstWiringBlockedAction.exposePublicUsers,
    CallV2ProductionFirstWiringBlockedAction.contactProductionServices,
    CallV2ProductionFirstWiringBlockedAction.deploy,
    CallV2ProductionFirstWiringBlockedAction.makeRoutesReachable,
    CallV2ProductionFirstWiringBlockedAction.directAppRouterRegistration,
    CallV2ProductionFirstWiringBlockedAction.directMainDartWiring,
    CallV2ProductionFirstWiringBlockedAction.constructStartupRuntime,
    CallV2ProductionFirstWiringBlockedAction.registerLifecycleObserver,
    CallV2ProductionFirstWiringBlockedAction.wireNavigatorOrAppKey,
    CallV2ProductionFirstWiringBlockedAction.openBackendFirebaseListeners,
    CallV2ProductionFirstWiringBlockedAction.initializeRtcEngine,
    CallV2ProductionFirstWiringBlockedAction.promptPermissions,
    CallV2ProductionFirstWiringBlockedAction.changePlatformOrPubspec,
  ],
  approvalRequirements: <CallV2ProductionFirstWiringApprovalRequirement>[
    CallV2ProductionFirstWiringApprovalRequirement
        .exactFirstWiringOptionSelectedByHuman,
    CallV2ProductionFirstWiringApprovalRequirement.exactAllowedFilesListed,
    CallV2ProductionFirstWiringApprovalRequirement
        .exactRollbackCommandOrRevertPlanListed,
    CallV2ProductionFirstWiringApprovalRequirement.killSwitchBehaviorDefined,
    CallV2ProductionFirstWiringApprovalRequirement
        .developerOnlyAllowlistBehaviorDefined,
    CallV2ProductionFirstWiringApprovalRequirement.noProductionServiceContact,
    CallV2ProductionFirstWiringApprovalRequirement.noPublicUserExposure,
    CallV2ProductionFirstWiringApprovalRequirement.noSensitiveLogs,
    CallV2ProductionFirstWiringApprovalRequirement.v1SmokePlanAccepted,
    CallV2ProductionFirstWiringApprovalRequirement
        .acceptedBackendEmulatorFlakeRecorded,
    CallV2ProductionFirstWiringApprovalRequirement.oneCommitOnly,
    CallV2ProductionFirstWiringApprovalRequirement
        .backupBranchVerifiedUnchanged,
  ],
  killSwitchRequirements: <CallV2ProductionFirstWiringKillSwitchRequirement>[
    CallV2ProductionFirstWiringKillSwitchRequirement.rolloutFalseByDefault,
    CallV2ProductionFirstWiringKillSwitchRequirement
        .routeRegistryNullWhileFalse,
    CallV2ProductionFirstWiringKillSwitchRequirement
        .disabledOwnerInertWhileFalse,
    CallV2ProductionFirstWiringKillSwitchRequirement.noRuntimeStartWhileFalse,
    CallV2ProductionFirstWiringKillSwitchRequirement
        .noBackendFirebaseRtcPermissionAccessWhileFalse,
    CallV2ProductionFirstWiringKillSwitchRequirement.oneCommitRollback,
    CallV2ProductionFirstWiringKillSwitchRequirement
        .emergencyDisablePathDocumented,
  ],
  rollbackRequirements: <CallV2ProductionFirstWiringRollbackRequirement>[
    CallV2ProductionFirstWiringRollbackRequirement.oneCommitRevert,
    CallV2ProductionFirstWiringRollbackRequirement.preserveRolloutFalse,
    CallV2ProductionFirstWiringRollbackRequirement
        .preserveRouteRegistryDisabledNull,
    CallV2ProductionFirstWiringRollbackRequirement.preserveDisabledOwnerInert,
    CallV2ProductionFirstWiringRollbackRequirement
        .removeSelectedDeveloperOnlyWiring,
    CallV2ProductionFirstWiringRollbackRequirement.verifyBackupBranchUnchanged,
    CallV2ProductionFirstWiringRollbackRequirement
        .noDeploymentRequiredForRollback,
  ],
  validationRequirements: <CallV2ProductionFirstWiringValidationRequirement>[
    CallV2ProductionFirstWiringValidationRequirement
        .focusedTestsForSelectedWiring,
    CallV2ProductionFirstWiringValidationRequirement.allCallV2DesignTests,
    CallV2ProductionFirstWiringValidationRequirement.allCallV2IntegrationTests,
    CallV2ProductionFirstWiringValidationRequirement.allCallV2UiTests,
    CallV2ProductionFirstWiringValidationRequirement.productionCompositionTests,
    CallV2ProductionFirstWiringValidationRequirement.finalReadinessTests,
    CallV2ProductionFirstWiringValidationRequirement.allCallV2Tests,
    CallV2ProductionFirstWiringValidationRequirement.backendCheck,
    CallV2ProductionFirstWiringValidationRequirement.deploymentValidation,
    CallV2ProductionFirstWiringValidationRequirement.rulesTests,
    CallV2ProductionFirstWiringValidationRequirement
        .focusedAcceptedEmulatorRaceTest,
    CallV2ProductionFirstWiringValidationRequirement
        .fullEmulatorSuitePassesOrAcceptedFlakeRecorded,
    CallV2ProductionFirstWiringValidationRequirement.fullFlutterAnalyze,
    CallV2ProductionFirstWiringValidationRequirement.gitDiffCheck,
  ],
  acceptedFlakes: <CallV2ProductionFirstWiringAcceptedFlake>[
    CallV2ProductionFirstWiringAcceptedFlake
        .fullBackendEmulatorSuiteRaceAcceptedByHumanForPhase6Z,
    CallV2ProductionFirstWiringAcceptedFlake
        .timeoutLifecycleRacesProduceOneAuthoritativeOutcome,
    CallV2ProductionFirstWiringAcceptedFlake.focusedIsolatedRaceTestPassed,
    CallV2ProductionFirstWiringAcceptedFlake.noBackendRulesFunctionsConfigDiff,
    CallV2ProductionFirstWiringAcceptedFlake.noPhase6ZBackendRuntimeReferences,
    CallV2ProductionFirstWiringAcceptedFlake
        .retryFullEmulatorInFutureRealWiringPhases,
  ],
);
