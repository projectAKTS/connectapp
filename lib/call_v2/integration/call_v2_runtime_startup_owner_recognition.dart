import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_runtime_startup_owner_hardening_audit.dart';

enum CallV2RuntimeStartupOwnerRecognitionStatus {
  humanApprovedPhase7AJ,
  developerOnly,
  rolloutFalse,
  metadataOnly,
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
  noRtcPermissionMediaDeviceAccess,
  noNavigatorWiring,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2RuntimeStartupOwnerRecognitionDecision {
  pass,
  blocked,
}

final class CallV2RuntimeStartupOwnerRecognition {
  factory CallV2RuntimeStartupOwnerRecognition({
    required List<CallV2RuntimeStartupOwnerRecognitionStatus> statuses,
  }) {
    return CallV2RuntimeStartupOwnerRecognition._(
      List<CallV2RuntimeStartupOwnerRecognitionStatus>.unmodifiable(statuses),
    );
  }

  const CallV2RuntimeStartupOwnerRecognition._(this.statuses);

  final List<CallV2RuntimeStartupOwnerRecognitionStatus> statuses;

  CallV2RuntimeStartupOwnerRecognitionDecision get decision {
    return passes
        ? CallV2RuntimeStartupOwnerRecognitionDecision.pass
        : CallV2RuntimeStartupOwnerRecognitionDecision.blocked;
  }

  bool get passes =>
      recordsHumanApprovedPhase7AJ &&
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
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
      recordsNoRtcPermissionMediaDeviceAccess &&
      recordsNoNavigatorWiring &&
      recordsNoLifecycleRegistration &&
      recordsNoAsyncHandles &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsHumanApprovedPhase7AJ => statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.humanApprovedPhase7AJ,
      );

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.developerOnly,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsDeveloperOnly &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsRolloutFalse &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.metadataOnly,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsStagedPreRuntimeOnly;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsRuntimeStartupOwnerHardeningPass =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus
            .runtimeStartupOwnerHardeningPass,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.decision ==
          CallV2RuntimeStartupOwnerHardeningAuditDecision.pass;

  bool get recordsRuntimeStartupOwnerClosed =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.runtimeStartupOwnerClosed,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsHardDisabled &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsUnreachable;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.runtimeUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRuntimeConstruction &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.runtimeNotStarted,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRuntimeStart &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRuntimeNotStarted;

  bool get recordsNoRuntimeStartupCall =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.noRuntimeStartupCall,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRuntimeStart;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit
          .recordsNoProductionCompositionConstruction &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.startupBridgeUncalled,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoStartupBridgeWiring &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoStartupBridgeCall;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.mainDartUnchanged,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoMainDartWiring &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsMainDartUnchanged;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.appRouterUnchanged,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoAppRouterWiring &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsAppRouterUnchanged;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.routesUnreachable,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.routeResolverNullWhileFalse,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit
          .recordsRouteRegistryNullWhileFalse &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.disabledRegistryNull,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsDisabledOwnerInert &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsDisabledRegistryNull;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.noBackendFirebaseAccess,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoBackendFirebaseAccess &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoBackendFirebaseAccess;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRtcPermissionAccess &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.noNavigatorWiring,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoNavigatorAccess &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.noLifecycleRegistration,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoLifecycleRegistration &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.noAsyncHandles,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoAsyncHandles &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.noDeployment,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoDeployment &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.rollbackOneCommit,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.rollbackPreserved &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsRollbackOneCommit;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2RuntimeStartupOwnerRecognitionStatus.v1Protected,
      ) &&
      callV2RuntimeStartupOwnerHardeningAudit.protectsV1 &&
      callV2FinalStagedPreRuntimeIntegrationAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'approvalRecorded': recordsHumanApprovedPhase7AJ,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
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
    return 'CallV2RuntimeStartupOwnerRecognition(${toSafeDebugMap()})';
  }
}

final callV2RuntimeStartupOwnerRecognition =
    CallV2RuntimeStartupOwnerRecognition(
  statuses: <CallV2RuntimeStartupOwnerRecognitionStatus>[
    CallV2RuntimeStartupOwnerRecognitionStatus.humanApprovedPhase7AJ,
    CallV2RuntimeStartupOwnerRecognitionStatus.developerOnly,
    CallV2RuntimeStartupOwnerRecognitionStatus.rolloutFalse,
    CallV2RuntimeStartupOwnerRecognitionStatus.metadataOnly,
    CallV2RuntimeStartupOwnerRecognitionStatus.finalStagedPreRuntimeAuditPass,
    CallV2RuntimeStartupOwnerRecognitionStatus.runtimeStartupOwnerHardeningPass,
    CallV2RuntimeStartupOwnerRecognitionStatus.runtimeStartupOwnerClosed,
    CallV2RuntimeStartupOwnerRecognitionStatus.runtimeUnconstructed,
    CallV2RuntimeStartupOwnerRecognitionStatus.runtimeNotStarted,
    CallV2RuntimeStartupOwnerRecognitionStatus.noRuntimeStartupCall,
    CallV2RuntimeStartupOwnerRecognitionStatus
        .productionCompositionUnconstructed,
    CallV2RuntimeStartupOwnerRecognitionStatus.startupBridgeUncalled,
    CallV2RuntimeStartupOwnerRecognitionStatus.mainDartUnchanged,
    CallV2RuntimeStartupOwnerRecognitionStatus.appRouterUnchanged,
    CallV2RuntimeStartupOwnerRecognitionStatus.routesUnreachable,
    CallV2RuntimeStartupOwnerRecognitionStatus.routeResolverNullWhileFalse,
    CallV2RuntimeStartupOwnerRecognitionStatus.disabledRegistryNull,
    CallV2RuntimeStartupOwnerRecognitionStatus.noBackendFirebaseAccess,
    CallV2RuntimeStartupOwnerRecognitionStatus.noRtcPermissionMediaDeviceAccess,
    CallV2RuntimeStartupOwnerRecognitionStatus.noNavigatorWiring,
    CallV2RuntimeStartupOwnerRecognitionStatus.noLifecycleRegistration,
    CallV2RuntimeStartupOwnerRecognitionStatus.noAsyncHandles,
    CallV2RuntimeStartupOwnerRecognitionStatus
        .noDependencyPlatformConfigChanges,
    CallV2RuntimeStartupOwnerRecognitionStatus.noDeployment,
    CallV2RuntimeStartupOwnerRecognitionStatus.rollbackOneCommit,
    CallV2RuntimeStartupOwnerRecognitionStatus.v1Protected,
  ],
);
