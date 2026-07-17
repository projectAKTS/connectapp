import 'call_v2_app_router_bridge_hardening_audit.dart';
import 'call_v2_final_pre_wiring_consolidation_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2MainStartupBridgeRecognitionStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  mainDartUnchanged,
  noMainStartupCall,
  noStartupBridgeCall,
  productionIntegrationDisabled,
  disabledOwnerInert,
  productionCompositionUnconstructed,
  runtimeUnconstructed,
  runtimeNotStarted,
  appRouterBridgeHardeningPass,
  routeResolverNullWhileFalse,
  routesUnreachable,
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

enum CallV2MainStartupBridgeRecognitionDecision {
  pass,
  blocked,
}

final class CallV2MainStartupBridgeRecognition {
  factory CallV2MainStartupBridgeRecognition({
    required List<CallV2MainStartupBridgeRecognitionStatus> statuses,
  }) {
    return CallV2MainStartupBridgeRecognition._(
      List<CallV2MainStartupBridgeRecognitionStatus>.unmodifiable(statuses),
    );
  }

  const CallV2MainStartupBridgeRecognition._(this.statuses);

  final List<CallV2MainStartupBridgeRecognitionStatus> statuses;

  CallV2MainStartupBridgeRecognitionDecision get decision {
    return passes
        ? CallV2MainStartupBridgeRecognitionDecision.pass
        : CallV2MainStartupBridgeRecognitionDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsMainDartUnchanged &&
      recordsNoMainStartupCall &&
      recordsNoStartupBridgeCall &&
      recordsProductionIntegrationDisabled &&
      recordsDisabledOwnerInert &&
      recordsProductionCompositionUnconstructed &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsAppRouterBridgeHardeningPass &&
      recordsRouteResolverNullWhileFalse &&
      recordsRoutesUnreachable &&
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
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.developerOnly,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2AppRouterBridgeHardeningAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly => statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.metadataOnly,
      );

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.mainDartUnchanged,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsNoMainDartWiring;

  bool get recordsNoMainStartupCall =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.noMainStartupCall,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsNoStartupBridgeWiring;

  bool get recordsNoStartupBridgeCall =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.noStartupBridgeCall,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsNoStartupBridgeWiring;

  bool get recordsProductionIntegrationDisabled =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.productionIntegrationDisabled,
      ) &&
      callV2FinalPreWiringConsolidationAudit.preWiringSafetyGateBlocked;

  bool get recordsDisabledOwnerInert =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.disabledOwnerInert,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsDisabledOwnerInert;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2FinalPreWiringConsolidationAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.runtimeUnconstructed,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.runtimeNotStarted,
      ) &&
      callV2FinalPreWiringConsolidationAudit.recordsRuntimeNotStarted;

  bool get recordsAppRouterBridgeHardeningPass =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.appRouterBridgeHardeningPass,
      ) &&
      callV2AppRouterBridgeHardeningAudit.decision ==
          CallV2AppRouterBridgeHardeningAuditDecision.pass;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.routeResolverNullWhileFalse,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsResolverNullWhileFalse;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.routesUnreachable,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoPublicRouteRegistered &&
      callV2AppRouterBridgeHardeningAudit.recordsNoRouteObjectCreatedWhileFalse;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.noBackendFirebaseAccess,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoBackendFirebaseAccess;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2AppRouterBridgeHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.noNavigatorWiring,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.noLifecycleRegistration,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.noAsyncHandles,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2AppRouterBridgeHardeningAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.noDeployment,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.rollbackOneCommit,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsRollbackOneCommit;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2MainStartupBridgeRecognitionStatus.v1Protected,
      ) &&
      callV2AppRouterBridgeHardeningAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'mainDartUnchanged': recordsMainDartUnchanged,
      'startupBridgeCalled': false,
      'productionIntegrationDisabled': recordsProductionIntegrationDisabled,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'appRouterBridgeHardeningPass': recordsAppRouterBridgeHardeningPass,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'routesReachable': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2MainStartupBridgeRecognition(${toSafeDebugMap()})';
  }
}

final callV2MainStartupBridgeRecognition = CallV2MainStartupBridgeRecognition(
  statuses: <CallV2MainStartupBridgeRecognitionStatus>[
    CallV2MainStartupBridgeRecognitionStatus.developerOnly,
    CallV2MainStartupBridgeRecognitionStatus.rolloutFalse,
    CallV2MainStartupBridgeRecognitionStatus.metadataOnly,
    CallV2MainStartupBridgeRecognitionStatus.mainDartUnchanged,
    CallV2MainStartupBridgeRecognitionStatus.noMainStartupCall,
    CallV2MainStartupBridgeRecognitionStatus.noStartupBridgeCall,
    CallV2MainStartupBridgeRecognitionStatus.productionIntegrationDisabled,
    CallV2MainStartupBridgeRecognitionStatus.disabledOwnerInert,
    CallV2MainStartupBridgeRecognitionStatus.productionCompositionUnconstructed,
    CallV2MainStartupBridgeRecognitionStatus.runtimeUnconstructed,
    CallV2MainStartupBridgeRecognitionStatus.runtimeNotStarted,
    CallV2MainStartupBridgeRecognitionStatus.appRouterBridgeHardeningPass,
    CallV2MainStartupBridgeRecognitionStatus.routeResolverNullWhileFalse,
    CallV2MainStartupBridgeRecognitionStatus.routesUnreachable,
    CallV2MainStartupBridgeRecognitionStatus.noBackendFirebaseAccess,
    CallV2MainStartupBridgeRecognitionStatus.noRtcPermissionMediaDeviceAccess,
    CallV2MainStartupBridgeRecognitionStatus.noNavigatorWiring,
    CallV2MainStartupBridgeRecognitionStatus.noLifecycleRegistration,
    CallV2MainStartupBridgeRecognitionStatus.noAsyncHandles,
    CallV2MainStartupBridgeRecognitionStatus.noDependencyPlatformConfigChanges,
    CallV2MainStartupBridgeRecognitionStatus.noDeployment,
    CallV2MainStartupBridgeRecognitionStatus.rollbackOneCommit,
    CallV2MainStartupBridgeRecognitionStatus.v1Protected,
  ],
);
