import '../ui/call_v2_production_route_destination.dart';

enum CallV2DeveloperRouteRegistrationSkeletonStatus {
  developerOnly,
  hardDisabled,
  rolloutFalse,
  callV2Unreachable,
  routeRegistryStillReturnsNull,
  noRouteObjectCreation,
  noScreenCreation,
  noRuntimeStart,
  noServiceAccess,
  noNavigationAccess,
  v1Protected,
}

enum CallV2DeveloperRouteRegistrationDecisionStatus {
  disabledNull,
  rejected,
}

enum CallV2DeveloperRouteRegistrationRejection {
  routeNameMissing,
  routeNameNotCanonical,
  routeNameContainsQueryOrFragment,
  routeNameContainsDynamicSegment,
  routeArgumentsNotNull,
}

enum CallV2DeveloperRouteRegistrationRollback {
  oneCommitRevert,
  keepRolloutFalse,
  keepRouteRegistryNull,
  noDeploymentRequired,
  v1Unaffected,
}

final class CallV2DeveloperRouteRegistrationDecision {
  const CallV2DeveloperRouteRegistrationDecision._(
    this.status,
    this.rejection,
  );

  const CallV2DeveloperRouteRegistrationDecision.disabledNull()
      : this._(
          CallV2DeveloperRouteRegistrationDecisionStatus.disabledNull,
          null,
        );

  const CallV2DeveloperRouteRegistrationDecision.rejected(this.rejection)
      : status = CallV2DeveloperRouteRegistrationDecisionStatus.rejected;

  final CallV2DeveloperRouteRegistrationDecisionStatus status;
  final CallV2DeveloperRouteRegistrationRejection? rejection;

  bool get createsRouteObject => false;
  bool get createsScreen => false;
  bool get startsRuntime => false;
  bool get accessesServices => false;
  bool get accessesNavigator => false;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'status': status.name,
      'rejected':
          status == CallV2DeveloperRouteRegistrationDecisionStatus.rejected,
      'hasReason': rejection != null,
      'createsRouteObject': createsRouteObject,
      'createsScreen': createsScreen,
      'startsRuntime': startsRuntime,
      'accessesServices': accessesServices,
      'accessesNavigator': accessesNavigator,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRouteRegistrationDecision(${toSafeDebugMap()})';
  }
}

final class CallV2DeveloperRouteRegistrationSkeleton {
  factory CallV2DeveloperRouteRegistrationSkeleton({
    required List<CallV2DeveloperRouteRegistrationSkeletonStatus> status,
    required Set<String> allowedRouteNames,
    required Set<String> excludedRouteNames,
    required List<CallV2DeveloperRouteRegistrationRollback>
        rollbackRequirements,
  }) {
    return CallV2DeveloperRouteRegistrationSkeleton._(
      List<CallV2DeveloperRouteRegistrationSkeletonStatus>.unmodifiable(
        status,
      ),
      Set<String>.unmodifiable(allowedRouteNames),
      Set<String>.unmodifiable(excludedRouteNames),
      List<CallV2DeveloperRouteRegistrationRollback>.unmodifiable(
        rollbackRequirements,
      ),
    );
  }

  const CallV2DeveloperRouteRegistrationSkeleton._(
    this.status,
    this.allowedRouteNames,
    this.excludedRouteNames,
    this.rollbackRequirements,
  );

  final List<CallV2DeveloperRouteRegistrationSkeletonStatus> status;
  final Set<String> allowedRouteNames;
  final Set<String> excludedRouteNames;
  final List<CallV2DeveloperRouteRegistrationRollback> rollbackRequirements;

  bool get isDeveloperOnly => status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.developerOnly,
      );

  bool get isHardDisabled => status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.hardDisabled,
      );

  bool get isRolloutEnabled => !status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.rolloutFalse,
      );

  bool get isReachable => !status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.callV2Unreachable,
      );

  bool get createsRouteObjects => !status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.noRouteObjectCreation,
      );

  bool get createsScreens => !status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.noScreenCreation,
      );

  bool get startsRuntime => !status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.noRuntimeStart,
      );

  bool get accessesServices => !status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.noServiceAccess,
      );

  bool get accessesNavigator => !status.contains(
        CallV2DeveloperRouteRegistrationSkeletonStatus.noNavigationAccess,
      );

  CallV2DeveloperRouteRegistrationDecision resolveWhileDisabled({
    required String? routeName,
    Object? routeArguments,
  }) {
    final validation = validateRoute(
      routeName: routeName,
      routeArguments: routeArguments,
    );
    if (validation != null) {
      return CallV2DeveloperRouteRegistrationDecision.rejected(validation);
    }
    return const CallV2DeveloperRouteRegistrationDecision.disabledNull();
  }

  CallV2DeveloperRouteRegistrationRejection? validateRoute({
    required String? routeName,
    Object? routeArguments,
  }) {
    if (routeArguments != null) {
      return CallV2DeveloperRouteRegistrationRejection.routeArgumentsNotNull;
    }
    if (routeName == null || routeName.isEmpty) {
      return CallV2DeveloperRouteRegistrationRejection.routeNameMissing;
    }
    if (routeName.contains('?') || routeName.contains('#')) {
      return CallV2DeveloperRouteRegistrationRejection
          .routeNameContainsQueryOrFragment;
    }
    if (routeName.contains(':') || routeName.contains('{')) {
      return CallV2DeveloperRouteRegistrationRejection
          .routeNameContainsDynamicSegment;
    }
    if (!allowedRouteNames.contains(routeName)) {
      return CallV2DeveloperRouteRegistrationRejection.routeNameNotCanonical;
    }
    return null;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'statusCount': status.length,
      'allowedRouteCount': allowedRouteNames.length,
      'excludedRouteCount': excludedRouteNames.length,
      'rollbackRequirementCount': rollbackRequirements.length,
      'developerOnly': isDeveloperOnly,
      'hardDisabled': isHardDisabled,
      'rolloutEnabled': isRolloutEnabled,
      'reachable': isReachable,
      'createsRouteObjects': createsRouteObjects,
      'createsScreens': createsScreens,
      'startsRuntime': startsRuntime,
      'accessesServices': accessesServices,
      'accessesNavigator': accessesNavigator,
    };
  }

  @override
  String toString() {
    return 'CallV2DeveloperRouteRegistrationSkeleton(${toSafeDebugMap()})';
  }
}

final callV2DeveloperRouteRegistrationSkeleton =
    CallV2DeveloperRouteRegistrationSkeleton(
  status: <CallV2DeveloperRouteRegistrationSkeletonStatus>[
    CallV2DeveloperRouteRegistrationSkeletonStatus.developerOnly,
    CallV2DeveloperRouteRegistrationSkeletonStatus.hardDisabled,
    CallV2DeveloperRouteRegistrationSkeletonStatus.rolloutFalse,
    CallV2DeveloperRouteRegistrationSkeletonStatus.callV2Unreachable,
    CallV2DeveloperRouteRegistrationSkeletonStatus
        .routeRegistryStillReturnsNull,
    CallV2DeveloperRouteRegistrationSkeletonStatus.noRouteObjectCreation,
    CallV2DeveloperRouteRegistrationSkeletonStatus.noScreenCreation,
    CallV2DeveloperRouteRegistrationSkeletonStatus.noRuntimeStart,
    CallV2DeveloperRouteRegistrationSkeletonStatus.noServiceAccess,
    CallV2DeveloperRouteRegistrationSkeletonStatus.noNavigationAccess,
    CallV2DeveloperRouteRegistrationSkeletonStatus.v1Protected,
  ],
  allowedRouteNames: <String>{
    CallV2ProductionRouteNames.connecting,
    CallV2ProductionRouteNames.activeAudio,
    CallV2ProductionRouteNames.activeVideo,
    CallV2ProductionRouteNames.controlledFailure,
  },
  excludedRouteNames: <String>{
    '/call-v2/ready',
  },
  rollbackRequirements: <CallV2DeveloperRouteRegistrationRollback>[
    CallV2DeveloperRouteRegistrationRollback.oneCommitRevert,
    CallV2DeveloperRouteRegistrationRollback.keepRolloutFalse,
    CallV2DeveloperRouteRegistrationRollback.keepRouteRegistryNull,
    CallV2DeveloperRouteRegistrationRollback.noDeploymentRequired,
    CallV2DeveloperRouteRegistrationRollback.v1Unaffected,
  ],
);
