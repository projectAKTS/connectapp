import 'call_v2_disabled_runtime_construction_scaffold.dart';
import 'call_v2_disabled_runtime_construction_scaffold_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionPlannerInterfaceStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  plannerInterfaceArtifactPresent,
  metadataOnly,
  notImportedByMain,
  notCalledFromMain,
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

enum CallV2DisabledRuntimeConstructionPlannerInterfaceDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionPlannerInterfaceRollback {
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

final class CallV2DisabledRuntimeConstructionPlannerInterface {
  factory CallV2DisabledRuntimeConstructionPlannerInterface({
    required List<CallV2DisabledRuntimeConstructionPlannerInterfaceStatus>
        statuses,
    required List<CallV2DisabledRuntimeConstructionPlannerInterfaceRollback>
        rollback,
  }) {
    return CallV2DisabledRuntimeConstructionPlannerInterface._(
      List<
          CallV2DisabledRuntimeConstructionPlannerInterfaceStatus>.unmodifiable(
        statuses,
      ),
      List<
          CallV2DisabledRuntimeConstructionPlannerInterfaceRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimeConstructionPlannerInterface._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimeConstructionPlannerInterfaceStatus> statuses;
  final List<CallV2DisabledRuntimeConstructionPlannerInterfaceRollback>
      rollback;

  CallV2DisabledRuntimeConstructionPlannerInterfaceDecision get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionPlannerInterfaceDecision.pass
        : CallV2DisabledRuntimeConstructionPlannerInterfaceDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsPlannerInterfaceArtifactPresent &&
      recordsMetadataOnly &&
      recordsNotImportedByMain &&
      recordsNotCalledFromMain &&
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

  bool get recordsHumanApproval => statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.humanApproved,
      );

  bool get recordsDeveloperOnly => statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.developerOnly,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsPlannerInterfaceArtifactPresent => statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .plannerInterfaceArtifactPresent,
      );

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.metadataOnly,
      ) &&
      recordsRuntimeConstructionBlocked &&
      recordsRuntimeDependencyAllocationBlocked &&
      recordsRuntimeDependencyPreparationBlocked &&
      recordsRuntimeCompositionBlocked &&
      recordsRuntimeCreationBlocked &&
      recordsRuntimeStartBlocked;

  bool get recordsNotImportedByMain => statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .notImportedByMain,
      );

  bool get recordsNotCalledFromMain => statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .notCalledFromMain,
      );

  bool get recordsScaffoldDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .scaffoldDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.decision ==
          CallV2DisabledRuntimeConstructionScaffoldDecision.pass;

  bool get recordsScaffoldHardeningAuditDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .scaffoldHardeningAuditDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionScaffoldHardeningAudit.decision ==
          CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision.pass;

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionScaffold.recordsNoOpWhileRolloutFalse;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeDependencyAllocationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .runtimeDependencyAllocationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeDependencyAllocationBlocked;

  bool get recordsRuntimeDependencyPreparationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .runtimeDependencyPreparationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeDependencyPreparationBlocked;

  bool get recordsRuntimeCompositionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .runtimeCompositionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRuntimeCompositionBlocked;

  bool get recordsRuntimeUnavailable =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .runtimeUnavailable,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRuntimeUnavailable;

  bool get recordsRuntimeCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .runtimeCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRuntimeCreationBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .runtimeStartBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRuntimeStartBlocked;

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .backendWritesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .backendReadsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .firestoreListenersBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .rtcInitializationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .rtcChannelJoinBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsRtcChannelJoinBlocked;

  bool get recordsRtcAccessConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .rtcAccessConsumptionBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRtcAccessConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .permissionRequestsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .capturePromptBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .navigatorWiringBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .navigatorCallsBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .asyncHandlesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .deploymentBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledRuntimeConstructionScaffold
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepPlannerInterfaceMetadataOnly,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepPlannerInterfaceUnwired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRuntimeConstructionBlocked,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRuntimeDependenciesUnallocated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRuntimeDependenciesUnprepared,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRuntimeUncomposed,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
            .noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.v1Protected,
      ) &&
      callV2DisabledRuntimeConstructionScaffold.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'artifactPresent': recordsPlannerInterfaceArtifactPresent,
      'metadataOnly': recordsMetadataOnly,
      'mainImport': false,
      'mainCall': false,
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
    return 'CallV2DisabledRuntimeConstructionPlannerInterface'
        '(${toSafeDebugMap()})';
  }
}

final callV2DisabledRuntimeConstructionPlannerInterface =
    CallV2DisabledRuntimeConstructionPlannerInterface(
  statuses: <CallV2DisabledRuntimeConstructionPlannerInterfaceStatus>[
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.humanApproved,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.developerOnly,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.rolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .plannerInterfaceArtifactPresent,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.metadataOnly,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.notImportedByMain,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.notCalledFromMain,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .scaffoldDecisionPass,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .scaffoldHardeningAuditDecisionPass,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .noOpWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .runtimeDependencyAllocationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .runtimeDependencyPreparationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .runtimeCompositionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.runtimeUnavailable,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .runtimeCreationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .backendWritesBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.backendReadsBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .rtcAccessConsumptionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .capturePromptBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.deploymentBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.rollbackOneCommit,
    CallV2DisabledRuntimeConstructionPlannerInterfaceStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionPlannerInterfaceRollback>[
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback.oneCommitRevert,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback.keepRolloutFalse,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepPlannerInterfaceMetadataOnly,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepPlannerInterfaceUnwired,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepRuntimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepRuntimeDependenciesUnallocated,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepRuntimeDependenciesUnprepared,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepRuntimeUncomposed,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback
        .noDeploymentRequired,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback.noConfigChanges,
    CallV2DisabledRuntimeConstructionPlannerInterfaceRollback.v1Unaffected,
  ],
);
