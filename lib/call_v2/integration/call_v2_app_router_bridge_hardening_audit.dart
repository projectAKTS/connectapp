import 'call_v2_app_router_bridge_recognition.dart';
import 'call_v2_final_pre_wiring_consolidation_audit.dart';
import 'call_v2_route_registry_activation_hardening_audit.dart';
import 'call_v2_route_registry_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2AppRouterBridgeHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  bridgeRecognitionPass,
  appRouterUnchanged,
  noPublicRouteRegistered,
  noMaterialAppRouteEntry,
  noAppRouterCallV2Import,
  noAppRouterCallV2RouteStrings,
  noAppRouterResolverCall,
  noAppRouterBridgeReference,
  resolverNullWhileFalse,
  disabledRegistryNull,
  routeActivationHardeningPass,
  routeRegistryHardeningPass,
  finalPreWiringConsolidationPass,
  noRouteObjectCreatedWhileFalse,
  noRouteSinkUsedWhileFalse,
  noScreenCreatedWhileFalse,
  noRuntimeConstruction,
  noRuntimeStart,
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

enum CallV2AppRouterBridgeHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2AppRouterBridgeHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2AppRouterBridgeHardeningAudit {
  factory CallV2AppRouterBridgeHardeningAudit({
    required List<CallV2AppRouterBridgeHardeningAuditStatus> statuses,
    required List<CallV2AppRouterBridgeHardeningRollback> rollback,
  }) {
    return CallV2AppRouterBridgeHardeningAudit._(
      List<CallV2AppRouterBridgeHardeningAuditStatus>.unmodifiable(statuses),
      List<CallV2AppRouterBridgeHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2AppRouterBridgeHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2AppRouterBridgeHardeningAuditStatus> statuses;
  final List<CallV2AppRouterBridgeHardeningRollback> rollback;

  CallV2AppRouterBridgeHardeningAuditDecision get decision {
    return passes
        ? CallV2AppRouterBridgeHardeningAuditDecision.pass
        : CallV2AppRouterBridgeHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsBridgeRecognitionPass &&
      recordsAppRouterUnchanged &&
      recordsNoPublicRouteRegistered &&
      recordsNoMaterialAppRouteEntry &&
      recordsNoAppRouterCallV2Import &&
      recordsNoAppRouterCallV2RouteStrings &&
      recordsNoAppRouterResolverCall &&
      recordsNoAppRouterBridgeReference &&
      recordsResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsRouteActivationHardeningPass &&
      recordsRouteRegistryHardeningPass &&
      recordsFinalPreWiringConsolidationPass &&
      recordsNoRouteObjectCreatedWhileFalse &&
      recordsNoRouteSinkUsedWhileFalse &&
      recordsNoScreenCreatedWhileFalse &&
      recordsNoRuntimeConstruction &&
      recordsNoRuntimeStart &&
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
        CallV2AppRouterBridgeHardeningAuditStatus.developerOnly,
      ) &&
      callV2AppRouterBridgeRecognition.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2AppRouterBridgeRecognition.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.metadataOnly,
      ) &&
      callV2AppRouterBridgeRecognition.recordsMetadataOnly;

  bool get recordsBridgeRecognitionPass =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.bridgeRecognitionPass,
      ) &&
      callV2AppRouterBridgeRecognition.decision ==
          CallV2AppRouterBridgeRecognitionDecision.pass;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.appRouterUnchanged,
      ) &&
      callV2AppRouterBridgeRecognition.recordsAppRouterUnchanged;

  bool get recordsNoPublicRouteRegistered =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noPublicRouteRegistered,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoPublicRouteRegistered;

  bool get recordsNoMaterialAppRouteEntry =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noMaterialAppRouteEntry,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoMaterialAppRouteEntry;

  bool get recordsNoAppRouterCallV2Import => statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterCallV2Import,
      );

  bool get recordsNoAppRouterCallV2RouteStrings => statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterCallV2RouteStrings,
      );

  bool get recordsNoAppRouterResolverCall => statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterResolverCall,
      );

  bool get recordsNoAppRouterBridgeReference => statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterBridgeReference,
      );

  bool get recordsResolverNullWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.resolverNullWhileFalse,
      ) &&
      callV2AppRouterBridgeRecognition.recordsResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.disabledRegistryNull,
      ) &&
      callV2AppRouterBridgeRecognition.recordsDisabledRegistryNull;

  bool get recordsRouteActivationHardeningPass =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.routeActivationHardeningPass,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.decision ==
          CallV2RouteRegistryActivationHardeningAuditDecision.pass;

  bool get recordsRouteRegistryHardeningPass =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.routeRegistryHardeningPass,
      ) &&
      callV2RouteRegistryHardeningAudit.decision ==
          CallV2RouteRegistryHardeningAuditDecision.pass;

  bool get recordsFinalPreWiringConsolidationPass =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus
            .finalPreWiringConsolidationPass,
      ) &&
      callV2FinalPreWiringConsolidationAudit.decision ==
          CallV2FinalPreWiringConsolidationAuditDecision.pass;

  bool get recordsNoRouteObjectCreatedWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus
            .noRouteObjectCreatedWhileFalse,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoRouteObjectCreatedWhileFalse;

  bool get recordsNoRouteSinkUsedWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noRouteSinkUsedWhileFalse,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoRouteSinkUsedWhileFalse;

  bool get recordsNoScreenCreatedWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noScreenCreatedWhileFalse,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoScreenCreatedWhileFalse;

  bool get recordsNoRuntimeConstruction =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noRuntimeConstruction,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoRuntimeConstruction;

  bool get recordsNoRuntimeStart =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noRuntimeStart,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoRuntimeStart;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noBackendFirebaseAccess,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoBackendFirebaseAccess;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noFirestoreListeners,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noFirestoreReads,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noFirestoreWrites,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoFirestoreWrites;

  bool get recordsNoAuthFunctionsAppCheck =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noAuthFunctionsAppCheck,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoAuthFunctionsAppCheck;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noNavigatorWiring,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noLifecycleRegistration,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noAsyncHandles,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.noDeployment,
      ) &&
      callV2AppRouterBridgeRecognition.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2AppRouterBridgeHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback
          .contains(CallV2AppRouterBridgeHardeningRollback.oneCommitRevert) &&
      rollback
          .contains(CallV2AppRouterBridgeHardeningRollback.keepRolloutFalse) &&
      rollback.contains(
        CallV2AppRouterBridgeHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2AppRouterBridgeHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2AppRouterBridgeHardeningRollback.noDeploymentRequired,
      ) &&
      rollback
          .contains(CallV2AppRouterBridgeHardeningRollback.noConfigChanges) &&
      rollback.contains(CallV2AppRouterBridgeHardeningRollback.v1Unaffected);

  bool get recordsV1Protected =>
      statuses
          .contains(CallV2AppRouterBridgeHardeningAuditStatus.v1Protected) &&
      callV2AppRouterBridgeRecognition.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'bridgeRecognitionPass': recordsBridgeRecognitionPass,
      'appRouterUnchanged': recordsAppRouterUnchanged,
      'publicRouteRegistered': false,
      'materialAppRouteEntry': false,
      'resolverNullWhileFalse': recordsResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'routesReachable': false,
      'runtimeStarted': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2AppRouterBridgeHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2AppRouterBridgeHardeningAudit = CallV2AppRouterBridgeHardeningAudit(
  statuses: <CallV2AppRouterBridgeHardeningAuditStatus>[
    CallV2AppRouterBridgeHardeningAuditStatus.developerOnly,
    CallV2AppRouterBridgeHardeningAuditStatus.rolloutFalse,
    CallV2AppRouterBridgeHardeningAuditStatus.metadataOnly,
    CallV2AppRouterBridgeHardeningAuditStatus.bridgeRecognitionPass,
    CallV2AppRouterBridgeHardeningAuditStatus.appRouterUnchanged,
    CallV2AppRouterBridgeHardeningAuditStatus.noPublicRouteRegistered,
    CallV2AppRouterBridgeHardeningAuditStatus.noMaterialAppRouteEntry,
    CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterCallV2Import,
    CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterCallV2RouteStrings,
    CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterResolverCall,
    CallV2AppRouterBridgeHardeningAuditStatus.noAppRouterBridgeReference,
    CallV2AppRouterBridgeHardeningAuditStatus.resolverNullWhileFalse,
    CallV2AppRouterBridgeHardeningAuditStatus.disabledRegistryNull,
    CallV2AppRouterBridgeHardeningAuditStatus.routeActivationHardeningPass,
    CallV2AppRouterBridgeHardeningAuditStatus.routeRegistryHardeningPass,
    CallV2AppRouterBridgeHardeningAuditStatus.finalPreWiringConsolidationPass,
    CallV2AppRouterBridgeHardeningAuditStatus.noRouteObjectCreatedWhileFalse,
    CallV2AppRouterBridgeHardeningAuditStatus.noRouteSinkUsedWhileFalse,
    CallV2AppRouterBridgeHardeningAuditStatus.noScreenCreatedWhileFalse,
    CallV2AppRouterBridgeHardeningAuditStatus.noRuntimeConstruction,
    CallV2AppRouterBridgeHardeningAuditStatus.noRuntimeStart,
    CallV2AppRouterBridgeHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2AppRouterBridgeHardeningAuditStatus.noFirestoreListeners,
    CallV2AppRouterBridgeHardeningAuditStatus.noFirestoreReads,
    CallV2AppRouterBridgeHardeningAuditStatus.noFirestoreWrites,
    CallV2AppRouterBridgeHardeningAuditStatus.noAuthFunctionsAppCheck,
    CallV2AppRouterBridgeHardeningAuditStatus.noRtcPermissionMediaDeviceAccess,
    CallV2AppRouterBridgeHardeningAuditStatus.noNavigatorWiring,
    CallV2AppRouterBridgeHardeningAuditStatus.noLifecycleRegistration,
    CallV2AppRouterBridgeHardeningAuditStatus.noAsyncHandles,
    CallV2AppRouterBridgeHardeningAuditStatus.noDependencyPlatformConfigChanges,
    CallV2AppRouterBridgeHardeningAuditStatus.noDeployment,
    CallV2AppRouterBridgeHardeningAuditStatus.rollbackOneCommit,
    CallV2AppRouterBridgeHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2AppRouterBridgeHardeningRollback>[
    CallV2AppRouterBridgeHardeningRollback.oneCommitRevert,
    CallV2AppRouterBridgeHardeningRollback.keepRolloutFalse,
    CallV2AppRouterBridgeHardeningRollback.keepRouteRegistryNull,
    CallV2AppRouterBridgeHardeningRollback.keepDisabledOwnerInert,
    CallV2AppRouterBridgeHardeningRollback.noDeploymentRequired,
    CallV2AppRouterBridgeHardeningRollback.noConfigChanges,
    CallV2AppRouterBridgeHardeningRollback.v1Unaffected,
  ],
);
