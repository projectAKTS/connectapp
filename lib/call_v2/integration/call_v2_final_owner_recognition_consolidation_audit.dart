import 'call_v2_backend_firebase_owner_recognition_hardening_audit.dart';
import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_lifecycle_observer_recognition_hardening_audit.dart';
import 'call_v2_navigator_owner_recognition_hardening_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_rtc_permission_owner_recognition_hardening_audit.dart';
import 'call_v2_runtime_startup_owner_recognition_hardening_audit.dart';

enum CallV2FinalOwnerRecognitionConsolidationAuditStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  runtimeStartupRecognitionHardeningPass,
  backendFirebaseRecognitionHardeningPass,
  rtcPermissionRecognitionHardeningPass,
  navigatorRecognitionHardeningPass,
  lifecycleObserverRecognitionHardeningPass,
  finalStagedPreRuntimeAuditPass,
  ownersClosedInert,
  runtimeUnconstructed,
  runtimeNotStarted,
  startupBridgeUncalled,
  noBackendFirebaseAccess,
  noFirestoreListeners,
  noFirestoreReads,
  noFirestoreWrites,
  noAuthFunctionsAppCheck,
  noRtcInitialized,
  noRtcEngineCreated,
  noRtcChannelJoined,
  noRtcTokenChannelConsumed,
  noPermissionsRequested,
  noMediaDeviceAccess,
  noNavigatorWiring,
  noNavigatorKey,
  noGlobalKey,
  noBuildContextStored,
  noMaterialAppRouteWiring,
  noNavigatorCalls,
  noLifecycleRegistration,
  noAppLifecycleListener,
  noWidgetsBindingObserver,
  noLifecycleCallbacksSubscriptions,
  noAsyncHandles,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  noDependencyPlatformConfigChanges,
  noRulesFunctionsConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2FinalOwnerRecognitionConsolidationAuditDecision {
  pass,
  blocked,
}

enum CallV2FinalOwnerRecognitionConsolidationRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2FinalOwnerRecognitionConsolidationAudit {
  factory CallV2FinalOwnerRecognitionConsolidationAudit({
    required List<CallV2FinalOwnerRecognitionConsolidationAuditStatus> statuses,
    required List<CallV2FinalOwnerRecognitionConsolidationRollback> rollback,
  }) {
    return CallV2FinalOwnerRecognitionConsolidationAudit._(
      List<CallV2FinalOwnerRecognitionConsolidationAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2FinalOwnerRecognitionConsolidationRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2FinalOwnerRecognitionConsolidationAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2FinalOwnerRecognitionConsolidationAuditStatus> statuses;
  final List<CallV2FinalOwnerRecognitionConsolidationRollback> rollback;

  CallV2FinalOwnerRecognitionConsolidationAuditDecision get decision {
    return passes
        ? CallV2FinalOwnerRecognitionConsolidationAuditDecision.pass
        : CallV2FinalOwnerRecognitionConsolidationAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsRuntimeStartupRecognitionHardeningPass &&
      recordsBackendFirebaseRecognitionHardeningPass &&
      recordsRtcPermissionRecognitionHardeningPass &&
      recordsNavigatorRecognitionHardeningPass &&
      recordsLifecycleObserverRecognitionHardeningPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsOwnersClosedInert &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsStartupBridgeUncalled &&
      recordsNoBackendFirebaseAccess &&
      recordsNoFirestoreListeners &&
      recordsNoFirestoreReads &&
      recordsNoFirestoreWrites &&
      recordsNoAuthFunctionsAppCheck &&
      recordsNoRtcInitialized &&
      recordsNoRtcEngineCreated &&
      recordsNoRtcChannelJoined &&
      recordsNoRtcTokenChannelConsumed &&
      recordsNoPermissionsRequested &&
      recordsNoMediaDeviceAccess &&
      recordsNoNavigatorWiring &&
      recordsNoNavigatorKey &&
      recordsNoGlobalKey &&
      recordsNoBuildContextStored &&
      recordsNoMaterialAppRouteWiring &&
      recordsNoNavigatorCalls &&
      recordsNoLifecycleRegistration &&
      recordsNoAppLifecycleListener &&
      recordsNoWidgetsBindingObserver &&
      recordsNoLifecycleCallbacksSubscriptions &&
      recordsNoAsyncHandles &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
      recordsNoDependencyPlatformConfigChanges &&
      recordsNoRulesFunctionsConfigChanges &&
      recordsNoDeployment &&
      recordsRollbackOneCommit &&
      recordsV1Protected;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.developerOnly,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsDeveloperOnly &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsDeveloperOnly &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsDeveloperOnly &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsDeveloperOnly &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsRolloutFalse &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsRolloutFalse &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsRolloutFalse &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRolloutFalse &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.metadataOnly,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsMetadataOnly &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsMetadataOnly &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsMetadataOnly &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsMetadataOnly &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsMetadataOnly;

  bool get recordsRuntimeStartupRecognitionHardeningPass =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .runtimeStartupRecognitionHardeningPass,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.decision ==
          CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsBackendFirebaseRecognitionHardeningPass =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .backendFirebaseRecognitionHardeningPass,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.decision ==
          CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsRtcPermissionRecognitionHardeningPass =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .rtcPermissionRecognitionHardeningPass,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.decision ==
          CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsNavigatorRecognitionHardeningPass =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .navigatorRecognitionHardeningPass,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.decision ==
          CallV2NavigatorOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsLifecycleObserverRecognitionHardeningPass =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .lifecycleObserverRecognitionHardeningPass,
      ) &&
      callV2LifecycleObserverRecognitionHardeningAudit.decision ==
          CallV2LifecycleObserverRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsOwnersClosedInert =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.ownersClosedInert,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRuntimeStartupOwnerClosed &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsBackendFirebaseOwnerClosed &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRtcPermissionOwnerClosed &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNavigatorOwnerClosed &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsLifecycleObserverClosed;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .runtimeUnconstructed,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsRuntimeUnconstructed &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.runtimeNotStarted,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRuntimeNotStarted &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRuntimeNotStarted &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRuntimeNotStarted &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRuntimeNotStarted &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsRuntimeNotStarted;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .startupBridgeUncalled,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsStartupBridgeUncalled &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsStartupBridgeUncalled;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noBackendFirebaseAccess,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoBackendFirebaseAccess &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoFirebaseAccess &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoBackendFirebaseAccess &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoBackendFirebaseAccess &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoBackendFirebaseAccess;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noFirestoreListeners,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoFirestoreListeners &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noFirestoreReads,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoFirestoreReads &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noFirestoreWrites,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoFirestoreWrites &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoFirestoreWrites;

  bool get recordsNoAuthFunctionsAppCheck =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noAuthFunctionsAppCheck,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoAuthFunctionsAppCheck &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsNoAuthCalls &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoFunctionsCalls &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoAppCheckCalls;

  bool get recordsNoRtcInitialized =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noRtcInitialized,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsNoRtcInitialized;

  bool get recordsNoRtcEngineCreated =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noRtcEngineCreated,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoRtcEngineCreated;

  bool get recordsNoRtcChannelJoined =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noRtcChannelJoined,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoRtcChannelJoined;

  bool get recordsNoRtcTokenChannelConsumed =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noRtcTokenChannelConsumed,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoRtcTokenChannelConsumed;

  bool get recordsNoPermissionsRequested =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noPermissionsRequested,
      ) &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoPermissionsRequested;

  bool get recordsNoMediaDeviceAccess =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noMediaDeviceAccess,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoDeviceEnumeration &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsNoMediaCapture &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoCameraPreview &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoAudioVideoPublish &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noNavigatorWiring,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoNavigatorWiring &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoNavigatorWiring &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoNavigatorWiring &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoNavigatorWiring &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsNoNavigatorWiring;

  bool get recordsNoNavigatorKey =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noNavigatorKey,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoNavigatorKey &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsNoNavigatorKey;

  bool get recordsNoGlobalKey =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noGlobalKey,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoGlobalKey &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsNoGlobalKey;

  bool get recordsNoBuildContextStored =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noBuildContextStored,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoBuildContextStored &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoBuildContextStored;

  bool get recordsNoMaterialAppRouteWiring =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noMaterialAppRouteWiring,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoMaterialAppRouteWiring;

  bool get recordsNoNavigatorCalls =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noNavigatorCalls,
      ) &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoNavigatorCalls;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoLifecycleRegistration &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoLifecycleRegistration &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoLifecycleRegistration &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoLifecycleRegistration &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoLifecycleRegistration;

  bool get recordsNoAppLifecycleListener =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noAppLifecycleListener,
      ) &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoAppLifecycleListener;

  bool get recordsNoWidgetsBindingObserver =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noWidgetsBindingObserver,
      ) &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoWidgetsBindingObserver;

  bool get recordsNoLifecycleCallbacksSubscriptions =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noLifecycleCallbacksSubscriptions,
      ) &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoLifecycleCallbacksSubscriptions;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noAsyncHandles,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoAsyncHandles &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoAsyncHandles &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsNoAsyncHandles &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoAsyncHandles &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsNoAsyncHandles;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.routesUnreachable,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRoutesUnreachable &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRoutesUnreachable &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRoutesUnreachable &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRoutesUnreachable &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .disabledRegistryNull,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsDisabledRegistryNull &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsDisabledRegistryNull &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsDisabledRegistryNull &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsDisabledRegistryNull &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsDisabledRegistryNull;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges &&
      callV2NavigatorOwnerRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges &&
      callV2LifecycleObserverRecognitionHardeningAudit
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoRulesFunctionsConfigChanges =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus
            .noRulesFunctionsConfigChanges,
      ) &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsNoRulesFunctionsConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.noDeployment,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsNoDeployment &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsNoDeployment &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsNoDeployment &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsNoDeployment &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2FinalOwnerRecognitionConsolidationRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2FinalOwnerRecognitionConsolidationRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2FinalOwnerRecognitionConsolidationRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2FinalOwnerRecognitionConsolidationRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2FinalOwnerRecognitionConsolidationRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2FinalOwnerRecognitionConsolidationRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2FinalOwnerRecognitionConsolidationRollback.v1Unaffected,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit
          .recordsRollbackOneCommit &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit
          .recordsRollbackOneCommit &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit
          .recordsRollbackOneCommit &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsRollbackOneCommit &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsRollbackOneCommit;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2FinalOwnerRecognitionConsolidationAuditStatus.v1Protected,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2RtcPermissionOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2NavigatorOwnerRecognitionHardeningAudit.recordsV1Protected &&
      callV2LifecycleObserverRecognitionHardeningAudit.recordsV1Protected;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'runtimeStartupHardeningPass':
          recordsRuntimeStartupRecognitionHardeningPass,
      'backendFirebaseHardeningPass':
          recordsBackendFirebaseRecognitionHardeningPass,
      'rtcPermissionHardeningPass':
          recordsRtcPermissionRecognitionHardeningPass,
      'navigatorHardeningPass': recordsNavigatorRecognitionHardeningPass,
      'observerHardeningPass': recordsLifecycleObserverRecognitionHardeningPass,
      'finalStagedPreRuntimeAuditPass': recordsFinalStagedPreRuntimeAuditPass,
      'ownersClosed': recordsOwnersClosedInert,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'startupBridgeCalled': false,
      'backendAccess': false,
      'firestoreListeners': false,
      'firestoreReads': false,
      'firestoreWrites': false,
      'authFunctionsAppCheck': false,
      'rtcInitialized': false,
      'rtcEngineCreated': false,
      'rtcChannelJoined': false,
      'rtcTokenChannelConsumed': false,
      'permissionsRequested': false,
      'mediaDeviceAccess': false,
      'navWired': false,
      'appKeyCreated': false,
      'globalKeyCreated': false,
      'widgetContextStored': false,
      'materialRouteTableWired': false,
      'navCalled': false,
      'observerRegistered': false,
      'appLifecycleHookCreated': false,
      'bindingObserverAttached': false,
      'callbacksSubscribed': false,
      'asyncHandlesOpened': false,
      'routesReachable': false,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'dependencyPlatformConfigChanged': false,
      'rulesFunctionsConfigChanged': false,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2FinalOwnerRecognitionConsolidationAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2FinalOwnerRecognitionConsolidationAudit =
    CallV2FinalOwnerRecognitionConsolidationAudit(
  statuses: <CallV2FinalOwnerRecognitionConsolidationAuditStatus>[
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.developerOnly,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.rolloutFalse,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.metadataOnly,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .runtimeStartupRecognitionHardeningPass,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .backendFirebaseRecognitionHardeningPass,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .rtcPermissionRecognitionHardeningPass,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .navigatorRecognitionHardeningPass,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .lifecycleObserverRecognitionHardeningPass,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .finalStagedPreRuntimeAuditPass,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.ownersClosedInert,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.runtimeUnconstructed,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.runtimeNotStarted,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.startupBridgeUncalled,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noBackendFirebaseAccess,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noFirestoreListeners,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noFirestoreReads,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noFirestoreWrites,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noAuthFunctionsAppCheck,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noRtcInitialized,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noRtcEngineCreated,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noRtcChannelJoined,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .noRtcTokenChannelConsumed,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noPermissionsRequested,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noMediaDeviceAccess,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noNavigatorWiring,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noNavigatorKey,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noGlobalKey,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noBuildContextStored,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .noMaterialAppRouteWiring,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noNavigatorCalls,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noLifecycleRegistration,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noAppLifecycleListener,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .noWidgetsBindingObserver,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .noLifecycleCallbacksSubscriptions,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noAsyncHandles,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.routesUnreachable,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .routeResolverNullWhileFalse,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.disabledRegistryNull,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus
        .noRulesFunctionsConfigChanges,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.noDeployment,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.rollbackOneCommit,
    CallV2FinalOwnerRecognitionConsolidationAuditStatus.v1Protected,
  ],
  rollback: <CallV2FinalOwnerRecognitionConsolidationRollback>[
    CallV2FinalOwnerRecognitionConsolidationRollback.oneCommitRevert,
    CallV2FinalOwnerRecognitionConsolidationRollback.keepRolloutFalse,
    CallV2FinalOwnerRecognitionConsolidationRollback.keepRouteRegistryNull,
    CallV2FinalOwnerRecognitionConsolidationRollback.keepDisabledOwnerInert,
    CallV2FinalOwnerRecognitionConsolidationRollback.noDeploymentRequired,
    CallV2FinalOwnerRecognitionConsolidationRollback.noConfigChanges,
    CallV2FinalOwnerRecognitionConsolidationRollback.v1Unaffected,
  ],
);
