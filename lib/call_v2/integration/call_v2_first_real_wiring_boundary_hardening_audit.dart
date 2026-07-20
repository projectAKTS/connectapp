import 'call_v2_final_owner_recognition_consolidation_audit.dart';
import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_first_real_wiring_boundary.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2FirstRealWiringBoundaryHardeningAuditStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  boundaryDecisionPass,
  productionExposureBlocked,
  publicRouteReachabilityBlocked,
  finalOwnerRecognitionConsolidationPass,
  finalStagedPreRuntimeAuditPass,
  metadataToWiringBoundaryOnly,
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
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  deploymentBlocked,
  configPlatformChangesBlocked,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2FirstRealWiringBoundaryHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2FirstRealWiringBoundaryHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepRuntimeUnstarted,
  keepNoBackendWrites,
  keepNoRtcPermissions,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2FirstRealWiringBoundaryHardeningAudit {
  factory CallV2FirstRealWiringBoundaryHardeningAudit({
    required List<CallV2FirstRealWiringBoundaryHardeningAuditStatus> statuses,
    required List<CallV2FirstRealWiringBoundaryHardeningRollback> rollback,
  }) {
    return CallV2FirstRealWiringBoundaryHardeningAudit._(
      List<CallV2FirstRealWiringBoundaryHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2FirstRealWiringBoundaryHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2FirstRealWiringBoundaryHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2FirstRealWiringBoundaryHardeningAuditStatus> statuses;
  final List<CallV2FirstRealWiringBoundaryHardeningRollback> rollback;

  CallV2FirstRealWiringBoundaryHardeningAuditDecision get decision {
    return passes
        ? CallV2FirstRealWiringBoundaryHardeningAuditDecision.pass
        : CallV2FirstRealWiringBoundaryHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsBoundaryDecisionPass &&
      recordsProductionExposureBlocked &&
      recordsPublicRouteReachabilityBlocked &&
      recordsFinalOwnerRecognitionConsolidationPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsMetadataToWiringBoundaryOnly &&
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
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsDeploymentBlocked &&
      recordsConfigPlatformChangesBlocked &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsHumanApproval =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.humanApproved,
      ) &&
      callV2FirstRealWiringBoundary.recordsHumanApproval;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.developerOnly,
      ) &&
      callV2FirstRealWiringBoundary.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2FirstRealWiringBoundary.recordsRolloutFalse;

  bool get recordsBoundaryDecisionPass =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.boundaryDecisionPass,
      ) &&
      callV2FirstRealWiringBoundary.decision ==
          CallV2FirstRealWiringBoundaryDecision.pass;

  bool get recordsProductionExposureBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .productionExposureBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsProductionExposureBlocked;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsPublicRouteReachabilityBlocked;

  bool get recordsFinalOwnerRecognitionConsolidationPass =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .finalOwnerRecognitionConsolidationPass,
      ) &&
      callV2FirstRealWiringBoundary
          .recordsFinalOwnerRecognitionConsolidationPass &&
      callV2FinalOwnerRecognitionConsolidationAudit.decision ==
          CallV2FinalOwnerRecognitionConsolidationAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FirstRealWiringBoundary.recordsFinalStagedPreRuntimeAuditPass &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsMetadataToWiringBoundaryOnly =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .metadataToWiringBoundaryOnly,
      ) &&
      callV2FirstRealWiringBoundary.recordsMetadataToWiringBoundaryOnly;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.runtimeStartBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRuntimeStartBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.backendWritesBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.backendReadsBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .firestoreListenersBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .rtcInitializationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.rtcChannelJoinBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .permissionRequestsBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.capturePromptBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .navigatorWiringBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsNavigatorWiringBlocked;

  bool get recordsNavigatorKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .navigatorKeyCreationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsNavigatorKeyCreationBlocked;

  bool get recordsGlobalKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .globalKeyCreationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsGlobalKeyCreationBlocked;

  bool get recordsBuildContextStorageBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .buildContextStorageBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsBuildContextStorageBlocked;

  bool get recordsMaterialAppRouteWiringBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .materialAppRouteWiringBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsMaterialAppRouteWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.navigatorCallsBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsLifecycleRegistrationBlocked;

  bool get recordsAppLifecycleListenerBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .appLifecycleListenerBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsAppLifecycleListenerBlocked;

  bool get recordsWidgetsBindingObserverBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .widgetsBindingObserverBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsWidgetsBindingObserverBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.asyncHandlesBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsAsyncHandlesBlocked;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2FirstRealWiringBoundary.recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.disabledRegistryNull,
      ) &&
      callV2FirstRealWiringBoundary.recordsDisabledRegistryNull;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.deploymentBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2FirstRealWiringBoundary.recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryHardeningRollback.v1Unaffected,
      ) &&
      callV2FirstRealWiringBoundary.recordsRollbackOneCommit;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryHardeningAuditStatus.v1Protected,
      ) &&
      callV2FirstRealWiringBoundary.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'boundaryPass': recordsBoundaryDecisionPass,
      'productionExposureBlocked': recordsProductionExposureBlocked,
      'publicRoutesReachable': false,
      'ownerRecognitionPass': recordsFinalOwnerRecognitionConsolidationPass,
      'preRuntimePass': recordsFinalStagedPreRuntimeAuditPass,
      'metadataBoundaryOnly': recordsMetadataToWiringBoundaryOnly,
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
      'resolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'deploymentChanged': false,
      'configPlatformChanged': false,
      'rollbackOneCommit': recordsRollbackOneCommit,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2FirstRealWiringBoundaryHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2FirstRealWiringBoundaryHardeningAudit =
    CallV2FirstRealWiringBoundaryHardeningAudit(
  statuses: <CallV2FirstRealWiringBoundaryHardeningAuditStatus>[
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.humanApproved,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.developerOnly,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.rolloutFalse,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.boundaryDecisionPass,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.productionExposureBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .finalOwnerRecognitionConsolidationPass,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .finalStagedPreRuntimeAuditPass,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .metadataToWiringBoundaryOnly,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.runtimeStartBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.startupBridgeCallBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.backendWritesBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.backendReadsBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.firestoreListenersBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.rtcInitializationBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.rtcEngineCreationBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.rtcChannelJoinBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.permissionRequestsBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.capturePromptBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.mediaDeviceAccessBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.navigatorWiringBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .navigatorKeyCreationBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.globalKeyCreationBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .buildContextStorageBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .materialAppRouteWiringBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.navigatorCallsBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .appLifecycleListenerBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .widgetsBindingObserverBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.asyncHandlesBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .routeResolverNullWhileFalse,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.disabledRegistryNull,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.deploymentBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.rollbackOneCommit,
    CallV2FirstRealWiringBoundaryHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2FirstRealWiringBoundaryHardeningRollback>[
    CallV2FirstRealWiringBoundaryHardeningRollback.oneCommitRevert,
    CallV2FirstRealWiringBoundaryHardeningRollback.keepRolloutFalse,
    CallV2FirstRealWiringBoundaryHardeningRollback.keepRouteRegistryNull,
    CallV2FirstRealWiringBoundaryHardeningRollback.keepRuntimeUnstarted,
    CallV2FirstRealWiringBoundaryHardeningRollback.keepNoBackendWrites,
    CallV2FirstRealWiringBoundaryHardeningRollback.keepNoRtcPermissions,
    CallV2FirstRealWiringBoundaryHardeningRollback.noDeploymentRequired,
    CallV2FirstRealWiringBoundaryHardeningRollback.noConfigChanges,
    CallV2FirstRealWiringBoundaryHardeningRollback.v1Unaffected,
  ],
);
