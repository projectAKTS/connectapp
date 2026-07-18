import 'call_v2_backend_firebase_owner_hardening_audit.dart';
import 'call_v2_backend_firebase_owner_recognition.dart';
import 'call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_runtime_startup_owner_recognition_hardening_audit.dart';

enum CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus {
  developerOnly,
  rolloutFalse,
  metadataOnly,
  backendFirebaseOwnerRecognitionPass,
  runtimeStartupRecognitionHardeningPass,
  finalStagedPreRuntimeAuditPass,
  backendFirebaseOwnerHardeningPass,
  backendFirebaseOwnerClosed,
  noFirebaseAccess,
  noFirestoreListeners,
  noFirestoreReads,
  noFirestoreWrites,
  noAuthCalls,
  noFunctionsCalls,
  noAppCheckCalls,
  noRulesFunctionsConfigChanges,
  runtimeUnconstructed,
  runtimeNotStarted,
  productionCompositionUnconstructed,
  startupBridgeUncalled,
  mainDartUnchanged,
  appRouterUnchanged,
  routesUnreachable,
  routeResolverNullWhileFalse,
  disabledRegistryNull,
  noRtcPermissionMediaDeviceAccess,
  noNavigatorWiring,
  noLifecycleRegistration,
  noAsyncHandles,
  noDependencyPlatformConfigChanges,
  noDeployment,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2BackendFirebaseOwnerRecognitionHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2BackendFirebaseOwnerRecognitionHardeningAudit {
  factory CallV2BackendFirebaseOwnerRecognitionHardeningAudit({
    required List<CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus>
        statuses,
    required List<CallV2BackendFirebaseOwnerRecognitionHardeningRollback>
        rollback,
  }) {
    return CallV2BackendFirebaseOwnerRecognitionHardeningAudit._(
      List<CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus>.unmodifiable(
          statuses),
      List<CallV2BackendFirebaseOwnerRecognitionHardeningRollback>.unmodifiable(
        rollback,
      ),
    );
  }

  const CallV2BackendFirebaseOwnerRecognitionHardeningAudit._(
    this.statuses,
    this.rollback,
  );

  final List<CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus>
      statuses;
  final List<CallV2BackendFirebaseOwnerRecognitionHardeningRollback> rollback;

  CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision get decision {
    return passes
        ? CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.pass
        : CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsRolloutFalse &&
      recordsMetadataOnly &&
      recordsBackendFirebaseOwnerRecognitionPass &&
      recordsRuntimeStartupRecognitionHardeningPass &&
      recordsFinalStagedPreRuntimeAuditPass &&
      recordsBackendFirebaseOwnerHardeningPass &&
      recordsBackendFirebaseOwnerClosed &&
      recordsNoFirebaseAccess &&
      recordsNoFirestoreListeners &&
      recordsNoFirestoreReads &&
      recordsNoFirestoreWrites &&
      recordsNoAuthCalls &&
      recordsNoFunctionsCalls &&
      recordsNoAppCheckCalls &&
      recordsNoRulesFunctionsConfigChanges &&
      recordsRuntimeUnconstructed &&
      recordsRuntimeNotStarted &&
      recordsProductionCompositionUnconstructed &&
      recordsStartupBridgeUncalled &&
      recordsMainDartUnchanged &&
      recordsAppRouterUnchanged &&
      recordsRoutesUnreachable &&
      recordsRouteResolverNullWhileFalse &&
      recordsDisabledRegistryNull &&
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
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.developerOnly,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsDeveloperOnly;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      callV2BackendFirebaseOwnerRecognition.recordsRolloutFalse;

  bool get recordsMetadataOnly =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.metadataOnly,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsMetadataOnly;

  bool get recordsBackendFirebaseOwnerRecognitionPass =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .backendFirebaseOwnerRecognitionPass,
      ) &&
      callV2BackendFirebaseOwnerRecognition.decision ==
          CallV2BackendFirebaseOwnerRecognitionDecision.pass;

  bool get recordsRuntimeStartupRecognitionHardeningPass =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .runtimeStartupRecognitionHardeningPass,
      ) &&
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.decision ==
          CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.pass;

  bool get recordsFinalStagedPreRuntimeAuditPass =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .finalStagedPreRuntimeAuditPass,
      ) &&
      callV2FinalStagedPreRuntimeIntegrationAudit.decision ==
          CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass;

  bool get recordsBackendFirebaseOwnerHardeningPass =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .backendFirebaseOwnerHardeningPass,
      ) &&
      callV2BackendFirebaseOwnerHardeningAudit.decision ==
          CallV2BackendFirebaseOwnerHardeningAuditDecision.pass;

  bool get recordsBackendFirebaseOwnerClosed =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .backendFirebaseOwnerClosed,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsBackendFirebaseOwnerClosed &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsHardDisabled &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsUnreachable &&
      callV2BackendFirebaseOwnerHardeningAudit.recordsDisabledOwnerInert;

  bool get recordsNoFirebaseAccess =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noFirebaseAccess,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoFirebaseAccess;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noFirestoreListeners,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noFirestoreReads,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoFirestoreReads;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noFirestoreWrites,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoFirestoreWrites;

  bool get recordsNoAuthCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noAuthCalls,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoAuthCalls;

  bool get recordsNoFunctionsCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noFunctionsCalls,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoFunctionsCalls;

  bool get recordsNoAppCheckCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noAppCheckCalls,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoAppCheckCalls;

  bool get recordsNoRulesFunctionsConfigChanges =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noRulesFunctionsConfigChanges,
      ) &&
      callV2BackendFirebaseOwnerRecognition
          .recordsNoRulesFunctionsConfigChanges;

  bool get recordsRuntimeUnconstructed =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .runtimeUnconstructed,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsRuntimeUnconstructed;

  bool get recordsRuntimeNotStarted =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .runtimeNotStarted,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsRuntimeNotStarted;

  bool get recordsProductionCompositionUnconstructed =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .productionCompositionUnconstructed,
      ) &&
      callV2BackendFirebaseOwnerRecognition
          .recordsProductionCompositionUnconstructed;

  bool get recordsStartupBridgeUncalled =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .startupBridgeUncalled,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsStartupBridgeUncalled;

  bool get recordsMainDartUnchanged =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .mainDartUnchanged,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsMainDartUnchanged;

  bool get recordsAppRouterUnchanged =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .appRouterUnchanged,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsAppRouterUnchanged;

  bool get recordsRoutesUnreachable =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .routesUnreachable,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsRoutesUnreachable;

  bool get recordsRouteResolverNullWhileFalse =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .routeResolverNullWhileFalse,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsRouteResolverNullWhileFalse;

  bool get recordsDisabledRegistryNull =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .disabledRegistryNull,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsDisabledRegistryNull;

  bool get recordsNoRtcPermissionMediaDeviceAccess =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noRtcPermissionMediaDeviceAccess,
      ) &&
      callV2BackendFirebaseOwnerRecognition
          .recordsNoRtcPermissionMediaDeviceAccess;

  bool get recordsNoNavigatorWiring =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noNavigatorWiring,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoNavigatorWiring;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noLifecycleRegistration,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoLifecycleRegistration;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noAsyncHandles,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoAsyncHandles;

  bool get recordsNoDependencyPlatformConfigChanges =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .noDependencyPlatformConfigChanges,
      ) &&
      callV2BackendFirebaseOwnerRecognition
          .recordsNoDependencyPlatformConfigChanges;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noDeployment,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsNoDeployment;

  bool get recordsRollbackOneCommit =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
            .rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningRollback
            .keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningRollback
            .keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningRollback
            .noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningRollback.v1Unaffected,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsRollbackOneCommit &&
      callV2BackendFirebaseOwnerHardeningAudit.rollbackPreserved;

  bool get recordsV1Protected =>
      statuses.contains(
        CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.v1Protected,
      ) &&
      callV2BackendFirebaseOwnerRecognition.recordsV1Protected &&
      callV2BackendFirebaseOwnerHardeningAudit.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'metadataOnly': recordsMetadataOnly,
      'recognitionPass': recordsBackendFirebaseOwnerRecognitionPass,
      'runtimeRecognitionHardeningPass':
          recordsRuntimeStartupRecognitionHardeningPass,
      'finalStagedPreRuntimeAuditPass': recordsFinalStagedPreRuntimeAuditPass,
      'backendOwnerHardeningPass': recordsBackendFirebaseOwnerHardeningPass,
      'backendOwnerClosed': recordsBackendFirebaseOwnerClosed,
      'firebaseAccess': false,
      'firestoreListenerOpened': false,
      'firestoreRead': false,
      'firestoreWrite': false,
      'authCalled': false,
      'functionsCalled': false,
      'appCheckCalled': false,
      'runtimeConstructed': false,
      'runtimeStarted': false,
      'routesReachable': false,
      'routeResolverNullWhileFalse': recordsRouteResolverNullWhileFalse,
      'disabledRegistryNull': recordsDisabledRegistryNull,
      'deploymentChanged': false,
      'v1Protected': recordsV1Protected,
    };
  }

  @override
  String toString() {
    return 'CallV2BackendFirebaseOwnerRecognitionHardeningAudit('
        '${toSafeDebugMap()})';
  }
}

final callV2BackendFirebaseOwnerRecognitionHardeningAudit =
    CallV2BackendFirebaseOwnerRecognitionHardeningAudit(
  statuses: <CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus>[
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.developerOnly,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.rolloutFalse,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.metadataOnly,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .backendFirebaseOwnerRecognitionPass,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .runtimeStartupRecognitionHardeningPass,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .finalStagedPreRuntimeAuditPass,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .backendFirebaseOwnerHardeningPass,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .backendFirebaseOwnerClosed,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noFirebaseAccess,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .noFirestoreListeners,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noFirestoreReads,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noFirestoreWrites,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noAuthCalls,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noFunctionsCalls,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noAppCheckCalls,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .noRulesFunctionsConfigChanges,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .runtimeUnconstructed,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.runtimeNotStarted,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .productionCompositionUnconstructed,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .startupBridgeUncalled,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.mainDartUnchanged,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .appRouterUnchanged,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.routesUnreachable,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .routeResolverNullWhileFalse,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .disabledRegistryNull,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .noRtcPermissionMediaDeviceAccess,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noNavigatorWiring,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .noLifecycleRegistration,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noAsyncHandles,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus
        .noDependencyPlatformConfigChanges,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.noDeployment,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.rollbackOneCommit,
    CallV2BackendFirebaseOwnerRecognitionHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2BackendFirebaseOwnerRecognitionHardeningRollback>[
    CallV2BackendFirebaseOwnerRecognitionHardeningRollback.oneCommitRevert,
    CallV2BackendFirebaseOwnerRecognitionHardeningRollback.keepRolloutFalse,
    CallV2BackendFirebaseOwnerRecognitionHardeningRollback
        .keepRouteRegistryNull,
    CallV2BackendFirebaseOwnerRecognitionHardeningRollback
        .keepDisabledOwnerInert,
    CallV2BackendFirebaseOwnerRecognitionHardeningRollback.noDeploymentRequired,
    CallV2BackendFirebaseOwnerRecognitionHardeningRollback.noConfigChanges,
    CallV2BackendFirebaseOwnerRecognitionHardeningRollback.v1Unaffected,
  ],
);
