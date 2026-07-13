import '../ui/call_v2_production_route_destination.dart';

enum CallV2DeveloperNavigatorOwnerSkeletonStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  callV2Unreachable,
  noRealNavigationWiring,
  noAppNavigationKey,
  noGlobalAppKey,
  noWidgetContextStorage,
  noNavigationCall,
  noMaterialRouteTableWiring,
  noAppRouterWiring,
  noRoutePush,
  noRoutePop,
  noRouteReplace,
  noRouteObjectCreation,
  noScreenCreation,
  noRuntimeStart,
  noServiceAccess,
  noMediaAccess,
  noCapabilityPrompt,
  v1Protected,
}

enum CallV2DeveloperNavigatorOwnershipRule {
  callV2OwnedRoutesOnly,
  noV1RoutesOwned,
  unknownRoutesNeverPopped,
  currentRouteMustMatchBeforePop,
  nullRouteArgumentsOnly,
  canonicalRouteNamesOnly,
}

enum CallV2DeveloperNavigatorAction {
  showConnecting,
  showAudio,
  showVideo,
  showFailure,
  closeCallV2Route,
  dismissFailure,
}

enum CallV2DeveloperNavigatorDecisionStatus {
  disabledInert,
  rejected,
  duplicateNoOp,
  staleIgnored,
}

enum CallV2DeveloperNavigatorRejection {
  routeNameMissing,
  routeNameNotCanonical,
  routeNameContainsQueryOrFragment,
  routeNameContainsDynamicSegment,
  routeArgumentsNotNull,
  currentRouteMismatch,
  routeNotOwned,
}

enum CallV2DeveloperNavigatorRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  noDeploymentRequired,
  v1Unaffected,
}

final class CallV2DeveloperNavigatorDecision {
  const CallV2DeveloperNavigatorDecision._({
    required this.status,
    required this.action,
    required this.generation,
    this.rejection,
  });

  const CallV2DeveloperNavigatorDecision.disabledInert({
    required CallV2DeveloperNavigatorAction action,
    required int generation,
  }) : this._(
          status: CallV2DeveloperNavigatorDecisionStatus.disabledInert,
          action: action,
          generation: generation,
        );

  const CallV2DeveloperNavigatorDecision.rejected({
    required CallV2DeveloperNavigatorAction action,
    required int generation,
    required CallV2DeveloperNavigatorRejection rejection,
  }) : this._(
          status: CallV2DeveloperNavigatorDecisionStatus.rejected,
          action: action,
          generation: generation,
          rejection: rejection,
        );

  const CallV2DeveloperNavigatorDecision.duplicateNoOp({
    required CallV2DeveloperNavigatorAction action,
    required int generation,
  }) : this._(
          status: CallV2DeveloperNavigatorDecisionStatus.duplicateNoOp,
          action: action,
          generation: generation,
        );

  const CallV2DeveloperNavigatorDecision.staleIgnored({
    required CallV2DeveloperNavigatorAction action,
    required int generation,
  }) : this._(
          status: CallV2DeveloperNavigatorDecisionStatus.staleIgnored,
          action: action,
          generation: generation,
        );

  final CallV2DeveloperNavigatorDecisionStatus status;
  final CallV2DeveloperNavigatorAction action;
  final int generation;
  final CallV2DeveloperNavigatorRejection? rejection;

  bool get createsRouteObject => false;
  bool get createsScreen => false;
  bool get startsRuntime => false;
  bool get accessesServices => false;
  bool get accessesMedia => false;
  bool get promptsForCapabilities => false;
  bool get accessesNavigation => false;
  bool get pushesRoute => false;
  bool get popsRoute => false;
  bool get replacesRoute => false;
  bool get accessesContext => false;
  bool get usesAppKey => false;
  bool get mutatesV1Route => false;
  bool get opensAsyncHandles => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'rejected': status == CallV2DeveloperNavigatorDecisionStatus.rejected,
      'duplicate':
          status == CallV2DeveloperNavigatorDecisionStatus.duplicateNoOp,
      'stale': status == CallV2DeveloperNavigatorDecisionStatus.staleIgnored,
      'hasReason': rejection != null,
      'generationKnown': generation >= 0,
      'createsRouteObject': createsRouteObject,
      'createsScreen': createsScreen,
      'startsRuntime': startsRuntime,
      'accessesServices': accessesServices,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'accessesNavigation': accessesNavigation,
      'pushesRoute': pushesRoute,
      'popsRoute': popsRoute,
      'replacesRoute': replacesRoute,
      'accessesContext': accessesContext,
      'usesAppKey': usesAppKey,
      'mutatesV1Route': mutatesV1Route,
      'opensAsyncHandles': opensAsyncHandles,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperNavigatorDecision(${toSafeDebugMap()})';
  }
}

final class CallV2DeveloperNavigatorOwnerSkeleton {
  factory CallV2DeveloperNavigatorOwnerSkeleton({
    required List<CallV2DeveloperNavigatorOwnerSkeletonStatus> status,
    required List<CallV2DeveloperNavigatorOwnershipRule> ownershipRules,
    required List<CallV2DeveloperNavigatorAction> actions,
    required Set<String> ownedRouteNames,
    required Set<String> excludedRouteNames,
    required List<CallV2DeveloperNavigatorRollback> rollbackRequirements,
  }) {
    return CallV2DeveloperNavigatorOwnerSkeleton._(
      List<CallV2DeveloperNavigatorOwnerSkeletonStatus>.unmodifiable(status),
      List<CallV2DeveloperNavigatorOwnershipRule>.unmodifiable(ownershipRules),
      List<CallV2DeveloperNavigatorAction>.unmodifiable(actions),
      Set<String>.unmodifiable(ownedRouteNames),
      Set<String>.unmodifiable(excludedRouteNames),
      List<CallV2DeveloperNavigatorRollback>.unmodifiable(
        rollbackRequirements,
      ),
    );
  }

  const CallV2DeveloperNavigatorOwnerSkeleton._(
    this.status,
    this.ownershipRules,
    this.actions,
    this.ownedRouteNames,
    this.excludedRouteNames,
    this.rollbackRequirements,
  );

  final List<CallV2DeveloperNavigatorOwnerSkeletonStatus> status;
  final List<CallV2DeveloperNavigatorOwnershipRule> ownershipRules;
  final List<CallV2DeveloperNavigatorAction> actions;
  final Set<String> ownedRouteNames;
  final Set<String> excludedRouteNames;
  final List<CallV2DeveloperNavigatorRollback> rollbackRequirements;

  bool get isDeveloperOnly => status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.developerOnly,
      );

  bool get isHardDisabled => status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.rolloutFalse,
      );

  bool get isReachable => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.callV2Unreachable,
      );

  bool get wiresRealNavigation => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noRealNavigationWiring,
      );

  bool get usesAppNavigationKey => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noAppNavigationKey,
      );

  bool get usesGlobalAppKey => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noGlobalAppKey,
      );

  bool get storesWidgetContext => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noWidgetContextStorage,
      );

  bool get callsNavigation => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noNavigationCall,
      );

  bool get wiresMaterialRouteTable => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noMaterialRouteTableWiring,
      );

  bool get wiresAppRouter => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noAppRouterWiring,
      );

  bool get pushesRoutes => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noRoutePush,
      );

  bool get popsRoutes => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noRoutePop,
      );

  bool get replacesRoutes => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noRouteReplace,
      );

  bool get createsRouteObjects => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noRouteObjectCreation,
      );

  bool get createsScreens => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noScreenCreation,
      );

  bool get startsRuntime => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noRuntimeStart,
      );

  bool get accessesServices => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noServiceAccess,
      );

  bool get accessesMedia => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noMediaAccess,
      );

  bool get promptsForCapabilities => !status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.noCapabilityPrompt,
      );

  bool get protectsV1 => status.contains(
        CallV2DeveloperNavigatorOwnerSkeletonStatus.v1Protected,
      );

  bool ownsRouteName(String? routeName) {
    if (routeName == null || routeName.isEmpty) return false;
    return ownedRouteNames.contains(routeName);
  }

  CallV2DeveloperNavigatorRejection? validateRouteOwnership({
    required String? routeName,
    Object? routeArguments,
  }) {
    if (routeArguments != null) {
      return CallV2DeveloperNavigatorRejection.routeArgumentsNotNull;
    }
    if (routeName == null || routeName.isEmpty) {
      return CallV2DeveloperNavigatorRejection.routeNameMissing;
    }
    if (routeName.contains('?') || routeName.contains('#')) {
      return CallV2DeveloperNavigatorRejection.routeNameContainsQueryOrFragment;
    }
    if (routeName.contains(':') || routeName.contains('{')) {
      return CallV2DeveloperNavigatorRejection.routeNameContainsDynamicSegment;
    }
    if (!ownedRouteNames.contains(routeName)) {
      return CallV2DeveloperNavigatorRejection.routeNameNotCanonical;
    }
    return null;
  }

  CallV2DeveloperNavigatorRejection? validateFutureClose({
    required String? ownedRouteName,
    required String? currentRouteName,
  }) {
    if (!ownsRouteName(ownedRouteName)) {
      return CallV2DeveloperNavigatorRejection.routeNotOwned;
    }
    if (currentRouteName != ownedRouteName) {
      return CallV2DeveloperNavigatorRejection.currentRouteMismatch;
    }
    return null;
  }

  CallV2DeveloperNavigatorDecision decideWhileDisabled({
    required CallV2DeveloperNavigatorAction action,
    required int generation,
    int? latestGeneration,
    String? routeName,
    Object? routeArguments,
    String? ownedRouteName,
    String? currentRouteName,
  }) {
    if (latestGeneration != null && generation < latestGeneration) {
      return CallV2DeveloperNavigatorDecision.staleIgnored(
        action: action,
        generation: generation,
      );
    }
    if (latestGeneration != null && generation == latestGeneration) {
      return CallV2DeveloperNavigatorDecision.duplicateNoOp(
        action: action,
        generation: generation,
      );
    }

    final rejection = switch (action) {
      CallV2DeveloperNavigatorAction.showConnecting ||
      CallV2DeveloperNavigatorAction.showAudio ||
      CallV2DeveloperNavigatorAction.showVideo ||
      CallV2DeveloperNavigatorAction.showFailure =>
        validateRouteOwnership(
          routeName: routeName ?? routeNameForAction(action),
          routeArguments: routeArguments,
        ),
      CallV2DeveloperNavigatorAction.closeCallV2Route ||
      CallV2DeveloperNavigatorAction.dismissFailure =>
        validateFutureClose(
          ownedRouteName: ownedRouteName,
          currentRouteName: currentRouteName,
        ),
    };

    if (rejection != null) {
      return CallV2DeveloperNavigatorDecision.rejected(
        action: action,
        generation: generation,
        rejection: rejection,
      );
    }
    return CallV2DeveloperNavigatorDecision.disabledInert(
      action: action,
      generation: generation,
    );
  }

  String? routeNameForAction(CallV2DeveloperNavigatorAction action) {
    return switch (action) {
      CallV2DeveloperNavigatorAction.showConnecting =>
        CallV2ProductionRouteNames.connecting,
      CallV2DeveloperNavigatorAction.showAudio =>
        CallV2ProductionRouteNames.activeAudio,
      CallV2DeveloperNavigatorAction.showVideo =>
        CallV2ProductionRouteNames.activeVideo,
      CallV2DeveloperNavigatorAction.showFailure =>
        CallV2ProductionRouteNames.controlledFailure,
      CallV2DeveloperNavigatorAction.closeCallV2Route ||
      CallV2DeveloperNavigatorAction.dismissFailure =>
        null,
    };
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': status.length,
      'ownershipRuleCount': ownershipRules.length,
      'actionCount': actions.length,
      'ownedRouteCount': ownedRouteNames.length,
      'excludedRouteCount': excludedRouteNames.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'wiresRealNavigation': wiresRealNavigation,
      'usesAppNavigationKey': usesAppNavigationKey,
      'usesGlobalAppKey': usesGlobalAppKey,
      'storesWidgetContext': storesWidgetContext,
      'callsNavigation': callsNavigation,
      'wiresMaterialRouteTable': wiresMaterialRouteTable,
      'wiresAppRouter': wiresAppRouter,
      'pushesRoutes': pushesRoutes,
      'popsRoutes': popsRoutes,
      'replacesRoutes': replacesRoutes,
      'createsRouteObjects': createsRouteObjects,
      'createsScreens': createsScreens,
      'startsRuntime': startsRuntime,
      'accessesServices': accessesServices,
      'accessesMedia': accessesMedia,
      'promptsForCapabilities': promptsForCapabilities,
      'protectsV1': protectsV1,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperNavigatorOwnerSkeleton(${toSafeDebugMap()})';
  }
}

final callV2DeveloperNavigatorOwnerSkeleton =
    CallV2DeveloperNavigatorOwnerSkeleton(
  status: <CallV2DeveloperNavigatorOwnerSkeletonStatus>[
    CallV2DeveloperNavigatorOwnerSkeletonStatus.developerOnly,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.hardDisabled,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.rolloutFalse,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.callV2Unreachable,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noRealNavigationWiring,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noAppNavigationKey,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noGlobalAppKey,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noWidgetContextStorage,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noNavigationCall,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noMaterialRouteTableWiring,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noAppRouterWiring,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noRoutePush,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noRoutePop,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noRouteReplace,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noRouteObjectCreation,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noScreenCreation,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noRuntimeStart,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noServiceAccess,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noMediaAccess,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.noCapabilityPrompt,
    CallV2DeveloperNavigatorOwnerSkeletonStatus.v1Protected,
  ],
  ownershipRules: <CallV2DeveloperNavigatorOwnershipRule>[
    CallV2DeveloperNavigatorOwnershipRule.callV2OwnedRoutesOnly,
    CallV2DeveloperNavigatorOwnershipRule.noV1RoutesOwned,
    CallV2DeveloperNavigatorOwnershipRule.unknownRoutesNeverPopped,
    CallV2DeveloperNavigatorOwnershipRule.currentRouteMustMatchBeforePop,
    CallV2DeveloperNavigatorOwnershipRule.nullRouteArgumentsOnly,
    CallV2DeveloperNavigatorOwnershipRule.canonicalRouteNamesOnly,
  ],
  actions: <CallV2DeveloperNavigatorAction>[
    CallV2DeveloperNavigatorAction.showConnecting,
    CallV2DeveloperNavigatorAction.showAudio,
    CallV2DeveloperNavigatorAction.showVideo,
    CallV2DeveloperNavigatorAction.showFailure,
    CallV2DeveloperNavigatorAction.closeCallV2Route,
    CallV2DeveloperNavigatorAction.dismissFailure,
  ],
  ownedRouteNames: <String>{
    CallV2ProductionRouteNames.connecting,
    CallV2ProductionRouteNames.activeAudio,
    CallV2ProductionRouteNames.activeVideo,
    CallV2ProductionRouteNames.controlledFailure,
  },
  excludedRouteNames: <String>{
    '/call-v2/ready',
  },
  rollbackRequirements: <CallV2DeveloperNavigatorRollback>[
    CallV2DeveloperNavigatorRollback.oneCommitRevert,
    CallV2DeveloperNavigatorRollback.keepRolloutFalse,
    CallV2DeveloperNavigatorRollback.keepRouteRegistryNull,
    CallV2DeveloperNavigatorRollback.noDeploymentRequired,
    CallV2DeveloperNavigatorRollback.v1Unaffected,
  ],
);
