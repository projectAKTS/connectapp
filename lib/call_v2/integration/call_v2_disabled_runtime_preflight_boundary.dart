import 'call_v2_disabled_startup_execution_boundary.dart';
import 'call_v2_disabled_startup_execution_boundary_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimePreflightBoundaryStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  runtimePreflightBoundaryPresent,
  noOpWhileRolloutFalse,
  startupBoundaryPass,
  startupBoundaryHardeningAuditPass,
  productionExposureBlocked,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
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

enum CallV2DisabledRuntimePreflightBoundaryDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimePreflightBoundaryRollback {
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

final class CallV2DisabledRuntimePreflightBoundary {
  factory CallV2DisabledRuntimePreflightBoundary({
    required List<CallV2DisabledRuntimePreflightBoundaryStatus> statuses,
    required List<CallV2DisabledRuntimePreflightBoundaryRollback> rollback,
  }) {
    return CallV2DisabledRuntimePreflightBoundary._(
      List<CallV2DisabledRuntimePreflightBoundaryStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2DisabledRuntimePreflightBoundaryRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimePreflightBoundary._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimePreflightBoundaryStatus> statuses;
  final List<CallV2DisabledRuntimePreflightBoundaryRollback> rollback;

  CallV2DisabledRuntimePreflightBoundaryDecision get decision {
    return passes
        ? CallV2DisabledRuntimePreflightBoundaryDecision.pass
        : CallV2DisabledRuntimePreflightBoundaryDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsRuntimePreflightBoundaryPresent &&
      recordsNoOpWhileRolloutFalse &&
      recordsStartupBoundaryPass &&
      recordsStartupBoundaryHardeningAuditPass &&
      recordsProductionExposureBlocked &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
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

  bool get recordsHumanApproval => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.humanApproved,
      );

  bool get recordsDeveloperOnly => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.developerOnly,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledStartupExecutionBoundary.recordsRolloutFalse &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit.recordsRolloutFalse;

  bool get recordsRuntimePreflightBoundaryPresent => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .runtimePreflightBoundaryPresent,
      );

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsStartupBoundaryPass =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.startupBoundaryPass,
      ) &&
      callV2DisabledStartupExecutionBoundary.decision ==
          CallV2DisabledStartupExecutionBoundaryDecision.pass;

  bool get recordsStartupBoundaryHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .startupBoundaryHardeningAuditPass,
      ) &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit.decision ==
          CallV2DisabledStartupExecutionBoundaryHardeningAuditDecision.pass;

  bool get recordsProductionExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.productionExposureBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsProductionExposureBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsPublicRouteReachabilityBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsCallV2ScreenExposureBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.runtimeConstructionBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsRuntimeConstructionBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.runtimeStartBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRuntimeStartBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRuntimeStartBlocked;

  bool get recordsRuntimeInstanceUnavailable => statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.runtimeInstanceUnavailable,
      );

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsProductionStartupBridgeBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.startupBridgeCallBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsStartupBridgeCallBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.backendWritesBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsBackendWritesBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.backendReadsBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsBackendReadsBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.firestoreListenersBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsFirestoreListenersBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsAuthFunctionsAppCheckBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.rtcInitializationBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRtcInitializationBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.rtcEngineCreationBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRtcEngineCreationBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.rtcChannelJoinBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsRtcChannelJoinBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsRtcTokenChannelConsumptionBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.permissionRequestsBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsPermissionRequestsBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.capturePromptBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsCapturePromptBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsMediaDeviceAccessBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.navigatorWiringBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsNavigatorWiringBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.navigatorCallsBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsNavigatorCallsBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsLifecycleRegistrationBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.asyncHandlesBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsAsyncHandlesBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledStartupExecutionBoundary
          .recordsRouteResolverNotCalledWhileRolloutFalse &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.deploymentBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsDeploymentBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledStartupExecutionBoundary
          .recordsConfigPlatformChangesBlocked &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimePreflightBoundaryRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimePreflightBoundaryStatus.v1Protected,
      ) &&
      callV2DisabledStartupExecutionBoundary.recordsV1Protected &&
      callV2DisabledStartupExecutionBoundaryHardeningAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'boundaryPresent': recordsRuntimePreflightBoundaryPresent,
      'noOpWhileRolloutFalse': recordsNoOpWhileRolloutFalse,
      'startupBoundaryPass': recordsStartupBoundaryPass,
      'startupHardeningPass': recordsStartupBoundaryHardeningAuditPass,
      'productionExposureBlocked': recordsProductionExposureBlocked,
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
    return 'CallV2DisabledRuntimePreflightBoundary(${toSafeDebugMap()})';
  }
}

CallV2DisabledRuntimePreflightBoundary
    executeCallV2DisabledRuntimePreflightBoundarySafely() {
  return callV2DisabledRuntimePreflightBoundary;
}

final callV2DisabledRuntimePreflightBoundary =
    CallV2DisabledRuntimePreflightBoundary(
  statuses: <CallV2DisabledRuntimePreflightBoundaryStatus>[
    CallV2DisabledRuntimePreflightBoundaryStatus.humanApproved,
    CallV2DisabledRuntimePreflightBoundaryStatus.developerOnly,
    CallV2DisabledRuntimePreflightBoundaryStatus.rolloutFalse,
    CallV2DisabledRuntimePreflightBoundaryStatus
        .runtimePreflightBoundaryPresent,
    CallV2DisabledRuntimePreflightBoundaryStatus.noOpWhileRolloutFalse,
    CallV2DisabledRuntimePreflightBoundaryStatus.startupBoundaryPass,
    CallV2DisabledRuntimePreflightBoundaryStatus
        .startupBoundaryHardeningAuditPass,
    CallV2DisabledRuntimePreflightBoundaryStatus.productionExposureBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.publicRouteReachabilityBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.callV2ScreenExposureBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.runtimeConstructionBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.runtimeStartBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.runtimeInstanceUnavailable,
    CallV2DisabledRuntimePreflightBoundaryStatus.productionStartupBridgeBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.startupBridgeCallBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.backendWritesBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.backendReadsBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.firestoreListenersBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.rtcInitializationBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.rtcEngineCreationBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.rtcChannelJoinBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.permissionRequestsBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.capturePromptBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.mediaDeviceAccessBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.navigatorWiringBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.navigatorCallsBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.lifecycleRegistrationBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.asyncHandlesBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimePreflightBoundaryStatus.deploymentBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.configPlatformChangesBlocked,
    CallV2DisabledRuntimePreflightBoundaryStatus.rollbackOneCommit,
    CallV2DisabledRuntimePreflightBoundaryStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimePreflightBoundaryRollback>[
    CallV2DisabledRuntimePreflightBoundaryRollback.oneCommitRevert,
    CallV2DisabledRuntimePreflightBoundaryRollback.keepRolloutFalse,
    CallV2DisabledRuntimePreflightBoundaryRollback.keepNoOpWhileFalse,
    CallV2DisabledRuntimePreflightBoundaryRollback.keepRuntimeUnavailable,
    CallV2DisabledRuntimePreflightBoundaryRollback.keepRuntimeUnstarted,
    CallV2DisabledRuntimePreflightBoundaryRollback.keepNoBackendWrites,
    CallV2DisabledRuntimePreflightBoundaryRollback.keepNoRtcPermissions,
    CallV2DisabledRuntimePreflightBoundaryRollback.noDeploymentRequired,
    CallV2DisabledRuntimePreflightBoundaryRollback.noConfigChanges,
    CallV2DisabledRuntimePreflightBoundaryRollback.v1Unaffected,
  ],
);
