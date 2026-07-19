import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_lifecycle_observer_hardening_audit.dart';
import 'call_v2_lifecycle_observer_recognition.dart';
import 'call_v2_navigator_owner_recognition_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2LifecycleObserverRecognitionHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  lifecycleObserverRecognitionPass,
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

enum CallV2LifecycleObserverRecognitionHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2LifecycleObserverRecognitionHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2LifecycleObserverRecognitionHardeningAudit {
  factory CallV2LifecycleObserverRecognitionHardeningAudit({
    required List<CallV2LifecycleObserverRecognitionHardeningAuditStatus>
        statuses,
    required List<CallV2LifecycleObserverRecognitionHardeningRollback> rollback,
  }) {
    return CallV2LifecycleObserverRecognitionHardeningAudit._(
      List<CallV2LifecycleObserverRecognitionHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2LifecycleObserverRecognitionHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2LifecycleObserverRecognitionHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2LifecycleObserverRecognitionHardeningAuditStatus> statuses;
  final List<CallV2LifecycleObserverRecognitionHardeningRollback> rollback;

  CallV2LifecycleObserverRecognitionHardeningAuditDecision get decision {
    return passes
        ? CallV2LifecycleObserverRecognitionHardeningAuditDecision.pass
        : CallV2LifecycleObserverRecognitionHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsLifecycleObserverRecognitionPass &&
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
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.developerOnly,
      ) &&
      callV2LifecycleObserverRecognition.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2LifecycleObserverRecognition.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.metadataOnly,
      ) &&
      callV2LifecycleObserverRecognition.recordsMetadataOnly;

  bool get recordsLifecycleObserverRecognitionPass =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .lifecycleObserverRecognitionPass,
      ) &&
      callV2LifecycleObserverRecognition.decision ==
          CallV2LifecycleObserverRecognitionDecision.pass;

  bool get recordsNavigatorRecognitionHardeningPass =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .navigatorRecognitionHardeningPass,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.decision ==
          CallV2NavigatorOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsLifecycleObserverHardeningPass =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .lifecycleObserverHardeningPass,
      ) &&
      callV2LifecycleObserverHardeningAudit.decision ==
          CallV2LifecycleObserverHardeningAuditDecision.pass;

  bool get recordsLifecycleObserverClosed =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .lifecycleObserverClosed,
      ) &&
      callV2LifecycleObserverRecognition.recordsLifecycleObserverClosed &&
      callV2LifecycleObserverHardeningAudit.recordsHardDisabled &&
      callV2LifecycleObserverHardeningAudit.recordsUnreachable &&
      callV2LifecycleObserverHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoLifecycleRegistration;

  bool get recordsNoAppLifecycleListener =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noAppLifecycleListener,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoAppLifecycleListener;

  bool get recordsNoWidgetsBindingObserver =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noWidgetsBindingObserver,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoWidgetsBindingObserver;

  bool get recordsNoLifecycleCallbacksSubscriptions =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noLifecycleCallbacksSubscriptions,
      ) &&
      callV2LifecycleObserverRecognition
          .recordsNoLifecycleCallbacksSubscriptions;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.noAsyncHandles,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoAsyncHandles;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noNavigatorWiring,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoNavigatorWiring;

  bool get recordsNoNavigatorKey =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.noNavigatorKey,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoNavigatorKey;

  bool get recordsNoGlobalKey =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.noGlobalKey,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoGlobalKey;

  bool get recordsNoBuildContextStored =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noBuildContextStored,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoBuildContextStored;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .runtimeUnconstructed,
      ) &&
      callV2LifecycleObserverRecognition.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .runtimeNotStarted,
      ) &&
      callV2LifecycleObserverRecognition.recordsRuntimeNotStarted;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2LifecycleObserverRecognition
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .startupBridgeUncalled,
      ) &&
      callV2LifecycleObserverRecognition.recordsStartupBridgeUncalled;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noBackendFirebaseAccess,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoBackendFirebaseAccess;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2LifecycleObserverRecognition
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .routesUnreachable,
      ) &&
      callV2LifecycleObserverRecognition.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2LifecycleObserverRecognition.recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .disabledRegistryNull,
      ) &&
      callV2LifecycleObserverRecognition.recordsDisabledRegistryNull;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2LifecycleObserverRecognition
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.noDeployment,
      ) &&
      callV2LifecycleObserverRecognition.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverRecognitionHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverRecognitionHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverRecognitionHardeningRollback
            .keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverRecognitionHardeningRollback
            .keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverRecognitionHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverRecognitionHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverRecognitionHardeningRollback.v1Unaffected,
      ) &&
      callV2LifecycleObserverRecognition.recordsRollbackOneCommit &&
      callV2LifecycleObserverHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2LifecycleObserverRecognitionHardeningAuditStatus.v1Protected,
      ) &&
      callV2LifecycleObserverRecognition.recordsV1Protected &&
      callV2LifecycleObserverHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'recognitionPass': recordsLifecycleObserverRecognitionPass,
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
    return 'CallV2LifecycleObserverRecognitionHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2LifecycleObserverRecognitionHardeningAudit =
    CallV2LifecycleObserverRecognitionHardeningAudit(
  statuses: <CallV2LifecycleObserverRecognitionHardeningAuditStatus>[
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.developerOnly,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.rolloutFalse,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.metadataOnly,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .lifecycleObserverRecognitionPass,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .navigatorRecognitionHardeningPass,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .finalStagedPreRuntimeAuditPass,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .lifecycleObserverHardeningPass,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .lifecycleObserverClosed,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .noLifecycleRegistration,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .noAppLifecycleListener,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .noWidgetsBindingObserver,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .noLifecycleCallbacksSubscriptions,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.noAsyncHandles,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.noNavigatorWiring,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.noNavigatorKey,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.noGlobalKey,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.noBuildContextStored,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.runtimeUnconstructed,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.runtimeNotStarted,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .productionCompositionUnconstructed,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .startupBridgeUncalled,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .noBackendFirebaseAccess,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.routesUnreachable,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .routeResolverNullWhileFalse,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.disabledRegistryNull,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.noDeployment,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.rollbackOneCommit,
    CallV2LifecycleObserverRecognitionHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2LifecycleObserverRecognitionHardeningRollback>[
    CallV2LifecycleObserverRecognitionHardeningRollback.oneCommitRevert,
    CallV2LifecycleObserverRecognitionHardeningRollback.keepRolloutFalse,
    CallV2LifecycleObserverRecognitionHardeningRollback.keepRouteRegistryNull,
    CallV2LifecycleObserverRecognitionHardeningRollback.keepDisabledOwnerInert,
    CallV2LifecycleObserverRecognitionHardeningRollback.noDeploymentRequired,
    CallV2LifecycleObserverRecognitionHardeningRollback.noConfigChanges,
    CallV2LifecycleObserverRecognitionHardeningRollback.v1Unaffected,
  ],
);
