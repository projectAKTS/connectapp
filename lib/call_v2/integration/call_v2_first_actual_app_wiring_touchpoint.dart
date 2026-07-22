import 'call_v2_first_real_wiring_boundary.dart';
import 'call_v2_first_real_wiring_boundary_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2FirstActualAppWiringTouchpointStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  appWiringTouchpointPresent,
  noOpWhileRolloutFalse,
  productionExposureBlocked,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
  firstRealWiringBoundaryPass,
  firstRealWiringBoundaryHardeningAuditPass,
  runtimeConstructionBlocked,
  runtimeStartBlocked,
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
  navigatorKeyCreationBlocked,
  globalKeyCreationBlocked,
  buildContextStorageBlocked,
  materialAppRouteWiringBlocked,
  navigatorCallsBlocked,
  lifecycleRegistrationBlocked,
  appLifecycleListenerBlocked,
  widgetsBindingObserverBlocked,
  asyncHandlesBlocked,
  routeResolverNotCalledWhileRolloutFalse,
  deploymentBlocked,
  configPlatformChangesBlocked,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2FirstActualAppWiringTouchpointDecision {
  pass,
  blocked,
}

enum CallV2FirstActualAppWiringTouchpointRollback {
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

final class CallV2FirstActualAppWiringTouchpoint {
  factory CallV2FirstActualAppWiringTouchpoint({
    required List<CallV2FirstActualAppWiringTouchpointStatus> statuses,
    required List<CallV2FirstActualAppWiringTouchpointRollback> rollback,
  }) {
    return CallV2FirstActualAppWiringTouchpoint._(
      List<CallV2FirstActualAppWiringTouchpointStatus>.unmodifiable(statuses),
      List<CallV2FirstActualAppWiringTouchpointRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2FirstActualAppWiringTouchpoint._(this.statuses, this.rollback);

  final List<CallV2FirstActualAppWiringTouchpointStatus> statuses;
  final List<CallV2FirstActualAppWiringTouchpointRollback> rollback;

  CallV2FirstActualAppWiringTouchpointDecision get decision {
    return passes
        ? CallV2FirstActualAppWiringTouchpointDecision.pass
        : CallV2FirstActualAppWiringTouchpointDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsAppWiringTouchpointPresent &&
      recordsNoOpWhileRolloutFalse &&
      recordsProductionExposureBlocked &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
      recordsFirstRealWiringBoundaryPass &&
      recordsFirstRealWiringBoundaryHardeningAuditPass &&
      recordsRuntimeConstructionBlocked &&
      recordsRuntimeStartBlocked &&
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
      recordsNavigatorKeyCreationBlocked &&
      recordsGlobalKeyCreationBlocked &&
      recordsBuildContextStorageBlocked &&
      recordsMaterialAppRouteWiringBlocked &&
      recordsNavigatorCallsBlocked &&
      recordsLifecycleRegistrationBlocked &&
      recordsAppLifecycleListenerBlocked &&
      recordsWidgetsBindingObserverBlocked &&
      recordsAsyncHandlesBlocked &&
      recordsRouteResolverNotCalledWhileRolloutFalse &&
      recordsDeploymentBlocked &&
      recordsConfigPlatformChangesBlocked &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsHumanApproval => statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.humanApproved,
      );

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.developerOnly,
      ) &&
      callV2FirstRealWiringBoundary.recordsDeveloperOnly &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2FirstRealWiringBoundary.recordsRolloutFalse &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsRolloutFalse;

  bool get recordsAppWiringTouchpointPresent => statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.appWiringTouchpointPresent,
      );

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsProductionExposureBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.productionExposureBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsProductionExposureBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsProductionExposureBlocked;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsPublicRouteReachabilityBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked => statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.callV2ScreenExposureBlocked,
      );

  bool get recordsFirstRealWiringBoundaryPass =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.firstRealWiringBoundaryPass,
      ) &&
      callV2FirstRealWiringBoundary.decision ==
          CallV2FirstRealWiringBoundaryDecision.pass;

  bool get recordsFirstRealWiringBoundaryHardeningAuditPass =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus
            .firstRealWiringBoundaryHardeningAuditPass,
      ) &&
      callV2FirstRealWiringBoundaryHardeningAudit.decision ==
          CallV2FirstRealWiringBoundaryHardeningAuditDecision.pass;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.runtimeConstructionBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRuntimeConstructionBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.runtimeStartBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRuntimeStartBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsRuntimeStartBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.startupBridgeCallBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsStartupBridgeCallBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.backendWritesBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsBackendWritesBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.backendReadsBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsBackendReadsBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.firestoreListenersBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsFirestoreListenersBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.authFunctionsAppCheckBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsAuthFunctionsAppCheckBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.rtcInitializationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcInitializationBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.rtcEngineCreationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcEngineCreationBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.rtcChannelJoinBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcChannelJoinBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcTokenChannelConsumptionBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.permissionRequestsBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsPermissionRequestsBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.capturePromptBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsCapturePromptBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.mediaDeviceAccessBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsMediaDeviceAccessBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.navigatorWiringBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsNavigatorWiringBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsNavigatorWiringBlocked;

  bool get recordsNavigatorKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.navigatorKeyCreationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsNavigatorKeyCreationBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsNavigatorKeyCreationBlocked;

  bool get recordsGlobalKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.globalKeyCreationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsGlobalKeyCreationBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsGlobalKeyCreationBlocked;

  bool get recordsBuildContextStorageBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.buildContextStorageBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsBuildContextStorageBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsBuildContextStorageBlocked;

  bool get recordsMaterialAppRouteWiringBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus
            .materialAppRouteWiringBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsMaterialAppRouteWiringBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsMaterialAppRouteWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.navigatorCallsBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsNavigatorCallsBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.lifecycleRegistrationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsLifecycleRegistrationBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAppLifecycleListenerBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.appLifecycleListenerBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsAppLifecycleListenerBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsAppLifecycleListenerBlocked;

  bool get recordsWidgetsBindingObserverBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus
            .widgetsBindingObserverBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsWidgetsBindingObserverBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsWidgetsBindingObserverBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.asyncHandlesBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsAsyncHandlesBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.deploymentBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsDeploymentBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.configPlatformChangesBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsConfigPlatformChangesBlocked &&
      callV2FirstRealWiringBoundaryHardeningAudit
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses
          .contains(CallV2FirstActualAppWiringTouchpointStatus.v1Protected) &&
      callV2FirstRealWiringBoundary.recordsV1Protected &&
      callV2FirstRealWiringBoundaryHardeningAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'appWiringTouchpointPresent': recordsAppWiringTouchpointPresent,
      'noOpWhileRolloutFalse': recordsNoOpWhileRolloutFalse,
      'productionExposureBlocked': recordsProductionExposureBlocked,
      'publicRoutesReachable': false,
      'screenExposureBlocked': recordsCallV2ScreenExposureBlocked,
      'firstBoundaryPass': recordsFirstRealWiringBoundaryPass,
      'hardeningPass': recordsFirstRealWiringBoundaryHardeningAuditPass,
      'runtimeConstructed': false,
      'runtimeStarted': false,
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
      'navKeyCreated': false,
      'globalKeyCreated': false,
      'widgetContextStored': false,
      'materialRouteTableWired': false,
      'navCalled': false,
      'lifecycleRegistered': false,
      'appLifecycleHookCreated': false,
      'bindingObserverAttached': false,
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
    return 'CallV2FirstActualAppWiringTouchpoint(${toSafeDebugMap()})';
  }
}

CallV2FirstActualAppWiringTouchpoint
    initializeCallV2FirstActualAppWiringTouchpointSafely() {
  return callV2FirstActualAppWiringTouchpoint;
}

final callV2FirstActualAppWiringTouchpoint =
    CallV2FirstActualAppWiringTouchpoint(
  statuses: <CallV2FirstActualAppWiringTouchpointStatus>[
    CallV2FirstActualAppWiringTouchpointStatus.humanApproved,
    CallV2FirstActualAppWiringTouchpointStatus.developerOnly,
    CallV2FirstActualAppWiringTouchpointStatus.rolloutFalse,
    CallV2FirstActualAppWiringTouchpointStatus.appWiringTouchpointPresent,
    CallV2FirstActualAppWiringTouchpointStatus.noOpWhileRolloutFalse,
    CallV2FirstActualAppWiringTouchpointStatus.productionExposureBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.publicRouteReachabilityBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.callV2ScreenExposureBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.firstRealWiringBoundaryPass,
    CallV2FirstActualAppWiringTouchpointStatus
        .firstRealWiringBoundaryHardeningAuditPass,
    CallV2FirstActualAppWiringTouchpointStatus.runtimeConstructionBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.runtimeStartBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.startupBridgeCallBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.backendWritesBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.backendReadsBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.firestoreListenersBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.authFunctionsAppCheckBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.rtcInitializationBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.rtcEngineCreationBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.rtcChannelJoinBlocked,
    CallV2FirstActualAppWiringTouchpointStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.permissionRequestsBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.capturePromptBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.mediaDeviceAccessBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.navigatorWiringBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.navigatorKeyCreationBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.globalKeyCreationBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.buildContextStorageBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.materialAppRouteWiringBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.navigatorCallsBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.lifecycleRegistrationBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.appLifecycleListenerBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.widgetsBindingObserverBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.asyncHandlesBlocked,
    CallV2FirstActualAppWiringTouchpointStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2FirstActualAppWiringTouchpointStatus.deploymentBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.configPlatformChangesBlocked,
    CallV2FirstActualAppWiringTouchpointStatus.rollbackOneCommit,
    CallV2FirstActualAppWiringTouchpointStatus.v1Protected,
  ],
  rollback: <CallV2FirstActualAppWiringTouchpointRollback>[
    CallV2FirstActualAppWiringTouchpointRollback.oneCommitRevert,
    CallV2FirstActualAppWiringTouchpointRollback.keepRolloutFalse,
    CallV2FirstActualAppWiringTouchpointRollback.keepNoOpWhileFalse,
    CallV2FirstActualAppWiringTouchpointRollback.keepRuntimeUnstarted,
    CallV2FirstActualAppWiringTouchpointRollback.keepNoBackendWrites,
    CallV2FirstActualAppWiringTouchpointRollback.keepNoRtcPermissions,
    CallV2FirstActualAppWiringTouchpointRollback.noDeploymentRequired,
    CallV2FirstActualAppWiringTouchpointRollback.noConfigChanges,
    CallV2FirstActualAppWiringTouchpointRollback.v1Unaffected,
  ],
);
