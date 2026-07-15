import 'call_v2_backend_firebase_owner.dart';
import 'call_v2_rollout_policy.dart';
import 'call_v2_route_registry.dart';

enum CallV2BackendFirebaseOwnerHardeningAuditStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noFirebaseImports,
  noFirestoreListeners,
  noFirestoreReads,
  noFirestoreWrites,
  noFirebaseAuthCalls,
  noFirebaseFunctionsCalls,
  noFirebaseAppCheckCalls,
  noProductionServiceContact,
  noRuntimeConstruction,
  noRuntimeStart,
  noNavigationAccess,
  noRtcPermissionAccess,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noAsyncHandles,
  noRulesFunctionsConfigChanges,
  noDeployment,
  actionsExact,
  sanitizedEventsExact,
  defaultDecisionsInert,
  duplicateDecisionNoOp,
  staleDecisionIgnored,
  backwardsTransitionRejected,
  ownershipMismatchRejected,
  rawPayloadRejected,
  terminalDecisionIgnored,
  safeDebugOnly,
  routeRegistryNullWhileFalse,
  disabledOwnerInert,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2BackendFirebaseOwnerHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2BackendFirebaseOwnerHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2BackendFirebaseOwnerHardeningAudit {
  factory CallV2BackendFirebaseOwnerHardeningAudit({
    required CallV2BackendFirebaseOwnerBoundary boundary,
    required List<CallV2BackendFirebaseOwnerHardeningAuditStatus> statuses,
    required List<CallV2BackendFirebaseOwnerHardeningRollback> rollback,
  }) {
    return CallV2BackendFirebaseOwnerHardeningAudit._(
      boundary,
      List<CallV2BackendFirebaseOwnerHardeningAuditStatus>.unmodifiable(
        statuses,
      ),
      List<CallV2BackendFirebaseOwnerHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2BackendFirebaseOwnerHardeningAudit._(
    this.boundary,
    this.statuses,
    this.rollback,
  );

  final CallV2BackendFirebaseOwnerBoundary boundary;
  final List<CallV2BackendFirebaseOwnerHardeningAuditStatus> statuses;
  final List<CallV2BackendFirebaseOwnerHardeningRollback> rollback;

  CallV2BackendFirebaseOwnerHardeningAuditDecision get decision {
    return passes
        ? CallV2BackendFirebaseOwnerHardeningAuditDecision.pass
        : CallV2BackendFirebaseOwnerHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsHardDisabled &&
      recordsRolloutFalse &&
      recordsUnreachable &&
      recordsNoFirebaseImports &&
      recordsNoFirestoreListeners &&
      recordsNoFirestoreReads &&
      recordsNoFirestoreWrites &&
      recordsNoFirebaseAuthCalls &&
      recordsNoFirebaseFunctionsCalls &&
      recordsNoFirebaseAppCheckCalls &&
      recordsNoProductionServiceContact &&
      recordsNoRuntimeConstruction &&
      recordsNoRuntimeStart &&
      recordsNoNavigationAccess &&
      recordsNoRtcPermissionAccess &&
      recordsNoLifecycleRegistration &&
      recordsNoRouteRegistryMutation &&
      recordsNoAsyncHandles &&
      recordsNoRulesFunctionsConfigChanges &&
      recordsNoDeployment &&
      backendActionsExact &&
      sanitizedEventsExact &&
      defaultDecisionsInert &&
      duplicateDecisionNoOp &&
      staleDecisionIgnored &&
      backwardsTransitionRejected &&
      ownershipMismatchRejected &&
      rawPayloadRejected &&
      terminalDecisionIgnored &&
      recordsSafeDebugOnly &&
      recordsRouteRegistryNullWhileFalse &&
      recordsDisabledOwnerInert &&
      rollbackPreserved &&
      protectsV1;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.developerOnly,
      ) &&
      boundary.isDeveloperOnly;

  bool get recordsHardDisabled =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.hardDisabled,
      ) &&
      boundary.isHardDisabled;

  bool get recordsRolloutFalse =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.rolloutFalse,
      ) &&
      !boundary.isRolloutEnabled &&
      !CallV2RolloutPolicy.productionEnabled;

  bool get recordsUnreachable =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.unreachable,
      ) &&
      !boundary.isReachable;

  bool get recordsNoFirebaseImports =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseImports,
      ) &&
      !boundary.importsFirebase;

  bool get recordsNoFirestoreListeners =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirestoreListeners,
      ) &&
      !boundary.opensFirestoreListeners;

  bool get recordsNoFirestoreReads =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirestoreReads,
      ) &&
      !boundary.readsFirestore;

  bool get recordsNoFirestoreWrites =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirestoreWrites,
      ) &&
      !boundary.writesFirestore;

  bool get recordsNoFirebaseAuthCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseAuthCalls,
      ) &&
      !boundary.callsFirebaseAuth;

  bool get recordsNoFirebaseFunctionsCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseFunctionsCalls,
      ) &&
      !boundary.callsFirebaseFunctions;

  bool get recordsNoFirebaseAppCheckCalls =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseAppCheckCalls,
      ) &&
      !boundary.callsFirebaseAppCheck;

  bool get recordsNoProductionServiceContact =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus
            .noProductionServiceContact,
      ) &&
      !boundary.contactsProductionServices;

  bool get recordsNoRuntimeConstruction =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noRuntimeConstruction,
      ) &&
      !boundary.constructsRuntime;

  bool get recordsNoRuntimeStart =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noRuntimeStart,
      ) &&
      !boundary.startsRuntime;

  bool get recordsNoNavigationAccess =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noNavigationAccess,
      ) &&
      !boundary.accessesNavigation;

  bool get recordsNoRtcPermissionAccess =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noRtcPermissionAccess,
      ) &&
      !boundary.accessesRtcPermissions;

  bool get recordsNoLifecycleRegistration =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noLifecycleRegistration,
      ) &&
      !boundary.registersLifecycle;

  bool get recordsNoRouteRegistryMutation =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noRouteRegistryMutation,
      ) &&
      !boundary.mutatesRouteRegistry;

  bool get recordsNoAsyncHandles =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noAsyncHandles,
      ) &&
      !boundary.opensAsyncHandles;

  bool get recordsNoRulesFunctionsConfigChanges =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus
            .noRulesFunctionsConfigChanges,
      ) &&
      !boundary.changesRulesFunctionsConfig;

  bool get recordsNoDeployment =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.noDeployment,
      ) &&
      !boundary.isDeploymentApproved;

  bool get backendActionsExact =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.actionsExact,
      ) &&
      boundary.actions.length == _expectedActions.length &&
      _listEquals(boundary.actions, _expectedActions);

  bool get sanitizedEventsExact =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.sanitizedEventsExact,
      ) &&
      boundary.events.length == _expectedEvents.length &&
      _listEquals(boundary.events, _expectedEvents);

  bool get defaultDecisionsInert =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.defaultDecisionsInert,
      ) &&
      boundary.actions.every((action) {
        final decision = boundary.decideWhileDisabled(
          action: action,
          generation: boundary.actions.indexOf(action) + 1,
        );
        return decision.status ==
                CallV2BackendFirebaseOwnerDecisionStatus.disabledInert &&
            _decisionHasNoSideEffects(decision);
      });

  bool get duplicateDecisionNoOp =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.duplicateDecisionNoOp,
      ) &&
      _decisionStatus(
            generation: 2,
            latestGeneration: 2,
          ) ==
          CallV2BackendFirebaseOwnerDecisionStatus.duplicateNoOp;

  bool get staleDecisionIgnored =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.staleDecisionIgnored,
      ) &&
      _decisionStatus(
            generation: 1,
            latestGeneration: 2,
          ) ==
          CallV2BackendFirebaseOwnerDecisionStatus.staleIgnored;

  bool get backwardsTransitionRejected =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus
            .backwardsTransitionRejected,
      ) &&
      _decisionStatus(
            generation: 3,
            event: CallV2BackendFirebaseOwnerEvent.sanitizedRinging,
            previousEvent: CallV2BackendFirebaseOwnerEvent.sanitizedActive,
          ) ==
          CallV2BackendFirebaseOwnerDecisionStatus.transitionRejected;

  bool get ownershipMismatchRejected =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus
            .ownershipMismatchRejected,
      ) &&
      _decisionStatus(
            generation: 3,
            ownershipMatches: false,
          ) ==
          CallV2BackendFirebaseOwnerDecisionStatus.ownershipRejected;

  bool get rawPayloadRejected =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.rawPayloadRejected,
      ) &&
      _decisionStatus(
            generation: 3,
            rawPayloadProvided: true,
          ) ==
          CallV2BackendFirebaseOwnerDecisionStatus.rawPayloadRejected;

  bool get terminalDecisionIgnored =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.terminalDecisionIgnored,
      ) &&
      _decisionStatus(
            generation: 3,
            event: CallV2BackendFirebaseOwnerEvent.sanitizedEnded,
          ) ==
          CallV2BackendFirebaseOwnerDecisionStatus.terminalIgnored;

  bool get recordsSafeDebugOnly => statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.safeDebugOnly,
      );

  bool get recordsRouteRegistryNullWhileFalse =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus
            .routeRegistryNullWhileFalse,
      ) &&
      !CallV2RolloutPolicy.productionEnabled &&
      !isCallV2DeveloperRouteRegistrationEnabled;

  bool get recordsDisabledOwnerInert => statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.disabledOwnerInert,
      );

  bool get rollbackPreserved =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.length == _expectedRollback.length &&
      _listEquals(rollback, _expectedRollback) &&
      boundary.rollbackPreserved;

  bool get protectsV1 =>
      statuses.contains(
        CallV2BackendFirebaseOwnerHardeningAuditStatus.v1Protected,
      ) &&
      boundary.protectsV1;

  CallV2BackendFirebaseOwnerDecisionStatus _decisionStatus({
    required int generation,
    int? latestGeneration,
    CallV2BackendFirebaseOwnerEvent? event,
    CallV2BackendFirebaseOwnerEvent? previousEvent,
    bool ownershipMatches = true,
    bool rawPayloadProvided = false,
  }) {
    final decision = boundary.decideWhileDisabled(
      action: CallV2BackendFirebaseOwnerAction.receiveSnapshot,
      generation: generation,
      latestGeneration: latestGeneration,
      event: event,
      previousEvent: previousEvent,
      ownershipMatches: ownershipMatches,
      rawPayloadProvided: rawPayloadProvided,
    );
    return _decisionHasNoSideEffects(decision)
        ? decision.status
        : CallV2BackendFirebaseOwnerDecisionStatus.rawPayloadRejected;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'decision': decision.name,
      'statusCount': statuses.length,
      'actionCount': boundary.actions.length,
      'eventCount': boundary.events.length,
      'rollbackCount': rollback.length,
      'rolloutEnabled': CallV2RolloutPolicy.productionEnabled,
      'passes': passes,
      'backendClosed': recordsUnreachable,
      'routeRegistryClosed': recordsRouteRegistryNullWhileFalse,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2BackendFirebaseOwnerHardeningAudit(${toSafeDebugMap()})';
  }
}

bool _decisionHasNoSideEffects(CallV2BackendFirebaseOwnerDecision decision) {
  return !decision.importsFirebase &&
      !decision.opensFirestoreListener &&
      !decision.readsFirestore &&
      !decision.writesFirestore &&
      !decision.callsAuth &&
      !decision.callsFunctions &&
      !decision.callsAppCheck &&
      !decision.contactsProductionServices &&
      !decision.constructsRuntime &&
      !decision.startsRuntime &&
      !decision.accessesNavigation &&
      !decision.accessesRtcPermissions &&
      !decision.registersLifecycle &&
      !decision.mutatesRouteRegistry &&
      !decision.opensAsyncHandles &&
      !decision.changesRulesFunctionsConfig &&
      !decision.mutatesV1State;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

const _expectedActions = <CallV2BackendFirebaseOwnerAction>[
  CallV2BackendFirebaseOwnerAction.attachBackend,
  CallV2BackendFirebaseOwnerAction.detachBackend,
  CallV2BackendFirebaseOwnerAction.receiveSnapshot,
  CallV2BackendFirebaseOwnerAction.sendMutation,
  CallV2BackendFirebaseOwnerAction.callFunction,
  CallV2BackendFirebaseOwnerAction.refreshAuth,
  CallV2BackendFirebaseOwnerAction.verifyAppCheck,
];

const _expectedEvents = <CallV2BackendFirebaseOwnerEvent>[
  CallV2BackendFirebaseOwnerEvent.sanitizedRinging,
  CallV2BackendFirebaseOwnerEvent.sanitizedActive,
  CallV2BackendFirebaseOwnerEvent.sanitizedEnded,
  CallV2BackendFirebaseOwnerEvent.sanitizedFailure,
  CallV2BackendFirebaseOwnerEvent.sanitizedUnknown,
];

const _expectedRollback = <CallV2BackendFirebaseOwnerHardeningRollback>[
  CallV2BackendFirebaseOwnerHardeningRollback.oneCommitRevert,
  CallV2BackendFirebaseOwnerHardeningRollback.keepRolloutFalse,
  CallV2BackendFirebaseOwnerHardeningRollback.keepRouteRegistryNull,
  CallV2BackendFirebaseOwnerHardeningRollback.keepDisabledOwnerInert,
  CallV2BackendFirebaseOwnerHardeningRollback.noDeploymentRequired,
  CallV2BackendFirebaseOwnerHardeningRollback.noConfigChanges,
  CallV2BackendFirebaseOwnerHardeningRollback.v1Unaffected,
];

final callV2BackendFirebaseOwnerHardeningAudit =
    CallV2BackendFirebaseOwnerHardeningAudit(
  boundary: callV2BackendFirebaseOwnerBoundary,
  statuses: <CallV2BackendFirebaseOwnerHardeningAuditStatus>[
    CallV2BackendFirebaseOwnerHardeningAuditStatus.developerOnly,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.hardDisabled,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.rolloutFalse,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.unreachable,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseImports,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirestoreListeners,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirestoreReads,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirestoreWrites,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseAuthCalls,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseFunctionsCalls,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noFirebaseAppCheckCalls,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noProductionServiceContact,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noRuntimeConstruction,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noRuntimeStart,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noNavigationAccess,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noRtcPermissionAccess,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noLifecycleRegistration,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noRouteRegistryMutation,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noAsyncHandles,
    CallV2BackendFirebaseOwnerHardeningAuditStatus
        .noRulesFunctionsConfigChanges,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.noDeployment,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.actionsExact,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.sanitizedEventsExact,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.defaultDecisionsInert,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.duplicateDecisionNoOp,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.staleDecisionIgnored,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.backwardsTransitionRejected,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.ownershipMismatchRejected,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.rawPayloadRejected,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.terminalDecisionIgnored,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.safeDebugOnly,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.routeRegistryNullWhileFalse,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.disabledOwnerInert,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.rollbackOneCommit,
    CallV2BackendFirebaseOwnerHardeningAuditStatus.v1Protected,
  ],
  rollback: _expectedRollback,
);
