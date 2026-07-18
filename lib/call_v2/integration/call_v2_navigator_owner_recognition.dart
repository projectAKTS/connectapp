import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_navigator_owner_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_rtc_permission_owner_recognition_hardening_audit.dart';

enum CallV2NavigatorOwnerRecognitionStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
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

enum CallV2NavigatorOwnerRecognitionDecision {
  pass,
  blocked,
}

final class CallV2NavigatorOwnerRecognition {
  factory CallV2NavigatorOwnerRecognition({
    required List<CallV2NavigatorOwnerRecognitionStatus> statuses,
  }) {
    return CallV2NavigatorOwnerRecognition._(
      List<CallV2NavigatorOwnerRecognitionStatus>.unmodifiable(statuses),
    );
  }

  const CallV2NavigatorOwnerRecognition._(this.statuses);

  final List<CallV2NavigatorOwnerRecognitionStatus> statuses;

  CallV2NavigatorOwnerRecognitionDecision get decision {
    return passes
        ? CallV2NavigatorOwnerRecognitionDecision.pass
        : CallV2NavigatorOwnerRecognitionDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
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
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.developerOnly) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsDeveloperOnly &&
      callV2NavigatorOwnerHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsRolloutFalse &&
      callV2NavigatorOwnerHardeningAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.metadataOnly) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsMetadataOnly;

  bool get recordsRtcPermissionRecognitionHardeningPass =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus
            .rtcPermissionRecognitionHardeningPass,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.decision ==
          CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsNavigatorOwnerHardeningPass =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.navigatorOwnerHardeningPass,
      ) &&
      callV2NavigatorOwnerHardeningAudit.decision ==
          CallV2NavigatorOwnerHardeningAuditDecision.pass;

  bool get recordsNavigatorOwnerClosed =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.navigatorOwnerClosed,
      ) &&
      callV2NavigatorOwnerHardeningAudit.recordsHardDisabled &&
      callV2NavigatorOwnerHardeningAudit.recordsUnreachable &&
      callV2NavigatorOwnerHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.noNavigatorWiring,
      ) &&
      !callV2NavigatorOwnerHardeningAudit.wiresRealNavigator;

  bool get recordsNoNavigatorKey =>
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.noNavigatorKey) &&
      !callV2NavigatorOwnerHardeningAudit.usesAppNavigatorKey;

  bool get recordsNoGlobalKey =>
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.noGlobalKey) &&
      !callV2NavigatorOwnerHardeningAudit.usesGlobalKey;

  bool get recordsNoBuildContextStored =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.noBuildContextStored,
      ) &&
      !callV2NavigatorOwnerHardeningAudit.storesBuildContext;

  bool get recordsNoMaterialAppRouteWiring =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.noMaterialAppRouteWiring,
      ) &&
      !callV2NavigatorOwnerHardeningAudit.wiresMaterialApp;

  bool get recordsNoNavigatorCalls =>
      statuses
          .contains(CallV2NavigatorOwnerRecognitionStatus.noNavigatorCalls) &&
      !callV2NavigatorOwnerHardeningAudit.callsNavigator;

  bool get recordsRoutesUnreachable =>
      statuses
          .contains(CallV2NavigatorOwnerRecognitionStatus.routesUnreachable) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRoutesUnreachable &&
      callV2NavigatorOwnerHardeningAudit.recordsUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.routeResolverNullWhileFalse,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2NavigatorOwnerHardeningAudit.recordsRouteRegistryNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.disabledRegistryNull,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsDisabledRegistryNull;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.runtimeUnconstructed,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed &&
      !callV2NavigatorOwnerHardeningAudit.startsRuntime;

  bool get recordsRuntimeNotStarted =>
      statuses
          .contains(CallV2NavigatorOwnerRecognitionStatus.runtimeNotStarted) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRuntimeNotStarted &&
      !callV2NavigatorOwnerHardeningAudit.startsRuntime;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.startupBridgeUncalled,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.noBackendFirebaseAccess,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoBackendFirebaseAccess &&
      !callV2NavigatorOwnerHardeningAudit.accessesBackendFirebase;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.noRtcPermissionMediaDeviceAccess,
      ) &&
      !callV2NavigatorOwnerHardeningAudit.accessesRtcPermissions;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.noLifecycleRegistration,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoLifecycleRegistration &&
      !callV2NavigatorOwnerHardeningAudit.registersLifecycle;

  bool get recordsNoAsyncHandles =>
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.noAsyncHandles) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsNoAsyncHandles &&
      !callV2NavigatorOwnerHardeningAudit.opensAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.noDependencyPlatformConfigChanges,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.noDeployment) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2NavigatorOwnerRecognitionStatus.rollbackOneCommit,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRollbackOneCommit &&
      callV2NavigatorOwnerHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses.contains(CallV2NavigatorOwnerRecognitionStatus.v1Protected) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2NavigatorOwnerHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
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
    return 'CallV2NavigatorOwnerRecognition(${toSafeDebugMap()})';
  }
}

final callV2NavigatorOwnerRecognition = CallV2NavigatorOwnerRecognition(
  statuses: <CallV2NavigatorOwnerRecognitionStatus>[
    CallV2NavigatorOwnerRecognitionStatus.developerOnly,
    CallV2NavigatorOwnerRecognitionStatus.rolloutFalse,
    CallV2NavigatorOwnerRecognitionStatus.metadataOnly,
    CallV2NavigatorOwnerRecognitionStatus.rtcPermissionRecognitionHardeningPass,
    CallV2NavigatorOwnerRecognitionStatus.finalStagedPreRuntimeAuditPass,
    CallV2NavigatorOwnerRecognitionStatus.navigatorOwnerHardeningPass,
    CallV2NavigatorOwnerRecognitionStatus.navigatorOwnerClosed,
    CallV2NavigatorOwnerRecognitionStatus.noNavigatorWiring,
    CallV2NavigatorOwnerRecognitionStatus.noNavigatorKey,
    CallV2NavigatorOwnerRecognitionStatus.noGlobalKey,
    CallV2NavigatorOwnerRecognitionStatus.noBuildContextStored,
    CallV2NavigatorOwnerRecognitionStatus.noMaterialAppRouteWiring,
    CallV2NavigatorOwnerRecognitionStatus.noNavigatorCalls,
    CallV2NavigatorOwnerRecognitionStatus.routesUnreachable,
    CallV2NavigatorOwnerRecognitionStatus.routeResolverNullWhileFalse,
    CallV2NavigatorOwnerRecognitionStatus.disabledRegistryNull,
    CallV2NavigatorOwnerRecognitionStatus.runtimeUnconstructed,
    CallV2NavigatorOwnerRecognitionStatus.runtimeNotStarted,
    CallV2NavigatorOwnerRecognitionStatus.productionCompositionUnconstructed,
    CallV2NavigatorOwnerRecognitionStatus.startupBridgeUncalled,
    CallV2NavigatorOwnerRecognitionStatus.noBackendFirebaseAccess,
    CallV2NavigatorOwnerRecognitionStatus.noRtcPermissionMediaDeviceAccess,
    CallV2NavigatorOwnerRecognitionStatus.noLifecycleRegistration,
    CallV2NavigatorOwnerRecognitionStatus.noAsyncHandles,
    CallV2NavigatorOwnerRecognitionStatus.noDependencyPlatformConfigChanges,
    CallV2NavigatorOwnerRecognitionStatus.noDeployment,
    CallV2NavigatorOwnerRecognitionStatus.rollbackOneCommit,
    CallV2NavigatorOwnerRecognitionStatus.v1Protected,
  ],
);
