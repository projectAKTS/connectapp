import 'call_v2_disabled_runtime_construction_gate.dart';
import 'call_v2_disabled_runtime_construction_gate_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionPlanBoundaryStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  runtimeConstructionPlanBoundaryPresent,
  noOpWhileRolloutFalse,
  runtimeConstructionGatePass,
  runtimeConstructionGateHardeningAuditPass,
  productionExposureBlocked,
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

enum CallV2DisabledRuntimeConstructionPlanBoundaryDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionPlanBoundaryRollback {
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

final class CallV2DisabledRuntimeConstructionPlanBoundary {
  factory CallV2DisabledRuntimeConstructionPlanBoundary({
    required List<CallV2DisabledRuntimeConstructionPlanBoundaryStatus> statuses,
    required List<CallV2DisabledRuntimeConstructionPlanBoundaryRollback>
        rollback,
  }) {
    return CallV2DisabledRuntimeConstructionPlanBoundary._(
      List<CallV2DisabledRuntimeConstructionPlanBoundaryStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2DisabledRuntimeConstructionPlanBoundaryRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimeConstructionPlanBoundary._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimeConstructionPlanBoundaryStatus> statuses;
  final List<CallV2DisabledRuntimeConstructionPlanBoundaryRollback> rollback;

  CallV2DisabledRuntimeConstructionPlanBoundaryDecision get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionPlanBoundaryDecision.pass
        : CallV2DisabledRuntimeConstructionPlanBoundaryDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsRuntimeConstructionPlanBoundaryPresent &&
      recordsNoOpWhileRolloutFalse &&
      recordsRuntimeConstructionGatePass &&
      recordsRuntimeConstructionGateHardeningAuditPass &&
      recordsProductionExposureBlocked &&
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

  bool get recordsHumanApproval => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.humanApproved,
      );

  bool get recordsDeveloperOnly => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.developerOnly,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsRuntimeConstructionPlanBoundaryPresent => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeConstructionPlanBoundaryPresent,
      );

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsRuntimeConstructionGatePass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeConstructionGatePass,
      ) &&
      callV2DisabledRuntimeConstructionGate.decision ==
          CallV2DisabledRuntimeConstructionGateDecision.pass;

  bool get recordsRuntimeConstructionGateHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeConstructionGateHardeningAuditPass,
      ) &&
      callV2DisabledRuntimeConstructionGateHardeningAudit.decision ==
          CallV2DisabledRuntimeConstructionGateHardeningAuditDecision.pass;

  bool get recordsProductionExposureBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .productionExposureBlocked,
      );

  bool get recordsPublicRouteReachabilityBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .publicRouteReachabilityBlocked,
      );

  bool get recordsCallV2ScreenExposureBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .callV2ScreenExposureBlocked,
      );

  bool get recordsRuntimeConstructionBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeConstructionBlocked,
      );

  bool get recordsRuntimeDependencyAllocationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeDependencyAllocationBlocked,
      );

  bool get recordsRuntimeDependencyPreparationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeDependencyPreparationBlocked,
      );

  bool get recordsRuntimeCompositionBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeCompositionBlocked,
      );

  bool get recordsRuntimeStartBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.runtimeStartBlocked,
      );

  bool get recordsRuntimeUnavailable => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.runtimeUnavailable,
      );

  bool get recordsRuntimeCreationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .runtimeCreationBlocked,
      );

  bool get recordsProductionStartupBridgeBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .productionStartupBridgeBlocked,
      );

  bool get recordsStartupBridgeCallBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .startupBridgeCallBlocked,
      );

  bool get recordsBackendWritesBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .backendWritesBlocked,
      );

  bool get recordsBackendReadsBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.backendReadsBlocked,
      );

  bool get recordsFirestoreListenersBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .firestoreListenersBlocked,
      );

  bool get recordsAuthFunctionsAppCheckBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .authFunctionsAppCheckBlocked,
      );

  bool get recordsRtcInitializationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .rtcInitializationBlocked,
      );

  bool get recordsRtcEngineCreationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .rtcEngineCreationBlocked,
      );

  bool get recordsRtcChannelJoinBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .rtcChannelJoinBlocked,
      );

  bool get recordsRtcTokenChannelConsumptionBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .rtcTokenChannelConsumptionBlocked,
      );

  bool get recordsPermissionRequestsBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .permissionRequestsBlocked,
      );

  bool get recordsCapturePromptBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .capturePromptBlocked,
      );

  bool get recordsMediaDeviceAccessBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .mediaDeviceAccessBlocked,
      );

  bool get recordsNavigatorWiringBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .navigatorWiringBlocked,
      );

  bool get recordsNavigatorCallsBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .navigatorCallsBlocked,
      );

  bool get recordsLifecycleRegistrationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .lifecycleRegistrationBlocked,
      );

  bool get recordsAsyncHandlesBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.asyncHandlesBlocked,
      );

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsDeploymentBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.deploymentBlocked,
      );

  bool get recordsConfigPlatformChangesBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus
            .configPlatformChangesBlocked,
      );

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepRuntimeConstructionBlocked,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepRuntimeDependenciesUnallocated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepRuntimeDependenciesUnprepared,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepRuntimeUncomposed,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryRollback.v1Unaffected,
      );

  bool get recordsV1Protected => statuses.contains(
        CallV2DisabledRuntimeConstructionPlanBoundaryStatus.v1Protected,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'boundaryPresent': recordsRuntimeConstructionPlanBoundaryPresent,
      'noOpWhileRolloutFalse': recordsNoOpWhileRolloutFalse,
      'gatePass': recordsRuntimeConstructionGatePass,
      'gateAuditPass': recordsRuntimeConstructionGateHardeningAuditPass,
      'productionExposureBlocked': recordsProductionExposureBlocked,
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
    return 'CallV2DisabledRuntimeConstructionPlanBoundary(${toSafeDebugMap()})';
  }
}

CallV2DisabledRuntimeConstructionPlanBoundary
    executeCallV2DisabledRuntimeConstructionPlanBoundarySafely() {
  return callV2DisabledRuntimeConstructionPlanBoundary;
}

final callV2DisabledRuntimeConstructionPlanBoundary =
    CallV2DisabledRuntimeConstructionPlanBoundary(
  statuses: <CallV2DisabledRuntimeConstructionPlanBoundaryStatus>[
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.humanApproved,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.developerOnly,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.rolloutFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .runtimeConstructionPlanBoundaryPresent,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.noOpWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .runtimeConstructionGatePass,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .runtimeConstructionGateHardeningAuditPass,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .productionExposureBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .runtimeDependencyAllocationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .runtimeDependencyPreparationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .runtimeCompositionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.runtimeUnavailable,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.runtimeCreationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.backendWritesBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.backendReadsBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.capturePromptBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.deploymentBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.rollbackOneCommit,
    CallV2DisabledRuntimeConstructionPlanBoundaryStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionPlanBoundaryRollback>[
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.oneCommitRevert,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.keepRolloutFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.keepNoOpWhileFalse,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback
        .keepRuntimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback
        .keepRuntimeDependenciesUnallocated,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback
        .keepRuntimeDependenciesUnprepared,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.keepRuntimeUncomposed,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback
        .keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.noDeploymentRequired,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.noConfigChanges,
    CallV2DisabledRuntimeConstructionPlanBoundaryRollback.v1Unaffected,
  ],
);
