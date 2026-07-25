import 'call_v2_disabled_runtime_construction_planner_interface.dart';
import 'call_v2_disabled_runtime_construction_scaffold.dart';
import 'call_v2_disabled_runtime_construction_scaffold_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus {
  auditArtifactPresent,
  plannerInterfaceExists,
  plannerInterfaceDecisionPass,
  metadataOnly,
  plannerInterfaceNotImportedByMain,
  plannerInterfaceNotCalledFromMain,
  rolloutFalse,
  scaffoldDecisionPass,
  scaffoldHardeningAuditDecisionPass,
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

enum CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepPlannerInterfaceMetadataOnly,
  keepPlannerInterfaceUnwired,
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

final class CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAudit {
  factory CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAudit({
    required List<
            CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus>
        statuses,
    required List<
            CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback>
        rollback,
  }) {
    return CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAudit._(
      List<
          CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<
          CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<
          CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus>
      statuses;
  final List<CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback>
      rollback;

  CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditDecision
      get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditDecision
            .pass
        : CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditDecision
            .blocked;
  }

  bool get passes =>
      recordsAuditArtifactPresent &&
      recordsPlannerInterfaceExists &&
      recordsPlannerInterfaceDecisionPass &&
      recordsMetadataOnly &&
      recordsPlannerInterfaceNotImportedByMain &&
      recordsPlannerInterfaceNotCalledFromMain &&
      recordsRolloutFalse &&
      recordsScaffoldDecisionPass &&
      recordsScaffoldHardeningAuditDecisionPass &&
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
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .auditArtifactPresent,
      );

  bool get recordsPlannerInterfaceExists =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .plannerInterfaceExists,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface.statuses.isNotEmpty &&
      callV2DisabledRuntimeConstructionPlannerInterface.rollback.isNotEmpty;

  bool get recordsPlannerInterfaceDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .plannerInterfaceDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface.decision ==
          CallV2DisabledRuntimeConstructionPlannerInterfaceDecision.pass;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .metadataOnly,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface.recordsMetadataOnly;

  bool get recordsPlannerInterfaceNotImportedByMain =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .plannerInterfaceNotImportedByMain,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsNotImportedByMain;

  bool get recordsPlannerInterfaceNotCalledFromMain =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .plannerInterfaceNotCalledFromMain,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsNotCalledFromMain;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsScaffoldDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .scaffoldDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.decision ==
          CallV2DisabledRuntimeConstructionScaffoldDecision.pass;

  bool get recordsScaffoldHardeningAuditDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .scaffoldHardeningAuditDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionScaffoldHardeningAudit.decision ==
          CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision.pass;

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsNoOpWhileRolloutFalse;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeDependencyAllocationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .runtimeDependencyAllocationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRuntimeDependencyAllocationBlocked;

  bool get recordsRuntimeDependencyPreparationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .runtimeDependencyPreparationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRuntimeDependencyPreparationBlocked;

  bool get recordsRuntimeCompositionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .runtimeCompositionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRuntimeCompositionBlocked;

  bool get recordsRuntimeUnavailable =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .runtimeUnavailable,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRuntimeUnavailable;

  bool get recordsRuntimeCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .runtimeCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRuntimeCreationBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .runtimeStartBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRuntimeStartBlocked;

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .backendWritesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .backendReadsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .firestoreListenersBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .rtcInitializationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .rtcChannelJoinBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRtcChannelJoinBlocked;

  bool get recordsRtcAccessConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .rtcAccessConsumptionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRtcAccessConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .permissionRequestsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .capturePromptBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .navigatorWiringBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .navigatorCallsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .asyncHandlesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .deploymentBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepPlannerInterfaceMetadataOnly,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepPlannerInterfaceUnwired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRuntimeConstructionBlocked,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRuntimeDependenciesUnallocated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRuntimeDependenciesUnprepared,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRuntimeUncomposed,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
            .v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
            .v1Protected,
      ) &&
      callV2DisabledRuntimeConstructionPlannerInterface.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'artifactPresent': recordsAuditArtifactPresent,
      'plannerPresent': recordsPlannerInterfaceExists,
      'plannerPass': recordsPlannerInterfaceDecisionPass,
      'metadataOnly': recordsMetadataOnly,
      'mainImport': false,
      'mainCall': false,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'scaffoldPass': recordsScaffoldDecisionPass,
      'scaffoldAuditPass': recordsScaffoldHardeningAuditDecisionPass,
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
    return 'CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAudit'
        '(${toSafeDebugMap()})';
  }
}

final callV2DisabledRuntimeConstructionPlannerInterfaceHardeningAudit =
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAudit(
  statuses: <CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus>[
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .auditArtifactPresent,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .plannerInterfaceExists,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .plannerInterfaceDecisionPass,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .metadataOnly,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .plannerInterfaceNotImportedByMain,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .plannerInterfaceNotCalledFromMain,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .rolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .scaffoldDecisionPass,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .scaffoldHardeningAuditDecisionPass,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .noOpWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .runtimeDependencyAllocationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .runtimeDependencyPreparationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .runtimeCompositionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .runtimeUnavailable,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .runtimeCreationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .backendWritesBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .backendReadsBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .rtcAccessConsumptionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .capturePromptBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .deploymentBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .rollbackOneCommit,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningAuditStatus
        .v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback>[
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .oneCommitRevert,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepPlannerInterfaceMetadataOnly,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepPlannerInterfaceUnwired,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRuntimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRuntimeDependenciesUnallocated,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRuntimeDependenciesUnprepared,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRuntimeUncomposed,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .noDeploymentRequired,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .noConfigChanges,
    CallV2DisabledRuntimeConstructionPlannerInterfaceHardeningRollback
        .v1Unaffected,
  ],
);
