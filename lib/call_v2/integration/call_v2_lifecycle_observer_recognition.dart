import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_lifecycle_observer_hardening_audit.dart';
import 'call_v2_navigator_owner_recognition_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2LifecycleObserverRecognitionStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  navigatorRecognitionHardeningPass,
  finalStagedPreRuntimeAuditPass,
  lifecycleObserverHardeningPass,
  lifecycleObserverClosed,
  noLifecycleRegistration,
  noAppLifecycleListener,
  noWidgetsBindingObserver,
  noLifecycleCallbacksSubscriptions,
  noAsyncHandles,
  noNavigatorWiring,
  noNavigatorKey,
  noGlobalKey,
  noBuildContextStored,
  runtimeUnconstructed,
  runtimeNotStarted,
  productionCompositionUnconstructed,
  startupBridgeUncalled,
  noBackendFirebaseAccess,
  noRtcPermissionMediaDeviceAccess,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2LifecycleObserverRecognitionDecision {
  pass,
  blocked,
}

final class CallV2LifecycleObserverRecognition {
  factory CallV2LifecycleObserverRecognition({
    required List<CallV2LifecycleObserverRecognitionStatus> statuses,
  }) {
    return CallV2LifecycleObserverRecognition._(
      List<CallV2LifecycleObserverRecognitionStatus>.unmodifiable(statuses),
    );
  }

  const CallV2LifecycleObserverRecognition._(this.statuses);

  final List<CallV2LifecycleObserverRecognitionStatus> statuses;

  CallV2LifecycleObserverRecognitionDecision get decision {
    return passes
        ? CallV2LifecycleObserverRecognitionDecision.pass
        : CallV2LifecycleObserverRecognitionDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsNavigatorRecognitionHardeningPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsLifecycleObserverHardeningPass &&
      recordsLifecycleObserverClosed &&
      recordsNoLifecycleRegistration &&
      recordsNoAppLifecycleListener &&
      recordsNoWidgetsBindingObserver &&
      recordsNoLifecycleCallbacksSubscriptions &&
      recordsNoAsyncHandles &&
      recordsNoNavigatorWiring &&
      recordsNoNavigatorKey &&
      recordsNoGlobalKey &&
      recordsNoBuildContextStored &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsProductionCompositionUnconstructed &&
      recordsStartupBridgeUncalled &&
      recordsNoBackendFirebaseAccess &&
      recordsNoRtcPermissionMediaDeviceAccess &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses
          .contains(CallV2LifecycleObserverRecognitionStatus.developerOnly) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsDeveloperOnly &&
      callV2LifecycleObserverHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses
          .contains(CallV2LifecycleObserverRecognitionStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRolloutFalse &&
      callV2LifecycleObserverHardeningAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses
          .contains(CallV2LifecycleObserverRecognitionStatus.metadataOnly) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsMetadataOnly;

  bool get recordsNavigatorRecognitionHardeningPass =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus
            .navigatorRecognitionHardeningPass,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.decision ==
          CallV2NavigatorOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsLifecycleObserverHardeningPass =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.lifecycleObserverHardeningPass,
      ) &&
      callV2LifecycleObserverHardeningAudit.decision ==
          CallV2LifecycleObserverHardeningAuditDecision.pass;

  bool get recordsLifecycleObserverClosed =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.lifecycleObserverClosed,
      ) &&
      callV2LifecycleObserverHardeningAudit.recordsHardDisabled &&
      callV2LifecycleObserverHardeningAudit.recordsUnreachable &&
      callV2LifecycleObserverHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.noLifecycleRegistration,
      ) &&
      callV2LifecycleObserverHardeningAudit.recordsNoObserverRegistration;

  bool get recordsNoAppLifecycleListener =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.noAppLifecycleListener,
      ) &&
      callV2LifecycleObserverHardeningAudit.recordsNoFrameworkLifecycleObserver;

  bool get recordsNoWidgetsBindingObserver =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.noWidgetsBindingObserver,
      ) &&
      callV2LifecycleObserverHardeningAudit.recordsNoBindingLifecycleObserver;

  bool get recordsNoLifecycleCallbacksSubscriptions =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus
            .noLifecycleCallbacksSubscriptions,
      ) &&
      callV2LifecycleObserverHardeningAudit.recordsNoObserverRegistration &&
      callV2LifecycleObserverHardeningAudit.recordsNoAsyncHandles;

  bool get recordsNoAsyncHandles =>
      statuses
          .contains(CallV2LifecycleObserverRecognitionStatus.noAsyncHandles) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoAsyncHandles &&
      callV2LifecycleObserverHardeningAudit.recordsNoAsyncHandles;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.noNavigatorWiring,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoNavigatorWiring &&
      callV2LifecycleObserverHardeningAudit.recordsNoNavigatorAccess;

  bool get recordsNoNavigatorKey =>
      statuses
          .contains(CallV2LifecycleObserverRecognitionStatus.noNavigatorKey) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoNavigatorKey;

  bool get recordsNoGlobalKey =>
      statuses.contains(CallV2LifecycleObserverRecognitionStatus.noGlobalKey) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoGlobalKey;

  bool get recordsNoBuildContextStored =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.noBuildContextStored,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoBuildContextStored;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.runtimeUnconstructed,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed &&
      callV2LifecycleObserverHardeningAudit.recordsNoRuntimeStart;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.runtimeNotStarted,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRuntimeNotStarted &&
      callV2LifecycleObserverHardeningAudit.recordsNoRuntimeStart;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.startupBridgeUncalled,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.noBackendFirebaseAccess,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoBackendFirebaseAccess &&
      callV2LifecycleObserverHardeningAudit.recordsNoBackendFirebaseAccess;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess &&
      callV2LifecycleObserverHardeningAudit.recordsNoRtcPermissionAccess;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.routesUnreachable,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRoutesUnreachable &&
      callV2LifecycleObserverHardeningAudit.recordsUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.routeResolverNullWhileFalse,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2LifecycleObserverHardeningAudit.recordsRouteRegistryNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.disabledRegistryNull,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsDisabledRegistryNull;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses
          .contains(CallV2LifecycleObserverRecognitionStatus.noDeployment) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionStatus.rollbackOneCommit,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRollbackOneCommit &&
      callV2LifecycleObserverHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses.contains(CallV2LifecycleObserverRecognitionStatus.v1Protected) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2LifecycleObserverHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'navigatorRecognitionHardeningPass':
          recordsNavigatorRecognitionHardeningPass,
      'finalStagedPreRuntimeAuditPass': recordsFinalStagedPreRuntimeAuditPass,
      'observerHardeningPass': recordsLifecycleObserverHardeningPass,
      'observerClosed': recordsLifecycleObserverClosed,
      'observerRegistered': false,
      'appLifecycleHookCreated': false,
      'bindingObserverAttached': false,
      'callbacksSubscribed': false,
      'asyncHandlesOpened': false,
      'navWired': false,
      'appKeyCreated': false,
      'globalKeyCreated': false,
      'widgetContextStored': false,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'backendAccess': false,
      'rtcPermissionAccess': false,
      'routesReachable': false,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2LifecycleObserverRecognition(${toSafeDebugMap()})';
  }
}

final callV2LifecycleObserverRecognition = CallV2LifecycleObserverRecognition(
  statuses: <CallV2LifecycleObserverRecognitionStatus>[
    CallV2LifecycleObserverRecognitionStatus.developerOnly,
    CallV2LifecycleObserverRecognitionStatus.rolloutFalse,
    CallV2LifecycleObserverRecognitionStatus.metadataOnly,
    CallV2LifecycleObserverRecognitionStatus.navigatorRecognitionHardeningPass,
    CallV2LifecycleObserverRecognitionStatus.finalStagedPreRuntimeAuditPass,
    CallV2LifecycleObserverRecognitionStatus.lifecycleObserverHardeningPass,
    CallV2LifecycleObserverRecognitionStatus.lifecycleObserverClosed,
    CallV2LifecycleObserverRecognitionStatus.noLifecycleRegistration,
    CallV2LifecycleObserverRecognitionStatus.noAppLifecycleListener,
    CallV2LifecycleObserverRecognitionStatus.noWidgetsBindingObserver,
    CallV2LifecycleObserverRecognitionStatus.noLifecycleCallbacksSubscriptions,
    CallV2LifecycleObserverRecognitionStatus.noAsyncHandles,
    CallV2LifecycleObserverRecognitionStatus.noNavigatorWiring,
    CallV2LifecycleObserverRecognitionStatus.noNavigatorKey,
    CallV2LifecycleObserverRecognitionStatus.noGlobalKey,
    CallV2LifecycleObserverRecognitionStatus.noBuildContextStored,
    CallV2LifecycleObserverRecognitionStatus.runtimeUnconstructed,
    CallV2LifecycleObserverRecognitionStatus.runtimeNotStarted,
    CallV2LifecycleObserverRecognitionStatus.productionCompositionUnconstructed,
    CallV2LifecycleObserverRecognitionStatus.startupBridgeUncalled,
    CallV2LifecycleObserverRecognitionStatus.noBackendFirebaseAccess,
    CallV2LifecycleObserverRecognitionStatus.noRtcPermissionMediaDeviceAccess,
    CallV2LifecycleObserverRecognitionStatus.routesUnreachable,
    CallV2LifecycleObserverRecognitionStatus.routeResolverNullWhileFalse,
    CallV2LifecycleObserverRecognitionStatus.disabledRegistryNull,
    CallV2LifecycleObserverRecognitionStatus.noDependencyPlatformConfigChanges,
    CallV2LifecycleObserverRecognitionStatus.noDeployment,
    CallV2LifecycleObserverRecognitionStatus.rollbackOneCommit,
    CallV2LifecycleObserverRecognitionStatus.v1Protected,
  ],
);
