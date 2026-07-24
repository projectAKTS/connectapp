import 'call_v2_disabled_runtime_construction_gate.dart';
import 'call_v2_disabled_runtime_construction_gate_hardening_audit.dart';
import 'call_v2_disabled_runtime_construction_plan_boundary.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus {
  auditArtifactPresent,
  planBoundaryExists,
  planBoundaryDecisionPass,
  executorInert,
  rolloutFalse,
  mainDartImportSingle,
  mainDartExecutorSingle,
  mainDartExecutionOrder,
  resolverGatedBehindRollout,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
  runtimeConstructionBlocked,
  runtimeDependencyAllocationBlocked,
  runtimeDependencyPreparationBlocked,
  runtimeCompositionBlocked,
  runtimeStartBlocked,
  runtimeUnavailable,
  runtimeCreationBlocked,
  productionStartupBridgeBlocked,
  startupBridgeCallBlocked,
  backendWritesBlocked,
  backendReadsBlocked,
  firestoreListenersBlocked,
  authFunctionsAppCheckBlocked,
  rtcInitializationBlocked,
  rtcEngineCreationBlocked,
  rtcChannelJoinBlocked,
  rtcTokenChannelConsumptionBlocked,
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

enum CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepNoOpWhileFalse,
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

final class CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit {
  factory CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit({
    required List<
            CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus>
        statuses,
    required List<
            CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback>
        rollback,
  }) {
    return CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit._(
      List<
          CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<
          CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus>
      statuses;
  final List<CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback>
      rollback;

  CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditDecision
      get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditDecision
            .pass
        : CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditDecision
            .blocked;
  }

  bool get passes =>
      recordsAuditArtifactPresent &&
      recordsPlanBoundaryExists &&
      recordsPlanBoundaryDecisionPass &&
      recordsExecutorInert &&
      recordsRolloutFalse &&
      recordsMainDartImportSingle &&
      recordsMainDartExecutorSingle &&
      recordsMainDartExecutionOrder &&
      recordsResolverGatedBehindRollout &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
      recordsRuntimeConstructionBlocked &&
      recordsRuntimeDependencyAllocationBlocked &&
      recordsRuntimeDependencyPreparationBlocked &&
      recordsRuntimeCompositionBlocked &&
      recordsRuntimeStartBlocked &&
      recordsRuntimeUnavailable &&
      recordsRuntimeCreationBlocked &&
      recordsProductionStartupBridgeBlocked &&
      recordsStartupBridgeCallBlocked &&
      recordsBackendWritesBlocked &&
      recordsBackendReadsBlocked &&
      recordsFirestoreListenersBlocked &&
      recordsAuthFunctionsAppCheckBlocked &&
      recordsRtcInitializationBlocked &&
      recordsRtcEngineCreationBlocked &&
      recordsRtcChannelJoinBlocked &&
      recordsRtcTokenChannelConsumptionBlocked &&
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

  bool get recordsAuditArtifactPresent => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .auditArtifactPresent,
      );

  bool get recordsPlanBoundaryExists =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .planBoundaryExists,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.statuses.isNotEmpty &&
      callV2DisabledRuntimeConstructionPlanBoundary.rollback.isNotEmpty;

  bool get recordsPlanBoundaryDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .planBoundaryDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.decision ==
          CallV2DisabledRuntimeConstructionPlanBoundaryDecision.pass &&
      callV2DisabledRuntimeConstructionGate.decision ==
          CallV2DisabledRuntimeConstructionGateDecision.pass &&
      callV2DisabledRuntimeConstructionGateHardeningAudit.decision ==
          CallV2DisabledRuntimeConstructionGateHardeningAuditDecision.pass;

  bool get recordsExecutorInert =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .executorInert,
      ) &&
      identical(
        executeCallV2DisabledRuntimeConstructionPlanBoundarySafely(),
        callV2DisabledRuntimeConstructionPlanBoundary,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsMainDartImportSingle => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .mainDartImportSingle,
      );

  bool get recordsMainDartExecutorSingle => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .mainDartExecutorSingle,
      );

  bool get recordsMainDartExecutionOrder => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .mainDartExecutionOrder,
      );

  bool get recordsResolverGatedBehindRollout => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .resolverGatedBehindRollout,
      );

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeDependencyAllocationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .runtimeDependencyAllocationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeDependencyAllocationBlocked;

  bool get recordsRuntimeDependencyPreparationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .runtimeDependencyPreparationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeDependencyPreparationBlocked;

  bool get recordsRuntimeCompositionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .runtimeCompositionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeCompositionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .runtimeStartBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsRuntimeStartBlocked;

  bool get recordsRuntimeUnavailable =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .runtimeUnavailable,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsRuntimeUnavailable;

  bool get recordsRuntimeCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .runtimeCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRuntimeCreationBlocked;

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .backendWritesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .backendReadsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .firestoreListenersBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .rtcInitializationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .rtcChannelJoinBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .permissionRequestsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .capturePromptBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .navigatorWiringBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .navigatorCallsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .asyncHandlesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .deploymentBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRuntimeConstructionBlocked,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRuntimeDependenciesUnallocated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRuntimeDependenciesUnprepared,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRuntimeUncomposed,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
            .v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
            .v1Protected,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'artifactPresent': recordsAuditArtifactPresent,
      'planBoundaryPass': recordsPlanBoundaryDecisionPass,
      'executorInert': recordsExecutorInert,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'importSingle': recordsMainDartImportSingle,
      'executorSingle': recordsMainDartExecutorSingle,
      'orderStable': recordsMainDartExecutionOrder,
      'resolverGated': recordsResolverGatedBehindRollout,
      'publicRoutesReachable': false,
      'screenExposureBlocked': recordsCallV2ScreenExposureBlocked,
      'runtimeConstructed': false,
      'runtimeDependenciesAllocated': false,
      'runtimeDependenciesPrepared': false,
      'runtimeComposed': false,
      'runtimeStarted': false,
      'runtimeAvailable': false,
      'runtimeCreated': false,
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
    return 'CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit =
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit(
  statuses: <CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus>[
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .auditArtifactPresent,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .planBoundaryExists,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .planBoundaryDecisionPass,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .executorInert,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .rolloutFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .mainDartImportSingle,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .mainDartExecutorSingle,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .mainDartExecutionOrder,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .resolverGatedBehindRollout,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .runtimeDependencyAllocationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .runtimeDependencyPreparationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .runtimeCompositionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .runtimeUnavailable,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .runtimeCreationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .backendWritesBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .backendReadsBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .capturePromptBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .deploymentBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .rollbackOneCommit,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditStatus
        .v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback>[
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .oneCommitRevert,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRolloutFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepNoOpWhileFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRuntimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRuntimeDependenciesUnallocated,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRuntimeDependenciesUnprepared,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRuntimeUncomposed,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .noDeploymentRequired,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback
        .noConfigChanges,
    CallV2DisabledRuntimeConstructionPlanBoundaryHardeningRollback.v1Unaffected,
  ],
);
