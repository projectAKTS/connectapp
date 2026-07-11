enum CallV2ProductionHumanApprovalStatus {
  noAutomaticRealAppWiring,
  rolloutFalse,
  deploymentNotAuthorized,
  backupBranchProtected,
  preRolloutNotReadyForUserRollout,
  securityPrivacyAuditActive,
  lifecycleHookupDesignOnly,
  realAppWiringNotImplemented,
  runtimeNotStarted,
  backendFirebaseRtcPermissionsDisconnected,
}

enum CallV2ProductionHumanDecisionOption {
  keepIsolated,
  createStagedRolloutDesignOnly,
  prepareDeveloperOnlyLifecycleObserverDesign,
  prepareDeveloperOnlyRouteRegistrationDesign,
  prepareFirstRealWiringPrAfterExplicitApproval,
}

enum CallV2ProductionHumanApprovalRecommendation {
  stagedRolloutDesignOnly,
  developerOnlyDesignPackageFirst,
  noAutomaticRealAppWiring,
}

enum CallV2ProductionHumanApprovalBlockedAction {
  changeRolloutFlag,
  modifyMainDart,
  modifyAppStartup,
  modifyAppRouter,
  enableRouteRegistry,
  wireNavigatorAdapterToRealApp,
  constructProductionUiCompositionFromAppStartup,
  startRuntime,
  openBackendFirebaseListeners,
  initializeRtc,
  requestPermissions,
  deploy,
}

enum CallV2ProductionHumanApprovalRequirement {
  humanApprovalRecorded,
  exactWiringScopeChosen,
  rollbackPathConfirmed,
  emergencyKillSwitchConfirmed,
  developerOnlyOrAllowlistStrategyDefined,
  noPublicUserRollout,
  noProductionServiceContactWithoutSeparateApproval,
  testPlanAccepted,
  backupBranchVerifiedUnchanged,
}

enum CallV2ProductionHumanApprovalPreWiringTest {
  allCallV2FlutterTests,
  allCallV2DesignTests,
  allCallV2IntegrationTests,
  allCallV2UiTests,
  finalReadinessAudit,
  securityPrivacyAudit,
  backendRulesEmulatorChecks,
  fullFlutterAnalyze,
  v1SmokeChecksIfAvailable,
}

enum CallV2ProductionHumanApprovalPostWiringTest {
  allPreWiringTestsAgain,
  realObserverLifecycleTestsIfLifecycleChosen,
  routeGatingTestsIfRouteChosen,
  killSwitchRollbackTests,
  noProductionServiceContactTests,
  startupIsolationTests,
  v1RegressionChecks,
}

enum CallV2ProductionHumanApprovalRollbackItem {
  keepRolloutFalse,
  routeRegistryReturnsNullWhileFalse,
  disableOrRemoveNewWiringInOneCommit,
  keepDisabledOwnerInertUnlessApproved,
  noDeploymentWithoutApproval,
  backupBranchRemainsUnchanged,
}

final class CallV2ProductionHumanApprovalPackage {
  factory CallV2ProductionHumanApprovalPackage({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionHumanApprovalStatus> currentStatus,
    required List<CallV2ProductionHumanDecisionOption> decisionOptions,
    required List<CallV2ProductionHumanApprovalRecommendation>
        recommendedOptions,
    required List<CallV2ProductionHumanApprovalBlockedAction> blockedActions,
    required List<CallV2ProductionHumanApprovalRequirement> approvalChecklist,
    required List<CallV2ProductionHumanApprovalPreWiringTest> preWiringTests,
    required List<CallV2ProductionHumanApprovalPostWiringTest> postWiringTests,
    required List<CallV2ProductionHumanApprovalRollbackItem> rollbackChecklist,
  }) {
    return CallV2ProductionHumanApprovalPackage._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionHumanApprovalStatus>.unmodifiable(currentStatus),
      List<CallV2ProductionHumanDecisionOption>.unmodifiable(decisionOptions),
      List<CallV2ProductionHumanApprovalRecommendation>.unmodifiable(
        recommendedOptions,
      ),
      List<CallV2ProductionHumanApprovalBlockedAction>.unmodifiable(
        blockedActions,
      ),
      List<CallV2ProductionHumanApprovalRequirement>.unmodifiable(
        approvalChecklist,
      ),
      List<CallV2ProductionHumanApprovalPreWiringTest>.unmodifiable(
        preWiringTests,
      ),
      List<CallV2ProductionHumanApprovalPostWiringTest>.unmodifiable(
        postWiringTests,
      ),
      List<CallV2ProductionHumanApprovalRollbackItem>.unmodifiable(
        rollbackChecklist,
      ),
    );
  }

  const CallV2ProductionHumanApprovalPackage._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.decisionOptions,
    this.recommendedOptions,
    this.blockedActions,
    this.approvalChecklist,
    this.preWiringTests,
    this.postWiringTests,
    this.rollbackChecklist,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionHumanApprovalStatus> currentStatus;
  final List<CallV2ProductionHumanDecisionOption> decisionOptions;
  final List<CallV2ProductionHumanApprovalRecommendation> recommendedOptions;
  final List<CallV2ProductionHumanApprovalBlockedAction> blockedActions;
  final List<CallV2ProductionHumanApprovalRequirement> approvalChecklist;
  final List<CallV2ProductionHumanApprovalPreWiringTest> preWiringTests;
  final List<CallV2ProductionHumanApprovalPostWiringTest> postWiringTests;
  final List<CallV2ProductionHumanApprovalRollbackItem> rollbackChecklist;

  bool get allowsAutomaticRealAppWiring => !currentStatus.contains(
        CallV2ProductionHumanApprovalStatus.noAutomaticRealAppWiring,
      );

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionHumanApprovalStatus.rolloutFalse,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionHumanApprovalStatus.deploymentNotAuthorized,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'decisionOptionCount': decisionOptions.length,
      'recommendedOptionCount': recommendedOptions.length,
      'blockedActionCount': blockedActions.length,
      'approvalChecklistCount': approvalChecklist.length,
      'preWiringTestCount': preWiringTests.length,
      'postWiringTestCount': postWiringTests.length,
      'rollbackChecklistCount': rollbackChecklist.length,
      'allowsAutomaticRealAppWiring': allowsAutomaticRealAppWiring,
      'rolloutEnabled': isRolloutEnabled,
      'deploymentAuthorized': isDeploymentAuthorized,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionHumanApprovalPackage(${toSafeDebugMap()})';
  }
}

final callV2ProductionHumanApprovalPackage =
    CallV2ProductionHumanApprovalPackage(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionHumanApprovalStatus>[
    CallV2ProductionHumanApprovalStatus.noAutomaticRealAppWiring,
    CallV2ProductionHumanApprovalStatus.rolloutFalse,
    CallV2ProductionHumanApprovalStatus.deploymentNotAuthorized,
    CallV2ProductionHumanApprovalStatus.backupBranchProtected,
    CallV2ProductionHumanApprovalStatus.preRolloutNotReadyForUserRollout,
    CallV2ProductionHumanApprovalStatus.securityPrivacyAuditActive,
    CallV2ProductionHumanApprovalStatus.lifecycleHookupDesignOnly,
    CallV2ProductionHumanApprovalStatus.realAppWiringNotImplemented,
    CallV2ProductionHumanApprovalStatus.runtimeNotStarted,
    CallV2ProductionHumanApprovalStatus
        .backendFirebaseRtcPermissionsDisconnected,
  ],
  decisionOptions: <CallV2ProductionHumanDecisionOption>[
    CallV2ProductionHumanDecisionOption.keepIsolated,
    CallV2ProductionHumanDecisionOption.createStagedRolloutDesignOnly,
    CallV2ProductionHumanDecisionOption
        .prepareDeveloperOnlyLifecycleObserverDesign,
    CallV2ProductionHumanDecisionOption
        .prepareDeveloperOnlyRouteRegistrationDesign,
    CallV2ProductionHumanDecisionOption
        .prepareFirstRealWiringPrAfterExplicitApproval,
  ],
  recommendedOptions: <CallV2ProductionHumanApprovalRecommendation>[
    CallV2ProductionHumanApprovalRecommendation.stagedRolloutDesignOnly,
    CallV2ProductionHumanApprovalRecommendation.developerOnlyDesignPackageFirst,
    CallV2ProductionHumanApprovalRecommendation.noAutomaticRealAppWiring,
  ],
  blockedActions: <CallV2ProductionHumanApprovalBlockedAction>[
    CallV2ProductionHumanApprovalBlockedAction.changeRolloutFlag,
    CallV2ProductionHumanApprovalBlockedAction.modifyMainDart,
    CallV2ProductionHumanApprovalBlockedAction.modifyAppStartup,
    CallV2ProductionHumanApprovalBlockedAction.modifyAppRouter,
    CallV2ProductionHumanApprovalBlockedAction.enableRouteRegistry,
    CallV2ProductionHumanApprovalBlockedAction.wireNavigatorAdapterToRealApp,
    CallV2ProductionHumanApprovalBlockedAction
        .constructProductionUiCompositionFromAppStartup,
    CallV2ProductionHumanApprovalBlockedAction.startRuntime,
    CallV2ProductionHumanApprovalBlockedAction.openBackendFirebaseListeners,
    CallV2ProductionHumanApprovalBlockedAction.initializeRtc,
    CallV2ProductionHumanApprovalBlockedAction.requestPermissions,
    CallV2ProductionHumanApprovalBlockedAction.deploy,
  ],
  approvalChecklist: <CallV2ProductionHumanApprovalRequirement>[
    CallV2ProductionHumanApprovalRequirement.humanApprovalRecorded,
    CallV2ProductionHumanApprovalRequirement.exactWiringScopeChosen,
    CallV2ProductionHumanApprovalRequirement.rollbackPathConfirmed,
    CallV2ProductionHumanApprovalRequirement.emergencyKillSwitchConfirmed,
    CallV2ProductionHumanApprovalRequirement
        .developerOnlyOrAllowlistStrategyDefined,
    CallV2ProductionHumanApprovalRequirement.noPublicUserRollout,
    CallV2ProductionHumanApprovalRequirement
        .noProductionServiceContactWithoutSeparateApproval,
    CallV2ProductionHumanApprovalRequirement.testPlanAccepted,
    CallV2ProductionHumanApprovalRequirement.backupBranchVerifiedUnchanged,
  ],
  preWiringTests: <CallV2ProductionHumanApprovalPreWiringTest>[
    CallV2ProductionHumanApprovalPreWiringTest.allCallV2FlutterTests,
    CallV2ProductionHumanApprovalPreWiringTest.allCallV2DesignTests,
    CallV2ProductionHumanApprovalPreWiringTest.allCallV2IntegrationTests,
    CallV2ProductionHumanApprovalPreWiringTest.allCallV2UiTests,
    CallV2ProductionHumanApprovalPreWiringTest.finalReadinessAudit,
    CallV2ProductionHumanApprovalPreWiringTest.securityPrivacyAudit,
    CallV2ProductionHumanApprovalPreWiringTest.backendRulesEmulatorChecks,
    CallV2ProductionHumanApprovalPreWiringTest.fullFlutterAnalyze,
    CallV2ProductionHumanApprovalPreWiringTest.v1SmokeChecksIfAvailable,
  ],
  postWiringTests: <CallV2ProductionHumanApprovalPostWiringTest>[
    CallV2ProductionHumanApprovalPostWiringTest.allPreWiringTestsAgain,
    CallV2ProductionHumanApprovalPostWiringTest
        .realObserverLifecycleTestsIfLifecycleChosen,
    CallV2ProductionHumanApprovalPostWiringTest.routeGatingTestsIfRouteChosen,
    CallV2ProductionHumanApprovalPostWiringTest.killSwitchRollbackTests,
    CallV2ProductionHumanApprovalPostWiringTest.noProductionServiceContactTests,
    CallV2ProductionHumanApprovalPostWiringTest.startupIsolationTests,
    CallV2ProductionHumanApprovalPostWiringTest.v1RegressionChecks,
  ],
  rollbackChecklist: <CallV2ProductionHumanApprovalRollbackItem>[
    CallV2ProductionHumanApprovalRollbackItem.keepRolloutFalse,
    CallV2ProductionHumanApprovalRollbackItem
        .routeRegistryReturnsNullWhileFalse,
    CallV2ProductionHumanApprovalRollbackItem
        .disableOrRemoveNewWiringInOneCommit,
    CallV2ProductionHumanApprovalRollbackItem
        .keepDisabledOwnerInertUnlessApproved,
    CallV2ProductionHumanApprovalRollbackItem.noDeploymentWithoutApproval,
    CallV2ProductionHumanApprovalRollbackItem.backupBranchRemainsUnchanged,
  ],
);
