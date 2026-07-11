enum CallV2ProductionStagedRolloutStatus {
  rolloutFlagFalse,
  callV2Unreachable,
  routeRegistryDisabled,
  disabledOwnerInert,
  runtimeNotStarted,
  backendFirebaseRtcPermissionsDisconnected,
  deploymentNotAuthorized,
  noPublicRolloutApproved,
}

enum CallV2ProductionStagedRolloutStage {
  keepIsolatedNoRollout,
  developerOnlyDesignReview,
  developerOnlyRealWiringPrAfterExplicitApproval,
  developerOnlyLocalInternalTestGate,
  smallInternalAllowlistGate,
  audioOnlyLimitedCohortGate,
  videoLimitedCohortGate,
  percentageRolloutGate,
  broaderRolloutGate,
  postRolloutMonitoringGate,
}

enum CallV2ProductionStagedRolloutGate {
  explicitHumanApproval,
  exactScopeSelected,
  emergencyKillSwitchDefined,
  rollbackPlanAccepted,
  backupVerifiedUnchanged,
  rolloutRemainsFalseUntilApproved,
  noProductionServiceContactWithoutApproval,
  allCallV2TestsPassed,
  backendRulesEmulatorChecksPassed,
  securityPrivacyAuditPassed,
  preRolloutReadinessAccepted,
  v1SmokeRegressionPlanAccepted,
}

enum CallV2ProductionStagedRolloutBlocker {
  noRealLifecycleObserverYet,
  noRouteRegistrationYet,
  noRuntimeWiringYet,
  noBackendFirebaseConnectionYet,
  noRtcConnectionYet,
  noPermissionFlowConnectionYet,
  noKillSwitchImplementationYet,
  noAllowlistImplementationYet,
  noProductionMonitoringPlanYet,
  appCheckDebugTokenLoggingBacklogOutsideCallV2,
  chatRouteLoggingBacklogOutsideCallV2,
}

enum CallV2ProductionStagedRolloutRollbackControl {
  oneCommitPerWiringPhase,
  rolloutFalseByDefault,
  routeRegistryReturnsNullWhileFalse,
  killSwitchCanDisableImmediately,
  disableOrRemoveNewWiringInOneCommit,
  noDeploymentWithoutApproval,
  backupBranchProtected,
  v1Unaffected,
}

enum CallV2ProductionStagedRolloutMonitoringRequirement {
  noSensitiveIdsTokensChannelsCredentialsInLogs,
  controlledEventCountersOnly,
  crashErrorRateWatch,
  callStartConnectEndFailureAggregateCountersOnly,
  noRawBackendPayloads,
  noRouteArgumentLogging,
  noDebugTokenLeakage,
  manualReviewBeforeAnalyticsOrLogging,
}

enum CallV2ProductionStagedRolloutV1Protection {
  noV1RouteChanges,
  noV1CallFlowChanges,
  noChatRouteBehaviorChangesInRolloutDesign,
  v1SmokeTestsBeforeAndAfterWiring,
  immediateRollbackIfV1RegressionDetected,
}

enum CallV2ProductionStagedRolloutApprovalRequirement {
  realWiringRequiresSeparateExplicitHumanApproval,
  publicUserRolloutRequiresDeveloperAndAllowlistSuccess,
  productionServiceContactRequiresSeparateApproval,
  emergencyKillSwitchRequiredBeforeUserExposure,
  allowlistRequiredBeforeUserExposure,
  everyFutureStageOneCommitAndReversible,
}

enum CallV2ProductionStagedRolloutRecommendation {
  noRealWiringYet,
  prepareExplicitHumanDecisionForOneDesignOnlyPackage,
  prepareDeveloperOnlyWiringPrOnlyAfterApproval,
}

final class CallV2ProductionStagedRolloutDesign {
  factory CallV2ProductionStagedRolloutDesign({
    required String protectedBackupBranch,
    required String protectedBackupSha,
    required List<CallV2ProductionStagedRolloutStatus> currentStatus,
    required List<CallV2ProductionStagedRolloutStage> rolloutStages,
    required List<CallV2ProductionStagedRolloutGate> gatesBeforeAnyWiring,
    required List<CallV2ProductionStagedRolloutBlocker> blockers,
    required List<CallV2ProductionStagedRolloutRollbackControl>
        rollbackControls,
    required List<CallV2ProductionStagedRolloutMonitoringRequirement>
        monitoringRequirements,
    required List<CallV2ProductionStagedRolloutV1Protection> v1Protections,
    required List<CallV2ProductionStagedRolloutApprovalRequirement>
        approvalRequirements,
    required List<CallV2ProductionStagedRolloutRecommendation>
        recommendedNextSteps,
  }) {
    return CallV2ProductionStagedRolloutDesign._(
      protectedBackupBranch,
      protectedBackupSha,
      List<CallV2ProductionStagedRolloutStatus>.unmodifiable(currentStatus),
      List<CallV2ProductionStagedRolloutStage>.unmodifiable(rolloutStages),
      List<CallV2ProductionStagedRolloutGate>.unmodifiable(
        gatesBeforeAnyWiring,
      ),
      List<CallV2ProductionStagedRolloutBlocker>.unmodifiable(blockers),
      List<CallV2ProductionStagedRolloutRollbackControl>.unmodifiable(
        rollbackControls,
      ),
      List<CallV2ProductionStagedRolloutMonitoringRequirement>.unmodifiable(
        monitoringRequirements,
      ),
      List<CallV2ProductionStagedRolloutV1Protection>.unmodifiable(
        v1Protections,
      ),
      List<CallV2ProductionStagedRolloutApprovalRequirement>.unmodifiable(
        approvalRequirements,
      ),
      List<CallV2ProductionStagedRolloutRecommendation>.unmodifiable(
        recommendedNextSteps,
      ),
    );
  }

  const CallV2ProductionStagedRolloutDesign._(
    this.protectedBackupBranch,
    this.protectedBackupSha,
    this.currentStatus,
    this.rolloutStages,
    this.gatesBeforeAnyWiring,
    this.blockers,
    this.rollbackControls,
    this.monitoringRequirements,
    this.v1Protections,
    this.approvalRequirements,
    this.recommendedNextSteps,
  );

  final String protectedBackupBranch;
  final String protectedBackupSha;
  final List<CallV2ProductionStagedRolloutStatus> currentStatus;
  final List<CallV2ProductionStagedRolloutStage> rolloutStages;
  final List<CallV2ProductionStagedRolloutGate> gatesBeforeAnyWiring;
  final List<CallV2ProductionStagedRolloutBlocker> blockers;
  final List<CallV2ProductionStagedRolloutRollbackControl> rollbackControls;
  final List<CallV2ProductionStagedRolloutMonitoringRequirement>
      monitoringRequirements;
  final List<CallV2ProductionStagedRolloutV1Protection> v1Protections;
  final List<CallV2ProductionStagedRolloutApprovalRequirement>
      approvalRequirements;
  final List<CallV2ProductionStagedRolloutRecommendation> recommendedNextSteps;

  bool get isRolloutEnabled => !currentStatus.contains(
        CallV2ProductionStagedRolloutStatus.rolloutFlagFalse,
      );

  bool get isCallV2Reachable => !currentStatus.contains(
        CallV2ProductionStagedRolloutStatus.callV2Unreachable,
      );

  bool get isDeploymentAuthorized => !currentStatus.contains(
        CallV2ProductionStagedRolloutStatus.deploymentNotAuthorized,
      );

  bool get hasPublicRolloutApproval => !currentStatus.contains(
        CallV2ProductionStagedRolloutStatus.noPublicRolloutApproved,
      );

  bool get stagesAreDesignOnly => approvalRequirements.contains(
        CallV2ProductionStagedRolloutApprovalRequirement
            .realWiringRequiresSeparateExplicitHumanApproval,
      );

  bool get allowsAutomaticWiring => !approvalRequirements.contains(
        CallV2ProductionStagedRolloutApprovalRequirement
            .realWiringRequiresSeparateExplicitHumanApproval,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'currentStatusCount': currentStatus.length,
      'rolloutStageCount': rolloutStages.length,
      'gateCount': gatesBeforeAnyWiring.length,
      'blockerCount': blockers.length,
      'rollbackControlCount': rollbackControls.length,
      'monitoringRequirementCount': monitoringRequirements.length,
      'v1ProtectionCount': v1Protections.length,
      'approvalRequirementCount': approvalRequirements.length,
      'recommendedNextStepCount': recommendedNextSteps.length,
      'rolloutEnabled': isRolloutEnabled,
      'callV2Reachable': isCallV2Reachable,
      'deploymentAuthorized': isDeploymentAuthorized,
      'publicRolloutApproved': hasPublicRolloutApproval,
      'stagesAreDesignOnly': stagesAreDesignOnly,
      'allowsAutomaticWiring': allowsAutomaticWiring,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionStagedRolloutDesign(${toSafeDebugMap()})';
  }
}

final callV2ProductionStagedRolloutDesign = CallV2ProductionStagedRolloutDesign(
  protectedBackupBranch: 'backup/call-v2-pre-phase6b-2026-07-04',
  protectedBackupSha: '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
  currentStatus: <CallV2ProductionStagedRolloutStatus>[
    CallV2ProductionStagedRolloutStatus.rolloutFlagFalse,
    CallV2ProductionStagedRolloutStatus.callV2Unreachable,
    CallV2ProductionStagedRolloutStatus.routeRegistryDisabled,
    CallV2ProductionStagedRolloutStatus.disabledOwnerInert,
    CallV2ProductionStagedRolloutStatus.runtimeNotStarted,
    CallV2ProductionStagedRolloutStatus
        .backendFirebaseRtcPermissionsDisconnected,
    CallV2ProductionStagedRolloutStatus.deploymentNotAuthorized,
    CallV2ProductionStagedRolloutStatus.noPublicRolloutApproved,
  ],
  rolloutStages: <CallV2ProductionStagedRolloutStage>[
    CallV2ProductionStagedRolloutStage.keepIsolatedNoRollout,
    CallV2ProductionStagedRolloutStage.developerOnlyDesignReview,
    CallV2ProductionStagedRolloutStage
        .developerOnlyRealWiringPrAfterExplicitApproval,
    CallV2ProductionStagedRolloutStage.developerOnlyLocalInternalTestGate,
    CallV2ProductionStagedRolloutStage.smallInternalAllowlistGate,
    CallV2ProductionStagedRolloutStage.audioOnlyLimitedCohortGate,
    CallV2ProductionStagedRolloutStage.videoLimitedCohortGate,
    CallV2ProductionStagedRolloutStage.percentageRolloutGate,
    CallV2ProductionStagedRolloutStage.broaderRolloutGate,
    CallV2ProductionStagedRolloutStage.postRolloutMonitoringGate,
  ],
  gatesBeforeAnyWiring: <CallV2ProductionStagedRolloutGate>[
    CallV2ProductionStagedRolloutGate.explicitHumanApproval,
    CallV2ProductionStagedRolloutGate.exactScopeSelected,
    CallV2ProductionStagedRolloutGate.emergencyKillSwitchDefined,
    CallV2ProductionStagedRolloutGate.rollbackPlanAccepted,
    CallV2ProductionStagedRolloutGate.backupVerifiedUnchanged,
    CallV2ProductionStagedRolloutGate.rolloutRemainsFalseUntilApproved,
    CallV2ProductionStagedRolloutGate.noProductionServiceContactWithoutApproval,
    CallV2ProductionStagedRolloutGate.allCallV2TestsPassed,
    CallV2ProductionStagedRolloutGate.backendRulesEmulatorChecksPassed,
    CallV2ProductionStagedRolloutGate.securityPrivacyAuditPassed,
    CallV2ProductionStagedRolloutGate.preRolloutReadinessAccepted,
    CallV2ProductionStagedRolloutGate.v1SmokeRegressionPlanAccepted,
  ],
  blockers: <CallV2ProductionStagedRolloutBlocker>[
    CallV2ProductionStagedRolloutBlocker.noRealLifecycleObserverYet,
    CallV2ProductionStagedRolloutBlocker.noRouteRegistrationYet,
    CallV2ProductionStagedRolloutBlocker.noRuntimeWiringYet,
    CallV2ProductionStagedRolloutBlocker.noBackendFirebaseConnectionYet,
    CallV2ProductionStagedRolloutBlocker.noRtcConnectionYet,
    CallV2ProductionStagedRolloutBlocker.noPermissionFlowConnectionYet,
    CallV2ProductionStagedRolloutBlocker.noKillSwitchImplementationYet,
    CallV2ProductionStagedRolloutBlocker.noAllowlistImplementationYet,
    CallV2ProductionStagedRolloutBlocker.noProductionMonitoringPlanYet,
    CallV2ProductionStagedRolloutBlocker
        .appCheckDebugTokenLoggingBacklogOutsideCallV2,
    CallV2ProductionStagedRolloutBlocker.chatRouteLoggingBacklogOutsideCallV2,
  ],
  rollbackControls: <CallV2ProductionStagedRolloutRollbackControl>[
    CallV2ProductionStagedRolloutRollbackControl.oneCommitPerWiringPhase,
    CallV2ProductionStagedRolloutRollbackControl.rolloutFalseByDefault,
    CallV2ProductionStagedRolloutRollbackControl
        .routeRegistryReturnsNullWhileFalse,
    CallV2ProductionStagedRolloutRollbackControl
        .killSwitchCanDisableImmediately,
    CallV2ProductionStagedRolloutRollbackControl
        .disableOrRemoveNewWiringInOneCommit,
    CallV2ProductionStagedRolloutRollbackControl.noDeploymentWithoutApproval,
    CallV2ProductionStagedRolloutRollbackControl.backupBranchProtected,
    CallV2ProductionStagedRolloutRollbackControl.v1Unaffected,
  ],
  monitoringRequirements: <CallV2ProductionStagedRolloutMonitoringRequirement>[
    CallV2ProductionStagedRolloutMonitoringRequirement
        .noSensitiveIdsTokensChannelsCredentialsInLogs,
    CallV2ProductionStagedRolloutMonitoringRequirement
        .controlledEventCountersOnly,
    CallV2ProductionStagedRolloutMonitoringRequirement.crashErrorRateWatch,
    CallV2ProductionStagedRolloutMonitoringRequirement
        .callStartConnectEndFailureAggregateCountersOnly,
    CallV2ProductionStagedRolloutMonitoringRequirement.noRawBackendPayloads,
    CallV2ProductionStagedRolloutMonitoringRequirement.noRouteArgumentLogging,
    CallV2ProductionStagedRolloutMonitoringRequirement.noDebugTokenLeakage,
    CallV2ProductionStagedRolloutMonitoringRequirement
        .manualReviewBeforeAnalyticsOrLogging,
  ],
  v1Protections: <CallV2ProductionStagedRolloutV1Protection>[
    CallV2ProductionStagedRolloutV1Protection.noV1RouteChanges,
    CallV2ProductionStagedRolloutV1Protection.noV1CallFlowChanges,
    CallV2ProductionStagedRolloutV1Protection
        .noChatRouteBehaviorChangesInRolloutDesign,
    CallV2ProductionStagedRolloutV1Protection.v1SmokeTestsBeforeAndAfterWiring,
    CallV2ProductionStagedRolloutV1Protection
        .immediateRollbackIfV1RegressionDetected,
  ],
  approvalRequirements: <CallV2ProductionStagedRolloutApprovalRequirement>[
    CallV2ProductionStagedRolloutApprovalRequirement
        .realWiringRequiresSeparateExplicitHumanApproval,
    CallV2ProductionStagedRolloutApprovalRequirement
        .publicUserRolloutRequiresDeveloperAndAllowlistSuccess,
    CallV2ProductionStagedRolloutApprovalRequirement
        .productionServiceContactRequiresSeparateApproval,
    CallV2ProductionStagedRolloutApprovalRequirement
        .emergencyKillSwitchRequiredBeforeUserExposure,
    CallV2ProductionStagedRolloutApprovalRequirement
        .allowlistRequiredBeforeUserExposure,
    CallV2ProductionStagedRolloutApprovalRequirement
        .everyFutureStageOneCommitAndReversible,
  ],
  recommendedNextSteps: <CallV2ProductionStagedRolloutRecommendation>[
    CallV2ProductionStagedRolloutRecommendation.noRealWiringYet,
    CallV2ProductionStagedRolloutRecommendation
        .prepareExplicitHumanDecisionForOneDesignOnlyPackage,
    CallV2ProductionStagedRolloutRecommendation
        .prepareDeveloperOnlyWiringPrOnlyAfterApproval,
  ],
);
