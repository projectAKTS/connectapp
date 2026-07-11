enum CallV2ProductionRouteRegistrationStatus {
  noRealRouteRegistrationImplemented,
  routeRegistryDisabled,
  rolloutFalse,
  appRouterDisconnected,
  mainStartupDisconnected,
  disabledRouteRegistryReturnsNull,
  callV2Unreachable,
  deploymentNotAuthorized,
}

enum CallV2ProductionRouteRegistrationAllowedLocation {
  isolatedCallV2RouteRegistryImplementation,
  isolatedAppStartupBoundaryOnlyIfApproved,
  developerOnlyRouteRegistrationPrOnly,
}

enum CallV2ProductionRouteRegistrationForbiddenLocation {
  appRouterDirectRegistration,
  mainDart,
  startup,
  v1RouteFiles,
  materialAppRouteTable,
}

enum CallV2ProductionRouteRegistrationForbiddenAction {
  changeRolloutFlag,
  registerMaterialAppRoutes,
  addDynamicRouteNames,
  addRouteArguments,
  addRouteIdsTokensChannelsCredentials,
  constructRuntime,
  contactBackendFirebaseRtcPermissions,
  deploy,
}

enum CallV2ProductionRouteRegistrationRouteSafetyRule {
  fixedCanonicalRoutesOnly,
  connectingRoute,
  audioRoute,
  videoRoute,
  failureRoute,
  readyRouteIsNotProduction,
  routeSettingsArgumentsNullOnly,
  noQuery,
  noFragment,
  noDynamicPathSegments,
  noIdsTokensChannelsCredentials,
  noUnrelatedV1RoutePop,
  routeRegistryReturnsNullWhileRolloutFalse,
}

enum CallV2ProductionRouteRegistrationGate {
  explicitHumanApproval,
  developerOnlyGate,
  allowlistGateBeforeAnyUser,
  emergencyKillSwitch,
  rolloutFalseUntilApproved,
  noProductionServiceContact,
  allTests,
  securityPrivacyAudit,
  stagedRolloutDesignAccepted,
  v1SmokePlan,
}

enum CallV2ProductionRouteRegistrationRollback {
  oneCommit,
  routeRegistryDisabledNull,
  rolloutFalse,
  removeNewRegistrationOwner,
  appRouterRemainsUnchangedIfPossible,
  noDeploymentWithoutApproval,
  backupBranchProtected,
}

enum CallV2ProductionRouteRegistrationV1Protection {
  noV1RouteFileChanges,
  noV1RouteBehaviorChanges,
  noV1CallFlowChanges,
  noChatRouteBehaviorChanges,
  v1SmokeBeforeAndAfterAnyRouteRegistration,
  immediateRollbackOnV1Regression,
}

enum CallV2ProductionRouteRegistrationTestRequirement {
  phase6UTests,
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

final class CallV2ProductionRouteRegistrationDesign {
  factory CallV2ProductionRouteRegistrationDesign({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionRouteRegistrationStatus> currentStatus,
    required List<CallV2ProductionRouteRegistrationAllowedLocation>
        allowedFutureLocations,
    required List<CallV2ProductionRouteRegistrationForbiddenLocation>
        forbiddenLocations,
    required List<CallV2ProductionRouteRegistrationForbiddenAction>
        forbiddenActions,
    required List<CallV2ProductionRouteRegistrationRouteSafetyRule>
        routeSafetyRules,
    required List<CallV2ProductionRouteRegistrationGate> gates,
    required List<CallV2ProductionRouteRegistrationRollback> rollbackControls,
    required List<CallV2ProductionRouteRegistrationV1Protection> v1Protections,
    required List<CallV2ProductionRouteRegistrationTestRequirement>
        testRequirements,
  }) {
    return CallV2ProductionRouteRegistrationDesign._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionRouteRegistrationStatus>.unmodifiable(
        currentStatus,
      ),
      List<CallV2ProductionRouteRegistrationAllowedLocation>.unmodifiable(
        allowedFutureLocations,
      ),
      List<CallV2ProductionRouteRegistrationForbiddenLocation>.unmodifiable(
        forbiddenLocations,
      ),
      List<CallV2ProductionRouteRegistrationForbiddenAction>.unmodifiable(
        forbiddenActions,
      ),
      List<CallV2ProductionRouteRegistrationRouteSafetyRule>.unmodifiable(
        routeSafetyRules,
      ),
      List<CallV2ProductionRouteRegistrationGate>.unmodifiable(gates),
      List<CallV2ProductionRouteRegistrationRollback>.unmodifiable(
        rollbackControls,
      ),
      List<CallV2ProductionRouteRegistrationV1Protection>.unmodifiable(
        v1Protections,
      ),
      List<CallV2ProductionRouteRegistrationTestRequirement>.unmodifiable(
        testRequirements,
      ),
    );
  }

  const CallV2ProductionRouteRegistrationDesign._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.allowedFutureLocations,
    this.forbiddenLocations,
    this.forbiddenActions,
    this.routeSafetyRules,
    this.gates,
    this.rollbackControls,
    this.v1Protections,
    this.testRequirements,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionRouteRegistrationStatus> currentStatus;
  final List<CallV2ProductionRouteRegistrationAllowedLocation>
      allowedFutureLocations;
  final List<CallV2ProductionRouteRegistrationForbiddenLocation>
      forbiddenLocations;
  final List<CallV2ProductionRouteRegistrationForbiddenAction> forbiddenActions;
  final List<CallV2ProductionRouteRegistrationRouteSafetyRule> routeSafetyRules;
  final List<CallV2ProductionRouteRegistrationGate> gates;
  final List<CallV2ProductionRouteRegistrationRollback> rollbackControls;
  final List<CallV2ProductionRouteRegistrationV1Protection> v1Protections;
  final List<CallV2ProductionRouteRegistrationTestRequirement> testRequirements;

  bool get isRouteRegistrationImplemented => !currentStatus.contains(
        CallV2ProductionRouteRegistrationStatus
            .noRealRouteRegistrationImplemented,
      );

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionRouteRegistrationStatus.rolloutFalse,
      );

  bool get isCallV2Reachable => !currentStatus.contains(
        CallV2ProductionRouteRegistrationStatus.callV2Unreachable,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionRouteRegistrationStatus.deploymentNotAuthorized,
      );

  bool get allowsAutomaticWiring => !gates.contains(
        CallV2ProductionRouteRegistrationGate.explicitHumanApproval,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'allowedFutureLocationCount': allowedFutureLocations.length,
      'forbiddenLocationCount': forbiddenLocations.length,
      'forbiddenActionCount': forbiddenActions.length,
      'routeSafetyRuleCount': routeSafetyRules.length,
      'gateCount': gates.length,
      'rollbackControlCount': rollbackControls.length,
      'v1ProtectionCount': v1Protections.length,
      'testRequirementCount': testRequirements.length,
      'routeRegistrationImplemented': isRouteRegistrationImplemented,
      'rolloutEnabled': isRolloutEnabled,
      'callV2Reachable': isCallV2Reachable,
      'deploymentAuthorized': isDeploymentAuthorized,
      'allowsAutomaticWiring': allowsAutomaticWiring,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteRegistrationDesign(${toSafeDebugMap()})';
  }
}

final callV2ProductionRouteRegistrationDesign =
    CallV2ProductionRouteRegistrationDesign(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionRouteRegistrationStatus>[
    CallV2ProductionRouteRegistrationStatus.noRealRouteRegistrationImplemented,
    CallV2ProductionRouteRegistrationStatus.routeRegistryDisabled,
    CallV2ProductionRouteRegistrationStatus.rolloutFalse,
    CallV2ProductionRouteRegistrationStatus.appRouterDisconnected,
    CallV2ProductionRouteRegistrationStatus.mainStartupDisconnected,
    CallV2ProductionRouteRegistrationStatus.disabledRouteRegistryReturnsNull,
    CallV2ProductionRouteRegistrationStatus.callV2Unreachable,
    CallV2ProductionRouteRegistrationStatus.deploymentNotAuthorized,
  ],
  allowedFutureLocations: <CallV2ProductionRouteRegistrationAllowedLocation>[
    CallV2ProductionRouteRegistrationAllowedLocation
        .isolatedCallV2RouteRegistryImplementation,
    CallV2ProductionRouteRegistrationAllowedLocation
        .isolatedAppStartupBoundaryOnlyIfApproved,
    CallV2ProductionRouteRegistrationAllowedLocation
        .developerOnlyRouteRegistrationPrOnly,
  ],
  forbiddenLocations: <CallV2ProductionRouteRegistrationForbiddenLocation>[
    CallV2ProductionRouteRegistrationForbiddenLocation
        .appRouterDirectRegistration,
    CallV2ProductionRouteRegistrationForbiddenLocation.mainDart,
    CallV2ProductionRouteRegistrationForbiddenLocation.startup,
    CallV2ProductionRouteRegistrationForbiddenLocation.v1RouteFiles,
    CallV2ProductionRouteRegistrationForbiddenLocation.materialAppRouteTable,
  ],
  forbiddenActions: <CallV2ProductionRouteRegistrationForbiddenAction>[
    CallV2ProductionRouteRegistrationForbiddenAction.changeRolloutFlag,
    CallV2ProductionRouteRegistrationForbiddenAction.registerMaterialAppRoutes,
    CallV2ProductionRouteRegistrationForbiddenAction.addDynamicRouteNames,
    CallV2ProductionRouteRegistrationForbiddenAction.addRouteArguments,
    CallV2ProductionRouteRegistrationForbiddenAction
        .addRouteIdsTokensChannelsCredentials,
    CallV2ProductionRouteRegistrationForbiddenAction.constructRuntime,
    CallV2ProductionRouteRegistrationForbiddenAction
        .contactBackendFirebaseRtcPermissions,
    CallV2ProductionRouteRegistrationForbiddenAction.deploy,
  ],
  routeSafetyRules: <CallV2ProductionRouteRegistrationRouteSafetyRule>[
    CallV2ProductionRouteRegistrationRouteSafetyRule.fixedCanonicalRoutesOnly,
    CallV2ProductionRouteRegistrationRouteSafetyRule.connectingRoute,
    CallV2ProductionRouteRegistrationRouteSafetyRule.audioRoute,
    CallV2ProductionRouteRegistrationRouteSafetyRule.videoRoute,
    CallV2ProductionRouteRegistrationRouteSafetyRule.failureRoute,
    CallV2ProductionRouteRegistrationRouteSafetyRule.readyRouteIsNotProduction,
    CallV2ProductionRouteRegistrationRouteSafetyRule
        .routeSettingsArgumentsNullOnly,
    CallV2ProductionRouteRegistrationRouteSafetyRule.noQuery,
    CallV2ProductionRouteRegistrationRouteSafetyRule.noFragment,
    CallV2ProductionRouteRegistrationRouteSafetyRule.noDynamicPathSegments,
    CallV2ProductionRouteRegistrationRouteSafetyRule
        .noIdsTokensChannelsCredentials,
    CallV2ProductionRouteRegistrationRouteSafetyRule.noUnrelatedV1RoutePop,
    CallV2ProductionRouteRegistrationRouteSafetyRule
        .routeRegistryReturnsNullWhileRolloutFalse,
  ],
  gates: <CallV2ProductionRouteRegistrationGate>[
    CallV2ProductionRouteRegistrationGate.explicitHumanApproval,
    CallV2ProductionRouteRegistrationGate.developerOnlyGate,
    CallV2ProductionRouteRegistrationGate.allowlistGateBeforeAnyUser,
    CallV2ProductionRouteRegistrationGate.emergencyKillSwitch,
    CallV2ProductionRouteRegistrationGate.rolloutFalseUntilApproved,
    CallV2ProductionRouteRegistrationGate.noProductionServiceContact,
    CallV2ProductionRouteRegistrationGate.allTests,
    CallV2ProductionRouteRegistrationGate.securityPrivacyAudit,
    CallV2ProductionRouteRegistrationGate.stagedRolloutDesignAccepted,
    CallV2ProductionRouteRegistrationGate.v1SmokePlan,
  ],
  rollbackControls: <CallV2ProductionRouteRegistrationRollback>[
    CallV2ProductionRouteRegistrationRollback.oneCommit,
    CallV2ProductionRouteRegistrationRollback.routeRegistryDisabledNull,
    CallV2ProductionRouteRegistrationRollback.rolloutFalse,
    CallV2ProductionRouteRegistrationRollback.removeNewRegistrationOwner,
    CallV2ProductionRouteRegistrationRollback
        .appRouterRemainsUnchangedIfPossible,
    CallV2ProductionRouteRegistrationRollback.noDeploymentWithoutApproval,
    CallV2ProductionRouteRegistrationRollback.backupBranchProtected,
  ],
  v1Protections: <CallV2ProductionRouteRegistrationV1Protection>[
    CallV2ProductionRouteRegistrationV1Protection.noV1RouteFileChanges,
    CallV2ProductionRouteRegistrationV1Protection.noV1RouteBehaviorChanges,
    CallV2ProductionRouteRegistrationV1Protection.noV1CallFlowChanges,
    CallV2ProductionRouteRegistrationV1Protection.noChatRouteBehaviorChanges,
    CallV2ProductionRouteRegistrationV1Protection
        .v1SmokeBeforeAndAfterAnyRouteRegistration,
    CallV2ProductionRouteRegistrationV1Protection
        .immediateRollbackOnV1Regression,
  ],
  testRequirements: <CallV2ProductionRouteRegistrationTestRequirement>[
    CallV2ProductionRouteRegistrationTestRequirement.phase6UTests,
    CallV2ProductionRouteRegistrationTestRequirement.allCallV2DesignTests,
    CallV2ProductionRouteRegistrationTestRequirement.allCallV2IntegrationTests,
    CallV2ProductionRouteRegistrationTestRequirement.allCallV2UiTests,
    CallV2ProductionRouteRegistrationTestRequirement.preIntegrationVerification,
    CallV2ProductionRouteRegistrationTestRequirement.productionCompositionTests,
    CallV2ProductionRouteRegistrationTestRequirement.finalReadinessTests,
    CallV2ProductionRouteRegistrationTestRequirement.allCallV2FlutterTests,
    CallV2ProductionRouteRegistrationTestRequirement.backendCheck,
    CallV2ProductionRouteRegistrationTestRequirement.deploymentValidation,
    CallV2ProductionRouteRegistrationTestRequirement.firestoreRulesTests,
    CallV2ProductionRouteRegistrationTestRequirement.emulatorTests,
    CallV2ProductionRouteRegistrationTestRequirement.fullFlutterAnalyze,
    CallV2ProductionRouteRegistrationTestRequirement.diffCheck,
  ],
);
