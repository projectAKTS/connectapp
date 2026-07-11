enum CallV2ProductionPreRolloutReadinessStatus {
  notReadyForUserRollout,
  notReadyForRealAppWiringWithoutApproval,
}

enum CallV2ProductionPreRolloutBoundaryInventory {
  disabledProductionIntegrationOwnerExists,
  productionUiContractsExist,
  productionPresentationMappingExists,
  productionViewModelsExist,
  isolatedScreenShellsExist,
  productionScreenFactoryExists,
  productionRouteObjectFactoryExists,
  productionRouteSinkExists,
  typedNavigatorAdapterBoundaryExists,
  uiCompositionOwnerExists,
  runtimeUiBridgeExists,
  lifecycleBridgeExists,
  lifecycleHookupDesignExists,
  permissionDeviceBridgeExists,
  callStateBridgeExists,
  securityPrivacyAuditExists,
}

enum CallV2ProductionPreRolloutDisabledState {
  rolloutFalse,
  routeRegistryDisabled,
  disabledRouteRegistryReturnsNull,
  appStartupIntegrationDisabledAndInert,
  noRealRouteRegistration,
  noProductionRuntimeStart,
  noProductionUiReachability,
  noBackendFirebaseRtcPermissionAccess,
  noDeployment,
}

enum CallV2ProductionPreRolloutApprovalGate {
  lifecycleObserverRegistration,
  startupMainChange,
  routeRegistryEnablement,
  navigatorAdapterWiringToRealApp,
  productionUiCompositionConstruction,
  runtimeConstruction,
  backendFirebaseIntegration,
  rtcIntegration,
  permissionRequestIntegration,
  rolloutFlagChange,
  deployment,
}

enum CallV2ProductionPreRolloutReadinessBlocker {
  noRealLifecycleObserverYet,
  noRealRouteRegistrationYet,
  noRuntimeWiringYet,
  noBackendFirebaseConnectionYet,
  noRtcConnectionYet,
  noPermissionFlowConnectionYet,
  appCheckDebugTokenLoggingBacklogOutsideCallV2,
  chatRouteArgumentLoggingBacklogOutsideCallV2,
  noStagedRolloutPlanImplementedYet,
}

enum CallV2ProductionPreRolloutRequiredTestGroup {
  allCallV2FlutterTests,
  allCallV2DesignTests,
  allCallV2IntegrationTests,
  allCallV2UiTests,
  finalReadinessAudit,
  backendCallV2Check,
  backendDeploymentValidation,
  firestoreRulesTests,
  emulatorTests,
  fullFlutterAnalyze,
  v1SmokeRegressionChecksIfAvailable,
}

enum CallV2ProductionPreRolloutRollbackControl {
  backupBranchUnchanged,
  rolloutFalse,
  routeRegistryReturnsNullWhileFalse,
  disabledOwnerInertUntilApproved,
  emergencyKillSwitchRequiredBeforeUserRollout,
  eachWiringPhaseOneCommitAndReversible,
  noDeploymentWithoutExplicitApproval,
}

enum CallV2ProductionPreRolloutBacklogFinding {
  appCheckDebugTokenLoggingOutsideCallV2,
  chatRouteArgumentLoggingOutsideCallV2,
}

enum CallV2ProductionPreRolloutNextPhaseRecommendation {
  humanApprovalPackageOrStagedRolloutDesignOnly,
  noAutomaticRealAppWiring,
}

final class CallV2ProductionPreRolloutReadinessAudit {
  factory CallV2ProductionPreRolloutReadinessAudit({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionPreRolloutReadinessStatus> statuses,
    required List<CallV2ProductionPreRolloutBoundaryInventory>
        acceptedBoundaryInventory,
    required List<CallV2ProductionPreRolloutDisabledState> disabledState,
    required List<CallV2ProductionPreRolloutApprovalGate> approvalGates,
    required List<CallV2ProductionPreRolloutReadinessBlocker> blockers,
    required List<CallV2ProductionPreRolloutRequiredTestGroup>
        requiredTestGroups,
    required List<CallV2ProductionPreRolloutRollbackControl> rollbackControls,
    required List<CallV2ProductionPreRolloutBacklogFinding> backlogFindings,
    required List<CallV2ProductionPreRolloutNextPhaseRecommendation>
        nextPhaseRecommendation,
  }) {
    return CallV2ProductionPreRolloutReadinessAudit._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionPreRolloutReadinessStatus>.unmodifiable(statuses),
      List<CallV2ProductionPreRolloutBoundaryInventory>.unmodifiable(
        acceptedBoundaryInventory,
      ),
      List<CallV2ProductionPreRolloutDisabledState>.unmodifiable(
        disabledState,
      ),
      List<CallV2ProductionPreRolloutApprovalGate>.unmodifiable(approvalGates),
      List<CallV2ProductionPreRolloutReadinessBlocker>.unmodifiable(blockers),
      List<CallV2ProductionPreRolloutRequiredTestGroup>.unmodifiable(
        requiredTestGroups,
      ),
      List<CallV2ProductionPreRolloutRollbackControl>.unmodifiable(
        rollbackControls,
      ),
      List<CallV2ProductionPreRolloutBacklogFinding>.unmodifiable(
        backlogFindings,
      ),
      List<CallV2ProductionPreRolloutNextPhaseRecommendation>.unmodifiable(
        nextPhaseRecommendation,
      ),
    );
  }

  const CallV2ProductionPreRolloutReadinessAudit._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.statuses,
    this.acceptedBoundaryInventory,
    this.disabledState,
    this.approvalGates,
    this.blockers,
    this.requiredTestGroups,
    this.rollbackControls,
    this.backlogFindings,
    this.nextPhaseRecommendation,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionPreRolloutReadinessStatus> statuses;
  final List<CallV2ProductionPreRolloutBoundaryInventory>
      acceptedBoundaryInventory;
  final List<CallV2ProductionPreRolloutDisabledState> disabledState;
  final List<CallV2ProductionPreRolloutApprovalGate> approvalGates;
  final List<CallV2ProductionPreRolloutReadinessBlocker> blockers;
  final List<CallV2ProductionPreRolloutRequiredTestGroup> requiredTestGroups;
  final List<CallV2ProductionPreRolloutRollbackControl> rollbackControls;
  final List<CallV2ProductionPreRolloutBacklogFinding> backlogFindings;
  final List<CallV2ProductionPreRolloutNextPhaseRecommendation>
      nextPhaseRecommendation;

  bool get isReadyForUserRollout => !statuses.contains(
        CallV2ProductionPreRolloutReadinessStatus.notReadyForUserRollout,
      );

  bool get canWireRealAppWithoutApproval => !statuses.contains(
        CallV2ProductionPreRolloutReadinessStatus
            .notReadyForRealAppWiringWithoutApproval,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': statuses.length,
      'acceptedBoundaryInventoryCount': acceptedBoundaryInventory.length,
      'disabledStateCount': disabledState.length,
      'approvalGateCount': approvalGates.length,
      'blockerCount': blockers.length,
      'requiredTestGroupCount': requiredTestGroups.length,
      'rollbackControlCount': rollbackControls.length,
      'backlogFindingCount': backlogFindings.length,
      'nextPhaseRecommendationCount': nextPhaseRecommendation.length,
      'readyForUserRollout': isReadyForUserRollout,
      'canWireRealAppWithoutApproval': canWireRealAppWithoutApproval,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionPreRolloutReadinessAudit(${toSafeDebugMap()})';
  }
}

final callV2ProductionPreRolloutReadinessAudit =
    CallV2ProductionPreRolloutReadinessAudit(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  statuses: <CallV2ProductionPreRolloutReadinessStatus>[
    CallV2ProductionPreRolloutReadinessStatus.notReadyForUserRollout,
    CallV2ProductionPreRolloutReadinessStatus
        .notReadyForRealAppWiringWithoutApproval,
  ],
  acceptedBoundaryInventory: <CallV2ProductionPreRolloutBoundaryInventory>[
    CallV2ProductionPreRolloutBoundaryInventory
        .disabledProductionIntegrationOwnerExists,
    CallV2ProductionPreRolloutBoundaryInventory.productionUiContractsExist,
    CallV2ProductionPreRolloutBoundaryInventory
        .productionPresentationMappingExists,
    CallV2ProductionPreRolloutBoundaryInventory.productionViewModelsExist,
    CallV2ProductionPreRolloutBoundaryInventory.isolatedScreenShellsExist,
    CallV2ProductionPreRolloutBoundaryInventory.productionScreenFactoryExists,
    CallV2ProductionPreRolloutBoundaryInventory
        .productionRouteObjectFactoryExists,
    CallV2ProductionPreRolloutBoundaryInventory.productionRouteSinkExists,
    CallV2ProductionPreRolloutBoundaryInventory
        .typedNavigatorAdapterBoundaryExists,
    CallV2ProductionPreRolloutBoundaryInventory.uiCompositionOwnerExists,
    CallV2ProductionPreRolloutBoundaryInventory.runtimeUiBridgeExists,
    CallV2ProductionPreRolloutBoundaryInventory.lifecycleBridgeExists,
    CallV2ProductionPreRolloutBoundaryInventory.lifecycleHookupDesignExists,
    CallV2ProductionPreRolloutBoundaryInventory.permissionDeviceBridgeExists,
    CallV2ProductionPreRolloutBoundaryInventory.callStateBridgeExists,
    CallV2ProductionPreRolloutBoundaryInventory.securityPrivacyAuditExists,
  ],
  disabledState: <CallV2ProductionPreRolloutDisabledState>[
    CallV2ProductionPreRolloutDisabledState.rolloutFalse,
    CallV2ProductionPreRolloutDisabledState.routeRegistryDisabled,
    CallV2ProductionPreRolloutDisabledState.disabledRouteRegistryReturnsNull,
    CallV2ProductionPreRolloutDisabledState
        .appStartupIntegrationDisabledAndInert,
    CallV2ProductionPreRolloutDisabledState.noRealRouteRegistration,
    CallV2ProductionPreRolloutDisabledState.noProductionRuntimeStart,
    CallV2ProductionPreRolloutDisabledState.noProductionUiReachability,
    CallV2ProductionPreRolloutDisabledState
        .noBackendFirebaseRtcPermissionAccess,
    CallV2ProductionPreRolloutDisabledState.noDeployment,
  ],
  approvalGates: <CallV2ProductionPreRolloutApprovalGate>[
    CallV2ProductionPreRolloutApprovalGate.lifecycleObserverRegistration,
    CallV2ProductionPreRolloutApprovalGate.startupMainChange,
    CallV2ProductionPreRolloutApprovalGate.routeRegistryEnablement,
    CallV2ProductionPreRolloutApprovalGate.navigatorAdapterWiringToRealApp,
    CallV2ProductionPreRolloutApprovalGate.productionUiCompositionConstruction,
    CallV2ProductionPreRolloutApprovalGate.runtimeConstruction,
    CallV2ProductionPreRolloutApprovalGate.backendFirebaseIntegration,
    CallV2ProductionPreRolloutApprovalGate.rtcIntegration,
    CallV2ProductionPreRolloutApprovalGate.permissionRequestIntegration,
    CallV2ProductionPreRolloutApprovalGate.rolloutFlagChange,
    CallV2ProductionPreRolloutApprovalGate.deployment,
  ],
  blockers: <CallV2ProductionPreRolloutReadinessBlocker>[
    CallV2ProductionPreRolloutReadinessBlocker.noRealLifecycleObserverYet,
    CallV2ProductionPreRolloutReadinessBlocker.noRealRouteRegistrationYet,
    CallV2ProductionPreRolloutReadinessBlocker.noRuntimeWiringYet,
    CallV2ProductionPreRolloutReadinessBlocker.noBackendFirebaseConnectionYet,
    CallV2ProductionPreRolloutReadinessBlocker.noRtcConnectionYet,
    CallV2ProductionPreRolloutReadinessBlocker.noPermissionFlowConnectionYet,
    CallV2ProductionPreRolloutReadinessBlocker
        .appCheckDebugTokenLoggingBacklogOutsideCallV2,
    CallV2ProductionPreRolloutReadinessBlocker
        .chatRouteArgumentLoggingBacklogOutsideCallV2,
    CallV2ProductionPreRolloutReadinessBlocker
        .noStagedRolloutPlanImplementedYet,
  ],
  requiredTestGroups: <CallV2ProductionPreRolloutRequiredTestGroup>[
    CallV2ProductionPreRolloutRequiredTestGroup.allCallV2FlutterTests,
    CallV2ProductionPreRolloutRequiredTestGroup.allCallV2DesignTests,
    CallV2ProductionPreRolloutRequiredTestGroup.allCallV2IntegrationTests,
    CallV2ProductionPreRolloutRequiredTestGroup.allCallV2UiTests,
    CallV2ProductionPreRolloutRequiredTestGroup.finalReadinessAudit,
    CallV2ProductionPreRolloutRequiredTestGroup.backendCallV2Check,
    CallV2ProductionPreRolloutRequiredTestGroup.backendDeploymentValidation,
    CallV2ProductionPreRolloutRequiredTestGroup.firestoreRulesTests,
    CallV2ProductionPreRolloutRequiredTestGroup.emulatorTests,
    CallV2ProductionPreRolloutRequiredTestGroup.fullFlutterAnalyze,
    CallV2ProductionPreRolloutRequiredTestGroup
        .v1SmokeRegressionChecksIfAvailable,
  ],
  rollbackControls: <CallV2ProductionPreRolloutRollbackControl>[
    CallV2ProductionPreRolloutRollbackControl.backupBranchUnchanged,
    CallV2ProductionPreRolloutRollbackControl.rolloutFalse,
    CallV2ProductionPreRolloutRollbackControl
        .routeRegistryReturnsNullWhileFalse,
    CallV2ProductionPreRolloutRollbackControl.disabledOwnerInertUntilApproved,
    CallV2ProductionPreRolloutRollbackControl
        .emergencyKillSwitchRequiredBeforeUserRollout,
    CallV2ProductionPreRolloutRollbackControl
        .eachWiringPhaseOneCommitAndReversible,
    CallV2ProductionPreRolloutRollbackControl
        .noDeploymentWithoutExplicitApproval,
  ],
  backlogFindings: <CallV2ProductionPreRolloutBacklogFinding>[
    CallV2ProductionPreRolloutBacklogFinding
        .appCheckDebugTokenLoggingOutsideCallV2,
    CallV2ProductionPreRolloutBacklogFinding
        .chatRouteArgumentLoggingOutsideCallV2,
  ],
  nextPhaseRecommendation: <CallV2ProductionPreRolloutNextPhaseRecommendation>[
    CallV2ProductionPreRolloutNextPhaseRecommendation
        .humanApprovalPackageOrStagedRolloutDesignOnly,
    CallV2ProductionPreRolloutNextPhaseRecommendation.noAutomaticRealAppWiring,
  ],
);
