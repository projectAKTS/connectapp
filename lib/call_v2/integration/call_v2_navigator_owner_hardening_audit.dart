import 'call_v2_navigator_owner.dart';
import 'call_v2_rollout_policy.dart';

enum CallV2NavigatorOwnerHardeningAuditStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noRealNavigatorWiring,
  noNavigatorCalls,
  noAppNavigatorKey,
  noGlobalKey,
  noBuildContextStorage,
  noMaterialAppWiring,
  noRouteObjectCreation,
  noRouteSinkUse,
  noScreenCreation,
  noRuntimeStart,
  noBackendFirebaseAccess,
  noRtcPermissionAccess,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noAsyncHandles,
  actionsExact,
  defaultDecisionsInert,
  duplicateDecisionNoOp,
  staleDecisionIgnored,
  routeMismatchDecisionIgnored,
  terminalDecisionIgnored,
  safeDebugOnly,
  routeRegistryNullWhileFalse,
  disabledOwnerInert,
  rollbackOneCommit,
  v1Protected,
}

enum CallV2NavigatorOwnerHardeningAuditDecision {
  pass,
  blocked,
}

enum CallV2NavigatorOwnerHardeningRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2NavigatorOwnerHardeningAudit {
  factory CallV2NavigatorOwnerHardeningAudit({
    required CallV2NavigationOwnerBoundary boundary,
    required List<CallV2NavigatorOwnerHardeningAuditStatus> statuses,
    required List<CallV2NavigatorOwnerHardeningRollback> rollback,
  }) {
    return CallV2NavigatorOwnerHardeningAudit._(
      boundary,
      List<CallV2NavigatorOwnerHardeningAuditStatus>.unmodifiable(statuses),
      List<CallV2NavigatorOwnerHardeningRollback>.unmodifiable(rollback),
    );
  }

  const CallV2NavigatorOwnerHardeningAudit._(
    this.boundary,
    this.statuses,
    this.rollback,
  );

  final CallV2NavigationOwnerBoundary boundary;
  final List<CallV2NavigatorOwnerHardeningAuditStatus> statuses;
  final List<CallV2NavigatorOwnerHardeningRollback> rollback;

  static const List<CallV2NavigationOwnerAction> expectedActions =
      <CallV2NavigationOwnerAction>[
    CallV2NavigationOwnerAction.showConnecting,
    CallV2NavigationOwnerAction.showAudio,
    CallV2NavigationOwnerAction.showVideo,
    CallV2NavigationOwnerAction.showFailure,
    CallV2NavigationOwnerAction.dismissFailure,
    CallV2NavigationOwnerAction.returnToPrevious,
  ];

  CallV2NavigatorOwnerHardeningAuditDecision get decision {
    return passes
        ? CallV2NavigatorOwnerHardeningAuditDecision.pass
        : CallV2NavigatorOwnerHardeningAuditDecision.blocked;
  }

  bool get passes =>
      recordsDeveloperOnly &&
      recordsHardDisabled &&
      recordsRolloutFalse &&
      recordsUnreachable &&
      wiresRealNavigator == false &&
      callsNavigator == false &&
      usesAppNavigatorKey == false &&
      usesGlobalKey == false &&
      storesBuildContext == false &&
      wiresMaterialApp == false &&
      createsRouteObject == false &&
      usesRouteSink == false &&
      createsScreen == false &&
      startsRuntime == false &&
      accessesBackendFirebase == false &&
      accessesRtcPermissions == false &&
      registersLifecycle == false &&
      mutatesRouteRegistry == false &&
      opensAsyncHandles == false &&
      actionsAreExact &&
      defaultDecisionsAreInert &&
      duplicateDecisionIsNoOp &&
      staleDecisionIsIgnored &&
      routeMismatchDecisionIsIgnored &&
      terminalDecisionIsIgnored &&
      recordsSafeDebugOnly &&
      recordsRouteRegistryNullWhileFalse &&
      recordsDisabledOwnerInert &&
      rollbackPreserved &&
      protectsV1;

  bool get recordsDeveloperOnly =>
      statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.developerOnly,
      ) &&
      boundary.isDeveloperOnly;

  bool get recordsHardDisabled =>
      statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.hardDisabled,
      ) &&
      boundary.isHardDisabled;

  bool get recordsRolloutFalse =>
      statuses
          .contains(CallV2NavigatorOwnerHardeningAuditStatus.rolloutFalse) &&
      !CallV2RolloutPolicy.productionEnabled &&
      !boundary.isRolloutEnabled;

  bool get recordsUnreachable =>
      statuses.contains(CallV2NavigatorOwnerHardeningAuditStatus.unreachable) &&
      !boundary.isReachable;

  bool get wiresRealNavigator =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noRealNavigatorWiring,
      ) ||
      boundary.wiresRealNavigation;

  bool get callsNavigator =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noNavigatorCalls,
      ) ||
      boundary.callsNavigation;

  bool get usesAppNavigatorKey =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noAppNavigatorKey,
      ) ||
      boundary.usesAppNavigationKey;

  bool get usesGlobalKey =>
      !statuses
          .contains(CallV2NavigatorOwnerHardeningAuditStatus.noGlobalKey) ||
      boundary.usesGlobalAppKey;

  bool get storesBuildContext =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noBuildContextStorage,
      ) ||
      boundary.storesWidgetContext;

  bool get wiresMaterialApp =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noMaterialAppWiring,
      ) ||
      boundary.wiresMaterialRouteTable;

  bool get createsRouteObject =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noRouteObjectCreation,
      ) ||
      boundary.createsRouteObject;

  bool get usesRouteSink =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noRouteSinkUse,
      ) ||
      boundary.usesRouteSink;

  bool get createsScreen =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noScreenCreation,
      ) ||
      boundary.createsScreen;

  bool get startsRuntime =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noRuntimeStart,
      ) ||
      boundary.startsRuntime;

  bool get accessesBackendFirebase =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noBackendFirebaseAccess,
      ) ||
      boundary.accessesBackendFirebase;

  bool get accessesRtcPermissions =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noRtcPermissionAccess,
      ) ||
      boundary.accessesRtcPermissions;

  bool get registersLifecycle =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noLifecycleRegistration,
      ) ||
      boundary.registersLifecycle;

  bool get mutatesRouteRegistry =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noRouteRegistryMutation,
      ) ||
      boundary.mutatesRouteRegistry;

  bool get opensAsyncHandles =>
      !statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.noAsyncHandles,
      ) ||
      boundary.opensAsyncHandles;

  bool get actionsAreExact =>
      statuses
          .contains(CallV2NavigatorOwnerHardeningAuditStatus.actionsExact) &&
      boundary.actions.length == expectedActions.length &&
      _listsMatch(boundary.actions, expectedActions);

  bool get defaultDecisionsAreInert =>
      statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.defaultDecisionsInert,
      ) &&
      expectedActions.every((action) {
        final decision = boundary.decideWhileDisabled(
          action: action,
          generation: expectedActions.indexOf(action) + 1,
        );
        return decision.status ==
                CallV2NavigationOwnerDecisionStatus.disabledInert &&
            _decisionHasNoSideEffects(decision);
      });

  bool get duplicateDecisionIsNoOp {
    final decision = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.showAudio,
      generation: 2,
      latestGeneration: 2,
    );
    return statuses.contains(
          CallV2NavigatorOwnerHardeningAuditStatus.duplicateDecisionNoOp,
        ) &&
        decision.status == CallV2NavigationOwnerDecisionStatus.duplicateNoOp &&
        _decisionHasNoSideEffects(decision);
  }

  bool get staleDecisionIsIgnored {
    final decision = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.showAudio,
      generation: 1,
      latestGeneration: 2,
    );
    return statuses.contains(
          CallV2NavigatorOwnerHardeningAuditStatus.staleDecisionIgnored,
        ) &&
        decision.status == CallV2NavigationOwnerDecisionStatus.staleIgnored &&
        _decisionHasNoSideEffects(decision);
  }

  bool get routeMismatchDecisionIsIgnored {
    final decision = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.returnToPrevious,
      generation: 3,
      ownedRouteName: 'owned',
      currentRouteName: 'current',
    );
    return statuses.contains(
          CallV2NavigatorOwnerHardeningAuditStatus.routeMismatchDecisionIgnored,
        ) &&
        decision.status ==
            CallV2NavigationOwnerDecisionStatus.routeMismatchIgnored &&
        _decisionHasNoSideEffects(decision);
  }

  bool get terminalDecisionIsIgnored {
    final decision = boundary.decideWhileDisabled(
      action: CallV2NavigationOwnerAction.dismissFailure,
      generation: 4,
      terminal: true,
    );
    return statuses.contains(
          CallV2NavigatorOwnerHardeningAuditStatus.terminalDecisionIgnored,
        ) &&
        decision.status ==
            CallV2NavigationOwnerDecisionStatus.terminalIgnored &&
        _decisionHasNoSideEffects(decision);
  }

  bool get recordsSafeDebugOnly =>
      statuses.contains(CallV2NavigatorOwnerHardeningAuditStatus.safeDebugOnly);

  bool get recordsRouteRegistryNullWhileFalse => statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.routeRegistryNullWhileFalse,
      );

  bool get recordsDisabledOwnerInert => statuses
      .contains(CallV2NavigatorOwnerHardeningAuditStatus.disabledOwnerInert);

  bool get rollbackPreserved =>
      statuses.contains(
        CallV2NavigatorOwnerHardeningAuditStatus.rollbackOneCommit,
      ) &&
      rollback.length == CallV2NavigatorOwnerHardeningRollback.values.length &&
      rollback.contains(
        CallV2NavigatorOwnerHardeningRollback.oneCommitRevert,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerHardeningRollback.keepRolloutFalse,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerHardeningRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerHardeningRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerHardeningRollback.noDeploymentRequired,
      ) &&
      rollback.contains(
        CallV2NavigatorOwnerHardeningRollback.noConfigChanges,
      ) &&
      rollback.contains(CallV2NavigatorOwnerHardeningRollback.v1Unaffected);

  bool get protectsV1 =>
      statuses.contains(CallV2NavigatorOwnerHardeningAuditStatus.v1Protected) &&
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
      'realNavigatorWiring': wiresRealNavigator,
      'routeRegistryNullWhileFalse': recordsRouteRegistryNullWhileFalse,
      'disabledOwnerInert': recordsDisabledOwnerInert,
      'defaultDecisionsInert': defaultDecisionsAreInert,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2NavigatorOwnerHardeningAudit(${toSafeDebugMap()})';
  }
}

bool _listsMatch<T>(List<T> actual, List<T> expected) {
  for (var index = 0; index < expected.length; index += 1) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

bool _decisionHasNoSideEffects(CallV2NavigationOwnerDecision decision) {
  return !decision.callsNavigation &&
      !decision.createsRouteObject &&
      !decision.createsScreen &&
      !decision.usesRouteSink &&
      !decision.startsRuntime &&
      !decision.accessesBackendFirebase &&
      !decision.accessesRtcPermissions &&
      !decision.registersLifecycle &&
      !decision.mutatesRouteRegistry &&
      !decision.opensAsyncHandles &&
      !decision.mutatesV1State;
}

final callV2NavigatorOwnerHardeningAudit = CallV2NavigatorOwnerHardeningAudit(
  boundary: callV2NavigationOwnerBoundary,
  statuses: <CallV2NavigatorOwnerHardeningAuditStatus>[
    CallV2NavigatorOwnerHardeningAuditStatus.developerOnly,
    CallV2NavigatorOwnerHardeningAuditStatus.hardDisabled,
    CallV2NavigatorOwnerHardeningAuditStatus.rolloutFalse,
    CallV2NavigatorOwnerHardeningAuditStatus.unreachable,
    CallV2NavigatorOwnerHardeningAuditStatus.noRealNavigatorWiring,
    CallV2NavigatorOwnerHardeningAuditStatus.noNavigatorCalls,
    CallV2NavigatorOwnerHardeningAuditStatus.noAppNavigatorKey,
    CallV2NavigatorOwnerHardeningAuditStatus.noGlobalKey,
    CallV2NavigatorOwnerHardeningAuditStatus.noBuildContextStorage,
    CallV2NavigatorOwnerHardeningAuditStatus.noMaterialAppWiring,
    CallV2NavigatorOwnerHardeningAuditStatus.noRouteObjectCreation,
    CallV2NavigatorOwnerHardeningAuditStatus.noRouteSinkUse,
    CallV2NavigatorOwnerHardeningAuditStatus.noScreenCreation,
    CallV2NavigatorOwnerHardeningAuditStatus.noRuntimeStart,
    CallV2NavigatorOwnerHardeningAuditStatus.noBackendFirebaseAccess,
    CallV2NavigatorOwnerHardeningAuditStatus.noRtcPermissionAccess,
    CallV2NavigatorOwnerHardeningAuditStatus.noLifecycleRegistration,
    CallV2NavigatorOwnerHardeningAuditStatus.noRouteRegistryMutation,
    CallV2NavigatorOwnerHardeningAuditStatus.noAsyncHandles,
    CallV2NavigatorOwnerHardeningAuditStatus.actionsExact,
    CallV2NavigatorOwnerHardeningAuditStatus.defaultDecisionsInert,
    CallV2NavigatorOwnerHardeningAuditStatus.duplicateDecisionNoOp,
    CallV2NavigatorOwnerHardeningAuditStatus.staleDecisionIgnored,
    CallV2NavigatorOwnerHardeningAuditStatus.routeMismatchDecisionIgnored,
    CallV2NavigatorOwnerHardeningAuditStatus.terminalDecisionIgnored,
    CallV2NavigatorOwnerHardeningAuditStatus.safeDebugOnly,
    CallV2NavigatorOwnerHardeningAuditStatus.routeRegistryNullWhileFalse,
    CallV2NavigatorOwnerHardeningAuditStatus.disabledOwnerInert,
    CallV2NavigatorOwnerHardeningAuditStatus.rollbackOneCommit,
    CallV2NavigatorOwnerHardeningAuditStatus.v1Protected,
  ],
  rollback: <CallV2NavigatorOwnerHardeningRollback>[
    CallV2NavigatorOwnerHardeningRollback.oneCommitRevert,
    CallV2NavigatorOwnerHardeningRollback.keepRolloutFalse,
    CallV2NavigatorOwnerHardeningRollback.keepRouteRegistryNull,
    CallV2NavigatorOwnerHardeningRollback.keepDisabledOwnerInert,
    CallV2NavigatorOwnerHardeningRollback.noDeploymentRequired,
    CallV2NavigatorOwnerHardeningRollback.noConfigChanges,
    CallV2NavigatorOwnerHardeningRollback.v1Unaffected,
  ],
);
