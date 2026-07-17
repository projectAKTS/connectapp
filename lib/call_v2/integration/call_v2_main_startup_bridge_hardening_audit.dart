import 'call_v2_app_router_bridge_hardening_audit.dart';
import 'call_v2_final_pre_wiring_consolidation_audit.dart';
import 'call_v2_main_startup_bridge_recognition.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2MainStartupBridgeHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  mainStartupBridgeRecognitionPass,
  mainDartUnchanged,
  noMainDartBridgeImport,
  noMainStartupCall,
  noStartupBridgeCall,
  startupBridgeUnchanged,
  productionIntegrationDisabled,
  disabledOwnerInert,
  productionCompositionUnconstructed,
  runtimeUnconstructed,
  runtimeNotStarted,
  appRouterBridgeHardeningPass,
  finalPreWiringConsolidationPass,
  routeResolverNullWhileFalse,
  routesUnreachable,
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

enum CallV2MainStartupBridgeHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2MainStartupBridgeHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2MainStartupBridgeHardeningAudit {
  factory CallV2MainStartupBridgeHardeningAudit({
    required List<CallV2MainStartupBridgeHardeningAuditStatus> statuses,
    required List<CallV2MainStartupBridgeHardeningRollback> rollback,
  }) {
    return CallV2MainStartupBridgeHardeningAudit._(
      List<CallV2MainStartupBridgeHardeningAuditStatus>.unmodifiable(statuses),
      List<CallV2MainStartupBridgeHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2MainStartupBridgeHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2MainStartupBridgeHardeningAuditStatus> statuses;
  final List<CallV2MainStartupBridgeHardeningRollback> rollback;

  CallV2MainStartupBridgeHardeningAuditDecision get decision {
    return passes
        ? CallV2MainStartupBridgeHardeningAuditDecision.pass
        : CallV2MainStartupBridgeHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsMainStartupBridgeRecognitionPass &&
      recordsMainDartUnchanged &&
      recordsNoMainDartBridgeImport &&
      recordsNoMainStartupCall &&
      recordsNoStartupBridgeCall &&
      recordsStartupBridgeUnchanged &&
      recordsProductionIntegrationDisabled &&
      recordsDisabledOwnerInert &&
      recordsProductionCompositionUnconstructed &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsAppRouterBridgeHardeningPass &&
      recordsFinalPreWiringConsolidationPass &&
      recordsRouteResolverNullWhileFalse &&
      recordsRoutesUnreachable &&
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

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.developerOnly,
      ) &&
      callV2MainStartupBridgeRecognition.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2MainStartupBridgeRecognition.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.metadataOnly,
      ) &&
      callV2MainStartupBridgeRecognition.recordsMetadataOnly;

  bool get recordsMainStartupBridgeRecognitionPass =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus
            .mainStartupBridgeRecognitionPass,
      ) &&
      callV2MainStartupBridgeRecognition.decision ==
          CallV2MainStartupBridgeRecognitionDecision.pass;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.mainDartUnchanged,
      ) &&
      callV2MainStartupBridgeRecognition.recordsMainDartUnchanged;

  bool get recordsNoMainDartBridgeImport =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noMainDartBridgeImport,
      ) &&
      callV2MainStartupBridgeRecognition.recordsMainDartUnchanged;

  bool get recordsNoMainStartupCall =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noMainStartupCall,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoMainStartupCall;

  bool get recordsNoStartupBridgeCall =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noStartupBridgeCall,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoStartupBridgeCall;

  bool get recordsStartupBridgeUnchanged =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.startupBridgeUnchanged,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoStartupBridgeCall;

  bool get recordsProductionIntegrationDisabled =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus
            .productionIntegrationDisabled,
      ) &&
      callV2MainStartupBridgeRecognition.recordsProductionIntegrationDisabled;

  bool get recordsDisabledOwnerInert =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.disabledOwnerInert,
      ) &&
      callV2MainStartupBridgeRecognition.recordsDisabledOwnerInert;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2MainStartupBridgeRecognition
          .recordsProductionCompositionUnconstructed;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.runtimeUnconstructed,
      ) &&
      callV2MainStartupBridgeRecognition.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.runtimeNotStarted,
      ) &&
      callV2MainStartupBridgeRecognition.recordsRuntimeNotStarted;

  bool get recordsAppRouterBridgeHardeningPass =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus
            .appRouterBridgeHardeningPass,
      ) &&
      callV2AppRouterBridgeHardeningAudit.decision ==
          CallV2AppRouterBridgeHardeningAuditDecision.pass;

  bool get recordsFinalPreWiringConsolidationPass =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus
            .finalPreWiringConsolidationPass,
      ) &&
      callV2FinalPreWiringConsolidationAudit.decision ==
          CallV2FinalPreWiringConsolidationAuditDecision.pass;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.routeResolverNullWhileFalse,
      ) &&
      callV2MainStartupBridgeRecognition.recordsRouteResolverNullWhileFalse;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.routesUnreachable,
      ) &&
      callV2MainStartupBridgeRecognition.recordsRoutesUnreachable;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noBackendFirebaseAccess,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoBackendFirebaseAccess;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noFirestoreListeners,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noFirestoreReads,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noFirestoreWrites,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoFirestoreWrites;

  bool get recordsNoAuthFunctionsAppCheck =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noAuthFunctionsAppCheck,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoAuthFunctionsAppCheck;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2MainStartupBridgeRecognition
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noNavigatorWiring,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noLifecycleRegistration,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noAsyncHandles,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2MainStartupBridgeRecognition
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.noDeployment,
      ) &&
      callV2MainStartupBridgeRecognition.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2MainStartupBridgeHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2MainStartupBridgeHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2MainStartupBridgeHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2MainStartupBridgeHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2MainStartupBridgeHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2MainStartupBridgeHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2MainStartupBridgeHardeningRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2MainStartupBridgeHardeningAuditStatus.v1Protected,
      ) &&
      callV2MainStartupBridgeRecognition.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'recognitionPass': recordsMainStartupBridgeRecognitionPass,
      'mainDartUnchanged': recordsMainDartUnchanged,
      'mainBridgeImport': false,
      'startupBridgeCalled': false,
      'startupBridgeUnchanged': recordsStartupBridgeUnchanged,
      'productionIntegrationDisabled': recordsProductionIntegrationDisabled,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'routesReachable': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2MainStartupBridgeHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2MainStartupBridgeHardeningAudit =
    CallV2MainStartupBridgeHardeningAudit(
  statuses: <CallV2MainStartupBridgeHardeningAuditStatus>[
    CallV2MainStartupBridgeHardeningAuditStatus.developerOnly,
    CallV2MainStartupBridgeHardeningAuditStatus.rolloutFalse,
    CallV2MainStartupBridgeHardeningAuditStatus.metadataOnly,
    CallV2MainStartupBridgeHardeningAuditStatus
        .mainStartupBridgeRecognitionPass,
    CallV2MainStartupBridgeHardeningAuditStatus.mainDartUnchanged,
    CallV2MainStartupBridgeHardeningAuditStatus.noMainDartBridgeImport,
    CallV2MainStartupBridgeHardeningAuditStatus.noMainStartupCall,
    CallV2MainStartupBridgeHardeningAuditStatus.noStartupBridgeCall,
    CallV2MainStartupBridgeHardeningAuditStatus.startupBridgeUnchanged,
    CallV2MainStartupBridgeHardeningAuditStatus.productionIntegrationDisabled,
    CallV2MainStartupBridgeHardeningAuditStatus.disabledOwnerInert,
    CallV2MainStartupBridgeHardeningAuditStatus
        .productionCompositionUnconstructed,
    CallV2MainStartupBridgeHardeningAuditStatus.runtimeUnconstructed,
    CallV2MainStartupBridgeHardeningAuditStatus.runtimeNotStarted,
    CallV2MainStartupBridgeHardeningAuditStatus.appRouterBridgeHardeningPass,
    CallV2MainStartupBridgeHardeningAuditStatus.finalPreWiringConsolidationPass,
    CallV2MainStartupBridgeHardeningAuditStatus.routeResolverNullWhileFalse,
    CallV2MainStartupBridgeHardeningAuditStatus.routesUnreachable,
    CallV2MainStartupBridgeHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2MainStartupBridgeHardeningAuditStatus.noFirestoreListeners,
    CallV2MainStartupBridgeHardeningAuditStatus.noFirestoreReads,
    CallV2MainStartupBridgeHardeningAuditStatus.noFirestoreWrites,
    CallV2MainStartupBridgeHardeningAuditStatus.noAuthFunctionsAppCheck,
    CallV2MainStartupBridgeHardeningAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2MainStartupBridgeHardeningAuditStatus.noNavigatorWiring,
    CallV2MainStartupBridgeHardeningAuditStatus.noLifecycleRegistration,
    CallV2MainStartupBridgeHardeningAuditStatus.noAsyncHandles,
    CallV2MainStartupBridgeHardeningAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2MainStartupBridgeHardeningAuditStatus.noDeployment,
    CallV2MainStartupBridgeHardeningAuditStatus.rollbackOneCommit,
    CallV2MainStartupBridgeHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2MainStartupBridgeHardeningRollback>[
    CallV2MainStartupBridgeHardeningRollback.oneCommitRevert,
    CallV2MainStartupBridgeHardeningRollback.keepRolloutFalse,
    CallV2MainStartupBridgeHardeningRollback.keepRouteRegistryNull,
    CallV2MainStartupBridgeHardeningRollback.keepDisabledOwnerInert,
    CallV2MainStartupBridgeHardeningRollback.noDeploymentRequired,
    CallV2MainStartupBridgeHardeningRollback.noConfigChanges,
    CallV2MainStartupBridgeHardeningRollback.v1Unaffected,
  ],
);
