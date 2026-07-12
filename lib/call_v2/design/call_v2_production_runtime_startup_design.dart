enum CallV2ProductionRuntimeStartupStatus {
  noRealRuntimeStartupImplemented,
  runtimeNotConstructedFromAppStartup,
  runtimeNotStarted,
  productionCompositionNotConstructedFromStartup,
  rolloutFalse,
  routeRegistryDisabled,
  callV2Unreachable,
  backendFirebaseDisconnected,
  rtcDisconnected,
  permissionsDisconnected,
  deploymentNotAuthorized,
}

enum CallV2ProductionRuntimeStartupAllowedLocation {
  isolatedCallV2ProductionIntegrationOwner,
  isolatedAppStartupBoundaryOnlyIfApproved,
  developerOnlyRuntimeStartupPrOnly,
}

enum CallV2ProductionRuntimeStartupForbiddenLocation {
  mainDartDirectRuntimeConstruction,
  appRouter,
  routeRegistry,
  lifecycleEventHandlerAlone,
  v1Files,
}

enum CallV2ProductionRuntimeStartupForbiddenAction {
  modifyMainDart,
  modifyAppStartup,
  modifyAppRouter,
  modifyRouteRegistryToStartRuntime,
  constructProductionCompositionFromStartup,
  startRuntime,
  startRtc,
  requestPermissions,
  openBackendFirebaseListeners,
  changeRolloutFlag,
  registerRoutes,
  addNavigationWiring,
  deploy,
}

enum CallV2ProductionRuntimeStartupSafetyRule {
  explicitHumanApprovalRequired,
  developerOnlyGateRequired,
  allowlistBeforeAnyUserExposure,
  emergencyKillSwitchRequired,
  rolloutFalseUntilApproved,
  startupIdempotent,
  duplicateStartupNoOp,
  startupAfterDisposeRejected,
  startupAfterTerminalRejected,
  staleGenerationMutationRejected,
  controlledStartupFailureOnly,
  noRawExceptionStackExposure,
  noSensitiveIdsTokensChannelsCredentialsInDebugLogs,
  noProductionServiceContactWithoutSeparateApproval,
}

enum CallV2ProductionRuntimeStartupDependencyGate {
  routeRegistrationDesignAccepted,
  lifecycleObserverDesignAccepted,
  navigatorWiringDesignAccepted,
  backendFirebaseDesignAcceptedBeforeServiceContact,
  rtcPermissionDesignAcceptedBeforeMediaStartup,
  securityPrivacyAuditAccepted,
  preRolloutReadinessAccepted,
  stagedRolloutDesignAccepted,
  allTestsPassed,
  v1SmokePlanAccepted,
}

enum CallV2ProductionRuntimeStartupLifecycleRule {
  resumeDoesNotStartRuntimeByItself,
  pauseInactiveHiddenDoNotStartRuntime,
  detachedSignOutAuthInvalidCleanupOnlyByExplicitPolicy,
  lifecycleEventNeedsSeparateApprovedActionBeforeStartup,
  runtimeStartupIsolatedFromAppBackgrounding,
}

enum CallV2ProductionRuntimeStartupRollback {
  oneCommit,
  removeStartupOwnerWiring,
  rolloutFalse,
  routeRegistryDisabledNull,
  lifecycleBridgeRemainsIsolated,
  navigatorAdapterRemainsIsolated,
  noBackendFirebaseRtcPermissionCleanupLeaks,
  noDeploymentWithoutApproval,
  backupBranchProtected,
}

enum CallV2ProductionRuntimeStartupV1Protection {
  noV1RouteChanges,
  noV1CallBehaviorChanges,
  noV1ChatBehaviorChanges,
  noAppStartupRegression,
  v1SmokeBeforeAndAfterAnyStartupWiring,
  immediateRollbackOnV1Regression,
}

enum CallV2ProductionRuntimeStartupTestRequirement {
  phase6XTests,
  phase6WTests,
  phase6VTests,
  phase6UTests,
  phase6TTests,
  allCallV2DesignTests,
  allCallV2IntegrationTests,
  allCallV2UiTests,
  preIntegrationVerification,
  productionCompositionTests,
  finalReadinessTests,
  allCallV2FlutterTests,
  backendCheck,
  deploymentValidation,
  firestoreRulesTests,
  emulatorTests,
  fullFlutterAnalyze,
  diffCheck,
}

final class CallV2ProductionRuntimeStartupDesign {
  factory CallV2ProductionRuntimeStartupDesign({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionRuntimeStartupStatus> currentStatus,
    required List<CallV2ProductionRuntimeStartupAllowedLocation>
        allowedFutureLocations,
    required List<CallV2ProductionRuntimeStartupForbiddenLocation>
        forbiddenLocations,
    required List<CallV2ProductionRuntimeStartupForbiddenAction>
        forbiddenActions,
    required List<CallV2ProductionRuntimeStartupSafetyRule> safetyRules,
    required List<CallV2ProductionRuntimeStartupDependencyGate> dependencyGates,
    required List<CallV2ProductionRuntimeStartupLifecycleRule> lifecycleRules,
    required List<CallV2ProductionRuntimeStartupRollback> rollbackControls,
    required List<CallV2ProductionRuntimeStartupV1Protection> v1Protections,
    required List<CallV2ProductionRuntimeStartupTestRequirement>
        testRequirements,
  }) {
    return CallV2ProductionRuntimeStartupDesign._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionRuntimeStartupStatus>.unmodifiable(currentStatus),
      List<CallV2ProductionRuntimeStartupAllowedLocation>.unmodifiable(
        allowedFutureLocations,
      ),
      List<CallV2ProductionRuntimeStartupForbiddenLocation>.unmodifiable(
        forbiddenLocations,
      ),
      List<CallV2ProductionRuntimeStartupForbiddenAction>.unmodifiable(
        forbiddenActions,
      ),
      List<CallV2ProductionRuntimeStartupSafetyRule>.unmodifiable(safetyRules),
      List<CallV2ProductionRuntimeStartupDependencyGate>.unmodifiable(
        dependencyGates,
      ),
      List<CallV2ProductionRuntimeStartupLifecycleRule>.unmodifiable(
        lifecycleRules,
      ),
      List<CallV2ProductionRuntimeStartupRollback>.unmodifiable(
        rollbackControls,
      ),
      List<CallV2ProductionRuntimeStartupV1Protection>.unmodifiable(
        v1Protections,
      ),
      List<CallV2ProductionRuntimeStartupTestRequirement>.unmodifiable(
        testRequirements,
      ),
    );
  }

  const CallV2ProductionRuntimeStartupDesign._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.allowedFutureLocations,
    this.forbiddenLocations,
    this.forbiddenActions,
    this.safetyRules,
    this.dependencyGates,
    this.lifecycleRules,
    this.rollbackControls,
    this.v1Protections,
    this.testRequirements,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionRuntimeStartupStatus> currentStatus;
  final List<CallV2ProductionRuntimeStartupAllowedLocation>
      allowedFutureLocations;
  final List<CallV2ProductionRuntimeStartupForbiddenLocation>
      forbiddenLocations;
  final List<CallV2ProductionRuntimeStartupForbiddenAction> forbiddenActions;
  final List<CallV2ProductionRuntimeStartupSafetyRule> safetyRules;
  final List<CallV2ProductionRuntimeStartupDependencyGate> dependencyGates;
  final List<CallV2ProductionRuntimeStartupLifecycleRule> lifecycleRules;
  final List<CallV2ProductionRuntimeStartupRollback> rollbackControls;
  final List<CallV2ProductionRuntimeStartupV1Protection> v1Protections;
  final List<CallV2ProductionRuntimeStartupTestRequirement> testRequirements;

  bool get isRuntimeStartupImplemented => !currentStatus.contains(
        CallV2ProductionRuntimeStartupStatus.noRealRuntimeStartupImplemented,
      );

  bool get isRuntimeStarted => !currentStatus.contains(
        CallV2ProductionRuntimeStartupStatus.runtimeNotStarted,
      );

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionRuntimeStartupStatus.rolloutFalse,
      );

  bool get isCallV2Reachable => !currentStatus.contains(
        CallV2ProductionRuntimeStartupStatus.callV2Unreachable,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionRuntimeStartupStatus.deploymentNotAuthorized,
      );

  bool get allowsAutomaticWiring => !safetyRules.contains(
        CallV2ProductionRuntimeStartupSafetyRule.explicitHumanApprovalRequired,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'allowedFutureLocationCount': allowedFutureLocations.length,
      'forbiddenLocationCount': forbiddenLocations.length,
      'forbiddenActionCount': forbiddenActions.length,
      'safetyRuleCount': safetyRules.length,
      'dependencyGateCount': dependencyGates.length,
      'lifecycleRuleCount': lifecycleRules.length,
      'rollbackControlCount': rollbackControls.length,
      'v1ProtectionCount': v1Protections.length,
      'testRequirementCount': testRequirements.length,
      'runtimeStartupImplemented': isRuntimeStartupImplemented,
      'runtimeStarted': isRuntimeStarted,
      'rolloutEnabled': isRolloutEnabled,
      'callV2Reachable': isCallV2Reachable,
      'deploymentAuthorized': isDeploymentAuthorized,
      'allowsAutomaticWiring': allowsAutomaticWiring,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRuntimeStartupDesign(${toSafeDebugMap()})';
  }
}

final callV2ProductionRuntimeStartupDesign =
    CallV2ProductionRuntimeStartupDesign(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionRuntimeStartupStatus>[
    CallV2ProductionRuntimeStartupStatus.noRealRuntimeStartupImplemented,
    CallV2ProductionRuntimeStartupStatus.runtimeNotConstructedFromAppStartup,
    CallV2ProductionRuntimeStartupStatus.runtimeNotStarted,
    CallV2ProductionRuntimeStartupStatus
        .productionCompositionNotConstructedFromStartup,
    CallV2ProductionRuntimeStartupStatus.rolloutFalse,
    CallV2ProductionRuntimeStartupStatus.routeRegistryDisabled,
    CallV2ProductionRuntimeStartupStatus.callV2Unreachable,
    CallV2ProductionRuntimeStartupStatus.backendFirebaseDisconnected,
    CallV2ProductionRuntimeStartupStatus.rtcDisconnected,
    CallV2ProductionRuntimeStartupStatus.permissionsDisconnected,
    CallV2ProductionRuntimeStartupStatus.deploymentNotAuthorized,
  ],
  allowedFutureLocations: <CallV2ProductionRuntimeStartupAllowedLocation>[
    CallV2ProductionRuntimeStartupAllowedLocation
        .isolatedCallV2ProductionIntegrationOwner,
    CallV2ProductionRuntimeStartupAllowedLocation
        .isolatedAppStartupBoundaryOnlyIfApproved,
    CallV2ProductionRuntimeStartupAllowedLocation
        .developerOnlyRuntimeStartupPrOnly,
  ],
  forbiddenLocations: <CallV2ProductionRuntimeStartupForbiddenLocation>[
    CallV2ProductionRuntimeStartupForbiddenLocation
        .mainDartDirectRuntimeConstruction,
    CallV2ProductionRuntimeStartupForbiddenLocation.appRouter,
    CallV2ProductionRuntimeStartupForbiddenLocation.routeRegistry,
    CallV2ProductionRuntimeStartupForbiddenLocation.lifecycleEventHandlerAlone,
    CallV2ProductionRuntimeStartupForbiddenLocation.v1Files,
  ],
  forbiddenActions: <CallV2ProductionRuntimeStartupForbiddenAction>[
    CallV2ProductionRuntimeStartupForbiddenAction.modifyMainDart,
    CallV2ProductionRuntimeStartupForbiddenAction.modifyAppStartup,
    CallV2ProductionRuntimeStartupForbiddenAction.modifyAppRouter,
    CallV2ProductionRuntimeStartupForbiddenAction
        .modifyRouteRegistryToStartRuntime,
    CallV2ProductionRuntimeStartupForbiddenAction
        .constructProductionCompositionFromStartup,
    CallV2ProductionRuntimeStartupForbiddenAction.startRuntime,
    CallV2ProductionRuntimeStartupForbiddenAction.startRtc,
    CallV2ProductionRuntimeStartupForbiddenAction.requestPermissions,
    CallV2ProductionRuntimeStartupForbiddenAction.openBackendFirebaseListeners,
    CallV2ProductionRuntimeStartupForbiddenAction.changeRolloutFlag,
    CallV2ProductionRuntimeStartupForbiddenAction.registerRoutes,
    CallV2ProductionRuntimeStartupForbiddenAction.addNavigationWiring,
    CallV2ProductionRuntimeStartupForbiddenAction.deploy,
  ],
  safetyRules: <CallV2ProductionRuntimeStartupSafetyRule>[
    CallV2ProductionRuntimeStartupSafetyRule.explicitHumanApprovalRequired,
    CallV2ProductionRuntimeStartupSafetyRule.developerOnlyGateRequired,
    CallV2ProductionRuntimeStartupSafetyRule.allowlistBeforeAnyUserExposure,
    CallV2ProductionRuntimeStartupSafetyRule.emergencyKillSwitchRequired,
    CallV2ProductionRuntimeStartupSafetyRule.rolloutFalseUntilApproved,
    CallV2ProductionRuntimeStartupSafetyRule.startupIdempotent,
    CallV2ProductionRuntimeStartupSafetyRule.duplicateStartupNoOp,
    CallV2ProductionRuntimeStartupSafetyRule.startupAfterDisposeRejected,
    CallV2ProductionRuntimeStartupSafetyRule.startupAfterTerminalRejected,
    CallV2ProductionRuntimeStartupSafetyRule.staleGenerationMutationRejected,
    CallV2ProductionRuntimeStartupSafetyRule.controlledStartupFailureOnly,
    CallV2ProductionRuntimeStartupSafetyRule.noRawExceptionStackExposure,
    CallV2ProductionRuntimeStartupSafetyRule
        .noSensitiveIdsTokensChannelsCredentialsInDebugLogs,
    CallV2ProductionRuntimeStartupSafetyRule
        .noProductionServiceContactWithoutSeparateApproval,
  ],
  dependencyGates: <CallV2ProductionRuntimeStartupDependencyGate>[
    CallV2ProductionRuntimeStartupDependencyGate
        .routeRegistrationDesignAccepted,
    CallV2ProductionRuntimeStartupDependencyGate
        .lifecycleObserverDesignAccepted,
    CallV2ProductionRuntimeStartupDependencyGate.navigatorWiringDesignAccepted,
    CallV2ProductionRuntimeStartupDependencyGate
        .backendFirebaseDesignAcceptedBeforeServiceContact,
    CallV2ProductionRuntimeStartupDependencyGate
        .rtcPermissionDesignAcceptedBeforeMediaStartup,
    CallV2ProductionRuntimeStartupDependencyGate.securityPrivacyAuditAccepted,
    CallV2ProductionRuntimeStartupDependencyGate.preRolloutReadinessAccepted,
    CallV2ProductionRuntimeStartupDependencyGate.stagedRolloutDesignAccepted,
    CallV2ProductionRuntimeStartupDependencyGate.allTestsPassed,
    CallV2ProductionRuntimeStartupDependencyGate.v1SmokePlanAccepted,
  ],
  lifecycleRules: <CallV2ProductionRuntimeStartupLifecycleRule>[
    CallV2ProductionRuntimeStartupLifecycleRule
        .resumeDoesNotStartRuntimeByItself,
    CallV2ProductionRuntimeStartupLifecycleRule
        .pauseInactiveHiddenDoNotStartRuntime,
    CallV2ProductionRuntimeStartupLifecycleRule
        .detachedSignOutAuthInvalidCleanupOnlyByExplicitPolicy,
    CallV2ProductionRuntimeStartupLifecycleRule
        .lifecycleEventNeedsSeparateApprovedActionBeforeStartup,
    CallV2ProductionRuntimeStartupLifecycleRule
        .runtimeStartupIsolatedFromAppBackgrounding,
  ],
  rollbackControls: <CallV2ProductionRuntimeStartupRollback>[
    CallV2ProductionRuntimeStartupRollback.oneCommit,
    CallV2ProductionRuntimeStartupRollback.removeStartupOwnerWiring,
    CallV2ProductionRuntimeStartupRollback.rolloutFalse,
    CallV2ProductionRuntimeStartupRollback.routeRegistryDisabledNull,
    CallV2ProductionRuntimeStartupRollback.lifecycleBridgeRemainsIsolated,
    CallV2ProductionRuntimeStartupRollback.navigatorAdapterRemainsIsolated,
    CallV2ProductionRuntimeStartupRollback
        .noBackendFirebaseRtcPermissionCleanupLeaks,
    CallV2ProductionRuntimeStartupRollback.noDeploymentWithoutApproval,
    CallV2ProductionRuntimeStartupRollback.backupBranchProtected,
  ],
  v1Protections: <CallV2ProductionRuntimeStartupV1Protection>[
    CallV2ProductionRuntimeStartupV1Protection.noV1RouteChanges,
    CallV2ProductionRuntimeStartupV1Protection.noV1CallBehaviorChanges,
    CallV2ProductionRuntimeStartupV1Protection.noV1ChatBehaviorChanges,
    CallV2ProductionRuntimeStartupV1Protection.noAppStartupRegression,
    CallV2ProductionRuntimeStartupV1Protection
        .v1SmokeBeforeAndAfterAnyStartupWiring,
    CallV2ProductionRuntimeStartupV1Protection.immediateRollbackOnV1Regression,
  ],
  testRequirements: <CallV2ProductionRuntimeStartupTestRequirement>[
    CallV2ProductionRuntimeStartupTestRequirement.phase6XTests,
    CallV2ProductionRuntimeStartupTestRequirement.phase6WTests,
    CallV2ProductionRuntimeStartupTestRequirement.phase6VTests,
    CallV2ProductionRuntimeStartupTestRequirement.phase6UTests,
    CallV2ProductionRuntimeStartupTestRequirement.phase6TTests,
    CallV2ProductionRuntimeStartupTestRequirement.allCallV2DesignTests,
    CallV2ProductionRuntimeStartupTestRequirement.allCallV2IntegrationTests,
    CallV2ProductionRuntimeStartupTestRequirement.allCallV2UiTests,
    CallV2ProductionRuntimeStartupTestRequirement.preIntegrationVerification,
    CallV2ProductionRuntimeStartupTestRequirement.productionCompositionTests,
    CallV2ProductionRuntimeStartupTestRequirement.finalReadinessTests,
    CallV2ProductionRuntimeStartupTestRequirement.allCallV2FlutterTests,
    CallV2ProductionRuntimeStartupTestRequirement.backendCheck,
    CallV2ProductionRuntimeStartupTestRequirement.deploymentValidation,
    CallV2ProductionRuntimeStartupTestRequirement.firestoreRulesTests,
    CallV2ProductionRuntimeStartupTestRequirement.emulatorTests,
    CallV2ProductionRuntimeStartupTestRequirement.fullFlutterAnalyze,
    CallV2ProductionRuntimeStartupTestRequirement.diffCheck,
  ],
);
