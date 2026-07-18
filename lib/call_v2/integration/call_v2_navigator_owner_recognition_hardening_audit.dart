import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_navigator_owner_hardening_audit.dart';
import 'call_v2_navigator_owner_recognition.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_rtc_permission_owner_recognition_hardening_audit.dart';

enum CallV2NavigatorOwnerRecognitionHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  navigatorOwnerRecognitionPass,
  rtcPermissionRecognitionHardeningPass,
  finalStagedPreRuntimeAuditPass,
  navigatorOwnerHardeningPass,
  navigatorOwnerClosed,
  noNavigatorWiring,
  noNavigatorKey,
  noGlobalKey,
  noBuildContextStored,
  noMaterialAppRouteWiring,
  noNavigatorCalls,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  runtimeUnconstructed,
  runtimeNotStarted,
  productionCompositionUnconstructed,
  startupBridgeUncalled,
  noBackendFirebaseAccess,
  noRtcPermissionMediaDeviceAccess,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2NavigatorOwnerRecognitionHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2NavigatorOwnerRecognitionHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2NavigatorOwnerRecognitionHardeningAudit {
  factory CallV2NavigatorOwnerRecognitionHardeningAudit({
    required List<CallV2NavigatorOwnerRecognitionHardeningAuditStatus> statuses,
    required List<CallV2NavigatorOwnerRecognitionHardeningRollback> rollback,
  }) {
    return CallV2NavigatorOwnerRecognitionHardeningAudit._(
      List<CallV2NavigatorOwnerRecognitionHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2NavigatorOwnerRecognitionHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2NavigatorOwnerRecognitionHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2NavigatorOwnerRecognitionHardeningAuditStatus> statuses;
  final List<CallV2NavigatorOwnerRecognitionHardeningRollback> rollback;

  CallV2NavigatorOwnerRecognitionHardeningAuditDecision get decision {
    return passes
        ? CallV2NavigatorOwnerRecognitionHardeningAuditDecision.pass
        : CallV2NavigatorOwnerRecognitionHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsNavigatorOwnerRecognitionPass &&
      recordsRtcPermissionRecognitionHardeningPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsNavigatorOwnerHardeningPass &&
      recordsNavigatorOwnerClosed &&
      recordsNoNavigatorWiring &&
      recordsNoNavigatorKey &&
      recordsNoGlobalKey &&
      recordsNoBuildContextStored &&
      recordsNoMaterialAppRouteWiring &&
      recordsNoNavigatorCalls &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsProductionCompositionUnconstructed &&
      recordsStartupBridgeUncalled &&
      recordsNoBackendFirebaseAccess &&
      recordsNoRtcPermissionMediaDeviceAccess &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.developerOnly,
      ) &&
      callV2NavigatorOwnerRecognition.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2NavigatorOwnerRecognition.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.metadataOnly,
      ) &&
      callV2NavigatorOwnerRecognition.recordsMetadataOnly;

  bool get recordsNavigatorOwnerRecognitionPass =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .navigatorOwnerRecognitionPass,
      ) &&
      callV2NavigatorOwnerRecognition.decision ==
          CallV2NavigatorOwnerRecognitionDecision.pass;

  bool get recordsRtcPermissionRecognitionHardeningPass =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .rtcPermissionRecognitionHardeningPass,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.decision ==
          CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsNavigatorOwnerHardeningPass =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .navigatorOwnerHardeningPass,
      ) &&
      callV2NavigatorOwnerHardeningAudit.decision ==
          CallV2NavigatorOwnerHardeningAuditDecision.pass;

  bool get recordsNavigatorOwnerClosed =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .navigatorOwnerClosed,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNavigatorOwnerClosed &&
      callV2NavigatorOwnerHardeningAudit.recordsHardDisabled &&
      callV2NavigatorOwnerHardeningAudit.recordsUnreachable &&
      callV2NavigatorOwnerHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noNavigatorWiring,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoNavigatorWiring;

  bool get recordsNoNavigatorKey =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noNavigatorKey,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoNavigatorKey;

  bool get recordsNoGlobalKey =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noGlobalKey,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoGlobalKey;

  bool get recordsNoBuildContextStored =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .noBuildContextStored,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoBuildContextStored;

  bool get recordsNoMaterialAppRouteWiring =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .noMaterialAppRouteWiring,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoMaterialAppRouteWiring;

  bool get recordsNoNavigatorCalls =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noNavigatorCalls,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoNavigatorCalls;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.routesUnreachable,
      ) &&
      callV2NavigatorOwnerRecognition.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2NavigatorOwnerRecognition.recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .disabledRegistryNull,
      ) &&
      callV2NavigatorOwnerRecognition.recordsDisabledRegistryNull;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .runtimeUnconstructed,
      ) &&
      callV2NavigatorOwnerRecognition.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.runtimeNotStarted,
      ) &&
      callV2NavigatorOwnerRecognition.recordsRuntimeNotStarted;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2NavigatorOwnerRecognition.recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .startupBridgeUncalled,
      ) &&
      callV2NavigatorOwnerRecognition.recordsStartupBridgeUncalled;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .noBackendFirebaseAccess,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoBackendFirebaseAccess;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noAsyncHandles,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noDeployment,
      ) &&
      callV2NavigatorOwnerRecognition.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerRecognitionHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerRecognitionHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerRecognitionHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerRecognitionHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerRecognitionHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerRecognitionHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerRecognitionHardeningRollback.v1Unaffected,
      ) &&
      callV2NavigatorOwnerRecognition.recordsRollbackOneCommit &&
      callV2NavigatorOwnerHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionHardeningAuditStatus.v1Protected,
      ) &&
      callV2NavigatorOwnerRecognition.recordsV1Protected &&
      callV2NavigatorOwnerHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'recognitionPass': recordsNavigatorOwnerRecognitionPass,
      'rtcRecognitionHardeningPass':
          recordsRtcPermissionRecognitionHardeningPass,
      'finalStagedPreRuntimeAuditPass': recordsFinalStagedPreRuntimeAuditPass,
      'ownerHardeningPass': recordsNavigatorOwnerHardeningPass,
      'ownerClosed': recordsNavigatorOwnerClosed,
      'navWired': false,
      'appKeyCreated': false,
      'globalKeyCreated': false,
      'widgetContextStored': false,
      'materialRouteTableWired': false,
      'navCalled': false,
      'routesReachable': false,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'backendAccess': false,
      'rtcPermissionAccess': false,
      'lifecycleRegistered': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2NavigatorOwnerRecognitionHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2NavigatorOwnerRecognitionHardeningAudit =
    CallV2NavigatorOwnerRecognitionHardeningAudit(
  statuses: <CallV2NavigatorOwnerRecognitionHardeningAuditStatus>[
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.developerOnly,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.rolloutFalse,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.metadataOnly,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .navigatorOwnerRecognitionPass,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .rtcPermissionRecognitionHardeningPass,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .finalStagedPreRuntimeAuditPass,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .navigatorOwnerHardeningPass,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.navigatorOwnerClosed,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noNavigatorWiring,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noNavigatorKey,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noGlobalKey,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noBuildContextStored,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .noMaterialAppRouteWiring,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noNavigatorCalls,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.routesUnreachable,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .routeResolverNullWhileFalse,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.disabledRegistryNull,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.runtimeUnconstructed,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.runtimeNotStarted,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .productionCompositionUnconstructed,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.startupBridgeUncalled,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noLifecycleRegistration,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noAsyncHandles,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.noDeployment,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.rollbackOneCommit,
    CallV2NavigatorOwnerRecognitionHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2NavigatorOwnerRecognitionHardeningRollback>[
    CallV2NavigatorOwnerRecognitionHardeningRollback.oneCommitRevert,
    CallV2NavigatorOwnerRecognitionHardeningRollback.keepRolloutFalse,
    CallV2NavigatorOwnerRecognitionHardeningRollback.keepRouteRegistryNull,
    CallV2NavigatorOwnerRecognitionHardeningRollback.keepDisabledOwnerInert,
    CallV2NavigatorOwnerRecognitionHardeningRollback.noDeploymentRequired,
    CallV2NavigatorOwnerRecognitionHardeningRollback.noConfigChanges,
    CallV2NavigatorOwnerRecognitionHardeningRollback.v1Unaffected,
  ],
);
