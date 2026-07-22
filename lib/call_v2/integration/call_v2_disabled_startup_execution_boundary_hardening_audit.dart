import 'call_v2_disabled_startup_execution_boundary.dart';
import 'call_v2_first_actual_app_wiring_touchpoint.dart';
import 'call_v2_first_actual_app_wiring_touchpoint_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus {
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
  appTouchpointPass,
  appTouchpointHardeningAuditPass,
  runtimeConstructionBlocked,
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

enum CallV2DisabledStartupExecutionBoundaryHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2DisabledStartupExecutionBoundaryHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepNoOpWhileFalse,
  keepRuntimeUnstarted,
  keepNoBackendWrites,
  keepNoRtcPermissions,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2DisabledStartupExecutionBoundaryHardeningAudit {
  factory CallV2DisabledStartupExecutionBoundaryHardeningAudit({
    required List<CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus>
        statuses,
    required List<CallV2DisabledStartupExecutionBoundaryHardeningRollback>
        rollback,
  }) {
    return CallV2DisabledStartupExecutionBoundaryHardeningAudit._(
      List<CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus>.unmodifiable(
          statuses),
      List<CallV2DisabledStartupExecutionBoundaryHardeningRollback>.unmodifiable(
          rollback),
    );
  }

  const CallV2DisabledStartupExecutionBoundaryHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus>
      statuses;
  final List<CallV2DisabledStartupExecutionBoundaryHardeningRollback> rollback;

  CallV2DisabledStartupExecutionBoundaryHardeningAuditDecision get decision {
    return passes
        ? CallV2DisabledStartupExecutionBoundaryHardeningAuditDecision.pass
        : CallV2DisabledStartupExecutionBoundaryHardeningAuditDecision.blocked;
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
      recordsAppTouchpointPass &&
      recordsAppTouchpointHardeningAuditPass &&
      recordsRuntimeConstructionBlocked &&
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
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .auditArtifactPresent,
      );

  bool get recordsBoundaryExists =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .boundaryExists,
      ) &&
      callV2DisabledStartupExecutionBoundary.statuses.isNotEmpty &&
      callV2DisabledStartupExecutionBoundary.rollback.isNotEmpty;

  bool get recordsBoundaryDecisionPass =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .boundaryDecisionPass,
      ) &&
      callV2DisabledStartupExecutionBoundary.decision ==
          CallV2DisabledStartupExecutionBoundaryDecision.pass;

  bool get recordsExecutorInert =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .executorInert,
      ) &&
      identical(
        executeCallV2DisabledStartupBoundarySafely(),
        callV2DisabledStartupExecutionBoundary,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledStartupExecutionBoundary.recordsRolloutFalse;

  bool get recordsMainDartImportSingle => statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .mainDartImportSingle,
      );

  bool get recordsMainDartExecutorSingle => statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .mainDartExecutorSingle,
      );

  bool get recordsMainDartExecutionOrder => statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .mainDartExecutionOrder,
      );

  bool get recordsResolverGatedBehindRollout => statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .resolverGatedBehindRollout,
      );

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsCallV2ScreenExposureBlocked;

  bool get recordsAppTouchpointPass =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .appTouchpointPass,
      ) &&
      callV2FirstActualAppWiringTouchpoint.decision ==
          CallV2FirstActualAppWiringTouchpointDecision.pass;

  bool get recordsAppTouchpointHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .appTouchpointHardeningAuditPass,
      ) &&
      callV2FirstActualAppWiringTouchpointHardeningAudit.decision ==
          CallV2FirstActualAppWiringTouchpointHardeningAuditDecision.pass;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .runtimeStartBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRuntimeStartBlocked;

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .backendWritesBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .backendReadsBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .firestoreListenersBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .rtcInitializationBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .rtcChannelJoinBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .permissionRequestsBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .capturePromptBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .navigatorWiringBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .navigatorCallsBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .asyncHandlesBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledStartupExecutionBoundary
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .deploymentBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback
            .keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback
            .keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback
            .keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback
            .keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus.v1Protected,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'artifactPresent': recordsAuditArtifactPresent,
      'boundaryPass': recordsBoundaryDecisionPass,
      'executorInert': recordsExecutorInert,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'mainImportSingle': recordsMainDartImportSingle,
      'mainExecutorSingle': recordsMainDartExecutorSingle,
      'mainOrderValid': recordsMainDartExecutionOrder,
      'resolverGated': recordsResolverGatedBehindRollout,
      'publicRoutesReachable': false,
      'screenExposureBlocked': recordsCallV2ScreenExposureBlocked,
      'runtimeConstructed': false,
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
    return 'CallV2DisabledStartupExecutionBoundaryHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2DisabledStartupExecutionBoundaryHardeningAudit =
    CallV2DisabledStartupExecutionBoundaryHardeningAudit(
  statuses: <CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus>[
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .auditArtifactPresent,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus.boundaryExists,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .boundaryDecisionPass,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus.executorInert,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus.rolloutFalse,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .mainDartImportSingle,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .mainDartExecutorSingle,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .mainDartExecutionOrder,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .resolverGatedBehindRollout,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .callV2ScreenExposureBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .appTouchpointPass,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .appTouchpointHardeningAuditPass,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .runtimeStartBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .productionStartupBridgeBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .startupBridgeCallBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .backendWritesBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .backendReadsBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .firestoreListenersBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .rtcInitializationBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .rtcEngineCreationBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .rtcChannelJoinBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .permissionRequestsBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .capturePromptBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .mediaDeviceAccessBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .navigatorWiringBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .navigatorCallsBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .asyncHandlesBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .deploymentBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus
        .rollbackOneCommit,
    CallV2DisabledStartupExecutionBoundaryHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2DisabledStartupExecutionBoundaryHardeningRollback>[
    CallV2DisabledStartupExecutionBoundaryHardeningRollback.oneCommitRevert,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback.keepRolloutFalse,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback.keepNoOpWhileFalse,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback
        .keepRuntimeUnstarted,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback.keepNoBackendWrites,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback
        .keepNoRtcPermissions,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback
        .noDeploymentRequired,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback.noConfigChanges,
    CallV2DisabledStartupExecutionBoundaryHardeningRollback.v1Unaffected,
  ],
);
