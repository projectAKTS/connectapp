enum CallV2ProductionNavigatorWiringStatus {
  noRealNavigatorWiringImplemented,
  noAppNavKeyIntroduced,
  noGlobalAppKeyIntroduced,
  noWidgetContextStored,
  noMaterialAppWiring,
  noAppRouterWiring,
  routeRegistryDisabled,
  rolloutFalse,
  callV2Unreachable,
  typedNavAdapterIsolated,
  deploymentNotAuthorized,
}

enum CallV2ProductionNavigatorWiringAllowedLocation {
  isolatedCallV2NavigatorOwner,
  isolatedAppStartupBoundaryOnlyIfApproved,
  developerOnlyNavigatorWiringPrOnly,
}

enum CallV2ProductionNavigatorWiringForbiddenLocation {
  appRouterDirectWiring,
  mainDartDirectNavigationLogic,
  startup,
  v1RouteFiles,
  v1CallFiles,
  v1ChatFiles,
}

enum CallV2ProductionNavigatorWiringForbiddenAction {
  modifyAppRouter,
  modifyMainDart,
  modifyStartup,
  changeRolloutFlag,
  registerRoutes,
  addAppNavKey,
  addGlobalAppKey,
  storeWidgetContext,
  useDirectNavigationOutsideTypedBoundary,
  passRouteArguments,
  addDynamicRouteNames,
  addIdsTokensChannelsCredentialsToNavigation,
  popUnrelatedV1Routes,
  startRuntime,
  contactBackendServicesRtcPermissions,
  deploy,
}

enum CallV2ProductionNavigatorWiringSafetyRule {
  typedNavPortOnly,
  callV2OwnedRoutePopOnly,
  noGenericPopOfUnrelatedAppRoutes,
  routeSettingsArgumentsNullOnly,
  fixedCanonicalRouteNamesOnly,
  noQuery,
  noFragment,
  noDynamicSegments,
  noIdsTokensChannelsCredentials,
  navigationAfterDisposeRejected,
  staleGenerationMutationRejected,
  duplicateNavigationIdempotentNoOp,
  adapterFailuresControlledSanitized,
}

enum CallV2ProductionNavigatorWiringRouteOwnershipRule {
  ownedRouteNameMustBeCanonical,
  currentRouteMustMatchOwnedRouteBeforePop,
  readyRouteIsNotProduction,
  v1RoutesNeverOwnedByCallV2,
  unknownRoutesNeverPoppedByCallV2,
}

enum CallV2ProductionNavigatorWiringGate {
  explicitHumanApproval,
  developerOnlyGate,
  allowlistBeforeUsers,
  emergencyKillSwitch,
  rolloutFalseUntilApproved,
  routeRegistrationDesignAccepted,
  lifecycleObserverDesignAccepted,
  securityPrivacyAudit,
  allTests,
  v1SmokePlan,
}

enum CallV2ProductionNavigatorWiringRollback {
  oneCommit,
  removeNavigatorOwnerWiring,
  rolloutFalse,
  routeRegistryDisabledNull,
  appRouterUnchangedIfPossible,
  mainDartUnchangedIfPossible,
  typedNavAdapterRemainsIsolated,
  noDeploymentWithoutApproval,
  backupBranchProtected,
}

enum CallV2ProductionNavigatorWiringV1Protection {
  noV1RouteFileChanges,
  noV1CallFileChanges,
  noV1ChatFileChanges,
  noV1RouteBehaviorChanges,
  noV1CallFlowChanges,
  noUnrelatedV1RoutePop,
  v1SmokeBeforeAndAfterAnyNavigatorWiring,
  immediateRollbackOnV1Regression,
}

enum CallV2ProductionNavigatorWiringTestRequirement {
  phase6WTests,
  phase6VTests,
  phase6UTests,
  phase6TTests,
  phase6STests,
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

final class CallV2ProductionNavigatorWiringDesign {
  factory CallV2ProductionNavigatorWiringDesign({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionNavigatorWiringStatus> currentStatus,
    required List<CallV2ProductionNavigatorWiringAllowedLocation>
        allowedFutureLocations,
    required List<CallV2ProductionNavigatorWiringForbiddenLocation>
        forbiddenLocations,
    required List<CallV2ProductionNavigatorWiringForbiddenAction>
        forbiddenActions,
    required List<CallV2ProductionNavigatorWiringSafetyRule> safetyRules,
    required List<CallV2ProductionNavigatorWiringRouteOwnershipRule>
        routeOwnershipRules,
    required List<CallV2ProductionNavigatorWiringGate> gates,
    required List<CallV2ProductionNavigatorWiringRollback> rollbackControls,
    required List<CallV2ProductionNavigatorWiringV1Protection> v1Protections,
    required List<CallV2ProductionNavigatorWiringTestRequirement>
        testRequirements,
  }) {
    return CallV2ProductionNavigatorWiringDesign._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionNavigatorWiringStatus>.unmodifiable(currentStatus),
      List<CallV2ProductionNavigatorWiringAllowedLocation>.unmodifiable(
        allowedFutureLocations,
      ),
      List<CallV2ProductionNavigatorWiringForbiddenLocation>.unmodifiable(
        forbiddenLocations,
      ),
      List<CallV2ProductionNavigatorWiringForbiddenAction>.unmodifiable(
        forbiddenActions,
      ),
      List<CallV2ProductionNavigatorWiringSafetyRule>.unmodifiable(
        safetyRules,
      ),
      List<CallV2ProductionNavigatorWiringRouteOwnershipRule>.unmodifiable(
        routeOwnershipRules,
      ),
      List<CallV2ProductionNavigatorWiringGate>.unmodifiable(gates),
      List<CallV2ProductionNavigatorWiringRollback>.unmodifiable(
        rollbackControls,
      ),
      List<CallV2ProductionNavigatorWiringV1Protection>.unmodifiable(
        v1Protections,
      ),
      List<CallV2ProductionNavigatorWiringTestRequirement>.unmodifiable(
        testRequirements,
      ),
    );
  }

  const CallV2ProductionNavigatorWiringDesign._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.allowedFutureLocations,
    this.forbiddenLocations,
    this.forbiddenActions,
    this.safetyRules,
    this.routeOwnershipRules,
    this.gates,
    this.rollbackControls,
    this.v1Protections,
    this.testRequirements,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionNavigatorWiringStatus> currentStatus;
  final List<CallV2ProductionNavigatorWiringAllowedLocation>
      allowedFutureLocations;
  final List<CallV2ProductionNavigatorWiringForbiddenLocation>
      forbiddenLocations;
  final List<CallV2ProductionNavigatorWiringForbiddenAction> forbiddenActions;
  final List<CallV2ProductionNavigatorWiringSafetyRule> safetyRules;
  final List<CallV2ProductionNavigatorWiringRouteOwnershipRule>
      routeOwnershipRules;
  final List<CallV2ProductionNavigatorWiringGate> gates;
  final List<CallV2ProductionNavigatorWiringRollback> rollbackControls;
  final List<CallV2ProductionNavigatorWiringV1Protection> v1Protections;
  final List<CallV2ProductionNavigatorWiringTestRequirement> testRequirements;

  bool get isNavigatorWiringImplemented => !currentStatus.contains(
        CallV2ProductionNavigatorWiringStatus.noRealNavigatorWiringImplemented,
      );

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionNavigatorWiringStatus.rolloutFalse,
      );

  bool get isCallV2Reachable => !currentStatus.contains(
        CallV2ProductionNavigatorWiringStatus.callV2Unreachable,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionNavigatorWiringStatus.deploymentNotAuthorized,
      );

  bool get allowsAutomaticWiring => !gates.contains(
        CallV2ProductionNavigatorWiringGate.explicitHumanApproval,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'allowedFutureLocationCount': allowedFutureLocations.length,
      'forbiddenLocationCount': forbiddenLocations.length,
      'forbiddenActionCount': forbiddenActions.length,
      'safetyRuleCount': safetyRules.length,
      'routeOwnershipRuleCount': routeOwnershipRules.length,
      'gateCount': gates.length,
      'rollbackControlCount': rollbackControls.length,
      'v1ProtectionCount': v1Protections.length,
      'testRequirementCount': testRequirements.length,
      'navigatorWiringImplemented': isNavigatorWiringImplemented,
      'rolloutEnabled': isRolloutEnabled,
      'callV2Reachable': isCallV2Reachable,
      'deploymentAuthorized': isDeploymentAuthorized,
      'allowsAutomaticWiring': allowsAutomaticWiring,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionNavigatorWiringDesign(${toSafeDebugMap()})';
  }
}

final callV2ProductionNavigatorWiringDesign =
    CallV2ProductionNavigatorWiringDesign(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionNavigatorWiringStatus>[
    CallV2ProductionNavigatorWiringStatus.noRealNavigatorWiringImplemented,
    CallV2ProductionNavigatorWiringStatus.noAppNavKeyIntroduced,
    CallV2ProductionNavigatorWiringStatus.noGlobalAppKeyIntroduced,
    CallV2ProductionNavigatorWiringStatus.noWidgetContextStored,
    CallV2ProductionNavigatorWiringStatus.noMaterialAppWiring,
    CallV2ProductionNavigatorWiringStatus.noAppRouterWiring,
    CallV2ProductionNavigatorWiringStatus.routeRegistryDisabled,
    CallV2ProductionNavigatorWiringStatus.rolloutFalse,
    CallV2ProductionNavigatorWiringStatus.callV2Unreachable,
    CallV2ProductionNavigatorWiringStatus.typedNavAdapterIsolated,
    CallV2ProductionNavigatorWiringStatus.deploymentNotAuthorized,
  ],
  allowedFutureLocations: <CallV2ProductionNavigatorWiringAllowedLocation>[
    CallV2ProductionNavigatorWiringAllowedLocation.isolatedCallV2NavigatorOwner,
    CallV2ProductionNavigatorWiringAllowedLocation
        .isolatedAppStartupBoundaryOnlyIfApproved,
    CallV2ProductionNavigatorWiringAllowedLocation
        .developerOnlyNavigatorWiringPrOnly,
  ],
  forbiddenLocations: <CallV2ProductionNavigatorWiringForbiddenLocation>[
    CallV2ProductionNavigatorWiringForbiddenLocation.appRouterDirectWiring,
    CallV2ProductionNavigatorWiringForbiddenLocation
        .mainDartDirectNavigationLogic,
    CallV2ProductionNavigatorWiringForbiddenLocation.startup,
    CallV2ProductionNavigatorWiringForbiddenLocation.v1RouteFiles,
    CallV2ProductionNavigatorWiringForbiddenLocation.v1CallFiles,
    CallV2ProductionNavigatorWiringForbiddenLocation.v1ChatFiles,
  ],
  forbiddenActions: <CallV2ProductionNavigatorWiringForbiddenAction>[
    CallV2ProductionNavigatorWiringForbiddenAction.modifyAppRouter,
    CallV2ProductionNavigatorWiringForbiddenAction.modifyMainDart,
    CallV2ProductionNavigatorWiringForbiddenAction.modifyStartup,
    CallV2ProductionNavigatorWiringForbiddenAction.changeRolloutFlag,
    CallV2ProductionNavigatorWiringForbiddenAction.registerRoutes,
    CallV2ProductionNavigatorWiringForbiddenAction.addAppNavKey,
    CallV2ProductionNavigatorWiringForbiddenAction.addGlobalAppKey,
    CallV2ProductionNavigatorWiringForbiddenAction.storeWidgetContext,
    CallV2ProductionNavigatorWiringForbiddenAction
        .useDirectNavigationOutsideTypedBoundary,
    CallV2ProductionNavigatorWiringForbiddenAction.passRouteArguments,
    CallV2ProductionNavigatorWiringForbiddenAction.addDynamicRouteNames,
    CallV2ProductionNavigatorWiringForbiddenAction
        .addIdsTokensChannelsCredentialsToNavigation,
    CallV2ProductionNavigatorWiringForbiddenAction.popUnrelatedV1Routes,
    CallV2ProductionNavigatorWiringForbiddenAction.startRuntime,
    CallV2ProductionNavigatorWiringForbiddenAction
        .contactBackendServicesRtcPermissions,
    CallV2ProductionNavigatorWiringForbiddenAction.deploy,
  ],
  safetyRules: <CallV2ProductionNavigatorWiringSafetyRule>[
    CallV2ProductionNavigatorWiringSafetyRule.typedNavPortOnly,
    CallV2ProductionNavigatorWiringSafetyRule.callV2OwnedRoutePopOnly,
    CallV2ProductionNavigatorWiringSafetyRule.noGenericPopOfUnrelatedAppRoutes,
    CallV2ProductionNavigatorWiringSafetyRule.routeSettingsArgumentsNullOnly,
    CallV2ProductionNavigatorWiringSafetyRule.fixedCanonicalRouteNamesOnly,
    CallV2ProductionNavigatorWiringSafetyRule.noQuery,
    CallV2ProductionNavigatorWiringSafetyRule.noFragment,
    CallV2ProductionNavigatorWiringSafetyRule.noDynamicSegments,
    CallV2ProductionNavigatorWiringSafetyRule.noIdsTokensChannelsCredentials,
    CallV2ProductionNavigatorWiringSafetyRule.navigationAfterDisposeRejected,
    CallV2ProductionNavigatorWiringSafetyRule.staleGenerationMutationRejected,
    CallV2ProductionNavigatorWiringSafetyRule.duplicateNavigationIdempotentNoOp,
    CallV2ProductionNavigatorWiringSafetyRule
        .adapterFailuresControlledSanitized,
  ],
  routeOwnershipRules: <CallV2ProductionNavigatorWiringRouteOwnershipRule>[
    CallV2ProductionNavigatorWiringRouteOwnershipRule
        .ownedRouteNameMustBeCanonical,
    CallV2ProductionNavigatorWiringRouteOwnershipRule
        .currentRouteMustMatchOwnedRouteBeforePop,
    CallV2ProductionNavigatorWiringRouteOwnershipRule.readyRouteIsNotProduction,
    CallV2ProductionNavigatorWiringRouteOwnershipRule
        .v1RoutesNeverOwnedByCallV2,
    CallV2ProductionNavigatorWiringRouteOwnershipRule
        .unknownRoutesNeverPoppedByCallV2,
  ],
  gates: <CallV2ProductionNavigatorWiringGate>[
    CallV2ProductionNavigatorWiringGate.explicitHumanApproval,
    CallV2ProductionNavigatorWiringGate.developerOnlyGate,
    CallV2ProductionNavigatorWiringGate.allowlistBeforeUsers,
    CallV2ProductionNavigatorWiringGate.emergencyKillSwitch,
    CallV2ProductionNavigatorWiringGate.rolloutFalseUntilApproved,
    CallV2ProductionNavigatorWiringGate.routeRegistrationDesignAccepted,
    CallV2ProductionNavigatorWiringGate.lifecycleObserverDesignAccepted,
    CallV2ProductionNavigatorWiringGate.securityPrivacyAudit,
    CallV2ProductionNavigatorWiringGate.allTests,
    CallV2ProductionNavigatorWiringGate.v1SmokePlan,
  ],
  rollbackControls: <CallV2ProductionNavigatorWiringRollback>[
    CallV2ProductionNavigatorWiringRollback.oneCommit,
    CallV2ProductionNavigatorWiringRollback.removeNavigatorOwnerWiring,
    CallV2ProductionNavigatorWiringRollback.rolloutFalse,
    CallV2ProductionNavigatorWiringRollback.routeRegistryDisabledNull,
    CallV2ProductionNavigatorWiringRollback.appRouterUnchangedIfPossible,
    CallV2ProductionNavigatorWiringRollback.mainDartUnchangedIfPossible,
    CallV2ProductionNavigatorWiringRollback.typedNavAdapterRemainsIsolated,
    CallV2ProductionNavigatorWiringRollback.noDeploymentWithoutApproval,
    CallV2ProductionNavigatorWiringRollback.backupBranchProtected,
  ],
  v1Protections: <CallV2ProductionNavigatorWiringV1Protection>[
    CallV2ProductionNavigatorWiringV1Protection.noV1RouteFileChanges,
    CallV2ProductionNavigatorWiringV1Protection.noV1CallFileChanges,
    CallV2ProductionNavigatorWiringV1Protection.noV1ChatFileChanges,
    CallV2ProductionNavigatorWiringV1Protection.noV1RouteBehaviorChanges,
    CallV2ProductionNavigatorWiringV1Protection.noV1CallFlowChanges,
    CallV2ProductionNavigatorWiringV1Protection.noUnrelatedV1RoutePop,
    CallV2ProductionNavigatorWiringV1Protection
        .v1SmokeBeforeAndAfterAnyNavigatorWiring,
    CallV2ProductionNavigatorWiringV1Protection.immediateRollbackOnV1Regression,
  ],
  testRequirements: <CallV2ProductionNavigatorWiringTestRequirement>[
    CallV2ProductionNavigatorWiringTestRequirement.phase6WTests,
    CallV2ProductionNavigatorWiringTestRequirement.phase6VTests,
    CallV2ProductionNavigatorWiringTestRequirement.phase6UTests,
    CallV2ProductionNavigatorWiringTestRequirement.phase6TTests,
    CallV2ProductionNavigatorWiringTestRequirement.phase6STests,
    CallV2ProductionNavigatorWiringTestRequirement.allCallV2DesignTests,
    CallV2ProductionNavigatorWiringTestRequirement.allCallV2IntegrationTests,
    CallV2ProductionNavigatorWiringTestRequirement.allCallV2UiTests,
    CallV2ProductionNavigatorWiringTestRequirement.preIntegrationVerification,
    CallV2ProductionNavigatorWiringTestRequirement.productionCompositionTests,
    CallV2ProductionNavigatorWiringTestRequirement.finalReadinessTests,
    CallV2ProductionNavigatorWiringTestRequirement.allCallV2FlutterTests,
    CallV2ProductionNavigatorWiringTestRequirement.backendCheck,
    CallV2ProductionNavigatorWiringTestRequirement.deploymentValidation,
    CallV2ProductionNavigatorWiringTestRequirement.firestoreRulesTests,
    CallV2ProductionNavigatorWiringTestRequirement.emulatorTests,
    CallV2ProductionNavigatorWiringTestRequirement.fullFlutterAnalyze,
    CallV2ProductionNavigatorWiringTestRequirement.diffCheck,
  ],
);
