enum CallV2ContractVersion {
  v2Phase3,
  unsupported,
}

enum CallV2ContractNode {
  runtime,
  subscriptionCoordinator,
  harness,
  mediaOrchestrator,
  resolver,
  mediaController,
  rtcAdapter,
  firestore,
  firebaseAuth,
  firebaseFunctions,
  rtcProviderTransport,
  ui,
  startup,
}

class CallV2ContractEdge {
  const CallV2ContractEdge({
    required this.from,
    required this.to,
  });

  final CallV2ContractNode from;
  final CallV2ContractNode to;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'from': from.name,
      'to': to.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CallV2ContractEdge && other.from == from && other.to == to;
  }

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() {
    return 'CallV2ContractEdge(${toSafeDebugMap()})';
  }
}

class CallV2ContractManifest {
  const CallV2ContractManifest({
    required this.version,
    required this.featureGateDefaultsDisabled,
    required this.runtimeConstructionSideEffectFree,
    required this.runtimeStartDoesNotStartMedia,
    required this.lifecycleSnapshotAuthoritative,
    required this.subscriptionCoordinatorOwnsFirestoreSubscriptionFlow,
    required this.runtimeOwnsTopLevelStartStopSequencing,
    required this.orchestratorOwnsSnapshotToMediaSequencing,
    required this.resolverOwnsConfigResolution,
    required this.mediaControllerOwnsRtcAdapterCalls,
    required this.terminalSnapshotOwnsMediaCleanup,
    required this.duplicateOperationsShareInFlightWork,
    required this.generationAndOperationIdentityProtectStaleCompletion,
    required this.rawCredentialsNeverAppearInPublicState,
    required this.productionAdaptersAbsent,
    required this.startupUiRoutesNativeWiringAbsent,
    required this.allowedDependencyEdges,
    required this.forbiddenDependencyEdges,
  });

  final CallV2ContractVersion version;
  final bool featureGateDefaultsDisabled;
  final bool runtimeConstructionSideEffectFree;
  final bool runtimeStartDoesNotStartMedia;
  final bool lifecycleSnapshotAuthoritative;
  final bool subscriptionCoordinatorOwnsFirestoreSubscriptionFlow;
  final bool runtimeOwnsTopLevelStartStopSequencing;
  final bool orchestratorOwnsSnapshotToMediaSequencing;
  final bool resolverOwnsConfigResolution;
  final bool mediaControllerOwnsRtcAdapterCalls;
  final bool terminalSnapshotOwnsMediaCleanup;
  final bool duplicateOperationsShareInFlightWork;
  final bool generationAndOperationIdentityProtectStaleCompletion;
  final bool rawCredentialsNeverAppearInPublicState;
  final bool productionAdaptersAbsent;
  final bool startupUiRoutesNativeWiringAbsent;
  final List<CallV2ContractEdge> allowedDependencyEdges;
  final List<CallV2ContractEdge> forbiddenDependencyEdges;

  bool get hasAcceptedVersion => version == CallV2ContractVersion.v2Phase3;

  bool get hasRequiredPhase3Invariants {
    return featureGateDefaultsDisabled &&
        runtimeConstructionSideEffectFree &&
        runtimeStartDoesNotStartMedia &&
        lifecycleSnapshotAuthoritative &&
        subscriptionCoordinatorOwnsFirestoreSubscriptionFlow &&
        runtimeOwnsTopLevelStartStopSequencing &&
        orchestratorOwnsSnapshotToMediaSequencing &&
        resolverOwnsConfigResolution &&
        mediaControllerOwnsRtcAdapterCalls &&
        terminalSnapshotOwnsMediaCleanup &&
        duplicateOperationsShareInFlightWork &&
        generationAndOperationIdentityProtectStaleCompletion &&
        rawCredentialsNeverAppearInPublicState &&
        productionAdaptersAbsent &&
        startupUiRoutesNativeWiringAbsent &&
        _containsAllEdges(
            allowedDependencyEdges, callV2AllowedDependencyEdges) &&
        _containsAllEdges(
          forbiddenDependencyEdges,
          callV2ForbiddenDependencyEdges,
        );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'version': version.name,
      'featureGateDefaultsDisabled': featureGateDefaultsDisabled,
      'runtimeConstructionSideEffectFree': runtimeConstructionSideEffectFree,
      'runtimeStartDoesNotStartMedia': runtimeStartDoesNotStartMedia,
      'lifecycleSnapshotAuthoritative': lifecycleSnapshotAuthoritative,
      'subscriptionCoordinatorOwnsFirestoreSubscriptionFlow':
          subscriptionCoordinatorOwnsFirestoreSubscriptionFlow,
      'runtimeOwnsTopLevelStartStopSequencing':
          runtimeOwnsTopLevelStartStopSequencing,
      'orchestratorOwnsSnapshotToMediaSequencing':
          orchestratorOwnsSnapshotToMediaSequencing,
      'resolverOwnsConfigResolution': resolverOwnsConfigResolution,
      'mediaControllerOwnsRtcAdapterCalls': mediaControllerOwnsRtcAdapterCalls,
      'terminalSnapshotOwnsMediaCleanup': terminalSnapshotOwnsMediaCleanup,
      'duplicateOperationsShareInFlightWork':
          duplicateOperationsShareInFlightWork,
      'generationAndOperationIdentityProtectStaleCompletion':
          generationAndOperationIdentityProtectStaleCompletion,
      'rawCredentialsNeverAppearInPublicState':
          rawCredentialsNeverAppearInPublicState,
      'productionAdaptersAbsent': productionAdaptersAbsent,
      'startupUiRoutesNativeWiringAbsent': startupUiRoutesNativeWiringAbsent,
      'allowedDependencyEdges':
          allowedDependencyEdges.map((edge) => edge.toSafeDebugMap()).toList(),
      'forbiddenDependencyEdges': forbiddenDependencyEdges
          .map((edge) => edge.toSafeDebugMap())
          .toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ContractManifest(${toSafeDebugMap()})';
  }
}

const callV2AllowedDependencyEdges = <CallV2ContractEdge>[
  CallV2ContractEdge(
    from: CallV2ContractNode.runtime,
    to: CallV2ContractNode.subscriptionCoordinator,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.subscriptionCoordinator,
    to: CallV2ContractNode.harness,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.runtime,
    to: CallV2ContractNode.mediaOrchestrator,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.mediaOrchestrator,
    to: CallV2ContractNode.resolver,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.resolver,
    to: CallV2ContractNode.mediaController,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.mediaController,
    to: CallV2ContractNode.rtcAdapter,
  ),
];

const callV2ForbiddenDependencyEdges = <CallV2ContractEdge>[
  CallV2ContractEdge(
    from: CallV2ContractNode.runtime,
    to: CallV2ContractNode.firestore,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.runtime,
    to: CallV2ContractNode.firebaseAuth,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.runtime,
    to: CallV2ContractNode.firebaseFunctions,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.runtime,
    to: CallV2ContractNode.rtcProviderTransport,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.runtime,
    to: CallV2ContractNode.rtcAdapter,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.mediaOrchestrator,
    to: CallV2ContractNode.firestore,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.resolver,
    to: CallV2ContractNode.rtcAdapter,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.mediaController,
    to: CallV2ContractNode.firestore,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.ui,
    to: CallV2ContractNode.rtcAdapter,
  ),
  CallV2ContractEdge(
    from: CallV2ContractNode.startup,
    to: CallV2ContractNode.rtcAdapter,
  ),
];

const callV2Phase3ContractManifest = CallV2ContractManifest(
  version: CallV2ContractVersion.v2Phase3,
  featureGateDefaultsDisabled: true,
  runtimeConstructionSideEffectFree: true,
  runtimeStartDoesNotStartMedia: true,
  lifecycleSnapshotAuthoritative: true,
  subscriptionCoordinatorOwnsFirestoreSubscriptionFlow: true,
  runtimeOwnsTopLevelStartStopSequencing: true,
  orchestratorOwnsSnapshotToMediaSequencing: true,
  resolverOwnsConfigResolution: true,
  mediaControllerOwnsRtcAdapterCalls: true,
  terminalSnapshotOwnsMediaCleanup: true,
  duplicateOperationsShareInFlightWork: true,
  generationAndOperationIdentityProtectStaleCompletion: true,
  rawCredentialsNeverAppearInPublicState: true,
  productionAdaptersAbsent: true,
  startupUiRoutesNativeWiringAbsent: true,
  allowedDependencyEdges: callV2AllowedDependencyEdges,
  forbiddenDependencyEdges: callV2ForbiddenDependencyEdges,
);

bool _containsAllEdges(
  List<CallV2ContractEdge> actual,
  List<CallV2ContractEdge> expected,
) {
  for (final edge in expected) {
    if (!actual.contains(edge)) return false;
  }
  return true;
}
