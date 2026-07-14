import 'call_v2_rollout_policy.dart';
import 'call_v2_route_registry.dart';

enum CallV2RouteRegistryHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  unreachable,
  resolverNullWhileFalse,
  disabledRegistryNull,
  canonicalRoutesExact,
  readyExcluded,
  dynamicRoutesExcluded,
  queryRoutesExcluded,
  fragmentRoutesExcluded,
  argumentsIgnoredWhileFalse,
  nonCallV2RoutesExcluded,
  noRouteObjectCreation,
  noRouteSinkUse,
  noScreenCreation,
  noRuntimeStart,
  noBackendFirebaseAccess,
  noRtcPermissionAccess,
  noNavigatorWiring,
  noLifecycleObserverRegistration,
  noAsyncHandles,
  noPubspecPlatformChanges,
  noRulesFunctionsConfigChanges,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2RouteRegistryHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2RouteRegistryHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RouteRegistryHardeningAudit {
  factory CallV2RouteRegistryHardeningAudit({
    required List<CallV2RouteRegistryHardeningAuditStatus> statuses,
    required List<CallV2RouteRegistryHardeningRollback> rollback,
  }) {
    return CallV2RouteRegistryHardeningAudit._(
      List<CallV2RouteRegistryHardeningAuditStatus>.unmodifiable(statuses),
      List<CallV2RouteRegistryHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2RouteRegistryHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2RouteRegistryHardeningAuditStatus> statuses;
  final List<CallV2RouteRegistryHardeningRollback> rollback;

  static const Set<String> expectedCanonicalRoutes = <String>{
    '/call-v2/connecting',
    '/call-v2/audio',
    '/call-v2/video',
    '/call-v2/failure',
  };

  CallV2RouteRegistryHardeningAuditDecision get decision {
    return passes
        ? CallV2RouteRegistryHardeningAuditDecision.pass
        : CallV2RouteRegistryHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsUnreachable &&
      recordsResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      canonicalRoutesAreExact &&
      excludesReadyRoute &&
      excludesDynamicRoutes &&
      excludesQueryRoutes &&
      excludesFragmentRoutes &&
      ignoresArgumentsWhileFalse &&
      excludesNonCallV2Routes &&
      createsRouteObject == false &&
      usesRouteSink == false &&
      createsScreen == false &&
      startsRuntime == false &&
      accessesBackendFirebase == false &&
      accessesRtcPermissions == false &&
      wiresNavigator == false &&
      registersLifecycleObserver == false &&
      createsAsyncHandles == false &&
      changesPubspecPlatform == false &&
      changesRulesFunctionsConfig == false &&
      rollbackPreserved &&
      protectsV1;

  bool get recordsDeveloperOnly =>
      statuses.contains(CallV2RouteRegistryHardeningAuditStatus.developerOnly);

  bool get recordsRolloutFalse =>
      statuses.contains(CallV2RouteRegistryHardeningAuditStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled &&
      !isCallV2DeveloperRouteRegistrationEnabled;

  bool get recordsUnreachable =>
      statuses.contains(CallV2RouteRegistryHardeningAuditStatus.unreachable);

  bool get recordsResolverNullWhileFalse => statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.resolverNullWhileFalse,
      );

  bool get recordsDisabledRegistryNull => statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.disabledRegistryNull,
      );

  bool get canonicalRoutesAreExact =>
      statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.canonicalRoutesExact,
      ) &&
      callV2DeveloperCanonicalRouteNames.length ==
          expectedCanonicalRoutes.length &&
      callV2DeveloperCanonicalRouteNames.containsAll(expectedCanonicalRoutes);

  bool get excludesReadyRoute =>
      statuses
          .contains(CallV2RouteRegistryHardeningAuditStatus.readyExcluded) &&
      !isCallV2DeveloperCanonicalRouteName('/call-v2/ready');

  bool get excludesDynamicRoutes => statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.dynamicRoutesExcluded,
      );

  bool get excludesQueryRoutes =>
      statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.queryRoutesExcluded,
      ) &&
      !isCallV2DeveloperCanonicalRouteName('/call-v2/audio?mode=debug');

  bool get excludesFragmentRoutes =>
      statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.fragmentRoutesExcluded,
      ) &&
      !isCallV2DeveloperCanonicalRouteName('/call-v2/video#camera');

  bool get ignoresArgumentsWhileFalse => statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.argumentsIgnoredWhileFalse,
      );

  bool get excludesNonCallV2Routes => statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.nonCallV2RoutesExcluded,
      );

  bool get createsRouteObject => !statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.noRouteObjectCreation,
      );

  bool get usesRouteSink => !statuses
      .contains(CallV2RouteRegistryHardeningAuditStatus.noRouteSinkUse);

  bool get createsScreen => !statuses
      .contains(CallV2RouteRegistryHardeningAuditStatus.noScreenCreation);

  bool get startsRuntime => !statuses
      .contains(CallV2RouteRegistryHardeningAuditStatus.noRuntimeStart);

  bool get accessesBackendFirebase => !statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.noBackendFirebaseAccess,
      );

  bool get accessesRtcPermissions => !statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.noRtcPermissionAccess,
      );

  bool get wiresNavigator => !statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.noNavigatorWiring,
      );

  bool get registersLifecycleObserver => !statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.noLifecycleObserverRegistration,
      );

  bool get createsAsyncHandles => !statuses
      .contains(CallV2RouteRegistryHardeningAuditStatus.noAsyncHandles);

  bool get changesPubspecPlatform => !statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.noPubspecPlatformChanges,
      );

  bool get changesRulesFunctionsConfig => !statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.noRulesFunctionsConfigChanges,
      );

  bool get rollbackPreserved =>
      statuses.contains(
        CallV2RouteRegistryHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(CallV2RouteRegistryHardeningRollback.oneCommitRevert) &&
      rollback.contains(
        CallV2RouteRegistryHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2RouteRegistryHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2RouteRegistryHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2RouteRegistryHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(CallV2RouteRegistryHardeningRollback.noConfigChanges) &&
      rollback.contains(CallV2RouteRegistryHardeningRollback.v1Unaffected);

  bool get protectsV1 =>
      statuses.contains(CallV2RouteRegistryHardeningAuditStatus.v1Protected);

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'canonicalRouteCount': callV2DeveloperCanonicalRouteNames.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'routeRegistrationEnabled': isCallV2DeveloperRouteRegistrationEnabled,
      'canonicalRoutesExact': canonicalRoutesAreExact,
      'readyExcluded': excludesReadyRoute,
      'unreachable': recordsUnreachable,
      'resolverNullWhileFalse': recordsResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2RouteRegistryHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2RouteRegistryHardeningAudit = CallV2RouteRegistryHardeningAudit(
  statuses: <CallV2RouteRegistryHardeningAuditStatus>[
    CallV2RouteRegistryHardeningAuditStatus.developerOnly,
    CallV2RouteRegistryHardeningAuditStatus.rolloutFalse,
    CallV2RouteRegistryHardeningAuditStatus.unreachable,
    CallV2RouteRegistryHardeningAuditStatus.resolverNullWhileFalse,
    CallV2RouteRegistryHardeningAuditStatus.disabledRegistryNull,
    CallV2RouteRegistryHardeningAuditStatus.canonicalRoutesExact,
    CallV2RouteRegistryHardeningAuditStatus.readyExcluded,
    CallV2RouteRegistryHardeningAuditStatus.dynamicRoutesExcluded,
    CallV2RouteRegistryHardeningAuditStatus.queryRoutesExcluded,
    CallV2RouteRegistryHardeningAuditStatus.fragmentRoutesExcluded,
    CallV2RouteRegistryHardeningAuditStatus.argumentsIgnoredWhileFalse,
    CallV2RouteRegistryHardeningAuditStatus.nonCallV2RoutesExcluded,
    CallV2RouteRegistryHardeningAuditStatus.noRouteObjectCreation,
    CallV2RouteRegistryHardeningAuditStatus.noRouteSinkUse,
    CallV2RouteRegistryHardeningAuditStatus.noScreenCreation,
    CallV2RouteRegistryHardeningAuditStatus.noRuntimeStart,
    CallV2RouteRegistryHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2RouteRegistryHardeningAuditStatus.noRtcPermissionAccess,
    CallV2RouteRegistryHardeningAuditStatus.noNavigatorWiring,
    CallV2RouteRegistryHardeningAuditStatus.noLifecycleObserverRegistration,
    CallV2RouteRegistryHardeningAuditStatus.noAsyncHandles,
    CallV2RouteRegistryHardeningAuditStatus.noPubspecPlatformChanges,
    CallV2RouteRegistryHardeningAuditStatus.noRulesFunctionsConfigChanges,
    CallV2RouteRegistryHardeningAuditStatus.rollbackOneCommit,
    CallV2RouteRegistryHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2RouteRegistryHardeningRollback>[
    CallV2RouteRegistryHardeningRollback.oneCommitRevert,
    CallV2RouteRegistryHardeningRollback.keepRolloutFalse,
    CallV2RouteRegistryHardeningRollback.keepRouteRegistryNull,
    CallV2RouteRegistryHardeningRollback.keepDisabledOwnerInert,
    CallV2RouteRegistryHardeningRollback.noDeploymentRequired,
    CallV2RouteRegistryHardeningRollback.noConfigChanges,
    CallV2RouteRegistryHardeningRollback.v1Unaffected,
  ],
);
