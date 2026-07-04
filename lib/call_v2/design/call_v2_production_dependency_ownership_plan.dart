enum CallV2ProductionDependency {
  appIntegrationOwner,
  productionComposition,
  startupBridge,
  uiCoordinator,
  presentationAdapter,
  productionRouteSink,
  routeFactory,
  runtime,
  rtcAdapter,
  observabilitySink,
  lifecycleSubscription,
  activeCallSessionState,
}

enum CallV2ProductionOwnerScope {
  appProcess,
  composition,
  uiFlow,
  navigation,
  runtimeSession,
  adapter,
}

enum CallV2ProductionConstructionPoint {
  afterRolloutAndApprovalGates,
  duringCompositionConstruction,
  duringStartupBridgeConstruction,
  duringCoordinatorConstruction,
  duringPresentationConstruction,
  duringRouteOwnerConstruction,
  duringRuntimeConstruction,
  onExplicitLaunchRequest,
}

enum CallV2ProductionLifecyclePoint {
  notStartedAtAppStartup,
  afterAuthenticatedLaunch,
  whenRouteSinkAttached,
  whenLifecycleOwnerStarts,
  onExplicitLeave,
  onTerminalSnapshot,
  onSignOut,
  onAppDispose,
}

enum CallV2ProductionRestartPolicy {
  neverAutomatically,
  recreateAfterFullDispose,
  idempotentSameRequestOnly,
  restartAfterControlledFailureOnly,
}

enum CallV2ProductionOwnershipTransferPolicy {
  forbidden,
  explicitDisposeDelegationOnly,
}

enum CallV2ProductionSingletonPolicy {
  forbidden,
  appOwnedSingleInstance,
}

class CallV2ProductionDependencyOwnership {
  const CallV2ProductionDependencyOwnership({
    required this.dependency,
    required this.owner,
    required this.ownerScope,
    required this.constructionPoint,
    required this.startPoint,
    required this.stopPoint,
    required this.disposePoint,
    required this.restartPolicy,
    required this.ownershipTransfer,
    required this.singletonPolicy,
  });

  final CallV2ProductionDependency dependency;
  final CallV2ProductionDependency? owner;
  final CallV2ProductionOwnerScope ownerScope;
  final CallV2ProductionConstructionPoint constructionPoint;
  final CallV2ProductionLifecyclePoint startPoint;
  final CallV2ProductionLifecyclePoint stopPoint;
  final CallV2ProductionLifecyclePoint disposePoint;
  final CallV2ProductionRestartPolicy restartPolicy;
  final CallV2ProductionOwnershipTransferPolicy ownershipTransfer;
  final CallV2ProductionSingletonPolicy singletonPolicy;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'dependency': dependency.name,
      'owner': owner?.name,
      'ownerScope': ownerScope.name,
      'constructionPoint': constructionPoint.name,
      'startPoint': startPoint.name,
      'stopPoint': stopPoint.name,
      'disposePoint': disposePoint.name,
      'restartPolicy': restartPolicy.name,
      'ownershipTransfer': ownershipTransfer.name,
      'singletonPolicy': singletonPolicy.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionDependencyOwnership(${toSafeDebugMap()})';
  }
}

class CallV2ProductionDependencyOwnershipPlan {
  factory CallV2ProductionDependencyOwnershipPlan({
    required List<CallV2ProductionDependencyOwnership> items,
    required List<CallV2ProductionDependency> constructionOrder,
    required List<CallV2ProductionDependency> disposalOrder,
  }) {
    return CallV2ProductionDependencyOwnershipPlan._(
      List<CallV2ProductionDependencyOwnership>.unmodifiable(items),
      List<CallV2ProductionDependency>.unmodifiable(constructionOrder),
      List<CallV2ProductionDependency>.unmodifiable(disposalOrder),
    );
  }

  const CallV2ProductionDependencyOwnershipPlan._(
    this.items,
    this.constructionOrder,
    this.disposalOrder,
  );

  final List<CallV2ProductionDependencyOwnership> items;
  final List<CallV2ProductionDependency> constructionOrder;
  final List<CallV2ProductionDependency> disposalOrder;

  CallV2ProductionDependencyOwnership ownershipFor(
    CallV2ProductionDependency dependency,
  ) {
    return items.singleWhere((item) => item.dependency == dependency);
  }

  bool get hasCircularOwnership {
    for (final item in items) {
      var owner = item.owner;
      final seen = <CallV2ProductionDependency>{item.dependency};
      while (owner != null) {
        if (!seen.add(owner)) return true;
        owner = ownershipFor(owner).owner;
      }
    }
    return false;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'items': items.map((item) => item.toSafeDebugMap()).toList(),
      'constructionOrder': constructionOrder.map((item) => item.name).toList(),
      'disposalOrder': disposalOrder.map((item) => item.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionDependencyOwnershipPlan(${toSafeDebugMap()})';
  }
}

const callV2ProductionDependencyOwnershipItems =
    <CallV2ProductionDependencyOwnership>[
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.appIntegrationOwner,
    owner: null,
    ownerScope: CallV2ProductionOwnerScope.appProcess,
    constructionPoint:
        CallV2ProductionConstructionPoint.afterRolloutAndApprovalGates,
    startPoint: CallV2ProductionLifecyclePoint.notStartedAtAppStartup,
    stopPoint: CallV2ProductionLifecyclePoint.onAppDispose,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.recreateAfterFullDispose,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.appOwnedSingleInstance,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.productionComposition,
    owner: CallV2ProductionDependency.appIntegrationOwner,
    ownerScope: CallV2ProductionOwnerScope.composition,
    constructionPoint:
        CallV2ProductionConstructionPoint.afterRolloutAndApprovalGates,
    startPoint: CallV2ProductionLifecyclePoint.notStartedAtAppStartup,
    stopPoint: CallV2ProductionLifecyclePoint.onAppDispose,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.recreateAfterFullDispose,
    ownershipTransfer:
        CallV2ProductionOwnershipTransferPolicy.explicitDisposeDelegationOnly,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.startupBridge,
    owner: CallV2ProductionDependency.productionComposition,
    ownerScope: CallV2ProductionOwnerScope.composition,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringStartupBridgeConstruction,
    startPoint: CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    stopPoint: CallV2ProductionLifecyclePoint.onExplicitLeave,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.idempotentSameRequestOnly,
    ownershipTransfer:
        CallV2ProductionOwnershipTransferPolicy.explicitDisposeDelegationOnly,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.uiCoordinator,
    owner: CallV2ProductionDependency.productionComposition,
    ownerScope: CallV2ProductionOwnerScope.uiFlow,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringCoordinatorConstruction,
    startPoint: CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    stopPoint: CallV2ProductionLifecyclePoint.onExplicitLeave,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.idempotentSameRequestOnly,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.presentationAdapter,
    owner: CallV2ProductionDependency.uiCoordinator,
    ownerScope: CallV2ProductionOwnerScope.uiFlow,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringPresentationConstruction,
    startPoint: CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    stopPoint: CallV2ProductionLifecyclePoint.onExplicitLeave,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.recreateAfterFullDispose,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.productionRouteSink,
    owner: CallV2ProductionDependency.presentationAdapter,
    ownerScope: CallV2ProductionOwnerScope.navigation,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringRouteOwnerConstruction,
    startPoint: CallV2ProductionLifecyclePoint.whenRouteSinkAttached,
    stopPoint: CallV2ProductionLifecyclePoint.onExplicitLeave,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.recreateAfterFullDispose,
    ownershipTransfer:
        CallV2ProductionOwnershipTransferPolicy.explicitDisposeDelegationOnly,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.routeFactory,
    owner: CallV2ProductionDependency.presentationAdapter,
    ownerScope: CallV2ProductionOwnerScope.navigation,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringRouteOwnerConstruction,
    startPoint: CallV2ProductionLifecyclePoint.whenRouteSinkAttached,
    stopPoint: CallV2ProductionLifecyclePoint.onExplicitLeave,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.neverAutomatically,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.runtime,
    owner: CallV2ProductionDependency.productionComposition,
    ownerScope: CallV2ProductionOwnerScope.runtimeSession,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringRuntimeConstruction,
    startPoint: CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    stopPoint: CallV2ProductionLifecyclePoint.onExplicitLeave,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.idempotentSameRequestOnly,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.rtcAdapter,
    owner: CallV2ProductionDependency.runtime,
    ownerScope: CallV2ProductionOwnerScope.adapter,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringCompositionConstruction,
    startPoint: CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    stopPoint: CallV2ProductionLifecyclePoint.onTerminalSnapshot,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy:
        CallV2ProductionRestartPolicy.restartAfterControlledFailureOnly,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.observabilitySink,
    owner: CallV2ProductionDependency.appIntegrationOwner,
    ownerScope: CallV2ProductionOwnerScope.appProcess,
    constructionPoint:
        CallV2ProductionConstructionPoint.afterRolloutAndApprovalGates,
    startPoint: CallV2ProductionLifecyclePoint.notStartedAtAppStartup,
    stopPoint: CallV2ProductionLifecyclePoint.onAppDispose,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.neverAutomatically,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.lifecycleSubscription,
    owner: CallV2ProductionDependency.appIntegrationOwner,
    ownerScope: CallV2ProductionOwnerScope.appProcess,
    constructionPoint:
        CallV2ProductionConstructionPoint.afterRolloutAndApprovalGates,
    startPoint: CallV2ProductionLifecyclePoint.whenLifecycleOwnerStarts,
    stopPoint: CallV2ProductionLifecyclePoint.onAppDispose,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.recreateAfterFullDispose,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
  CallV2ProductionDependencyOwnership(
    dependency: CallV2ProductionDependency.activeCallSessionState,
    owner: CallV2ProductionDependency.uiCoordinator,
    ownerScope: CallV2ProductionOwnerScope.uiFlow,
    constructionPoint:
        CallV2ProductionConstructionPoint.duringCoordinatorConstruction,
    startPoint: CallV2ProductionLifecyclePoint.afterAuthenticatedLaunch,
    stopPoint: CallV2ProductionLifecyclePoint.onExplicitLeave,
    disposePoint: CallV2ProductionLifecyclePoint.onAppDispose,
    restartPolicy: CallV2ProductionRestartPolicy.idempotentSameRequestOnly,
    ownershipTransfer: CallV2ProductionOwnershipTransferPolicy.forbidden,
    singletonPolicy: CallV2ProductionSingletonPolicy.forbidden,
  ),
];

const callV2ProductionDependencyConstructionOrder =
    <CallV2ProductionDependency>[
  CallV2ProductionDependency.appIntegrationOwner,
  CallV2ProductionDependency.observabilitySink,
  CallV2ProductionDependency.lifecycleSubscription,
  CallV2ProductionDependency.productionComposition,
  CallV2ProductionDependency.runtime,
  CallV2ProductionDependency.rtcAdapter,
  CallV2ProductionDependency.startupBridge,
  CallV2ProductionDependency.uiCoordinator,
  CallV2ProductionDependency.activeCallSessionState,
  CallV2ProductionDependency.presentationAdapter,
  CallV2ProductionDependency.routeFactory,
  CallV2ProductionDependency.productionRouteSink,
];

const callV2ProductionDependencyDisposalOrder = <CallV2ProductionDependency>[
  CallV2ProductionDependency.lifecycleSubscription,
  CallV2ProductionDependency.presentationAdapter,
  CallV2ProductionDependency.productionRouteSink,
  CallV2ProductionDependency.routeFactory,
  CallV2ProductionDependency.uiCoordinator,
  CallV2ProductionDependency.activeCallSessionState,
  CallV2ProductionDependency.startupBridge,
  CallV2ProductionDependency.runtime,
  CallV2ProductionDependency.rtcAdapter,
  CallV2ProductionDependency.productionComposition,
  CallV2ProductionDependency.observabilitySink,
  CallV2ProductionDependency.appIntegrationOwner,
];

final callV2ProductionDependencyOwnershipPlan =
    CallV2ProductionDependencyOwnershipPlan(
  items: callV2ProductionDependencyOwnershipItems,
  constructionOrder: callV2ProductionDependencyConstructionOrder,
  disposalOrder: callV2ProductionDependencyDisposalOrder,
);
