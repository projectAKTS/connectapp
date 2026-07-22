import 'call_v2_disabled_runtime_preflight_boundary.dart';
import 'call_v2_disabled_runtime_preflight_boundary_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2DisabledRuntimeConstructionGateStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  runtimeConstructionGatePresent,
  noOpWhileRolloutFalse,
  runtimePreflightBoundaryPass,
  runtimePreflightHardeningAuditPass,
  productionExposureBlocked,
  publicRouteReachabilityBlocked,
  callV2ScreenExposureBlocked,
  runtimeConstructionBlocked,
  runtimeStartBlocked,
  runtimeInstanceUnavailable,
  runtimeInstanceCreationBlocked,
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

enum CallV2DisabledRuntimeConstructionGateDecision {
  pass,
  blocked,
}

enum CallV2DisabledRuntimeConstructionGateRollback {
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

final class CallV2DisabledRuntimeConstructionGate {
  factory CallV2DisabledRuntimeConstructionGate({
    required List<CallV2DisabledRuntimeConstructionGateStatus> statuses,
    required List<CallV2DisabledRuntimeConstructionGateRollback> rollback,
  }) {
    return CallV2DisabledRuntimeConstructionGate._(
      List<CallV2DisabledRuntimeConstructionGateStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2DisabledRuntimeConstructionGateRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2DisabledRuntimeConstructionGate._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2DisabledRuntimeConstructionGateStatus> statuses;
  final List<CallV2DisabledRuntimeConstructionGateRollback> rollback;

  CallV2DisabledRuntimeConstructionGateDecision get decision {
    return passes
        ? CallV2DisabledRuntimeConstructionGateDecision.pass
        : CallV2DisabledRuntimeConstructionGateDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsRuntimeConstructionGatePresent &&
      recordsNoOpWhileRolloutFalse &&
      recordsRuntimePreflightBoundaryPass &&
      recordsRuntimePreflightHardeningAuditPass &&
      recordsProductionExposureBlocked &&
      recordsPublicRouteReachabilityBlocked &&
      recordsCallV2ScreenExposureBlocked &&
      recordsRuntimeConstructionBlocked &&
      recordsRuntimeStartBlocked &&
      recordsRuntimeInstanceUnavailable &&
      recordsRuntimeInstanceCreationBlocked &&
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
        CallV2DisabledRuntimeConstructionGateStatus.humanApproved,
      );

  bool get recordsDeveloperOnly => statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.developerOnly,
      );

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimePreflightBoundary.recordsRolloutFalse &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit.recordsRolloutFalse;

  bool get recordsRuntimeConstructionGatePresent => statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .runtimeConstructionGatePresent,
      );

  bool get recordsNoOpWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.noOpWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsRuntimePreflightBoundaryPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .runtimePreflightBoundaryPass,
      ) &&
      callV2DisabledRuntimePreflightBoundary.decision ==
          CallV2DisabledRuntimePreflightBoundaryDecision.pass;

  bool get recordsRuntimePreflightHardeningAuditPass =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .runtimePreflightHardeningAuditPass,
      ) &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit.decision ==
          CallV2DisabledRuntimePreflightBoundaryHardeningAuditDecision.pass;

  bool get recordsProductionExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.productionExposureBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsProductionExposureBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsPublicRouteReachabilityBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.callV2ScreenExposureBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsCallV2ScreenExposureBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsCallV2ScreenExposureBlocked;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.runtimeConstructionBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsRuntimeConstructionBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.runtimeStartBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRuntimeStartBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRuntimeStartBlocked;

  bool get recordsRuntimeInstanceUnavailable =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.runtimeInstanceUnavailable,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsRuntimeInstanceUnavailable &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRuntimeInstanceUnavailable;

  bool get recordsRuntimeInstanceCreationBlocked => statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .runtimeInstanceCreationBlocked,
      );

  bool get recordsProductionStartupBridgeBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .productionStartupBridgeBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsProductionStartupBridgeBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsProductionStartupBridgeBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.startupBridgeCallBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsStartupBridgeCallBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.backendWritesBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsBackendWritesBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.backendReadsBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsBackendReadsBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.firestoreListenersBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsFirestoreListenersBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsAuthFunctionsAppCheckBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.rtcInitializationBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRtcInitializationBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.rtcEngineCreationBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRtcEngineCreationBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.rtcChannelJoinBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsRtcChannelJoinBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsRtcTokenChannelConsumptionBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.permissionRequestsBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsPermissionRequestsBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.capturePromptBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsCapturePromptBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.mediaDeviceAccessBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsMediaDeviceAccessBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.navigatorWiringBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsNavigatorWiringBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsNavigatorWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.navigatorCallsBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsNavigatorCallsBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsLifecycleRegistrationBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsLifecycleRegistrationBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.asyncHandlesBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsAsyncHandlesBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNotCalledWhileRolloutFalse =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .routeResolverNotCalledWhileRolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2DisabledRuntimePreflightBoundary
          .recordsRouteResolverNotCalledWhileRolloutFalse &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsRouteResolverNotCalledWhileRolloutFalse;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.deploymentBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsDeploymentBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2DisabledRuntimePreflightBoundary
          .recordsConfigPlatformChangesBlocked &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit
          .recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.keepRuntimeUnavailable,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.keepRuntimeUncreated,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2DisabledRuntimeConstructionGateRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2DisabledRuntimeConstructionGateStatus.v1Protected,
      ) &&
      callV2DisabledRuntimePreflightBoundary.recordsV1Protected &&
      callV2DisabledRuntimePreflightBoundaryHardeningAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'gatePresent': recordsRuntimeConstructionGatePresent,
      'noOpWhileRolloutFalse': recordsNoOpWhileRolloutFalse,
      'preflightPass': recordsRuntimePreflightBoundaryPass,
      'preflightAuditPass': recordsRuntimePreflightHardeningAuditPass,
      'productionExposureBlocked': recordsProductionExposureBlocked,
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
    return 'CallV2DisabledRuntimeConstructionGate(${toSafeDebugMap()})';
  }
}

CallV2DisabledRuntimeConstructionGate
    executeCallV2DisabledRuntimeConstructionGateSafely() {
  return callV2DisabledRuntimeConstructionGate;
}

final callV2DisabledRuntimeConstructionGate =
    CallV2DisabledRuntimeConstructionGate(
  statuses: <CallV2DisabledRuntimeConstructionGateStatus>[
    CallV2DisabledRuntimeConstructionGateStatus.humanApproved,
    CallV2DisabledRuntimeConstructionGateStatus.developerOnly,
    CallV2DisabledRuntimeConstructionGateStatus.rolloutFalse,
    CallV2DisabledRuntimeConstructionGateStatus.runtimeConstructionGatePresent,
    CallV2DisabledRuntimeConstructionGateStatus.noOpWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionGateStatus.runtimePreflightBoundaryPass,
    CallV2DisabledRuntimeConstructionGateStatus
        .runtimePreflightHardeningAuditPass,
    CallV2DisabledRuntimeConstructionGateStatus.productionExposureBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.publicRouteReachabilityBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.callV2ScreenExposureBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.runtimeConstructionBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.runtimeStartBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.runtimeInstanceUnavailable,
    CallV2DisabledRuntimeConstructionGateStatus.runtimeInstanceCreationBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.productionStartupBridgeBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.startupBridgeCallBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.backendWritesBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.backendReadsBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.firestoreListenersBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.authFunctionsAppCheckBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.rtcInitializationBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.rtcEngineCreationBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.rtcChannelJoinBlocked,
    CallV2DisabledRuntimeConstructionGateStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.permissionRequestsBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.capturePromptBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.mediaDeviceAccessBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.navigatorWiringBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.navigatorCallsBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.lifecycleRegistrationBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.asyncHandlesBlocked,
    CallV2DisabledRuntimeConstructionGateStatus
        .routeResolverNotCalledWhileRolloutFalse,
    CallV2DisabledRuntimeConstructionGateStatus.deploymentBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.configPlatformChangesBlocked,
    CallV2DisabledRuntimeConstructionGateStatus.rollbackOneCommit,
    CallV2DisabledRuntimeConstructionGateStatus.v1Protected,
  ],
  rollback: <CallV2DisabledRuntimeConstructionGateRollback>[
    CallV2DisabledRuntimeConstructionGateRollback.oneCommitRevert,
    CallV2DisabledRuntimeConstructionGateRollback.keepRolloutFalse,
    CallV2DisabledRuntimeConstructionGateRollback.keepNoOpWhileFalse,
    CallV2DisabledRuntimeConstructionGateRollback.keepRuntimeUnavailable,
    CallV2DisabledRuntimeConstructionGateRollback.keepRuntimeUnstarted,
    CallV2DisabledRuntimeConstructionGateRollback.keepRuntimeUncreated,
    CallV2DisabledRuntimeConstructionGateRollback.keepNoBackendWrites,
    CallV2DisabledRuntimeConstructionGateRollback.keepNoRtcPermissions,
    CallV2DisabledRuntimeConstructionGateRollback.noDeploymentRequired,
    CallV2DisabledRuntimeConstructionGateRollback.noConfigChanges,
    CallV2DisabledRuntimeConstructionGateRollback.v1Unaffected,
  ],
);
