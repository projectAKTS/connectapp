import 'call_v2_disabled_runtime_construction_gate.dart';
import 'call_v2_disabled_runtime_preflight_boundary.dart';
import 'call_v2_disabled_runtime_preflight_boundary_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionGateHardeningAuditStatus {
  auditArtifactPresent,
  gateExists,
  gateDecisionPass,
  executorInert,
  rolloutFalse,
  mainDartImportSingle,
  mainDartExecutorSingle,
  mainDartExecutionOrder,
  resolverGatedBehindRollout,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
  runtimeConstructionBlocked,
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

enum CallV2DisabledRuntimeConstructionGateHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionGateHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepNoOpWhileFalse,
  keepRuntimeUnavailable,
  keepRuntimeUnstarted,
  keepRuntimeUncreated,
  keepNoBackendWrites,
  keepNoRtcPermissions,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DisabledRuntimeConstructionGateHardeningAudit {
  factory CallV2DisabledRuntimeConstructionGateHardeningAudit({
    required List<CallV2DisabledRuntimeConstructionGateHardeningAuditStatus>
        statuses,
    required List<CallV2DisabledRuntimeConstructionGateHardeningRollback>
        rollback,
  }) {
    return CallV2DisabledRuntimeConstructionGateHardeningAudit._(
      List<
          CallV2DisabledRuntimeConstructionGateHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2DisabledRuntimeConstructionGateHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimeConstructionGateHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimeConstructionGateHardeningAuditStatus>
      statuses;
  final List<CallV2DisabledRuntimeConstructionGateHardeningRollback> rollback;

  CallV2DisabledRuntimeConstructionGateHardeningAuditDecision get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionGateHardeningAuditDecision.pass
        : CallV2DisabledRuntimeConstructionGateHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsAuditArtifactPresent &&
      recordsGateExists &&
      recordsGateDecisionPass &&
      recordsExecutorInert &&
      recordsRolloutFalse &&
      recordsMainDartImportSingle &&
      recordsMainDartExecutorSingle &&
      recordsMainDartExecutionOrder &&
      recordsResolverGatedBehindRollout &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
      recordsRuntimeConstructionBlocked &&
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
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .auditArtifactPresent,
      );

  bool get recordsGateExists =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.gateExists,
      ) &&
      callV2DisabledRuntimeConstructionGate.statuses.isNotEmpty &&
      callV2DisabledRuntimeConstructionGate.rollback.isNotEmpty;

  bool get recordsGateDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .gateDecisionPass,
      ) &&
      callV2DisabledRuntimeConstructionGate.statuses.isNotEmpty &&
      callV2DisabledRuntimeConstructionGate.rollback.isNotEmpty;

  bool get recordsExecutorInert =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.executorInert,
      ) &&
      identical(
        executeCallV2DisabledRuntimeConstructionGateSafely(),
        callV2DisabledRuntimeConstructionGate,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsMainDartImportSingle => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .mainDartImportSingle,
      );

  bool get recordsMainDartExecutorSingle => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .mainDartExecutorSingle,
      );

  bool get recordsMainDartExecutionOrder => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .mainDartExecutionOrder,
      );

  bool get recordsResolverGatedBehindRollout => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .resolverGatedBehindRollout,
      );

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.statuses.isNotEmpty &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit.statuses.isNotEmpty;

  bool get recordsCallV2ScreenExposureBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .callV2ScreenExposureBlocked,
      );

  bool get recordsRuntimeConstructionBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .runtimeConstructionBlocked,
      );

  bool get recordsRuntimeStartBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .runtimeStartBlocked,
      );

  bool get recordsRuntimeUnavailable => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .runtimeUnavailable,
      );

  bool get recordsRuntimeCreationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .runtimeCreationBlocked,
      );

  bool get recordsProductionStartupBridgeBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .productionStartupBridgeBlocked,
      );

  bool get recordsStartupBridgeCallBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .startupBridgeCallBlocked,
      );

  bool get recordsBackendWritesBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .backendWritesBlocked,
      );

  bool get recordsBackendReadsBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .backendReadsBlocked,
      );

  bool get recordsFirestoreListenersBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .firestoreListenersBlocked,
      );

  bool get recordsAuthFunctionsAppCheckBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      );

  bool get recordsRtcInitializationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .rtcInitializationBlocked,
      );

  bool get recordsRtcEngineCreationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .rtcEngineCreationBlocked,
      );

  bool get recordsRtcChannelJoinBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .rtcChannelJoinBlocked,
      );

  bool get recordsRtcTokenChannelConsumptionBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .rtcTokenChannelConsumptionBlocked,
      );

  bool get recordsPermissionRequestsBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .permissionRequestsBlocked,
      );

  bool get recordsCapturePromptBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .capturePromptBlocked,
      );

  bool get recordsMediaDeviceAccessBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      );

  bool get recordsNavigatorWiringBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .navigatorWiringBlocked,
      );

  bool get recordsNavigatorCallsBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .navigatorCallsBlocked,
      );

  bool get recordsLifecycleRegistrationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      );

  bool get recordsAsyncHandlesBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .asyncHandlesBlocked,
      );

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsDeploymentBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .deploymentBlocked,
      );

  bool get recordsConfigPlatformChangesBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .configPlatformChangesBlocked,
      );

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback
            .keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback
            .keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback
            .keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback
            .keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateHardeningRollback.v1Unaffected,
      );

  bool get recordsV1Protected => statuses.contains(
        CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.v1Protected,
      );

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'gateExists': recordsGateExists,
      'gateDecisionPass': recordsGateDecisionPass,
      'executorInert': recordsExecutorInert,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'mainImportSingle': recordsMainDartImportSingle,
      'mainExecutorSingle': recordsMainDartExecutorSingle,
      'mainOrderPass': recordsMainDartExecutionOrder,
      'resolverGated': recordsResolverGatedBehindRollout,
      'publicRoutesReachable': false,
      'screenExposureBlocked': recordsCallV2ScreenExposureBlocked,
      'runtimeConstructed': false,
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
    return 'CallV2DisabledRuntimeConstructionGateHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2DisabledRuntimeConstructionGateHardeningAudit =
    CallV2DisabledRuntimeConstructionGateHardeningAudit(
  statuses: <CallV2DisabledRuntimeConstructionGateHardeningAuditStatus>[
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .auditArtifactPresent,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.gateExists,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.gateDecisionPass,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.executorInert,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.rolloutFalse,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .mainDartImportSingle,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .mainDartExecutorSingle,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .mainDartExecutionOrder,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .resolverGatedBehindRollout,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .runtimeUnavailable,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .runtimeCreationBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .backendWritesBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .backendReadsBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .capturePromptBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.deploymentBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.rollbackOneCommit,
    CallV2DisabledRuntimeConstructionGateHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionGateHardeningRollback>[
    CallV2DisabledRuntimeConstructionGateHardeningRollback.oneCommitRevert,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.keepRolloutFalse,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.keepNoOpWhileFalse,
    CallV2DisabledRuntimeConstructionGateHardeningRollback
        .keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.keepNoBackendWrites,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.keepNoRtcPermissions,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.noDeploymentRequired,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.noConfigChanges,
    CallV2DisabledRuntimeConstructionGateHardeningRollback.v1Unaffected,
  ],
);
