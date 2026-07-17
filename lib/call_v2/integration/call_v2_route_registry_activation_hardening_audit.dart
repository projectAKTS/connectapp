import 'call_v2_final_pre_wiring_consolidation_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_route_registry.dart';
import 'call_v2_route_registry_hardening_audit.dart';

enum CallV2RouteRegistryActivationHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  routeRegistrationDisabled,
  resolverNullWhileFalse,
  disabledRegistryNull,
  canonicalRoutesExact,
  legacyReadyExcluded,
  hostileArgsIgnoredWhileFalse,
  noRouteObjectCreatedWhileFalse,
  noRouteSinkUsedWhileFalse,
  noScreenCreatedWhileFalse,
  noRuntimeConstruction,
  noRuntimeStart,
  noProductionCompositionConstruction,
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
  finalPreWiringConsolidationPass,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2RouteRegistryActivationHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2RouteRegistryActivationHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RouteRegistryActivationHardeningAudit {
  factory CallV2RouteRegistryActivationHardeningAudit({
    required List<CallV2RouteRegistryActivationHardeningAuditStatus> statuses,
    required List<CallV2RouteRegistryActivationHardeningRollback> rollback,
  }) {
    return CallV2RouteRegistryActivationHardeningAudit._(
      List<CallV2RouteRegistryActivationHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2RouteRegistryActivationHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2RouteRegistryActivationHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2RouteRegistryActivationHardeningAuditStatus> statuses;
  final List<CallV2RouteRegistryActivationHardeningRollback> rollback;

  static const Set<String> expectedCanonicalRoutes = <String>{
    '/call-v2/connecting',
    '/call-v2/audio',
    '/call-v2/video',
    '/call-v2/failure',
  };

  CallV2RouteRegistryActivationHardeningAuditDecision get decision {
    return passes
        ? CallV2RouteRegistryActivationHardeningAuditDecision.pass
        : CallV2RouteRegistryActivationHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsRouteRegistrationDisabled &&
      recordsResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsCanonicalRoutesExact &&
      recordsLegacyReadyExcluded &&
      recordsHostileArgsIgnoredWhileFalse &&
      recordsNoRouteObjectCreatedWhileFalse &&
      recordsNoRouteSinkUsedWhileFalse &&
      recordsNoScreenCreatedWhileFalse &&
      recordsNoRuntimeConstruction &&
      recordsNoRuntimeStart &&
      recordsNoProductionCompositionConstruction &&
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
      recordsFinalPreWiringConsolidationPass &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.developerOnly,
      ) &&
      callV2RouteRegistryActivation.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RouteRegistryActivation.recordsRolloutFalse;

  bool get recordsRouteRegistrationDisabled =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .routeRegistrationDisabled,
      ) &&
      !isCallV2DeveloperRouteRegistrationEnabled;

  bool get recordsResolverNullWhileFalse =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .resolverNullWhileFalse,
      ) &&
      callV2RouteRegistryActivation.recordsResolverNullWhileFalse &&
      callV2RouteRegistryHardeningAudit.recordsResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.disabledRegistryNull,
      ) &&
      callV2RouteRegistryHardeningAudit.recordsDisabledRegistryNull;

  bool get recordsCanonicalRoutesExact =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.canonicalRoutesExact,
      ) &&
      callV2DeveloperCanonicalRouteNames.length ==
          expectedCanonicalRoutes.length &&
      callV2DeveloperCanonicalRouteNames.containsAll(expectedCanonicalRoutes) &&
      callV2RouteRegistryHardeningAudit.canonicalRoutesAreExact;

  bool get recordsLegacyReadyExcluded =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.legacyReadyExcluded,
      ) &&
      !isCallV2DeveloperCanonicalRouteName(CallV2RouteNames.ready) &&
      callV2RouteRegistryHardeningAudit.excludesReadyRoute;

  bool get recordsHostileArgsIgnoredWhileFalse =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .hostileArgsIgnoredWhileFalse,
      ) &&
      callV2RouteRegistryHardeningAudit.ignoresArgumentsWhileFalse;

  bool get recordsNoRouteObjectCreatedWhileFalse =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noRouteObjectCreatedWhileFalse,
      ) &&
      callV2RouteRegistryActivation.recordsNoRouteObjectCreatedWhileFalse &&
      !callV2RouteRegistryHardeningAudit.createsRouteObject;

  bool get recordsNoRouteSinkUsedWhileFalse =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noRouteSinkUsedWhileFalse,
      ) &&
      callV2RouteRegistryActivation.recordsRouteSinkBlockedWhileFalse &&
      !callV2RouteRegistryHardeningAudit.usesRouteSink;

  bool get recordsNoScreenCreatedWhileFalse =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noScreenCreatedWhileFalse,
      ) &&
      callV2RouteRegistryActivation.recordsNoScreenCreatedWhileFalse &&
      !callV2RouteRegistryHardeningAudit.createsScreen;

  bool get recordsNoRuntimeConstruction =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noRuntimeConstruction,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsRuntimeUnconstructed;

  bool get recordsNoRuntimeStart =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noRuntimeStart,
      ) &&
      callV2RouteRegistryActivation.recordsNoRuntimeStart &&
      !callV2RouteRegistryHardeningAudit.startsRuntime &&
      callV2FinalPreWiringConsolidationAudit.recordsRuntimeNotStarted;

  bool get recordsNoProductionCompositionConstruction =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noProductionCompositionConstruction,
      ) &&
      callV2FinalPreWiringConsolidationAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noBackendFirebaseAccess,
      ) &&
      callV2RouteRegistryActivation.recordsNoBackendAccess &&
      !callV2RouteRegistryHardeningAudit.accessesBackendFirebase &&
      callV2FinalPreWiringConsolidationAudit.recordsNoBackendFirebaseAccess;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noFirestoreListeners,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noFirestoreReads,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noFirestoreWrites,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsNoFirestoreWrites;

  bool get recordsNoAuthFunctionsAppCheck =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noAuthFunctionsAppCheck,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsNoAuthFunctionsAppCheck;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2RouteRegistryActivation.recordsNoRtcPermissionAccess &&
      !callV2RouteRegistryHardeningAudit.accessesRtcPermissions &&
      callV2FinalPreWiringConsolidationAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noNavigatorWiring,
      ) &&
      callV2RouteRegistryActivation.recordsNoNavigationAccess &&
      !callV2RouteRegistryHardeningAudit.wiresNavigator &&
      callV2FinalPreWiringConsolidationAudit.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2RouteRegistryActivation.recordsNoLifecycleRegistration &&
      !callV2RouteRegistryHardeningAudit.registersLifecycleObserver &&
      callV2FinalPreWiringConsolidationAudit.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noAsyncHandles,
      ) &&
      callV2RouteRegistryActivation.recordsNoAsyncHandles &&
      !callV2RouteRegistryHardeningAudit.createsAsyncHandles &&
      callV2FinalPreWiringConsolidationAudit.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2RouteRegistryActivation.recordsNoDependencyPlatformConfigChanges &&
      !callV2RouteRegistryHardeningAudit.changesPubspecPlatform &&
      !callV2RouteRegistryHardeningAudit.changesRulesFunctionsConfig &&
      callV2FinalPreWiringConsolidationAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.noDeployment,
      ) &&
      callV2RouteRegistryActivation.recordsNoDeployment &&
      callV2FinalPreWiringConsolidationAudit.recordsNoDeployment;

  bool get recordsFinalPreWiringConsolidationPass =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus
            .finalPreWiringConsolidationPass,
      ) &&
      callV2FinalPreWiringConsolidationAudit.decision ==
          CallV2FinalPreWiringConsolidationAuditDecision.pass;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2RouteRegistryActivationHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2RouteRegistryActivationHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2RouteRegistryActivationHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2RouteRegistryActivationHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2RouteRegistryActivationHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2RouteRegistryActivationHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2RouteRegistryActivationHardeningRollback.v1Unaffected,
      );

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2RouteRegistryActivationHardeningAuditStatus.v1Protected,
      ) &&
      callV2RouteRegistryActivation.recordsV1Protected &&
      callV2RouteRegistryHardeningAudit.protectsV1 &&
      callV2FinalPreWiringConsolidationAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'canonicalRouteCount': callV2DeveloperCanonicalRouteNames.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'routeRegistrationEnabled': isCallV2DeveloperRouteRegistrationEnabled,
      'resolverNullWhileFalse': recordsResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'canonicalRoutesExact': recordsCanonicalRoutesExact,
      'legacyReadyExcluded': recordsLegacyReadyExcluded,
      'finalConsolidationPass': recordsFinalPreWiringConsolidationPass,
      'rollbackOneCommit': recordsRollbackOneCommit,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2RouteRegistryActivationHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2RouteRegistryActivationHardeningAudit =
    CallV2RouteRegistryActivationHardeningAudit(
  statuses: <CallV2RouteRegistryActivationHardeningAuditStatus>[
    CallV2RouteRegistryActivationHardeningAuditStatus.developerOnly,
    CallV2RouteRegistryActivationHardeningAuditStatus.rolloutFalse,
    CallV2RouteRegistryActivationHardeningAuditStatus.routeRegistrationDisabled,
    CallV2RouteRegistryActivationHardeningAuditStatus.resolverNullWhileFalse,
    CallV2RouteRegistryActivationHardeningAuditStatus.disabledRegistryNull,
    CallV2RouteRegistryActivationHardeningAuditStatus.canonicalRoutesExact,
    CallV2RouteRegistryActivationHardeningAuditStatus.legacyReadyExcluded,
    CallV2RouteRegistryActivationHardeningAuditStatus
        .hostileArgsIgnoredWhileFalse,
    CallV2RouteRegistryActivationHardeningAuditStatus
        .noRouteObjectCreatedWhileFalse,
    CallV2RouteRegistryActivationHardeningAuditStatus.noRouteSinkUsedWhileFalse,
    CallV2RouteRegistryActivationHardeningAuditStatus.noScreenCreatedWhileFalse,
    CallV2RouteRegistryActivationHardeningAuditStatus.noRuntimeConstruction,
    CallV2RouteRegistryActivationHardeningAuditStatus.noRuntimeStart,
    CallV2RouteRegistryActivationHardeningAuditStatus
        .noProductionCompositionConstruction,
    CallV2RouteRegistryActivationHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2RouteRegistryActivationHardeningAuditStatus.noFirestoreListeners,
    CallV2RouteRegistryActivationHardeningAuditStatus.noFirestoreReads,
    CallV2RouteRegistryActivationHardeningAuditStatus.noFirestoreWrites,
    CallV2RouteRegistryActivationHardeningAuditStatus.noAuthFunctionsAppCheck,
    CallV2RouteRegistryActivationHardeningAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2RouteRegistryActivationHardeningAuditStatus.noNavigatorWiring,
    CallV2RouteRegistryActivationHardeningAuditStatus.noLifecycleRegistration,
    CallV2RouteRegistryActivationHardeningAuditStatus.noAsyncHandles,
    CallV2RouteRegistryActivationHardeningAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2RouteRegistryActivationHardeningAuditStatus.noDeployment,
    CallV2RouteRegistryActivationHardeningAuditStatus
        .finalPreWiringConsolidationPass,
    CallV2RouteRegistryActivationHardeningAuditStatus.rollbackOneCommit,
    CallV2RouteRegistryActivationHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2RouteRegistryActivationHardeningRollback>[
    CallV2RouteRegistryActivationHardeningRollback.oneCommitRevert,
    CallV2RouteRegistryActivationHardeningRollback.keepRolloutFalse,
    CallV2RouteRegistryActivationHardeningRollback.keepRouteRegistryNull,
    CallV2RouteRegistryActivationHardeningRollback.keepDisabledOwnerInert,
    CallV2RouteRegistryActivationHardeningRollback.noDeploymentRequired,
    CallV2RouteRegistryActivationHardeningRollback.noConfigChanges,
    CallV2RouteRegistryActivationHardeningRollback.v1Unaffected,
  ],
);
