import 'call_v2_app_router_bridge_hardening_audit.dart';
import 'call_v2_app_router_bridge_recognition.dart';
import 'call_v2_final_pre_wiring_consolidation_audit.dart';
import 'call_v2_main_startup_bridge_hardening_audit.dart';
import 'call_v2_main_startup_bridge_recognition.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_route_registry.dart';
import 'call_v2_route_registry_activation_hardening_audit.dart';
import 'call_v2_route_registry_hardening_audit.dart';

enum CallV2FinalStagedPreRuntimeIntegrationAuditStatus {
  developerOnly,
  rolloutFalse,
  stagedPreRuntimeOnly,
  routeRegistryActivationPass,
  routeActivationHardeningPass,
  routeRegistryHardeningPass,
  appRouterBridgeRecognitionPass,
  appRouterBridgeHardeningPass,
  mainStartupBridgeRecognitionPass,
  mainStartupBridgeHardeningPass,
  finalPreWiringConsolidationPass,
  canonicalRoutesKnown,
  legacyReadyExcluded,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  noRouteObjectCreatedWhileFalse,
  noRouteSinkUsedWhileFalse,
  noScreenCreatedWhileFalse,
  mainDartUnchanged,
  appRouterUnchanged,
  startupBridgeUnchanged,
  noMainStartupCall,
  noStartupBridgeCall,
  productionIntegrationDisabled,
  disabledOwnerInert,
  productionCompositionUnconstructed,
  runtimeUnconstructed,
  runtimeNotStarted,
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

enum CallV2FinalStagedPreRuntimeIntegrationAuditDecision {
  pass,
  blocked,
}

enum CallV2FinalStagedPreRuntimeIntegrationRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2FinalStagedPreRuntimeIntegrationAudit {
  factory CallV2FinalStagedPreRuntimeIntegrationAudit({
    required List<CallV2FinalStagedPreRuntimeIntegrationAuditStatus> statuses,
    required List<CallV2FinalStagedPreRuntimeIntegrationRollback> rollback,
  }) {
    return CallV2FinalStagedPreRuntimeIntegrationAudit._(
      List<CallV2FinalStagedPreRuntimeIntegrationAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2FinalStagedPreRuntimeIntegrationRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2FinalStagedPreRuntimeIntegrationAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2FinalStagedPreRuntimeIntegrationAuditStatus> statuses;
  final List<CallV2FinalStagedPreRuntimeIntegrationRollback> rollback;

  CallV2FinalStagedPreRuntimeIntegrationAuditDecision get decision {
    return passes
        ? CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass
        : CallV2FinalStagedPreRuntimeIntegrationAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsStagedPreRuntimeOnly &&
      recordsRouteRegistryActivationPass &&
      recordsRouteActivationHardeningPass &&
      recordsRouteRegistryHardeningPass &&
      recordsAppRouterBridgeRecognitionPass &&
      recordsAppRouterBridgeHardeningPass &&
      recordsMainStartupBridgeRecognitionPass &&
      recordsMainStartupBridgeHardeningPass &&
      recordsFinalPreWiringConsolidationPass &&
      recordsCanonicalRoutesKnown &&
      recordsLegacyReadyExcluded &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsNoRouteObjectCreatedWhileFalse &&
      recordsNoRouteSinkUsedWhileFalse &&
      recordsNoScreenCreatedWhileFalse &&
      recordsMainDartUnchanged &&
      recordsAppRouterUnchanged &&
      recordsStartupBridgeUnchanged &&
      recordsNoMainStartupCall &&
      recordsNoStartupBridgeCall &&
      recordsProductionIntegrationDisabled &&
      recordsDisabledOwnerInert &&
      recordsProductionCompositionUnconstructed &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
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
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.developerOnly,
      ) &&
      callV2RouteRegistryActivation.recordsDeveloperOnly &&
      callV2FinalPreWiringConsolidationAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RouteRegistryActivation.recordsRolloutFalse &&
      callV2MainStartupBridgeHardeningAudit.recordsRolloutFalse;

  bool get recordsStagedPreRuntimeOnly =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.stagedPreRuntimeOnly,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsMetadataOnly;

  bool get recordsRouteRegistryActivationPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .routeRegistryActivationPass,
      ) &&
      callV2RouteRegistryActivation.decision ==
          CallV2RouteRegistryActivationDecision.pass;

  bool get recordsRouteActivationHardeningPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .routeActivationHardeningPass,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.decision ==
          CallV2RouteRegistryActivationHardeningAuditDecision.pass;

  bool get recordsRouteRegistryHardeningPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .routeRegistryHardeningPass,
      ) &&
      callV2RouteRegistryHardeningAudit.decision ==
          CallV2RouteRegistryHardeningAuditDecision.pass;

  bool get recordsAppRouterBridgeRecognitionPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .appRouterBridgeRecognitionPass,
      ) &&
      callV2AppRouterBridgeRecognition.decision ==
          CallV2AppRouterBridgeRecognitionDecision.pass;

  bool get recordsAppRouterBridgeHardeningPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .appRouterBridgeHardeningPass,
      ) &&
      callV2AppRouterBridgeHardeningAudit.decision ==
          CallV2AppRouterBridgeHardeningAuditDecision.pass;

  bool get recordsMainStartupBridgeRecognitionPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .mainStartupBridgeRecognitionPass,
      ) &&
      callV2MainStartupBridgeRecognition.decision ==
          CallV2MainStartupBridgeRecognitionDecision.pass;

  bool get recordsMainStartupBridgeHardeningPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .mainStartupBridgeHardeningPass,
      ) &&
      callV2MainStartupBridgeHardeningAudit.decision ==
          CallV2MainStartupBridgeHardeningAuditDecision.pass;

  bool get recordsFinalPreWiringConsolidationPass =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .finalPreWiringConsolidationPass,
      ) &&
      callV2FinalPreWiringConsolidationAudit.decision ==
          CallV2FinalPreWiringConsolidationAuditDecision.pass;

  bool get recordsCanonicalRoutesKnown =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.canonicalRoutesKnown,
      ) &&
      callV2RouteRegistryActivation.recordsRouteNamesKnown &&
      callV2RouteRegistryActivationHardeningAudit.recordsCanonicalRoutesExact;

  bool get recordsLegacyReadyExcluded =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.legacyReadyExcluded,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsLegacyReadyExcluded;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.routesUnreachable,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsRoutesUnreachable &&
      callV2MainStartupBridgeHardeningAudit.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsResolverNullWhileFalse &&
      callV2MainStartupBridgeHardeningAudit.recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.disabledRegistryNull,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsDisabledRegistryNull &&
      callV2AppRouterBridgeHardeningAudit.recordsDisabledRegistryNull;

  bool get recordsNoRouteObjectCreatedWhileFalse =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noRouteObjectCreatedWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoRouteObjectCreatedWhileFalse &&
      callV2AppRouterBridgeHardeningAudit.recordsNoRouteObjectCreatedWhileFalse;

  bool get recordsNoRouteSinkUsedWhileFalse =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noRouteSinkUsedWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoRouteSinkUsedWhileFalse &&
      callV2AppRouterBridgeHardeningAudit.recordsNoRouteSinkUsedWhileFalse;

  bool get recordsNoScreenCreatedWhileFalse =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noScreenCreatedWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoScreenCreatedWhileFalse &&
      callV2AppRouterBridgeHardeningAudit.recordsNoScreenCreatedWhileFalse;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.mainDartUnchanged,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsMainDartUnchanged;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.appRouterUnchanged,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsAppRouterUnchanged;

  bool get recordsStartupBridgeUnchanged =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .startupBridgeUnchanged,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsStartupBridgeUnchanged;

  bool get recordsNoMainStartupCall =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noMainStartupCall,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoMainStartupCall;

  bool get recordsNoStartupBridgeCall =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noStartupBridgeCall,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoStartupBridgeCall;

  bool get recordsProductionIntegrationDisabled =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .productionIntegrationDisabled,
      ) &&
      callV2MainStartupBridgeHardeningAudit
          .recordsProductionIntegrationDisabled;

  bool get recordsDisabledOwnerInert =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.disabledOwnerInert,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2MainStartupBridgeHardeningAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.runtimeUnconstructed,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.runtimeNotStarted,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsRuntimeNotStarted;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noBackendFirebaseAccess,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoBackendFirebaseAccess;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noFirestoreListeners,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noFirestoreReads,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noFirestoreWrites,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoFirestoreWrites;

  bool get recordsNoAuthFunctionsAppCheck =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noAuthFunctionsAppCheck,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoAuthFunctionsAppCheck;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2MainStartupBridgeHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noNavigatorWiring,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noAsyncHandles,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2MainStartupBridgeHardeningAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noDeployment,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2FinalStagedPreRuntimeIntegrationRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2FinalStagedPreRuntimeIntegrationRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2FinalStagedPreRuntimeIntegrationRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2FinalStagedPreRuntimeIntegrationRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2FinalStagedPreRuntimeIntegrationRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2FinalStagedPreRuntimeIntegrationRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2FinalStagedPreRuntimeIntegrationRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2FinalStagedPreRuntimeIntegrationAuditStatus.v1Protected,
      ) &&
      callV2MainStartupBridgeHardeningAudit.recordsV1Protected &&
      callV2FinalPreWiringConsolidationAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'canonicalRouteCount': callV2DeveloperCanonicalRouteNames.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'stagedPreRuntimeOnly': recordsStagedPreRuntimeOnly,
      'routeActivationPass': recordsRouteRegistryActivationPass,
      'routeHardeningPass': recordsRouteActivationHardeningPass,
      'appBridgeHardeningPass': recordsAppRouterBridgeHardeningPass,
      'mainBridgeHardeningPass': recordsMainStartupBridgeHardeningPass,
      'finalConsolidationPass': recordsFinalPreWiringConsolidationPass,
      'resolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'routesReachable': false,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2FinalStagedPreRuntimeIntegrationAudit(${toSafeDebugMap()})';
  }
}

final callV2FinalStagedPreRuntimeIntegrationAudit =
    CallV2FinalStagedPreRuntimeIntegrationAudit(
  statuses: <CallV2FinalStagedPreRuntimeIntegrationAuditStatus>[
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.developerOnly,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.rolloutFalse,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.stagedPreRuntimeOnly,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .routeRegistryActivationPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .routeActivationHardeningPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .routeRegistryHardeningPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .appRouterBridgeRecognitionPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .appRouterBridgeHardeningPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .mainStartupBridgeRecognitionPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .mainStartupBridgeHardeningPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .finalPreWiringConsolidationPass,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.canonicalRoutesKnown,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.legacyReadyExcluded,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.routesUnreachable,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .routeResolverNullWhileFalse,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.disabledRegistryNull,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .noRouteObjectCreatedWhileFalse,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noRouteSinkUsedWhileFalse,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noScreenCreatedWhileFalse,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.mainDartUnchanged,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.appRouterUnchanged,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.startupBridgeUnchanged,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noMainStartupCall,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noStartupBridgeCall,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .productionIntegrationDisabled,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.disabledOwnerInert,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .productionCompositionUnconstructed,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.runtimeUnconstructed,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.runtimeNotStarted,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noBackendFirebaseAccess,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noFirestoreListeners,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noFirestoreReads,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noFirestoreWrites,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noAuthFunctionsAppCheck,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noNavigatorWiring,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noLifecycleRegistration,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noAsyncHandles,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.noDeployment,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.rollbackOneCommit,
    CallV2FinalStagedPreRuntimeIntegrationAuditStatus.v1Protected,
  ],
  rollback: <CallV2FinalStagedPreRuntimeIntegrationRollback>[
    CallV2FinalStagedPreRuntimeIntegrationRollback.oneCommitRevert,
    CallV2FinalStagedPreRuntimeIntegrationRollback.keepRolloutFalse,
    CallV2FinalStagedPreRuntimeIntegrationRollback.keepRouteRegistryNull,
    CallV2FinalStagedPreRuntimeIntegrationRollback.keepDisabledOwnerInert,
    CallV2FinalStagedPreRuntimeIntegrationRollback.noDeploymentRequired,
    CallV2FinalStagedPreRuntimeIntegrationRollback.noConfigChanges,
    CallV2FinalStagedPreRuntimeIntegrationRollback.v1Unaffected,
  ],
);
