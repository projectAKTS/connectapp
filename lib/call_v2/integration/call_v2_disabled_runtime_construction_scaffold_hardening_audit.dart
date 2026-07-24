import 'call_v2_disabled_runtime_construction_plan_boundary.dart';
import 'call_v2_disabled_runtime_construction_plan_boundary_hardening_audit.dart';
import 'call_v2_disabled_runtime_construction_scaffold.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus {
  auditArtifactPresent,
  scaffoldExists,
  scaffoldDecisionPass,
  metadataOnly,
  scaffoldNotImportedByMain,
  scaffoldNotCalledFromMain,
  rolloutFalse,
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

enum CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionScaffoldHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
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

final class CallV2DisabledRuntimeConstructionScaffoldHardeningAudit {
  factory CallV2DisabledRuntimeConstructionScaffoldHardeningAudit({
    required List<CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus>
        statuses,
    required List<CallV2DisabledRuntimeConstructionScaffoldHardeningRollback>
        rollback,
  }) {
    return CallV2DisabledRuntimeConstructionScaffoldHardeningAudit._(
      List<CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus>.unmodifiable(
          statuses),
      List<CallV2DisabledRuntimeConstructionScaffoldHardeningRollback>.unmodifiable(
          rollback),
    );
  }

  const CallV2DisabledRuntimeConstructionScaffoldHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus>
      statuses;
  final List<CallV2DisabledRuntimeConstructionScaffoldHardeningRollback>
      rollback;

  CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision.pass
        : CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision
            .blocked;
  }

  bool get passes =>
      recordsAuditArtifactPresent &&
      recordsScaffoldExists &&
      recordsScaffoldDecisionPass &&
      recordsMetadataOnly &&
      recordsScaffoldNotImportedByMain &&
      recordsScaffoldNotCalledFromMain &&
      recordsRolloutFalse &&
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

  bool get recordsAuditArtifactPresent => statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .auditArtifactPresent,
      );

  bool get recordsScaffoldExists =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .scaffoldExists,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.statuses.isNotEmpty &&
      callV2DisabledRuntimeConstructionScaffold.rollback.isNotEmpty;

  bool get recordsScaffoldDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .scaffoldDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.decision ==
          CallV2DisabledRuntimeConstructionScaffoldDecision.pass;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .metadataOnly,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsMetadataOnly;

  bool get recordsScaffoldNotImportedByMain =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .scaffoldNotImportedByMain,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsNotCalledFromMain;

  bool get recordsScaffoldNotCalledFromMain =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .scaffoldNotCalledFromMain,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsNotCalledFromMain;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsPlanBoundaryPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .planBoundaryPass,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundary.decision ==
          CallV2DisabledRuntimeConstructionPlanBoundaryDecision.pass;

  bool get recordsPlanBoundaryHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .planBoundaryHardeningAuditPass,
      ) &&
      callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit.decision ==
          CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditDecision
              .pass;

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionScaffold.recordsNoOpWhileRolloutFalse;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeDependencyAllocationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .runtimeDependencyAllocationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeDependencyAllocationBlocked;

  bool get recordsRuntimeDependencyPreparationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .runtimeDependencyPreparationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeDependencyPreparationBlocked;

  bool get recordsRuntimeCompositionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .runtimeCompositionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeCompositionBlocked;

  bool get recordsRuntimeUnavailable =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .runtimeUnavailable,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRuntimeUnavailable;

  bool get recordsRuntimeCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .runtimeCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRuntimeCreationBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .runtimeStartBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRuntimeStartBlocked;

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .backendWritesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .backendReadsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .firestoreListenersBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .rtcInitializationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .rtcChannelJoinBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRtcChannelJoinBlocked;

  bool get recordsRtcAccessConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .rtcAccessConsumptionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRtcAccessConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .permissionRequestsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .capturePromptBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .navigatorWiringBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .navigatorCallsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .asyncHandlesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .deploymentBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepScaffoldMetadataOnly,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepScaffoldUncalled,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRuntimeConstructionBlocked,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRuntimeDependenciesUnallocated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRuntimeDependenciesUnprepared,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRuntimeUncomposed,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
            .noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
            .v1Protected,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'artifactPresent': recordsAuditArtifactPresent,
      'scaffoldPresent': recordsScaffoldExists,
      'scaffoldPass': recordsScaffoldDecisionPass,
      'metadataOnly': recordsMetadataOnly,
      'mainImport': false,
      'mainCall': false,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
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
    return 'CallV2DisabledRuntimeConstructionScaffoldHardeningAudit'
        '(${toSafeDebugMap()})';
  }
}

final callV2DisabledRuntimeConstructionScaffoldHardeningAudit =
    CallV2DisabledRuntimeConstructionScaffoldHardeningAudit(
  statuses: <CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus>[
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .auditArtifactPresent,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .scaffoldExists,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .scaffoldDecisionPass,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus.metadataOnly,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .scaffoldNotImportedByMain,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .scaffoldNotCalledFromMain,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus.rolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .planBoundaryPass,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .planBoundaryHardeningAuditPass,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .noOpWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .runtimeDependencyAllocationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .runtimeDependencyPreparationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .runtimeCompositionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .runtimeUnavailable,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .runtimeCreationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .backendWritesBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .backendReadsBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .rtcAccessConsumptionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .capturePromptBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .deploymentBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus
        .rollbackOneCommit,
    CallV2DisabledRuntimeConstructionScaffoldHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionScaffoldHardeningRollback>[
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback.oneCommitRevert,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback.keepRolloutFalse,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepScaffoldMetadataOnly,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepScaffoldUncalled,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepRuntimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepRuntimeDependenciesUnallocated,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepRuntimeDependenciesUnprepared,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepRuntimeUncomposed,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback
        .noDeploymentRequired,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback.noConfigChanges,
    CallV2DisabledRuntimeConstructionScaffoldHardeningRollback.v1Unaffected,
  ],
);
