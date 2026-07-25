enum CallV2RuntimeDependencyKind {
  callSessionStore,
  tokenProvider,
  rtcAdapter,
  permissionAdapter,
  lifecycleAdapter,
  safeDiagnostics,
  clock,
  localUserIdentityProvider,
  remoteParticipantProvider,
}

class CallV2RuntimeDependencyRequirement {
  const CallV2RuntimeDependencyRequirement({
    required this.kind,
    required this.requiredForFakeFlow,
    required this.productionAllocated,
  });

  final CallV2RuntimeDependencyKind kind;
  final bool requiredForFakeFlow;
  final bool productionAllocated;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'kind': kind.name,
      'requiredForFakeFlow': requiredForFakeFlow,
      'productionAllocated': productionAllocated,
    };
  }
}

class CallV2RuntimeDependencyManifest {
  const CallV2RuntimeDependencyManifest({
    required List<CallV2RuntimeDependencyRequirement> requirements,
  }) : _requirements = requirements;

  static const developerOnly =
      CallV2RuntimeDependencyManifest(requirements: _developerRequirements);

  final List<CallV2RuntimeDependencyRequirement> _requirements;

  List<CallV2RuntimeDependencyRequirement> get requirements {
    return List<CallV2RuntimeDependencyRequirement>.unmodifiable(
      _requirements,
    );
  }

  bool get allocatesProductionDependencies {
    return _requirements.any((requirement) => requirement.productionAllocated);
  }

  Set<CallV2RuntimeDependencyKind> get requiredKinds {
    return _requirements.map((requirement) => requirement.kind).toSet();
  }

  bool get complete {
    return requiredKinds.containsAll(CallV2RuntimeDependencyKind.values);
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'requirementCount': _requirements.length,
      'complete': complete,
      'allocatesProductionDependencies': allocatesProductionDependencies,
    };
  }
}

const _developerRequirements = <CallV2RuntimeDependencyRequirement>[
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.callSessionStore,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.tokenProvider,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.rtcAdapter,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.permissionAdapter,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.lifecycleAdapter,
    requiredForFakeFlow: false,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.safeDiagnostics,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.clock,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.localUserIdentityProvider,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
  CallV2RuntimeDependencyRequirement(
    kind: CallV2RuntimeDependencyKind.remoteParticipantProvider,
    requiredForFakeFlow: true,
    productionAllocated: false,
  ),
];
