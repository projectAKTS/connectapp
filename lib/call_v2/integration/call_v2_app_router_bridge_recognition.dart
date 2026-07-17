import 'call_v2_route_registry.dart';
import 'call_v2_route_registry_activation_hardening_audit.dart';
import 'call_v2_route_registry_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2AppRouterBridgeRecognitionStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  routeRecognitionKnown,
  appRouterUnchanged,
  noPublicRouteRegistered,
  noMaterialAppRouteEntry,
  resolverNullWhileFalse,
  disabledRegistryNull,
  noRouteObjectCreatedWhileFalse,
  noScreenCreatedWhileFalse,
  noRouteSinkUsedWhileFalse,
  noRuntimeConstruction,
  noRuntimeStart,
  noBackendFirebaseAccess,
  noRtcPermissionMediaDeviceAccess,
  noNavigatorWiring,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2AppRouterBridgeRecognitionDecision {
  pass,
  blocked,
}

final class CallV2AppRouterBridgeRecognition {
  factory CallV2AppRouterBridgeRecognition({
    required List<CallV2AppRouterBridgeRecognitionStatus> statuses,
  }) {
    return CallV2AppRouterBridgeRecognition._(
      List<CallV2AppRouterBridgeRecognitionStatus>.unmodifiable(statuses),
    );
  }

  const CallV2AppRouterBridgeRecognition._(this.statuses);

  final List<CallV2AppRouterBridgeRecognitionStatus> statuses;

  CallV2AppRouterBridgeRecognitionDecision get decision {
    return passes
        ? CallV2AppRouterBridgeRecognitionDecision.pass
        : CallV2AppRouterBridgeRecognitionDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsRouteRecognitionKnown &&
      recordsAppRouterUnchanged &&
      recordsNoPublicRouteRegistered &&
      recordsNoMaterialAppRouteEntry &&
      recordsResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsNoRouteObjectCreatedWhileFalse &&
      recordsNoScreenCreatedWhileFalse &&
      recordsNoRouteSinkUsedWhileFalse &&
      recordsNoRuntimeConstruction &&
      recordsNoRuntimeStart &&
      recordsNoBackendFirebaseAccess &&
      recordsNoRtcPermissionMediaDeviceAccess &&
      recordsNoNavigatorWiring &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses.contains(CallV2AppRouterBridgeRecognitionStatus.developerOnly) &&
      callV2RouteRegistryActivationHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(CallV2AppRouterBridgeRecognitionStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RouteRegistryActivationHardeningAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(CallV2AppRouterBridgeRecognitionStatus.metadataOnly);

  bool get recordsRouteRecognitionKnown =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.routeRecognitionKnown,
      ) &&
      callV2RouteRegistryActivation.recordsRouteNamesKnown &&
      callV2RouteRegistryActivationHardeningAudit.recordsCanonicalRoutesExact &&
      callV2RouteRegistryActivationHardeningAudit.recordsLegacyReadyExcluded;

  bool get recordsAppRouterUnchanged => statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.appRouterUnchanged,
      );

  bool get recordsNoPublicRouteRegistered => statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noPublicRouteRegistered,
      );

  bool get recordsNoMaterialAppRouteEntry => statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noMaterialAppRouteEntry,
      );

  bool get recordsResolverNullWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.resolverNullWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsResolverNullWhileFalse &&
      callV2RouteRegistryHardeningAudit.recordsResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.disabledRegistryNull,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsDisabledRegistryNull;

  bool get recordsNoRouteObjectCreatedWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noRouteObjectCreatedWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoRouteObjectCreatedWhileFalse;

  bool get recordsNoScreenCreatedWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noScreenCreatedWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoScreenCreatedWhileFalse;

  bool get recordsNoRouteSinkUsedWhileFalse =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noRouteSinkUsedWhileFalse,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoRouteSinkUsedWhileFalse;

  bool get recordsNoRuntimeConstruction =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noRuntimeConstruction,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoRuntimeConstruction;

  bool get recordsNoRuntimeStart =>
      statuses
          .contains(CallV2AppRouterBridgeRecognitionStatus.noRuntimeStart) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoRuntimeStart;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noBackendFirebaseAccess,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoBackendFirebaseAccess;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noNavigatorWiring,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.noLifecycleRegistration,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses
          .contains(CallV2AppRouterBridgeRecognitionStatus.noAsyncHandles) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2RouteRegistryActivationHardeningAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(CallV2AppRouterBridgeRecognitionStatus.noDeployment) &&
      callV2RouteRegistryActivationHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2AppRouterBridgeRecognitionStatus.rollbackOneCommit,
      ) &&
      callV2RouteRegistryActivationHardeningAudit.recordsRollbackOneCommit;

  bool get recordsV1Protected =>
      statuses.contains(CallV2AppRouterBridgeRecognitionStatus.v1Protected) &&
      callV2RouteRegistryActivationHardeningAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'canonicalRouteCount': callV2DeveloperCanonicalRouteNames.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'routeRecognitionKnown': recordsRouteRecognitionKnown,
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
    return 'CallV2AppRouterBridgeRecognition(${toSafeDebugMap()})';
  }
}

final callV2AppRouterBridgeRecognition = CallV2AppRouterBridgeRecognition(
  statuses: <CallV2AppRouterBridgeRecognitionStatus>[
    CallV2AppRouterBridgeRecognitionStatus.developerOnly,
    CallV2AppRouterBridgeRecognitionStatus.rolloutFalse,
    CallV2AppRouterBridgeRecognitionStatus.metadataOnly,
    CallV2AppRouterBridgeRecognitionStatus.routeRecognitionKnown,
    CallV2AppRouterBridgeRecognitionStatus.appRouterUnchanged,
    CallV2AppRouterBridgeRecognitionStatus.noPublicRouteRegistered,
    CallV2AppRouterBridgeRecognitionStatus.noMaterialAppRouteEntry,
    CallV2AppRouterBridgeRecognitionStatus.resolverNullWhileFalse,
    CallV2AppRouterBridgeRecognitionStatus.disabledRegistryNull,
    CallV2AppRouterBridgeRecognitionStatus.noRouteObjectCreatedWhileFalse,
    CallV2AppRouterBridgeRecognitionStatus.noScreenCreatedWhileFalse,
    CallV2AppRouterBridgeRecognitionStatus.noRouteSinkUsedWhileFalse,
    CallV2AppRouterBridgeRecognitionStatus.noRuntimeConstruction,
    CallV2AppRouterBridgeRecognitionStatus.noRuntimeStart,
    CallV2AppRouterBridgeRecognitionStatus.noBackendFirebaseAccess,
    CallV2AppRouterBridgeRecognitionStatus.noRtcPermissionMediaDeviceAccess,
    CallV2AppRouterBridgeRecognitionStatus.noNavigatorWiring,
    CallV2AppRouterBridgeRecognitionStatus.noLifecycleRegistration,
    CallV2AppRouterBridgeRecognitionStatus.noAsyncHandles,
    CallV2AppRouterBridgeRecognitionStatus.noDependencyPlatformConfigChanges,
    CallV2AppRouterBridgeRecognitionStatus.noDeployment,
    CallV2AppRouterBridgeRecognitionStatus.rollbackOneCommit,
    CallV2AppRouterBridgeRecognitionStatus.v1Protected,
  ],
);
