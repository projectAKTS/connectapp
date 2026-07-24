import 'call_v2_disabled_runtime_preflight_boundary.dart';
import 'call_v2_disabled_startup_execution_boundary.dart';
import 'call_v2_disabled_startup_execution_boundary_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus {
  auditArtifactPresent,
  boundaryExists,
  boundaryDecisionPass,
  executorInert,
  rolloutFalse,
  mainDartImportSingle,
  mainDartExecutorSingle,
  mainDartExecutionOrder,
  resolverGatedBehindRollout,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
  startupBoundaryPass,
  startupBoundaryHardeningAuditPass,
  runtimeConstructionBlocked,
  runtimeStartBlocked,
  runtimeInstanceUnavailable,
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

enum CallV2DisabledRuntimePreflightBoundaryHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimePreflightBoundaryHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepNoOpWhileFalse,
  keepRuntimeUnavailable,
  keepRuntimeUnstarted,
  keepNoBackendWrites,
  keepNoRtcPermissions,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DisabledRuntimePreflightBoundaryHardeningAudit {
  factory CallV2DisabledRuntimePreflightBoundaryHardeningAudit({
    required List<CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus>
        statuses,
    required List<CallV2DisabledRuntimePreflightBoundaryHardeningRollback>
        rollback,
  }) {
    return CallV2DisabledRuntimePreflightBoundaryHardeningAudit._(
      List<
          CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<
          CallV2DisabledRuntimePreflightBoundaryHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimePreflightBoundaryHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus>
      statuses;
  final List<CallV2DisabledRuntimePreflightBoundaryHardeningRollback> rollback;

  CallV2DisabledRuntimePreflightBoundaryHardeningAuditDecision get decision {
    return passes
        ? CallV2DisabledRuntimePreflightBoundaryHardeningAuditDecision.pass
        : CallV2DisabledRuntimePreflightBoundaryHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsAuditArtifactPresent &&
      recordsBoundaryExists &&
      recordsBoundaryDecisionPass &&
      recordsExecutorInert &&
      recordsRolloutFalse &&
      recordsMainDartImportSingle &&
      recordsMainDartExecutorSingle &&
      recordsMainDartExecutionOrder &&
      recordsResolverGatedBehindRollout &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
      recordsStartupBoundaryPass &&
      recordsStartupBoundaryHardeningAuditPass &&
      recordsRuntimeConstructionBlocked &&
      recordsRuntimeStartBlocked &&
      recordsRuntimeInstanceUnavailable &&
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
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .auditArtifactPresent,
      );

  bool get recordsBoundaryExists =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .boundaryExists,
      ) &&
      callV2DisabledRuntimePreflightBoundary.statuses.isNotEmpty &&
      callV2DisabledRuntimePreflightBoundary.rollback.isNotEmpty;

  bool get recordsBoundaryDecisionPass =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .boundaryDecisionPass,
      ) &&
      callV2DisabledRuntimePreflightBoundary.decision ==
          CallV2DisabledRuntimePreflightBoundaryDecision.pass;

  bool get recordsExecutorInert =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .executorInert,
      ) &&
      identical(
        executeCallV2DisabledRuntimePreflightBoundarySafely(),
        callV2DisabledRuntimePreflightBoundary,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimePreflightBoundary.recordsRolloutFalse;

  bool get recordsMainDartImportSingle => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .mainDartImportSingle,
      );

  bool get recordsMainDartExecutorSingle => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .mainDartExecutorSingle,
      );

  bool get recordsMainDartExecutionOrder => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .mainDartExecutionOrder,
      );

  bool get recordsResolverGatedBehindRollout => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .resolverGatedBehindRollout,
      );

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsCallV2ScreenExposureBlocked;

  bool get recordsStartupBoundaryPass =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .startupBoundaryPass,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsHumanApproval &&
      callV2DisabledStartupExecutionBoundary.recordsDeveloperOnly &&
      callV2DisabledStartupExecutionBoundary.recordsRolloutFalse &&
      callV2DisabledStartupExecutionBoundary
          .recordsStartupExecutionBoundaryPresent &&
      callV2DisabledStartupExecutionBoundary.recordsNoOpWhileRolloutFalse &&
      callV2DisabledStartupExecutionBoundary.recordsRuntimeStartBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsBackendWritesBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsBackendReadsBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsFirestoreListenersBlocked &&
      callV2DisabledStartupExecutionBoundary
          .recordsAuthFunctionsAppCheckBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsRtcInitializationBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsPermissionRequestsBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsNavigatorCallsBlocked &&
      callV2DisabledStartupExecutionBoundary
          .recordsLifecycleRegistrationBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsAsyncHandlesBlocked &&
      callV2DisabledStartupExecutionBoundary.recordsV1Protected &&
      callV2DisabledRuntimePreflightBoundary.recordsStartupBoundaryPass;

  bool get recordsStartupBoundaryHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .startupBoundaryHardeningAuditPass,
      ) &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsAuditArtifactPresent &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsBoundaryExists &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsExecutorInert &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRolloutFalse &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRuntimeStartBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsBackendWritesBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsBackendReadsBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsFirestoreListenersBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsAuthFunctionsAppCheckBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRtcInitializationBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsPermissionRequestsBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsNavigatorCallsBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsLifecycleRegistrationBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsAsyncHandlesBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit.recordsV1Protected &&
      callV2DisabledRuntimePreflightBoundary
          .recordsStartupBoundaryHardeningAuditPass;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .runtimeStartBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRuntimeStartBlocked;

  bool get recordsRuntimeInstanceUnavailable =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .runtimeInstanceUnavailable,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRuntimeInstanceUnavailable;

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .backendWritesBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .backendReadsBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .firestoreListenersBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .rtcInitializationBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .rtcChannelJoinBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .permissionRequestsBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .capturePromptBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .navigatorWiringBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .navigatorCallsBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .asyncHandlesBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimePreflightBoundary
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .deploymentBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback
            .keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback
            .keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback
            .keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback
            .keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback
            .keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus.v1Protected,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'boundaryPresent': recordsBoundaryExists,
      'boundaryDecisionPass': recordsBoundaryDecisionPass,
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
    return 'CallV2DisabledRuntimePreflightBoundaryHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2DisabledRuntimePreflightBoundaryHardeningAudit =
    CallV2DisabledRuntimePreflightBoundaryHardeningAudit(
  statuses: <CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus>[
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .auditArtifactPresent,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus.boundaryExists,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .boundaryDecisionPass,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus.executorInert,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus.rolloutFalse,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .mainDartImportSingle,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .mainDartExecutorSingle,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .mainDartExecutionOrder,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .resolverGatedBehindRollout,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .startupBoundaryPass,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .startupBoundaryHardeningAuditPass,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .runtimeStartBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .runtimeInstanceUnavailable,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .startupBridgeCallBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .backendWritesBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .backendReadsBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .firestoreListenersBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .rtcInitializationBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .rtcChannelJoinBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .permissionRequestsBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .capturePromptBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .navigatorWiringBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .navigatorCallsBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .asyncHandlesBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .deploymentBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus
        .rollbackOneCommit,
    CallV2DisabledRuntimePreflightBoundaryHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimePreflightBoundaryHardeningRollback>[
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback.oneCommitRevert,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback.keepRolloutFalse,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback.keepNoOpWhileFalse,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback
        .keepRuntimeUnavailable,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback
        .keepRuntimeUnstarted,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback.keepNoBackendWrites,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback
        .keepNoRtcPermissions,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback
        .noDeploymentRequired,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback.noConfigChanges,
    CallV2DisabledRuntimePreflightBoundaryHardeningRollback.v1Unaffected,
  ],
);
