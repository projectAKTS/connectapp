enum CallV2NavigationOwnerBoundaryStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  unreachable,
  noRealNavigationWiring,
  noNavigationCalls,
  noAppNavigationKey,
  noGlobalAppKey,
  noWidgetContextStorage,
  noMaterialRouteTableWiring,
  noRouteObjectCreation,
  noRouteSinkUse,
  noScreenCreation,
  noRuntimeStart,
  noBackendFirebaseAccess,
  noRtcPermissionAccess,
  noLifecycleRegistration,
  noRouteRegistryMutation,
  noAsyncHandles,
  v1Protected,
}

enum CallV2NavigationOwnerAction {
  showConnecting,
  showAudio,
  showVideo,
  showFailure,
  dismissFailure,
  returnToPrevious,
}

enum CallV2NavigationOwnerDecisionStatus {
  disabledInert,
  duplicateNoOp,
  staleIgnored,
  routeMismatchIgnored,
  terminalIgnored,
}

final class CallV2NavigationOwnerDecision {
  const CallV2NavigationOwnerDecision._({
    required this.status,
    required this.action,
    required this.generation,
  });

  const CallV2NavigationOwnerDecision.disabledInert({
    required CallV2NavigationOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2NavigationOwnerDecisionStatus.disabledInert,
          action: action,
          generation: generation,
        );

  const CallV2NavigationOwnerDecision.duplicateNoOp({
    required CallV2NavigationOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2NavigationOwnerDecisionStatus.duplicateNoOp,
          action: action,
          generation: generation,
        );

  const CallV2NavigationOwnerDecision.staleIgnored({
    required CallV2NavigationOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2NavigationOwnerDecisionStatus.staleIgnored,
          action: action,
          generation: generation,
        );

  const CallV2NavigationOwnerDecision.routeMismatchIgnored({
    required CallV2NavigationOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2NavigationOwnerDecisionStatus.routeMismatchIgnored,
          action: action,
          generation: generation,
        );

  const CallV2NavigationOwnerDecision.terminalIgnored({
    required CallV2NavigationOwnerAction action,
    required int generation,
  }) : this._(
          status: CallV2NavigationOwnerDecisionStatus.terminalIgnored,
          action: action,
          generation: generation,
        );

  final CallV2NavigationOwnerDecisionStatus status;
  final CallV2NavigationOwnerAction action;
  final int generation;

  bool get callsNavigation => false;
  bool get createsRouteObject => false;
  bool get createsScreen => false;
  bool get usesRouteSink => false;
  bool get startsRuntime => false;
  bool get accessesBackendFirebase => false;
  bool get accessesRtcPermissions => false;
  bool get registersLifecycle => false;
  bool get mutatesRouteRegistry => false;
  bool get opensAsyncHandles => false;
  bool get mutatesV1State => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'action': action.name,
      'generationKnown': generation >= 0,
      'callsNavigation': callsNavigation,
      'createsRouteObject': createsRouteObject,
      'createsScreen': createsScreen,
      'usesRouteSink': usesRouteSink,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'registersLifecycle': registersLifecycle,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'mutatesV1State': mutatesV1State,
    };
  }

  @override
  String toString() {
    return 'CallV2NavigationOwnerDecision(${toSafeDebugMap()})';
  }
}

final class CallV2NavigationOwnerBoundary {
  factory CallV2NavigationOwnerBoundary({
    required List<CallV2NavigationOwnerBoundaryStatus> statuses,
    required List<CallV2NavigationOwnerAction> actions,
  }) {
    return CallV2NavigationOwnerBoundary._(
      List<CallV2NavigationOwnerBoundaryStatus>.unmodifiable(statuses),
      List<CallV2NavigationOwnerAction>.unmodifiable(actions),
    );
  }

  const CallV2NavigationOwnerBoundary._(
    this.statuses,
    this.actions,
  );

  final List<CallV2NavigationOwnerBoundaryStatus> statuses;
  final List<CallV2NavigationOwnerAction> actions;

  bool get isDeveloperOnly => statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.developerOnly,
      );

  bool get isHardDisabled => statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.rolloutFalse,
      );

  bool get isReachable => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.unreachable,
      );

  bool get wiresRealNavigation => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noRealNavigationWiring,
      );

  bool get callsNavigation => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noNavigationCalls,
      );

  bool get usesAppNavigationKey => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noAppNavigationKey,
      );

  bool get usesGlobalAppKey => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noGlobalAppKey,
      );

  bool get storesWidgetContext => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noWidgetContextStorage,
      );

  bool get wiresMaterialRouteTable => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noMaterialRouteTableWiring,
      );

  bool get createsRouteObject => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noRouteObjectCreation,
      );

  bool get usesRouteSink => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noRouteSinkUse,
      );

  bool get createsScreen => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noScreenCreation,
      );

  bool get startsRuntime => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noRuntimeStart,
      );

  bool get accessesBackendFirebase => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noBackendFirebaseAccess,
      );

  bool get accessesRtcPermissions => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noRtcPermissionAccess,
      );

  bool get registersLifecycle => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noLifecycleRegistration,
      );

  bool get mutatesRouteRegistry => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noRouteRegistryMutation,
      );

  bool get opensAsyncHandles => !statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.noAsyncHandles,
      );

  bool get protectsV1 => statuses.contains(
        CallV2NavigationOwnerBoundaryStatus.v1Protected,
      );

  CallV2NavigationOwnerDecision decideWhileDisabled({
    required CallV2NavigationOwnerAction action,
    required int generation,
    int? latestGeneration,
    String? ownedRouteName,
    String? currentRouteName,
    bool terminal = false,
  }) {
    if (terminal) {
      return CallV2NavigationOwnerDecision.terminalIgnored(
        action: action,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2NavigationOwnerDecision.staleIgnored(
        action: action,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2NavigationOwnerDecision.duplicateNoOp(
        action: action,
        generation: generation,
      );
    }
    if (ownedRouteName != null &&
        currentRouteName != null &&
        ownedRouteName != currentRouteName) {
      return CallV2NavigationOwnerDecision.routeMismatchIgnored(
        action: action,
        generation: generation,
      );
    }
    return CallV2NavigationOwnerDecision.disabledInert(
      action: action,
      generation: generation,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': statuses.length,
      'actionCount': actions.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'wiresRealNavigation': wiresRealNavigation,
      'callsNavigation': callsNavigation,
      'usesAppNavigationKey': usesAppNavigationKey,
      'usesGlobalAppKey': usesGlobalAppKey,
      'storesWidgetContext': storesWidgetContext,
      'wiresMaterialRouteTable': wiresMaterialRouteTable,
      'createsRouteObject': createsRouteObject,
      'usesRouteSink': usesRouteSink,
      'createsScreen': createsScreen,
      'startsRuntime': startsRuntime,
      'accessesBackend': accessesBackendFirebase,
      'accessesMediaCapabilities': accessesRtcPermissions,
      'registersLifecycle': registersLifecycle,
      'mutatesRouteRegistry': mutatesRouteRegistry,
      'opensAsyncHandles': opensAsyncHandles,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2NavigationOwnerBoundary(${toSafeDebugMap()})';
  }
}

final callV2NavigationOwnerBoundary = CallV2NavigationOwnerBoundary(
  statuses: <CallV2NavigationOwnerBoundaryStatus>[
    CallV2NavigationOwnerBoundaryStatus.developerOnly,
    CallV2NavigationOwnerBoundaryStatus.hardDisabled,
    CallV2NavigationOwnerBoundaryStatus.rolloutFalse,
    CallV2NavigationOwnerBoundaryStatus.unreachable,
    CallV2NavigationOwnerBoundaryStatus.noRealNavigationWiring,
    CallV2NavigationOwnerBoundaryStatus.noNavigationCalls,
    CallV2NavigationOwnerBoundaryStatus.noAppNavigationKey,
    CallV2NavigationOwnerBoundaryStatus.noGlobalAppKey,
    CallV2NavigationOwnerBoundaryStatus.noWidgetContextStorage,
    CallV2NavigationOwnerBoundaryStatus.noMaterialRouteTableWiring,
    CallV2NavigationOwnerBoundaryStatus.noRouteObjectCreation,
    CallV2NavigationOwnerBoundaryStatus.noRouteSinkUse,
    CallV2NavigationOwnerBoundaryStatus.noScreenCreation,
    CallV2NavigationOwnerBoundaryStatus.noRuntimeStart,
    CallV2NavigationOwnerBoundaryStatus.noBackendFirebaseAccess,
    CallV2NavigationOwnerBoundaryStatus.noRtcPermissionAccess,
    CallV2NavigationOwnerBoundaryStatus.noLifecycleRegistration,
    CallV2NavigationOwnerBoundaryStatus.noRouteRegistryMutation,
    CallV2NavigationOwnerBoundaryStatus.noAsyncHandles,
    CallV2NavigationOwnerBoundaryStatus.v1Protected,
  ],
  actions: <CallV2NavigationOwnerAction>[
    CallV2NavigationOwnerAction.showConnecting,
    CallV2NavigationOwnerAction.showAudio,
    CallV2NavigationOwnerAction.showVideo,
    CallV2NavigationOwnerAction.showFailure,
    CallV2NavigationOwnerAction.dismissFailure,
    CallV2NavigationOwnerAction.returnToPrevious,
  ],
);
