import 'call_v2_final_owner_recognition_consolidation_audit.dart';
import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2FirstRealWiringBoundaryStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
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

enum CallV2FirstRealWiringBoundaryDecision {
  pass,
  blocked,
}

enum CallV2FirstRealWiringBoundaryRollback {
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

final class CallV2FirstRealWiringBoundary {
  factory CallV2FirstRealWiringBoundary({
    required List<CallV2FirstRealWiringBoundaryStatus> statuses,
    required List<CallV2FirstRealWiringBoundaryRollback> rollback,
  }) {
    return CallV2FirstRealWiringBoundary._(
      List<CallV2FirstRealWiringBoundaryStatus>.unmodifiable(statuses),
      List<CallV2FirstRealWiringBoundaryRollback>.unmodifiable(rollback),
    );
  }

  const CallV2FirstRealWiringBoundary._(this.statuses, this.rollback);

  final List<CallV2FirstRealWiringBoundaryStatus> statuses;
  final List<CallV2FirstRealWiringBoundaryRollback> rollback;

  CallV2FirstRealWiringBoundaryDecision get decision {
    return passes
        ? CallV2FirstRealWiringBoundaryDecision.pass
        : CallV2FirstRealWiringBoundaryDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
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
      statuses.contains(CallV2FirstRealWiringBoundaryStatus.humanApproved);

  bool get recordsDeveloperOnly =>
      statuses.contains(CallV2FirstRealWiringBoundaryStatus.developerOnly) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsDeveloperOnly &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(CallV2FirstRealWiringBoundaryStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsRolloutFalse &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRolloutFalse;

  bool get recordsProductionExposureBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.productionExposureBlocked,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsProductionIntegrationDisabled;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.publicRouteReachabilityBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsRoutesUnreachable &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRoutesUnreachable;

  bool get recordsFinalOwnerRecognitionConsolidationPass =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus
            .finalOwnerRecognitionConsolidationPass,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.decision ==
          CallV2FinalOwnerRecognitionConsolidationAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsMetadataToWiringBoundaryOnly =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.metadataToWiringBoundaryOnly,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsMetadataOnly &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsStagedPreRuntimeOnly;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.runtimeConstructionBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsRuntimeUnconstructed &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRuntimeUnconstructed;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.runtimeStartBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsRuntimeNotStarted &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRuntimeNotStarted;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.startupBridgeCallBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsStartupBridgeUncalled &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoStartupBridgeCall;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.backendWritesBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoFirestoreWrites &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoFirestoreWrites;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.backendReadsBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoFirestoreReads &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoFirestoreReads;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.firestoreListenersBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoFirestoreListeners &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoFirestoreListeners;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.authFunctionsAppCheckBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoAuthFunctionsAppCheck &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoAuthFunctionsAppCheck;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.rtcInitializationBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoRtcInitialized;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.rtcEngineCreationBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoRtcEngineCreated;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.rtcChannelJoinBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoRtcChannelJoined;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoRtcTokenChannelConsumed;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.permissionRequestsBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoPermissionsRequested;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.capturePromptBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoPermissionsRequested;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.mediaDeviceAccessBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoMediaDeviceAccess &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.navigatorWiringBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoNavigatorWiring &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoNavigatorWiring;

  bool get recordsNavigatorKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.navigatorKeyCreationBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoNavigatorKey;

  bool get recordsGlobalKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.globalKeyCreationBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoGlobalKey;

  bool get recordsBuildContextStorageBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.buildContextStorageBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoBuildContextStored;

  bool get recordsMaterialAppRouteWiringBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.materialAppRouteWiringBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoMaterialAppRouteWiring;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.navigatorCallsBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoNavigatorCalls;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.lifecycleRegistrationBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoLifecycleRegistration &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoLifecycleRegistration;

  bool get recordsAppLifecycleListenerBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.appLifecycleListenerBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoAppLifecycleListener;

  bool get recordsWidgetsBindingObserverBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.widgetsBindingObserverBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoWidgetsBindingObserver;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.asyncHandlesBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoAsyncHandles &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoAsyncHandles;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.routeResolverNullWhileFalse,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.disabledRegistryNull,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsDisabledRegistryNull &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsDisabledRegistryNull;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.deploymentBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsNoDeployment &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoDeployment;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.configPlatformChangesBlocked,
      ) &&
      callV2FinalOwnerRecognitionConsolidationAudit
          .recordsNoDependencyPlatformConfigChanges &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2FirstRealWiringBoundaryStatus.rollbackOneCommit,
      ) &&
      rollback
          .contains(CallV2FirstRealWiringBoundaryRollback.oneCommitRevert) &&
      rollback
          .contains(CallV2FirstRealWiringBoundaryRollback.keepRolloutFalse) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryRollback.keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryRollback.keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryRollback.keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2FirstRealWiringBoundaryRollback.noDeploymentRequired,
      ) &&
      rollback
          .contains(CallV2FirstRealWiringBoundaryRollback.noConfigChanges) &&
      rollback.contains(CallV2FirstRealWiringBoundaryRollback.v1Unaffected);

  bool get recordsV1Protected =>
      statuses.contains(CallV2FirstRealWiringBoundaryStatus.v1Protected) &&
      callV2FinalOwnerRecognitionConsolidationAudit.recordsV1Protected &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'humanApproved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
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
    return 'CallV2FirstRealWiringBoundary(${toSafeDebugMap()})';
  }
}

final callV2FirstRealWiringBoundary = CallV2FirstRealWiringBoundary(
  statuses: <CallV2FirstRealWiringBoundaryStatus>[
    CallV2FirstRealWiringBoundaryStatus.humanApproved,
    CallV2FirstRealWiringBoundaryStatus.developerOnly,
    CallV2FirstRealWiringBoundaryStatus.rolloutFalse,
    CallV2FirstRealWiringBoundaryStatus.productionExposureBlocked,
    CallV2FirstRealWiringBoundaryStatus.publicRouteReachabilityBlocked,
    CallV2FirstRealWiringBoundaryStatus.finalOwnerRecognitionConsolidationPass,
    CallV2FirstRealWiringBoundaryStatus.finalStagedPreRuntimeAuditPass,
    CallV2FirstRealWiringBoundaryStatus.metadataToWiringBoundaryOnly,
    CallV2FirstRealWiringBoundaryStatus.runtimeConstructionBlocked,
    CallV2FirstRealWiringBoundaryStatus.runtimeStartBlocked,
    CallV2FirstRealWiringBoundaryStatus.startupBridgeCallBlocked,
    CallV2FirstRealWiringBoundaryStatus.backendWritesBlocked,
    CallV2FirstRealWiringBoundaryStatus.backendReadsBlocked,
    CallV2FirstRealWiringBoundaryStatus.firestoreListenersBlocked,
    CallV2FirstRealWiringBoundaryStatus.authFunctionsAppCheckBlocked,
    CallV2FirstRealWiringBoundaryStatus.rtcInitializationBlocked,
    CallV2FirstRealWiringBoundaryStatus.rtcEngineCreationBlocked,
    CallV2FirstRealWiringBoundaryStatus.rtcChannelJoinBlocked,
    CallV2FirstRealWiringBoundaryStatus.rtcTokenChannelConsumptionBlocked,
    CallV2FirstRealWiringBoundaryStatus.permissionRequestsBlocked,
    CallV2FirstRealWiringBoundaryStatus.capturePromptBlocked,
    CallV2FirstRealWiringBoundaryStatus.mediaDeviceAccessBlocked,
    CallV2FirstRealWiringBoundaryStatus.navigatorWiringBlocked,
    CallV2FirstRealWiringBoundaryStatus.navigatorKeyCreationBlocked,
    CallV2FirstRealWiringBoundaryStatus.globalKeyCreationBlocked,
    CallV2FirstRealWiringBoundaryStatus.buildContextStorageBlocked,
    CallV2FirstRealWiringBoundaryStatus.materialAppRouteWiringBlocked,
    CallV2FirstRealWiringBoundaryStatus.navigatorCallsBlocked,
    CallV2FirstRealWiringBoundaryStatus.lifecycleRegistrationBlocked,
    CallV2FirstRealWiringBoundaryStatus.appLifecycleListenerBlocked,
    CallV2FirstRealWiringBoundaryStatus.widgetsBindingObserverBlocked,
    CallV2FirstRealWiringBoundaryStatus.asyncHandlesBlocked,
    CallV2FirstRealWiringBoundaryStatus.routeResolverNullWhileFalse,
    CallV2FirstRealWiringBoundaryStatus.disabledRegistryNull,
    CallV2FirstRealWiringBoundaryStatus.deploymentBlocked,
    CallV2FirstRealWiringBoundaryStatus.configPlatformChangesBlocked,
    CallV2FirstRealWiringBoundaryStatus.rollbackOneCommit,
    CallV2FirstRealWiringBoundaryStatus.v1Protected,
  ],
  rollback: <CallV2FirstRealWiringBoundaryRollback>[
    CallV2FirstRealWiringBoundaryRollback.oneCommitRevert,
    CallV2FirstRealWiringBoundaryRollback.keepRolloutFalse,
    CallV2FirstRealWiringBoundaryRollback.keepRouteRegistryNull,
    CallV2FirstRealWiringBoundaryRollback.keepRuntimeUnstarted,
    CallV2FirstRealWiringBoundaryRollback.keepNoBackendWrites,
    CallV2FirstRealWiringBoundaryRollback.keepNoRtcPermissions,
    CallV2FirstRealWiringBoundaryRollback.noDeploymentRequired,
    CallV2FirstRealWiringBoundaryRollback.noConfigChanges,
    CallV2FirstRealWiringBoundaryRollback.v1Unaffected,
  ],
);
