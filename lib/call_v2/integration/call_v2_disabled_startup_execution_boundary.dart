import 'call_v2_first_actual_app_wiring_touchpoint.dart';
import 'call_v2_first_actual_app_wiring_touchpoint_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledStartupExecutionBoundaryStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  startupExecutionBoundaryPresent,
  noOpWhileRolloutFalse,
  appTouchpointPass,
  appTouchpointHardeningAuditPass,
  productionExposureBlocked,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
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

enum CallV2DisabledStartupExecutionBoundaryDecision {
  pass,
  blocked,
}

enum CallV2DisabledStartupExecutionBoundaryRollback {
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

final class CallV2DisabledStartupExecutionBoundary {
  factory CallV2DisabledStartupExecutionBoundary({
    required List<CallV2DisabledStartupExecutionBoundaryStatus> statuses,
    required List<CallV2DisabledStartupExecutionBoundaryRollback> rollback,
  }) {
    return CallV2DisabledStartupExecutionBoundary._(
      List<CallV2DisabledStartupExecutionBoundaryStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2DisabledStartupExecutionBoundaryRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledStartupExecutionBoundary._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledStartupExecutionBoundaryStatus> statuses;
  final List<CallV2DisabledStartupExecutionBoundaryRollback> rollback;

  CallV2DisabledStartupExecutionBoundaryDecision get decision {
    return passes
        ? CallV2DisabledStartupExecutionBoundaryDecision.pass
        : CallV2DisabledStartupExecutionBoundaryDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsStartupExecutionBoundaryPresent &&
      recordsNoOpWhileRolloutFalse &&
      recordsAppTouchpointPass &&
      recordsAppTouchpointHardeningAuditPass &&
      recordsProductionExposureBlocked &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
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

  bool get recordsHumanApproval => statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.humanApproved,
      );

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.developerOnly,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsDeveloperOnly &&
      callV2FirstActualAppWiringTouchpointHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2FirstActualAppWiringTouchpoint.recordsRolloutFalse &&
      callV2FirstActualAppWiringTouchpointHardeningAudit.recordsRolloutFalse;

  bool get recordsStartupExecutionBoundaryPresent => statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .startupExecutionBoundaryPresent,
      );

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsAppTouchpointPass =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.appTouchpointPass,
      ) &&
      callV2FirstActualAppWiringTouchpoint.decision ==
          CallV2FirstActualAppWiringTouchpointDecision.pass;

  bool get recordsAppTouchpointHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .appTouchpointHardeningAuditPass,
      ) &&
      callV2FirstActualAppWiringTouchpointHardeningAudit.decision ==
          CallV2FirstActualAppWiringTouchpointHardeningAuditDecision.pass;

  bool get recordsProductionExposureBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.productionExposureBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsProductionExposureBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsProductionExposureBlocked;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint
          .recordsPublicRouteReachabilityBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsCallV2ScreenExposureBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.runtimeConstructionBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRuntimeConstructionBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.runtimeStartBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRuntimeStartBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsRuntimeStartBlocked;

  bool get recordsProductionStartupBridgeBlocked => statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .productionStartupBridgeBlocked,
      );

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.startupBridgeCallBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsStartupBridgeCallBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.backendWritesBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsBackendWritesBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.backendReadsBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsBackendReadsBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.firestoreListenersBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsFirestoreListenersBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint
          .recordsAuthFunctionsAppCheckBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.rtcInitializationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRtcInitializationBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.rtcEngineCreationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRtcEngineCreationBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.rtcChannelJoinBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRtcChannelJoinBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint
          .recordsRtcTokenChannelConsumptionBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.permissionRequestsBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsPermissionRequestsBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.capturePromptBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsCapturePromptBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.mediaDeviceAccessBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsMediaDeviceAccessBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.navigatorWiringBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsNavigatorWiringBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.navigatorCallsBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsNavigatorCallsBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint
          .recordsLifecycleRegistrationBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.asyncHandlesBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsAsyncHandlesBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2FirstActualAppWiringTouchpoint
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.deploymentBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsDeploymentBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint
          .recordsConfigPlatformChangesBlocked &&
      callV2FirstActualAppWiringTouchpointHardeningAudit
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledStartupExecutionBoundaryRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledStartupExecutionBoundaryStatus.v1Protected,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsV1Protected &&
      callV2FirstActualAppWiringTouchpointHardeningAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'boundaryPresent': recordsStartupExecutionBoundaryPresent,
      'noOpWhileRolloutFalse': recordsNoOpWhileRolloutFalse,
      'touchpointPass': recordsAppTouchpointPass,
      'hardeningPass': recordsAppTouchpointHardeningAuditPass,
      'productionExposureBlocked': recordsProductionExposureBlocked,
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
    return 'CallV2DisabledStartupExecutionBoundary(${toSafeDebugMap()})';
  }
}

CallV2DisabledStartupExecutionBoundary
    executeCallV2DisabledStartupBoundarySafely() {
  return callV2DisabledStartupExecutionBoundary;
}

final callV2DisabledStartupExecutionBoundary =
    CallV2DisabledStartupExecutionBoundary(
  statuses: <CallV2DisabledStartupExecutionBoundaryStatus>[
    CallV2DisabledStartupExecutionBoundaryStatus.humanApproved,
    CallV2DisabledStartupExecutionBoundaryStatus.developerOnly,
    CallV2DisabledStartupExecutionBoundaryStatus.rolloutFalse,
    CallV2DisabledStartupExecutionBoundaryStatus
        .startupExecutionBoundaryPresent,
    CallV2DisabledStartupExecutionBoundaryStatus.noOpWhileRolloutFalse,
    CallV2DisabledStartupExecutionBoundaryStatus.appTouchpointPass,
    CallV2DisabledStartupExecutionBoundaryStatus
        .appTouchpointHardeningAuditPass,
    CallV2DisabledStartupExecutionBoundaryStatus.productionExposureBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.publicRouteReachabilityBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.callV2ScreenExposureBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.runtimeConstructionBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.runtimeStartBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.productionStartupBridgeBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.startupBridgeCallBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.backendWritesBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.backendReadsBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.firestoreListenersBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.authFunctionsAppCheckBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.rtcInitializationBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.rtcEngineCreationBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.rtcChannelJoinBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.permissionRequestsBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.capturePromptBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.mediaDeviceAccessBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.navigatorWiringBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.navigatorCallsBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.lifecycleRegistrationBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.asyncHandlesBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledStartupExecutionBoundaryStatus.deploymentBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.configPlatformChangesBlocked,
    CallV2DisabledStartupExecutionBoundaryStatus.rollbackOneCommit,
    CallV2DisabledStartupExecutionBoundaryStatus.v1Protected,
  ],
  rollback: <CallV2DisabledStartupExecutionBoundaryRollback>[
    CallV2DisabledStartupExecutionBoundaryRollback.oneCommitRevert,
    CallV2DisabledStartupExecutionBoundaryRollback.keepRolloutFalse,
    CallV2DisabledStartupExecutionBoundaryRollback.keepNoOpWhileFalse,
    CallV2DisabledStartupExecutionBoundaryRollback.keepRuntimeUnstarted,
    CallV2DisabledStartupExecutionBoundaryRollback.keepNoBackendWrites,
    CallV2DisabledStartupExecutionBoundaryRollback.keepNoRtcPermissions,
    CallV2DisabledStartupExecutionBoundaryRollback.noDeploymentRequired,
    CallV2DisabledStartupExecutionBoundaryRollback.noConfigChanges,
    CallV2DisabledStartupExecutionBoundaryRollback.v1Unaffected,
  ],
);
