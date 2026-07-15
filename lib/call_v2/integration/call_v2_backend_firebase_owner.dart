enum CallV2BackendFirebaseOwnerStatus {
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
  v1Protected,
}

enum CallV2BackendFirebaseOwnerAction {
  attachBackend,
  detachBackend,
  receiveSnapshot,
  sendMutation,
  callFunction,
  refreshAuth,
  verifyAppCheck,
}

enum CallV2BackendFirebaseOwnerEvent {
  sanitizedRinging,
  sanitizedActive,
  sanitizedEnded,
  sanitizedFailure,
  sanitizedUnknown,
}

enum CallV2BackendFirebaseOwnerDecisionStatus {
  disabledInert,
  duplicateNoOp,
  staleIgnored,
  transitionRejected,
  ownershipRejected,
  rawPayloadRejected,
  terminalIgnored,
}

enum CallV2BackendFirebaseOwnerRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  keepDisabledOwnerInert,
  noDeploymentRequired,
  noConfigChanges,
  v1Unaffected,
}

final class CallV2BackendFirebaseOwnerDecision {
  const CallV2BackendFirebaseOwnerDecision({
    required this.status,
    required this.action,
    required this.generation,
    this.event,
  });

  final CallV2BackendFirebaseOwnerDecisionStatus status;
  final CallV2BackendFirebaseOwnerAction action;
  final int generation;
  final CallV2BackendFirebaseOwnerEvent? event;

  bool get importsFirebase => false;
  bool get opensFirestoreListener => false;
  bool get readsFirestore => false;
  bool get writesFirestore => false;
  bool get callsAuth => false;
  bool get callsFunctions => false;
  bool get callsAppCheck => false;
  bool get contactsProductionServices => false;
  bool get constructsRuntime => false;
  bool get startsRuntime => false;
  bool get accessesNavigation => false;
  bool get accessesRtcPermissions => false;
  bool get registersLifecycle => false;
  bool get mutatesRouteRegistry => false;
  bool get opensAsyncHandles => false;
  bool get changesRulesFunctionsConfig => false;
  bool get mutatesV1State => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'handled': true,
      'hasEvent': event != null,
      'generationKnown': generation >= 0,
      'importsFirebase': importsFirebase,
      'opensDocumentListener': opensFirestoreListener,
      'readsDocuments': readsFirestore,
      'writesDocuments': writesFirestore,
      'callsAuth': callsAuth,
      'callsFunctions': callsFunctions,
      'callsIntegrityCheck': callsAppCheck,
      'contactsProductionServices': contactsProductionServices,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'accessesNavigation': accessesNavigation,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'registersLifecycle': registersLifecycle,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'changesServerConfig': changesRulesFunctionsConfig,
      'mutatesV1State': mutatesV1State,
    };
  }

  @override
  String toString() {
    return 'CallV2BackendFirebaseOwnerDecision(${toSafeDebugMap()})';
  }
}

final class CallV2BackendFirebaseOwnerBoundary {
  factory CallV2BackendFirebaseOwnerBoundary({
    required List<CallV2BackendFirebaseOwnerStatus> statuses,
    required List<CallV2BackendFirebaseOwnerAction> actions,
    required List<CallV2BackendFirebaseOwnerEvent> events,
    required List<CallV2BackendFirebaseOwnerRollback> rollback,
  }) {
    return CallV2BackendFirebaseOwnerBoundary._(
      List<CallV2BackendFirebaseOwnerStatus>.unmodifiable(statuses),
      List<CallV2BackendFirebaseOwnerAction>.unmodifiable(actions),
      List<CallV2BackendFirebaseOwnerEvent>.unmodifiable(events),
      List<CallV2BackendFirebaseOwnerRollback>.unmodifiable(rollback),
    );
  }

  const CallV2BackendFirebaseOwnerBoundary._(
    this.statuses,
    this.actions,
    this.events,
    this.rollback,
  );

  final List<CallV2BackendFirebaseOwnerStatus> statuses;
  final List<CallV2BackendFirebaseOwnerAction> actions;
  final List<CallV2BackendFirebaseOwnerEvent> events;
  final List<CallV2BackendFirebaseOwnerRollback> rollback;

  bool get isDeveloperOnly =>
      statuses.contains(CallV2BackendFirebaseOwnerStatus.developerOnly);
  bool get isHardDisabled =>
      statuses.contains(CallV2BackendFirebaseOwnerStatus.hardDisabled);
  bool get isRolloutEnabled =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.rolloutFalse);
  bool get isReachable =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.unreachable);
  bool get importsFirebase =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.noFirebaseImports);
  bool get opensFirestoreListeners => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noFirestoreListeners,
      );
  bool get readsFirestore =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.noFirestoreReads);
  bool get writesFirestore =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.noFirestoreWrites);
  bool get callsFirebaseAuth => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noFirebaseAuthCalls,
      );
  bool get callsFirebaseFunctions => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noFirebaseFunctionsCalls,
      );
  bool get callsFirebaseAppCheck => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noFirebaseAppCheckCalls,
      );
  bool get contactsProductionServices => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noProductionServiceContact,
      );
  bool get constructsRuntime => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noRuntimeConstruction,
      );
  bool get startsRuntime =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.noRuntimeStart);
  bool get accessesNavigation =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.noNavigationAccess);
  bool get accessesRtcPermissions => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noRtcPermissionAccess,
      );
  bool get registersLifecycle => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noLifecycleRegistration,
      );
  bool get mutatesRouteRegistry => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noRouteRegistryMutation,
      );
  bool get opensAsyncHandles =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.noAsyncHandles);
  bool get changesRulesFunctionsConfig => !statuses.contains(
        CallV2BackendFirebaseOwnerStatus.noRulesFunctionsConfigChanges,
      );
  bool get isDeploymentApproved =>
      !statuses.contains(CallV2BackendFirebaseOwnerStatus.noDeployment);
  bool get protectsV1 =>
      statuses.contains(CallV2BackendFirebaseOwnerStatus.v1Protected);

  CallV2BackendFirebaseOwnerDecision decideWhileDisabled({
    required CallV2BackendFirebaseOwnerAction action,
    required int generation,
    int? latestGeneration,
    CallV2BackendFirebaseOwnerEvent? event,
    CallV2BackendFirebaseOwnerEvent? previousEvent,
    bool ownershipMatches = true,
    bool rawPayloadProvided = false,
    bool terminal = false,
  }) {
    final status = _decisionStatus(
      generation: generation,
      latestGeneration: latestGeneration,
      event: event,
      previousEvent: previousEvent,
      ownershipMatches: ownershipMatches,
      rawPayloadProvided: rawPayloadProvided,
      terminal: terminal,
    );
    return CallV2BackendFirebaseOwnerDecision(
      status: status,
      action: action,
      generation: generation,
      event: event,
    );
  }

  CallV2BackendFirebaseOwnerDecisionStatus _decisionStatus({
    required int generation,
    required int? latestGeneration,
    required CallV2BackendFirebaseOwnerEvent? event,
    required CallV2BackendFirebaseOwnerEvent? previousEvent,
    required bool ownershipMatches,
    required bool rawPayloadProvided,
    required bool terminal,
  }) {
    if (rawPayloadProvided) {
      return CallV2BackendFirebaseOwnerDecisionStatus.rawPayloadRejected;
    }
    if (!ownershipMatches) {
      return CallV2BackendFirebaseOwnerDecisionStatus.ownershipRejected;
    }
    if (terminal || _isTerminalEvent(event)) {
      return CallV2BackendFirebaseOwnerDecisionStatus.terminalIgnored;
    }
    if (_isBackwardsTransition(event: event, previousEvent: previousEvent)) {
      return CallV2BackendFirebaseOwnerDecisionStatus.transitionRejected;
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2BackendFirebaseOwnerDecisionStatus.duplicateNoOp;
    }
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2BackendFirebaseOwnerDecisionStatus.staleIgnored;
    }
    return CallV2BackendFirebaseOwnerDecisionStatus.disabledInert;
  }

  bool _isTerminalEvent(CallV2BackendFirebaseOwnerEvent? event) {
    return event == CallV2BackendFirebaseOwnerEvent.sanitizedEnded ||
        event == CallV2BackendFirebaseOwnerEvent.sanitizedFailure;
  }

  bool _isBackwardsTransition({
    required CallV2BackendFirebaseOwnerEvent? event,
    required CallV2BackendFirebaseOwnerEvent? previousEvent,
  }) {
    if (event == null || previousEvent == null) return false;
    return _eventRank(event) < _eventRank(previousEvent);
  }

  int _eventRank(CallV2BackendFirebaseOwnerEvent event) {
    switch (event) {
      case CallV2BackendFirebaseOwnerEvent.sanitizedUnknown:
        return 0;
      case CallV2BackendFirebaseOwnerEvent.sanitizedRinging:
        return 1;
      case CallV2BackendFirebaseOwnerEvent.sanitizedActive:
        return 2;
      case CallV2BackendFirebaseOwnerEvent.sanitizedEnded:
      case CallV2BackendFirebaseOwnerEvent.sanitizedFailure:
        return 3;
    }
  }

  bool get rollbackPreserved =>
      rollback.contains(CallV2BackendFirebaseOwnerRollback.oneCommitRevert) &&
      rollback.contains(CallV2BackendFirebaseOwnerRollback.keepRolloutFalse) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRollback.keepRouteRegistryNull,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRollback.keepDisabledOwnerInert,
      ) &&
      rollback.contains(
        CallV2BackendFirebaseOwnerRollback.noDeploymentRequired,
      ) &&
      rollback.contains(CallV2BackendFirebaseOwnerRollback.noConfigChanges) &&
      rollback.contains(CallV2BackendFirebaseOwnerRollback.v1Unaffected);

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': statuses.length,
      'actionCount': actions.length,
      'eventCount': events.length,
      'rollbackCount': rollback.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'importsFirebase': importsFirebase,
      'opensDocumentListeners': opensFirestoreListeners,
      'readsDocuments': readsFirestore,
      'writesDocuments': writesFirestore,
      'callsAuth': callsFirebaseAuth,
      'callsFunctions': callsFirebaseFunctions,
      'callsIntegrityCheck': callsFirebaseAppCheck,
      'contactsProductionServices': contactsProductionServices,
      'constructsRuntime': constructsRuntime,
      'startsRuntime': startsRuntime,
      'accessesNavigation': accessesNavigation,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'registersLifecycle': registersLifecycle,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'changesServerConfig': changesRulesFunctionsConfig,
      'deploymentApproved': isDeploymentApproved,
      'rollbackPreserved': rollbackPreserved,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2BackendFirebaseOwnerBoundary(${toSafeDebugMap()})';
  }
}

final callV2BackendFirebaseOwnerBoundary = CallV2BackendFirebaseOwnerBoundary(
  statuses: <CallV2BackendFirebaseOwnerStatus>[
    CallV2BackendFirebaseOwnerStatus.developerOnly,
    CallV2BackendFirebaseOwnerStatus.hardDisabled,
    CallV2BackendFirebaseOwnerStatus.rolloutFalse,
    CallV2BackendFirebaseOwnerStatus.unreachable,
    CallV2BackendFirebaseOwnerStatus.noFirebaseImports,
    CallV2BackendFirebaseOwnerStatus.noFirestoreListeners,
    CallV2BackendFirebaseOwnerStatus.noFirestoreReads,
    CallV2BackendFirebaseOwnerStatus.noFirestoreWrites,
    CallV2BackendFirebaseOwnerStatus.noFirebaseAuthCalls,
    CallV2BackendFirebaseOwnerStatus.noFirebaseFunctionsCalls,
    CallV2BackendFirebaseOwnerStatus.noFirebaseAppCheckCalls,
    CallV2BackendFirebaseOwnerStatus.noProductionServiceContact,
    CallV2BackendFirebaseOwnerStatus.noRuntimeConstruction,
    CallV2BackendFirebaseOwnerStatus.noRuntimeStart,
    CallV2BackendFirebaseOwnerStatus.noNavigationAccess,
    CallV2BackendFirebaseOwnerStatus.noRtcPermissionAccess,
    CallV2BackendFirebaseOwnerStatus.noLifecycleRegistration,
    CallV2BackendFirebaseOwnerStatus.noRouteRegistryMutation,
    CallV2BackendFirebaseOwnerStatus.noAsyncHandles,
    CallV2BackendFirebaseOwnerStatus.noRulesFunctionsConfigChanges,
    CallV2BackendFirebaseOwnerStatus.noDeployment,
    CallV2BackendFirebaseOwnerStatus.v1Protected,
  ],
  actions: <CallV2BackendFirebaseOwnerAction>[
    CallV2BackendFirebaseOwnerAction.attachBackend,
    CallV2BackendFirebaseOwnerAction.detachBackend,
    CallV2BackendFirebaseOwnerAction.receiveSnapshot,
    CallV2BackendFirebaseOwnerAction.sendMutation,
    CallV2BackendFirebaseOwnerAction.callFunction,
    CallV2BackendFirebaseOwnerAction.refreshAuth,
    CallV2BackendFirebaseOwnerAction.verifyAppCheck,
  ],
  events: <CallV2BackendFirebaseOwnerEvent>[
    CallV2BackendFirebaseOwnerEvent.sanitizedRinging,
    CallV2BackendFirebaseOwnerEvent.sanitizedActive,
    CallV2BackendFirebaseOwnerEvent.sanitizedEnded,
    CallV2BackendFirebaseOwnerEvent.sanitizedFailure,
    CallV2BackendFirebaseOwnerEvent.sanitizedUnknown,
  ],
  rollback: <CallV2BackendFirebaseOwnerRollback>[
    CallV2BackendFirebaseOwnerRollback.oneCommitRevert,
    CallV2BackendFirebaseOwnerRollback.keepRolloutFalse,
    CallV2BackendFirebaseOwnerRollback.keepRouteRegistryNull,
    CallV2BackendFirebaseOwnerRollback.keepDisabledOwnerInert,
    CallV2BackendFirebaseOwnerRollback.noDeploymentRequired,
    CallV2BackendFirebaseOwnerRollback.noConfigChanges,
    CallV2BackendFirebaseOwnerRollback.v1Unaffected,
  ],
);
