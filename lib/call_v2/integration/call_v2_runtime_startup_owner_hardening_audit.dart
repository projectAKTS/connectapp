import 'call_v2_rollout_policy.dart';
import 'call_v2_runtime_startup_owner.dart';

enum CallV2RuntimeStartupOwnerHardeningAuditStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noRuntimeConstruction,
  noRuntimeStart,
  noProductionCompositionConstruction,
  noStartupBridgeWiring,
  noMainDartWiring,
  noAppRouterWiring,
  noBackendFirebaseAccess,
  noRtcPermissionAccess,
  noNavigatorAccess,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noAsyncHandles,
  noDeployment,
  actionsExact,
  defaultDecisionsInert,
  duplicateDecisionNoOp,
  staleDecisionIgnored,
  disposedDecisionRejected,
  terminalDecisionIgnored,
  safeDebugOnly,
  routeRegistryNullWhileFalse,
  disabledOwnerInert,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2RuntimeStartupOwnerHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2RuntimeStartupOwnerHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2RuntimeStartupOwnerHardeningAudit {
  factory CallV2RuntimeStartupOwnerHardeningAudit({
    required CallV2RuntimeStartupOwnerBoundary boundary,
    required List<CallV2RuntimeStartupOwnerHardeningAuditStatus> statuses,
    required List<CallV2RuntimeStartupOwnerHardeningRollback> rollback,
  }) {
    return CallV2RuntimeStartupOwnerHardeningAudit._(
      boundary,
      List<CallV2RuntimeStartupOwnerHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2RuntimeStartupOwnerHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2RuntimeStartupOwnerHardeningAudit._(
    this.boundary,
    this.statuses,
    this.rollback,
  );

  final CallV2RuntimeStartupOwnerBoundary boundary;
  final List<CallV2RuntimeStartupOwnerHardeningAuditStatus> statuses;
  final List<CallV2RuntimeStartupOwnerHardeningRollback> rollback;

  static const List<CallV2RuntimeStartupOwnerAction> expectedActions =
      <CallV2RuntimeStartupOwnerAction>[
    CallV2RuntimeStartupOwnerAction.requestStartup,
    CallV2RuntimeStartupOwnerAction.requestShutdown,
    CallV2RuntimeStartupOwnerAction.markReady,
    CallV2RuntimeStartupOwnerAction.markFailure,
    CallV2RuntimeStartupOwnerAction.retryStartup,
  ];

  CallV2RuntimeStartupOwnerHardeningAuditDecision get decision {
    return passes
        ? CallV2RuntimeStartupOwnerHardeningAuditDecision.pass
        : CallV2RuntimeStartupOwnerHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsHardDisabled &&
      recordsRolloutFalse &&
      recordsUnreachable &&
      recordsNoRuntimeConstruction &&
      recordsNoRuntimeStart &&
      recordsNoProductionCompositionConstruction &&
      recordsNoStartupBridgeWiring &&
      recordsNoMainDartWiring &&
      recordsNoAppRouterWiring &&
      recordsNoBackendFirebaseAccess &&
      recordsNoRtcPermissionAccess &&
      recordsNoNavigatorAccess &&
      recordsNoLifecycleRegistration &&
      recordsNoRouteRegistryMutation &&
      recordsNoAsyncHandles &&
      recordsNoDeployment &&
      actionsAreExact &&
      defaultDecisionsAreInert &&
      duplicateDecisionIsNoOp &&
      staleDecisionIsIgnored &&
      disposedDecisionIsRejected &&
      terminalDecisionIsIgnored &&
      recordsSafeDebugOnly &&
      recordsRouteRegistryNullWhileFalse &&
      recordsDisabledOwnerInert &&
      rollbackPreserved &&
      protectsV1;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.developerOnly,
      ) &&
      boundary.isDeveloperOnly;

  bool get recordsHardDisabled =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.hardDisabled,
      ) &&
      boundary.isHardDisabled;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      !boundary.isRolloutEnabled;

  bool get recordsUnreachable =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.unreachable,
      ) &&
      !boundary.isReachable;

  bool get recordsNoRuntimeConstruction =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noRuntimeConstruction,
      ) &&
      !boundary.constructsRuntime;

  bool get recordsNoRuntimeStart =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noRuntimeStart,
      ) &&
      !boundary.startsRuntime;

  bool get recordsNoProductionCompositionConstruction =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus
            .noProductionCompositionConstruction,
      ) &&
      !boundary.constructsProductionComposition;

  bool get recordsNoStartupBridgeWiring =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noStartupBridgeWiring,
      ) &&
      !boundary.wiresStartupBridge;

  bool get recordsNoMainDartWiring =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noMainDartWiring,
      ) &&
      !boundary.wiresMainDart;

  bool get recordsNoAppRouterWiring =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noAppRouterWiring,
      ) &&
      !boundary.wiresAppRouter;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noBackendFirebaseAccess,
      ) &&
      !boundary.accessesBackend;

  bool get recordsNoRtcPermissionAccess =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noRtcPermissionAccess,
      ) &&
      !boundary.accessesMediaCapabilities;

  bool get recordsNoNavigatorAccess =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noNavigatorAccess,
      ) &&
      !boundary.accessesNavigation;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noLifecycleRegistration,
      ) &&
      !boundary.registersLifecycle;

  bool get recordsNoRouteRegistryMutation =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noRouteRegistryMutation,
      ) &&
      !boundary.mutatesRouteRegistry;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noAsyncHandles,
      ) &&
      !boundary.opensAsyncHandles;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.noDeployment,
      ) &&
      !boundary.isDeploymentApproved;

  bool get actionsAreExact =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.actionsExact,
      ) &&
      boundary.actions.length == expectedActions.length &&
      _listsMatch(boundary.actions, expectedActions);

  bool get defaultDecisionsAreInert =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.defaultDecisionsInert,
      ) &&
      boundary.actions.every((action) {
        final decision = boundary.decideWhileDisabled(
          action: action,
          generation: boundary.actions.indexOf(action) + 1,
        );
        return decision.status ==
                CallV2RuntimeStartupOwnerDecisionStatus.disabledInert &&
            _decisionHasNoSideEffects(decision);
      });

  bool get duplicateDecisionIsNoOp =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.duplicateDecisionNoOp,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RuntimeStartupOwnerAction.requestStartup,
          generation: 2,
          latestGeneration: 2,
        ),
        CallV2RuntimeStartupOwnerDecisionStatus.duplicateNoOp,
      );

  bool get staleDecisionIsIgnored =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.staleDecisionIgnored,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RuntimeStartupOwnerAction.requestStartup,
          generation: 1,
          latestGeneration: 2,
        ),
        CallV2RuntimeStartupOwnerDecisionStatus.staleIgnored,
      );

  bool get disposedDecisionIsRejected =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.disposedDecisionRejected,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RuntimeStartupOwnerAction.requestShutdown,
          generation: 3,
          disposed: true,
        ),
        CallV2RuntimeStartupOwnerDecisionStatus.rejected,
      );

  bool get terminalDecisionIsIgnored =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.terminalDecisionIgnored,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          action: CallV2RuntimeStartupOwnerAction.markReady,
          generation: 4,
          terminal: true,
        ),
        CallV2RuntimeStartupOwnerDecisionStatus.terminalIgnored,
      );

  bool get recordsSafeDebugOnly => statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.safeDebugOnly,
      );

  bool get recordsRouteRegistryNullWhileFalse => statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus
            .routeRegistryNullWhileFalse,
      );

  bool get recordsDisabledOwnerInert => statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.disabledOwnerInert,
      );

  bool get rollbackPreserved =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(
        CallV2RuntimeStartupOwnerHardeningRollback.v1Unaffected,
      );

  bool get protectsV1 =>
      statuses.contains(
        CallV2RuntimeStartupOwnerHardeningAuditStatus.v1Protected,
      ) &&
      boundary.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'actionCount': boundary.actions.length,
      'developerOnly': recordsDeveloperOnly,
      'hardDisabled': recordsHardDisabled,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'reachable': boundary.isReachable,
      'actionsExact': actionsAreExact,
      'defaultDecisionsInert': defaultDecisionsAreInert,
      'duplicateDecisionNoOp': duplicateDecisionIsNoOp,
      'staleDecisionIgnored': staleDecisionIsIgnored,
      'disposedDecisionRejected': disposedDecisionIsRejected,
      'terminalDecisionIgnored': terminalDecisionIsIgnored,
      'routeRegistryNullWhileFalse': recordsRouteRegistryNullWhileFalse,
      'disabledOwnerInert': recordsDisabledOwnerInert,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  bool _decisionMatches(
    CallV2RuntimeStartupOwnerDecision decision,
    CallV2RuntimeStartupOwnerDecisionStatus expected,
  ) {
    return decision.status == expected && _decisionHasNoSideEffects(decision);
  }

  bool _decisionHasNoSideEffects(
    CallV2RuntimeStartupOwnerDecision decision,
  ) {
    return !decision.constructsRuntime &&
        !decision.startsRuntime &&
        !decision.constructsProductionComposition &&
        !decision.wiresStartupBridge &&
        !decision.accessesBackend &&
        !decision.accessesMediaCapabilities &&
        !decision.accessesNavigation &&
        !decision.registersLifecycle &&
        !decision.mutatesRouteRegistry &&
        !decision.opensAsyncHandles &&
        !decision.mutatesV1State &&
        !decision.exposesPublicUsers &&
        !decision.contactsProductionServices;
  }

  bool _listsMatch<T>(List<T> actual, List<T> expected) {
    if (actual.length != expected.length) return false;
    for (var index = 0; index < actual.length; index += 1) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'CallV2RuntimeStartupOwnerHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2RuntimeStartupOwnerHardeningAudit =
    CallV2RuntimeStartupOwnerHardeningAudit(
  boundary: callV2RuntimeStartupOwnerBoundary,
  statuses: <CallV2RuntimeStartupOwnerHardeningAuditStatus>[
    CallV2RuntimeStartupOwnerHardeningAuditStatus.developerOnly,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.hardDisabled,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.rolloutFalse,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.unreachable,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noRuntimeConstruction,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noRuntimeStart,
    CallV2RuntimeStartupOwnerHardeningAuditStatus
        .noProductionCompositionConstruction,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noStartupBridgeWiring,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noMainDartWiring,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noAppRouterWiring,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noRtcPermissionAccess,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noNavigatorAccess,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noLifecycleRegistration,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noRouteRegistryMutation,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noAsyncHandles,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.noDeployment,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.actionsExact,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.defaultDecisionsInert,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.duplicateDecisionNoOp,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.staleDecisionIgnored,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.disposedDecisionRejected,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.terminalDecisionIgnored,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.safeDebugOnly,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.routeRegistryNullWhileFalse,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.disabledOwnerInert,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.rollbackOneCommit,
    CallV2RuntimeStartupOwnerHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2RuntimeStartupOwnerHardeningRollback>[
    CallV2RuntimeStartupOwnerHardeningRollback.oneCommitRevert,
    CallV2RuntimeStartupOwnerHardeningRollback.keepRolloutFalse,
    CallV2RuntimeStartupOwnerHardeningRollback.keepRouteRegistryNull,
    CallV2RuntimeStartupOwnerHardeningRollback.keepDisabledOwnerInert,
    CallV2RuntimeStartupOwnerHardeningRollback.noDeploymentRequired,
    CallV2RuntimeStartupOwnerHardeningRollback.noConfigChanges,
    CallV2RuntimeStartupOwnerHardeningRollback.v1Unaffected,
  ],
);
