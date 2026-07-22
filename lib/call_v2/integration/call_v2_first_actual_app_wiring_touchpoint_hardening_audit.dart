import 'call_v2_first_actual_app_wiring_touchpoint.dart';
import 'call_v2_first_real_wiring_boundary.dart';
import 'call_v2_first_real_wiring_boundary_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2FirstActualAppWiringTouchpointHardeningAuditStatus {
  humanApproved,
  developerOnly,
  rolloutFalse,
  touchpointDecisionPass,
  initializerInert,
  mainDartImportSingle,
  mainDartInitializerSingleBeforeRunApp,
  resolverGatedBehindRollout,
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
  deploymentBlocked,
  configPlatformChangesBlocked,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2FirstActualAppWiringTouchpointHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2FirstActualAppWiringTouchpointHardeningRollback {
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

final class CallV2FirstActualAppWiringTouchpointHardeningAudit {
  factory CallV2FirstActualAppWiringTouchpointHardeningAudit({
    required List<CallV2FirstActualAppWiringTouchpointHardeningAuditStatus>
        statuses,
    required List<CallV2FirstActualAppWiringTouchpointHardeningRollback>
        rollback,
  }) {
    return CallV2FirstActualAppWiringTouchpointHardeningAudit._(
      List<CallV2FirstActualAppWiringTouchpointHardeningAuditStatus>.unmodifiable(
          statuses),
      List<CallV2FirstActualAppWiringTouchpointHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2FirstActualAppWiringTouchpointHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2FirstActualAppWiringTouchpointHardeningAuditStatus> statuses;
  final List<CallV2FirstActualAppWiringTouchpointHardeningRollback> rollback;

  CallV2FirstActualAppWiringTouchpointHardeningAuditDecision get decision {
    return passes
        ? CallV2FirstActualAppWiringTouchpointHardeningAuditDecision.pass
        : CallV2FirstActualAppWiringTouchpointHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsHumanApproval &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsTouchpointDecisionPass &&
      recordsInitializerInert &&
      recordsMainDartImportSingle &&
      recordsMainDartInitializerSingleBeforeRunApp &&
      recordsResolverGatedBehindRollout &&
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
      recordsDeploymentBlocked &&
      recordsConfigPlatformChangesBlocked &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsHumanApproval =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.humanApproved,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsHumanApproval;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.developerOnly,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2FirstActualAppWiringTouchpoint.recordsRolloutFalse;

  bool get recordsTouchpointDecisionPass =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .touchpointDecisionPass,
      ) &&
      callV2FirstActualAppWiringTouchpoint.decision ==
          CallV2FirstActualAppWiringTouchpointDecision.pass;

  bool get recordsInitializerInert =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .initializerInert,
      ) &&
      identical(
        initializeCallV2FirstActualAppWiringTouchpointSafely(),
        callV2FirstActualAppWiringTouchpoint,
      );

  bool get recordsMainDartImportSingle => statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .mainDartImportSingle,
      );

  bool get recordsMainDartInitializerSingleBeforeRunApp => statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .mainDartInitializerSingleBeforeRunApp,
      );

  bool get recordsResolverGatedBehindRollout => statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .resolverGatedBehindRollout,
      );

  bool get recordsProductionExposureBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .productionExposureBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsProductionExposureBlocked;

  bool get recordsPublicRouteReachabilityBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .publicRouteReachabilityBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint
          .recordsPublicRouteReachabilityBlocked;

  bool get recordsCallV2ScreenExposureBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .callV2ScreenExposureBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsCallV2ScreenExposureBlocked;

  bool get recordsFirstRealWiringBoundaryPass =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .firstRealWiringBoundaryPass,
      ) &&
      callV2FirstRealWiringBoundary.decision ==
          CallV2FirstRealWiringBoundaryDecision.pass &&
      callV2FirstActualAppWiringTouchpoint.recordsFirstRealWiringBoundaryPass;

  bool get recordsFirstRealWiringBoundaryHardeningAuditPass =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .firstRealWiringBoundaryHardeningAuditPass,
      ) &&
      callV2FirstRealWiringBoundaryHardeningAudit.decision ==
          CallV2FirstRealWiringBoundaryHardeningAuditDecision.pass &&
      callV2FirstActualAppWiringTouchpoint
          .recordsFirstRealWiringBoundaryHardeningAuditPass;

  bool get recordsRuntimeConstructionBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .runtimeConstructionBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRuntimeConstructionBlocked;

  bool get recordsRuntimeStartBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .runtimeStartBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRuntimeStartBlocked;

  bool get recordsStartupBridgeCallBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .startupBridgeCallBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsStartupBridgeCallBlocked;

  bool get recordsBackendWritesBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .backendWritesBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsBackendWritesBlocked;

  bool get recordsBackendReadsBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .backendReadsBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsBackendReadsBlocked;

  bool get recordsFirestoreListenersBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .firestoreListenersBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsFirestoreListenersBlocked;

  bool get recordsAuthFunctionsAppCheckBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .authFunctionsAppCheckBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsAuthFunctionsAppCheckBlocked;

  bool get recordsRtcInitializationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .rtcInitializationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRtcInitializationBlocked;

  bool get recordsRtcEngineCreationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .rtcEngineCreationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRtcEngineCreationBlocked;

  bool get recordsRtcChannelJoinBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .rtcChannelJoinBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRtcChannelJoinBlocked;

  bool get recordsRtcTokenChannelConsumptionBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .rtcTokenChannelConsumptionBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint
          .recordsRtcTokenChannelConsumptionBlocked;

  bool get recordsPermissionRequestsBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .permissionRequestsBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsPermissionRequestsBlocked;

  bool get recordsCapturePromptBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .capturePromptBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsCapturePromptBlocked;

  bool get recordsMediaDeviceAccessBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .mediaDeviceAccessBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsMediaDeviceAccessBlocked;

  bool get recordsNavigatorWiringBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .navigatorWiringBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsNavigatorWiringBlocked;

  bool get recordsNavigatorKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .navigatorKeyCreationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsNavigatorKeyCreationBlocked;

  bool get recordsGlobalKeyCreationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .globalKeyCreationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsGlobalKeyCreationBlocked;

  bool get recordsBuildContextStorageBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .buildContextStorageBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsBuildContextStorageBlocked;

  bool get recordsMaterialAppRouteWiringBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .materialAppRouteWiringBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsMaterialAppRouteWiringBlocked;

  bool get recordsNavigatorCallsBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .navigatorCallsBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsNavigatorCallsBlocked;

  bool get recordsLifecycleRegistrationBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .lifecycleRegistrationBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsLifecycleRegistrationBlocked;

  bool get recordsAppLifecycleListenerBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .appLifecycleListenerBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsAppLifecycleListenerBlocked;

  bool get recordsWidgetsBindingObserverBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .widgetsBindingObserverBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsWidgetsBindingObserverBlocked;

  bool get recordsAsyncHandlesBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .asyncHandlesBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsAsyncHandlesBlocked;

  bool get recordsDeploymentBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .deploymentBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsDeploymentBlocked;

  bool get recordsConfigPlatformChangesBlocked =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .configPlatformChangesBlocked,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsConfigPlatformChangesBlocked;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback
            .keepNoOpWhileFalse,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback
            .keepRuntimeUnstarted,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback
            .keepNoBackendWrites,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback
            .keepNoRtcPermissions,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2FirstActualAppWiringTouchpointHardeningRollback.v1Unaffected,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsRollbackOneCommit;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.v1Protected,
      ) &&
      callV2FirstActualAppWiringTouchpoint.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'approved': recordsHumanApproval,
      'developerOnly': recordsDeveloperOnly,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'touchpointPass': recordsTouchpointDecisionPass,
      'initializerInert': recordsInitializerInert,
      'mainImportSingle': recordsMainDartImportSingle,
      'mainCallSingleBeforeRunApp':
          recordsMainDartInitializerSingleBeforeRunApp,
      'resolverGated': recordsResolverGatedBehindRollout,
      'productionExposureBlocked': recordsProductionExposureBlocked,
      'publicReachable': false,
      'screenExposed': false,
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
      'deploymentChanged': false,
      'configPlatformChanged': false,
      'rollbackOneCommit': recordsRollbackOneCommit,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2FirstActualAppWiringTouchpointHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2FirstActualAppWiringTouchpointHardeningAudit =
    CallV2FirstActualAppWiringTouchpointHardeningAudit(
  statuses: <CallV2FirstActualAppWiringTouchpointHardeningAuditStatus>[
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.humanApproved,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.developerOnly,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.rolloutFalse,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .touchpointDecisionPass,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.initializerInert,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .mainDartImportSingle,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .mainDartInitializerSingleBeforeRunApp,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .resolverGatedBehindRollout,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .productionExposureBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .publicRouteReachabilityBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .callV2ScreenExposureBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .firstRealWiringBoundaryPass,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .firstRealWiringBoundaryHardeningAuditPass,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .runtimeConstructionBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .runtimeStartBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .startupBridgeCallBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .backendWritesBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .backendReadsBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .firestoreListenersBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .authFunctionsAppCheckBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .rtcInitializationBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .rtcEngineCreationBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .rtcChannelJoinBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .rtcTokenChannelConsumptionBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .permissionRequestsBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .capturePromptBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .mediaDeviceAccessBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .navigatorWiringBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .navigatorKeyCreationBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .globalKeyCreationBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .buildContextStorageBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .materialAppRouteWiringBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .navigatorCallsBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .lifecycleRegistrationBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .appLifecycleListenerBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .widgetsBindingObserverBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .asyncHandlesBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.deploymentBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus
        .configPlatformChangesBlocked,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.rollbackOneCommit,
    CallV2FirstActualAppWiringTouchpointHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2FirstActualAppWiringTouchpointHardeningRollback>[
    CallV2FirstActualAppWiringTouchpointHardeningRollback.oneCommitRevert,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.keepRolloutFalse,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.keepNoOpWhileFalse,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.keepRuntimeUnstarted,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.keepNoBackendWrites,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.keepNoRtcPermissions,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.noDeploymentRequired,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.noConfigChanges,
    CallV2FirstActualAppWiringTouchpointHardeningRollback.v1Unaffected,
  ],
);
