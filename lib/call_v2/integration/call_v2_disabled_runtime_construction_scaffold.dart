import 'call_v2_disabled_runtime_construction_plan_boundary.dart';
import 'call_v2_disabled_runtime_construction_plan_boundary_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionScaffoldStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  scaffoldArtifactPresent,
  metadataOnly,
  notCalledFromMain,
  planBoundaryPass,
  planBoundaryHardeningAuditPass,
  noOpWhileRolloutFalse,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
  runtimeConstructionBlocked,
  runtimeDependencyAllocationBlocked,
  runtimeDependencyPreparationBlocked,
  runtimeCompositionBlocked,
  runtimeUnavailable,
  runtimeCreationBlocked,
  runtimeStartBlocked,
  productionStartupBridgeBlocked,
  startupBridgeCallBlocked,
  backendWritesBlocked,
  backendReadsBlocked,
  firestoreListenersBlocked,
  authFunctionsAppCheckBlocked,
  rtcInitializationBlocked,
  rtcEngineCreationBlocked,
  rtcChannelJoinBlocked,
  rtcAccessConsumptionBlocked,
  permissionRequestsBlocked,
  capturePromptBlocked,
  mediaDeviceAccessBlocked,
  navigatorWiringBlocked,
  navigatorCallsBlocked,
  lifecycleRegistrationBlocked,
  asyncHandlesBlocked,
  routeResolverNotCalledWhileRolloutFalse,
  deploymentBlocked,
  configPlatformChangesBlocked,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2DisabledRuntimeConstructionScaffoldDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionScaffoldRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepNoOpWhileFalse,
  keepScaffoldMetadataOnly,
  keepScaffoldUncalled,
  keepRuntimeConstructionBlocked,
  keepRuntimeDependenciesUnallocated,
  keepRuntimeDependenciesUnprepared,
  keepRuntimeUncomposed,
  keepRuntimeUnavailable,
  keepRuntimeUnstarted,
  keepRuntimeUncreated,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DisabledRuntimeConstructionScaffold {
  factory CallV2DisabledRuntimeConstructionScaffold({
    required List<CallV2DisabledRuntimeConstructionScaffoldStatus> statuses,
    required List<CallV2DisabledRuntimeConstructionScaffoldRollback> rollback,
  }) {
    return CallV2DisabledRuntimeConstructionScaffold._(
      List<CallV2DisabledRuntimeConstructionScaffoldStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2DisabledRuntimeConstructionScaffoldRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimeConstructionScaffold._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimeConstructionScaffoldStatus> statuses;
  final List<CallV2DisabledRuntimeConstructionScaffoldRollback> rollback;

  CallV2DisabledRuntimeConstructionScaffoldDecision get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionScaffoldDecision.pass
        : CallV2DisabledRuntimeConstructionScaffoldDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsScaffoldArtifactPresent &&
      recordsMetadataOnly &&
      recordsNotCalledFromMain &&
      recordsPlanBoundaryPass &&
      recordsPlanBoundaryHardeningAuditPass &&
      recordsNoOpWhileRolloutFalse &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
      recordsRuntimeConstructionBlocked &&
      recordsRuntimeDependencyAllocationBlocked &&
      recordsRuntimeDependencyPreparationBlocked &&
      recordsRuntimeCompositionBlocked &&
      recordsRuntimeUnavailable &&
      recordsRuntimeCreationBlocked &&
      recordsRuntimeStartBlocked &&
      recordsProductionStartupBridgeBlocked &&
      recordsStartupBridgeCallBlocked &&
      recordsBackendWritesBlocked &&
      recordsBackendReadsBlocked &&
      recordsFirestoreListenersBlocked &&
      recordsAuthFunctionsAppCheckBlocked &&
      recordsRtcInitializationBlocked &&
      recordsRtcEngineCreationBlocked &&
      recordsRtcChannelJoinBlocked &&
      recordsRtcAccessConsumptionBlocked &&
      recordsPermissionRequestsBlocked &&
      recordsCapturePromptBlocked &&
      recordsMediaDeviceAccessBlocked &&
      recordsNavigatorWiringBlocked &&
      recordsNavigatorCallsBlocked &&
      recordsLifecycleRegistrationBlocked &&
      recordsAsyncHandlesBlocked &&
      recordsRouteResolverNotCalledWhileRolloutFalse &&
      recordsDeploymentBlocked &&
      recordsConfigPlatformChangesBlocked &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsHumanApproval => statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.humanApproved,
      );

  bool get recordsDeveloperOnly => statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.developerOnly,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsScaffoldArtifactPresent => statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.scaffoldArtifactPresent,
      );

  bool get recordsMetadataOnly => statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.metadataOnly,
      );

  bool get recordsNotCalledFromMain => statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.notCalledFromMain,
      );

  bool get recordsPlanBoundaryPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.planBoundaryPass,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsHumanApproval &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsDeveloperOnly &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsRolloutFalse &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeConstructionPlanBoundaryPresent;

  bool get recordsPlanBoundaryHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .planBoundaryHardeningAuditPass,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit
          .recordsAuditArtifactPresent &&
      callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit
          .recordsPlanBoundaryExists &&
      callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit
          .recordsRolloutFalse;

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeDependencyAllocationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .runtimeDependencyAllocationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeDependencyAllocationBlocked;

  bool get recordsRuntimeDependencyPreparationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .runtimeDependencyPreparationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeDependencyPreparationBlocked;

  bool get recordsRuntimeCompositionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .runtimeCompositionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeCompositionBlocked;

  bool get recordsRuntimeUnavailable =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeUnavailable,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsRuntimeUnavailable;

  bool get recordsRuntimeCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeCreationBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeStartBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsRuntimeStartBlocked;

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.backendWritesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.backendReadsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .firestoreListenersBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .rtcInitializationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.rtcChannelJoinBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcChannelJoinBlocked;

  bool get recordsRtcAccessConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .rtcAccessConsumptionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .permissionRequestsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.capturePromptBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.navigatorWiringBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.navigatorCallsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.asyncHandlesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.deploymentBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback
            .keepScaffoldMetadataOnly,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.keepScaffoldUncalled,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback
            .keepRuntimeConstructionBlocked,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback
            .keepRuntimeDependenciesUnallocated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback
            .keepRuntimeDependenciesUnprepared,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.keepRuntimeUncomposed,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldStatus.v1Protected,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'artifactPresent': recordsScaffoldArtifactPresent,
      'metadataOnly': recordsMetadataOnly,
      'mainCalled': false,
      'planPass': recordsPlanBoundaryPass,
      'planAuditPass': recordsPlanBoundaryHardeningAuditPass,
      'noOpWhileFalse': recordsNoOpWhileRolloutFalse,
      'publicRoutesReachable': false,
      'screenExposureBlocked': recordsCallV2ScreenExposureBlocked,
      'runtimeConstructed': false,
      'runtimeDependenciesAllocated': false,
      'runtimeDependenciesPrepared': false,
      'runtimeComposed': false,
      'runtimeAvailable': false,
      'runtimeCreated': false,
      'runtimeStarted': false,
      'productionBridgeCalled': false,
      'startupBridgeCalled': false,
      'backendWrites': false,
      'backendReads': false,
      'firestoreListeners': false,
      'authFunctionsAppCheck': false,
      'rtcInitialized': false,
      'rtcEngineCreated': false,
      'rtcJoined': false,
      'rtcAccessConsumed': false,
      'permissionsRequested': false,
      'capturePrompted': false,
      'mediaDeviceAccess': false,
      'navWired': false,
      'navCalled': false,
      'lifecycleRegistered': false,
      'asyncHandlesOpened': false,
      'resolverCalledWhileFalse': false,
      'deploymentChanged': false,
      'configPlatformChanged': false,
      'rollbackOneCommit': recordsRollbackOneCommit,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2DisabledRuntimeConstructionScaffold(${toSafeDebugMap()})';
  }
}

final callV2DisabledRuntimeConstructionScaffold =
    CallV2DisabledRuntimeConstructionScaffold(
  statuses: <CallV2DisabledRuntimeConstructionScaffoldStatus>[
    CallV2DisabledRuntimeConstructionScaffoldStatus.humanApproved,
    CallV2DisabledRuntimeConstructionScaffoldStatus.developerOnly,
    CallV2DisabledRuntimeConstructionScaffoldStatus.rolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldStatus.scaffoldArtifactPresent,
    CallV2DisabledRuntimeConstructionScaffoldStatus.metadataOnly,
    CallV2DisabledRuntimeConstructionScaffoldStatus.notCalledFromMain,
    CallV2DisabledRuntimeConstructionScaffoldStatus.planBoundaryPass,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .planBoundaryHardeningAuditPass,
    CallV2DisabledRuntimeConstructionScaffoldStatus.noOpWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .runtimeDependencyAllocationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .runtimeDependencyPreparationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeCompositionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeUnavailable,
    CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeCreationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.backendWritesBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.backendReadsBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.rtcAccessConsumptionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.capturePromptBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldStatus.deploymentBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionScaffoldStatus.rollbackOneCommit,
    CallV2DisabledRuntimeConstructionScaffoldStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionScaffoldRollback>[
    CallV2DisabledRuntimeConstructionScaffoldRollback.oneCommitRevert,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepRolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepNoOpWhileFalse,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepScaffoldMetadataOnly,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepScaffoldUncalled,
    CallV2DisabledRuntimeConstructionScaffoldRollback
        .keepRuntimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldRollback
        .keepRuntimeDependenciesUnallocated,
    CallV2DisabledRuntimeConstructionScaffoldRollback
        .keepRuntimeDependenciesUnprepared,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepRuntimeUncomposed,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionScaffoldRollback.keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionScaffoldRollback.noDeploymentRequired,
    CallV2DisabledRuntimeConstructionScaffoldRollback.noConfigChanges,
    CallV2DisabledRuntimeConstructionScaffoldRollback.v1Unaffected,
  ],
);
