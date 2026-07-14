import 'call_v2_lifecycle_observer.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2LifecycleObserverHardeningAuditStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noFrameworkLifecycleObserver,
  noBindingLifecycleObserver,
  noObserverRegistration,
  noRuntimeStart,
  noBackendFirebaseAccess,
  noRtcPermissionAccess,
  noNavigatorAccess,
  noRouteRegistryMutation,
  noAsyncHandles,
  eventsExact,
  defaultDecisionsInert,
  duplicateDecisionNoOp,
  staleDecisionIgnored,
  terminalDecisionIgnored,
  safeDebugOnly,
  routeRegistryNullWhileFalse,
  disabledOwnerInert,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2LifecycleObserverHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2LifecycleObserverHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2LifecycleObserverHardeningAudit {
  factory CallV2LifecycleObserverHardeningAudit({
    required CallV2LifecycleObserverBoundary boundary,
    required List<CallV2LifecycleObserverHardeningAuditStatus> statuses,
    required List<CallV2LifecycleObserverHardeningRollback> rollback,
  }) {
    return CallV2LifecycleObserverHardeningAudit._(
      boundary,
      List<CallV2LifecycleObserverHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2LifecycleObserverHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2LifecycleObserverHardeningAudit._(
    this.boundary,
    this.statuses,
    this.rollback,
  );

  final CallV2LifecycleObserverBoundary boundary;
  final List<CallV2LifecycleObserverHardeningAuditStatus> statuses;
  final List<CallV2LifecycleObserverHardeningRollback> rollback;

  CallV2LifecycleObserverHardeningAuditDecision get decision {
    return passes
        ? CallV2LifecycleObserverHardeningAuditDecision.pass
        : CallV2LifecycleObserverHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsHardDisabled &&
      recordsRolloutFalse &&
      recordsUnreachable &&
      recordsNoFrameworkLifecycleObserver &&
      recordsNoBindingLifecycleObserver &&
      recordsNoObserverRegistration &&
      recordsNoRuntimeStart &&
      recordsNoBackendFirebaseAccess &&
      recordsNoRtcPermissionAccess &&
      recordsNoNavigatorAccess &&
      recordsNoRouteRegistryMutation &&
      recordsNoAsyncHandles &&
      lifecycleEventsAreExact &&
      defaultDecisionsAreInert &&
      duplicateDecisionIsNoOp &&
      staleDecisionIsIgnored &&
      terminalDecisionIsIgnored &&
      recordsSafeDebugOnly &&
      recordsRouteRegistryNullWhileFalse &&
      recordsDisabledOwnerInert &&
      rollbackPreserved &&
      protectsV1;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.developerOnly,
      ) &&
      boundary.isDeveloperOnly;

  bool get recordsHardDisabled =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.hardDisabled,
      ) &&
      boundary.isHardDisabled;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.rolloutFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      !boundary.isRolloutEnabled;

  bool get recordsUnreachable =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.unreachable,
      ) &&
      !boundary.isReachable;

  bool get recordsNoFrameworkLifecycleObserver =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus
            .noFrameworkLifecycleObserver,
      ) &&
      !boundary.registersFrameworkLifecycleObserver;

  bool get recordsNoBindingLifecycleObserver =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noBindingLifecycleObserver,
      ) &&
      !boundary.registersBindingLifecycleObserver;

  bool get recordsNoObserverRegistration =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noObserverRegistration,
      ) &&
      !boundary.registersObserver;

  bool get recordsNoRuntimeStart =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noRuntimeStart,
      ) &&
      !boundary.startsRuntime;

  bool get recordsNoBackendFirebaseAccess =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noBackendFirebaseAccess,
      ) &&
      !boundary.accessesBackendFirebase;

  bool get recordsNoRtcPermissionAccess =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noRtcPermissionAccess,
      ) &&
      !boundary.accessesRtcPermissions;

  bool get recordsNoNavigatorAccess =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noNavigatorAccess,
      ) &&
      !boundary.accessesNavigator;

  bool get recordsNoRouteRegistryMutation =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noRouteRegistryMutation,
      ) &&
      !boundary.mutatesRouteRegistry;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.noAsyncHandles,
      ) &&
      !boundary.opensAsyncHandles;

  bool get lifecycleEventsAreExact =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.eventsExact,
      ) &&
      boundary.events.length == 5 &&
      boundary.events[0] == CallV2LifecycleObserverEvent.resumed &&
      boundary.events[1] == CallV2LifecycleObserverEvent.inactive &&
      boundary.events[2] == CallV2LifecycleObserverEvent.paused &&
      boundary.events[3] == CallV2LifecycleObserverEvent.hidden &&
      boundary.events[4] == CallV2LifecycleObserverEvent.detached;

  bool get defaultDecisionsAreInert =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.defaultDecisionsInert,
      ) &&
      boundary.events.every((event) {
        final decision = boundary.decideWhileDisabled(
          event: event,
          generation: 1,
        );
        return decision.status ==
                CallV2LifecycleObserverDecisionStatus.disabledInert &&
            _decisionHasNoSideEffects(decision);
      });

  bool get duplicateDecisionIsNoOp =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.duplicateDecisionNoOp,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          event: CallV2LifecycleObserverEvent.paused,
          generation: 2,
          latestGeneration: 2,
        ),
        CallV2LifecycleObserverDecisionStatus.duplicateNoOp,
      );

  bool get staleDecisionIsIgnored =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.staleDecisionIgnored,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          event: CallV2LifecycleObserverEvent.paused,
          generation: 1,
          latestGeneration: 2,
        ),
        CallV2LifecycleObserverDecisionStatus.staleIgnored,
      );

  bool get terminalDecisionIsIgnored =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.terminalDecisionIgnored,
      ) &&
      _decisionMatches(
        boundary.decideWhileDisabled(
          event: CallV2LifecycleObserverEvent.detached,
          generation: 3,
          latestGeneration: 3,
          terminal: true,
        ),
        CallV2LifecycleObserverDecisionStatus.terminalIgnored,
      );

  bool get recordsSafeDebugOnly => statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.safeDebugOnly,
      );

  bool get recordsRouteRegistryNullWhileFalse => statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.routeRegistryNullWhileFalse,
      );

  bool get recordsDisabledOwnerInert => statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.disabledOwnerInert,
      );

  bool get rollbackPreserved =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2LifecycleObserverHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(CallV2LifecycleObserverHardeningRollback.v1Unaffected);

  bool get protectsV1 =>
      statuses.contains(
        CallV2LifecycleObserverHardeningAuditStatus.v1Protected,
      ) &&
      boundary.protectsV1;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'rollbackCount': rollback.length,
      'eventCount': boundary.events.length,
      'developerOnly': recordsDeveloperOnly,
      'hardDisabled': recordsHardDisabled,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'reachable': boundary.isReachable,
      'eventsExact': lifecycleEventsAreExact,
      'defaultDecisionsInert': defaultDecisionsAreInert,
      'duplicateDecisionNoOp': duplicateDecisionIsNoOp,
      'staleDecisionIgnored': staleDecisionIsIgnored,
      'terminalDecisionIgnored': terminalDecisionIsIgnored,
      'routeRegistryNullWhileFalse': recordsRouteRegistryNullWhileFalse,
      'disabledOwnerInert': recordsDisabledOwnerInert,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  bool _decisionMatches(
    CallV2LifecycleObserverDecision decision,
    CallV2LifecycleObserverDecisionStatus expected,
  ) {
    return decision.status == expected && _decisionHasNoSideEffects(decision);
  }

  bool _decisionHasNoSideEffects(CallV2LifecycleObserverDecision decision) {
    return !decision.registersObserver &&
        !decision.startsRuntime &&
        !decision.accessesBackendFirebase &&
        !decision.accessesRtcPermissions &&
        !decision.accessesNavigator &&
        !decision.mutatesRouteRegistry &&
        !decision.opensAsyncHandles &&
        !decision.mutatesV1State;
  }

  @override
  String toString() {
    return 'CallV2LifecycleObserverHardeningAudit(${toSafeDebugMap()})';
  }
}

final callV2LifecycleObserverHardeningAudit =
    CallV2LifecycleObserverHardeningAudit(
  boundary: callV2LifecycleObserverBoundary,
  statuses: <CallV2LifecycleObserverHardeningAuditStatus>[
    CallV2LifecycleObserverHardeningAuditStatus.developerOnly,
    CallV2LifecycleObserverHardeningAuditStatus.hardDisabled,
    CallV2LifecycleObserverHardeningAuditStatus.rolloutFalse,
    CallV2LifecycleObserverHardeningAuditStatus.unreachable,
    CallV2LifecycleObserverHardeningAuditStatus.noFrameworkLifecycleObserver,
    CallV2LifecycleObserverHardeningAuditStatus.noBindingLifecycleObserver,
    CallV2LifecycleObserverHardeningAuditStatus.noObserverRegistration,
    CallV2LifecycleObserverHardeningAuditStatus.noRuntimeStart,
    CallV2LifecycleObserverHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2LifecycleObserverHardeningAuditStatus.noRtcPermissionAccess,
    CallV2LifecycleObserverHardeningAuditStatus.noNavigatorAccess,
    CallV2LifecycleObserverHardeningAuditStatus.noRouteRegistryMutation,
    CallV2LifecycleObserverHardeningAuditStatus.noAsyncHandles,
    CallV2LifecycleObserverHardeningAuditStatus.eventsExact,
    CallV2LifecycleObserverHardeningAuditStatus.defaultDecisionsInert,
    CallV2LifecycleObserverHardeningAuditStatus.duplicateDecisionNoOp,
    CallV2LifecycleObserverHardeningAuditStatus.staleDecisionIgnored,
    CallV2LifecycleObserverHardeningAuditStatus.terminalDecisionIgnored,
    CallV2LifecycleObserverHardeningAuditStatus.safeDebugOnly,
    CallV2LifecycleObserverHardeningAuditStatus.routeRegistryNullWhileFalse,
    CallV2LifecycleObserverHardeningAuditStatus.disabledOwnerInert,
    CallV2LifecycleObserverHardeningAuditStatus.rollbackOneCommit,
    CallV2LifecycleObserverHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2LifecycleObserverHardeningRollback>[
    CallV2LifecycleObserverHardeningRollback.oneCommitRevert,
    CallV2LifecycleObserverHardeningRollback.keepRolloutFalse,
    CallV2LifecycleObserverHardeningRollback.keepRouteRegistryNull,
    CallV2LifecycleObserverHardeningRollback.keepDisabledOwnerInert,
    CallV2LifecycleObserverHardeningRollback.noDeploymentRequired,
    CallV2LifecycleObserverHardeningRollback.noConfigChanges,
    CallV2LifecycleObserverHardeningRollback.v1Unaffected,
  ],
);
