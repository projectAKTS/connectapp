import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_runtime_startup_owner_hardening_audit.dart';
import 'call_v2_runtime_startup_owner_recognition.dart';

enum CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus {
  humanApprovedPhase7AJ,
  developerOnly,
  rolloutFalse,
  metadataOnly,
  runtimeStartupOwnerRecognitionPass,
  finalStagedPreRuntimeAuditPass,
  runtimeStartupOwnerHardeningPass,
  runtimeStartupOwnerClosed,
  runtimeUnconstructed,
  runtimeNotStarted,
  noRuntimeStartupCall,
  productionCompositionUnconstructed,
  startupBridgeUncalled,
  mainDartUnchanged,
  appRouterUnchanged,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  noBackendFirebaseAccess,
  noFirestoreListeners,
  noFirestoreReads,
  noFirestoreWrites,
  noAuthFunctionsAppCheck,
  noRtcPermissionMediaDeviceAccess,
  noNavigatorWiring,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2RuntimeStartupOwnerRecognitionHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RuntimeStartupOwnerRecognitionHardeningAudit {
  factory CallV2RuntimeStartupOwnerRecognitionHardeningAudit({
    required List<CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus>
        statuses,
    required List<CallV2RuntimeStartupOwnerRecognitionHardeningRollback>
        rollback,
  }) {
    return CallV2RuntimeStartupOwnerRecognitionHardeningAudit._(
      List<CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus>.unmodifiable(
          statuses),
      List<CallV2RuntimeStartupOwnerRecognitionHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2RuntimeStartupOwnerRecognitionHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus> statuses;
  final List<CallV2RuntimeStartupOwnerRecognitionHardeningRollback> rollback;

  CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision get decision {
    return passes
        ? CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.pass
        : CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsHumanApprovedPhase7AJ &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsRuntimeStartupOwnerRecognitionPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsRuntimeStartupOwnerHardeningPass &&
      recordsRuntimeStartupOwnerClosed &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsNoRuntimeStartupCall &&
      recordsProductionCompositionUnconstructed &&
      recordsStartupBridgeUncalled &&
      recordsMainDartUnchanged &&
      recordsAppRouterUnchanged &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsNoBackendFirebaseAccess &&
      recordsNoFirestoreListeners &&
      recordsNoFirestoreReads &&
      recordsNoFirestoreWrites &&
      recordsNoAuthFunctionsAppCheck &&
      recordsNoRtcPermissionMediaDeviceAccess &&
      recordsNoNavigatorWiring &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsHumanApprovedPhase7AJ =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .humanApprovedPhase7AJ,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsHumanApprovedPhase7AJ;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.developerOnly,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RuntimeStartupOwnerRecognition.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.metadataOnly,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsMetadataOnly;

  bool get recordsRuntimeStartupOwnerRecognitionPass =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .runtimeStartupOwnerRecognitionPass,
      ) &&
      callV2RuntimeStartupOwnerRecognition.decision ==
          CallV2RuntimeStartupOwnerRecognitionDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsRuntimeStartupOwnerHardeningPass =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .runtimeStartupOwnerHardeningPass,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.decision ==
          CallV2RuntimeStartupOwnerHardeningAuditDecision.pass;

  bool get recordsRuntimeStartupOwnerClosed =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .runtimeStartupOwnerClosed,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsRuntimeStartupOwnerClosed &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsHardDisabled &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsUnreachable;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .runtimeUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .runtimeNotStarted,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsRuntimeNotStarted;

  bool get recordsNoRuntimeStartupCall =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noRuntimeStartupCall,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsNoRuntimeStartupCall;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerRecognition
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .startupBridgeUncalled,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsStartupBridgeUncalled;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .mainDartUnchanged,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsMainDartUnchanged;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .appRouterUnchanged,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsAppRouterUnchanged;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .routesUnreachable,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .disabledRegistryNull,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsDisabledRegistryNull;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noBackendFirebaseAccess,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsNoBackendFirebaseAccess;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noFirestoreListeners,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noFirestoreReads,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noFirestoreWrites,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoFirestoreWrites;

  bool get recordsNoAuthFunctionsAppCheck =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noAuthFunctionsAppCheck,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoAuthFunctionsAppCheck;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2RuntimeStartupOwnerRecognition
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noNavigatorWiring,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.noAsyncHandles,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2RuntimeStartupOwnerRecognition
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.noDeployment,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningRollback
            .keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningRollback
            .keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningRollback.v1Unaffected,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsRollbackOneCommit &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRollbackOneCommit;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.v1Protected,
      ) &&
      callV2RuntimeStartupOwnerRecognition.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'approvalRecorded': recordsHumanApprovedPhase7AJ,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'recognitionPass': recordsRuntimeStartupOwnerRecognitionPass,
      'finalStagedPreRuntimeAuditPass': recordsFinalStagedPreRuntimeAuditPass,
      'runtimeStartupOwnerHardeningPass':
          recordsRuntimeStartupOwnerHardeningPass,
      'runtimeStartupOwnerClosed': recordsRuntimeStartupOwnerClosed,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'runtimeStartupCalled': false,
      'productionCompositionConstructed': false,
      'startupBridgeCalled': false,
      'routesReachable': false,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2RuntimeStartupOwnerRecognitionHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2RuntimeStartupOwnerRecognitionHardeningAudit =
    CallV2RuntimeStartupOwnerRecognitionHardeningAudit(
  statuses: <CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus>[
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .humanApprovedPhase7AJ,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.developerOnly,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.rolloutFalse,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.metadataOnly,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .runtimeStartupOwnerRecognitionPass,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .finalStagedPreRuntimeAuditPass,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .runtimeStartupOwnerHardeningPass,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .runtimeStartupOwnerClosed,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .runtimeUnconstructed,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.runtimeNotStarted,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .noRuntimeStartupCall,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .productionCompositionUnconstructed,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .startupBridgeUncalled,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.mainDartUnchanged,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.appRouterUnchanged,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.routesUnreachable,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .routeResolverNullWhileFalse,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .disabledRegistryNull,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .noBackendFirebaseAccess,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .noFirestoreListeners,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.noFirestoreReads,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.noFirestoreWrites,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .noAuthFunctionsAppCheck,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.noNavigatorWiring,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .noLifecycleRegistration,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.noAsyncHandles,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.noDeployment,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.rollbackOneCommit,
    CallV2RuntimeStartupOwnerRecognitionHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2RuntimeStartupOwnerRecognitionHardeningRollback>[
    CallV2RuntimeStartupOwnerRecognitionHardeningRollback.oneCommitRevert,
    CallV2RuntimeStartupOwnerRecognitionHardeningRollback.keepRolloutFalse,
    CallV2RuntimeStartupOwnerRecognitionHardeningRollback.keepRouteRegistryNull,
    CallV2RuntimeStartupOwnerRecognitionHardeningRollback
        .keepDisabledOwnerInert,
    CallV2RuntimeStartupOwnerRecognitionHardeningRollback.noDeploymentRequired,
    CallV2RuntimeStartupOwnerRecognitionHardeningRollback.noConfigChanges,
    CallV2RuntimeStartupOwnerRecognitionHardeningRollback.v1Unaffected,
  ],
);
