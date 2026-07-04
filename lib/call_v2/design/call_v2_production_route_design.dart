enum CallV2ProductionRouteDestination {
  connecting,
  activeAudio,
  activeVideo,
  controlledFailure,
  incomingReview,
}

enum CallV2ProductionRouteArgumentPolicy {
  typedSessionReferenceOnly,
  noArbitraryMap,
  noCredentialPayload,
  noIdentifierInRouteName,
}

enum CallV2ProductionRoutePrecedencePolicy {
  existingAppRoutesFirst,
  callV2RoutesBehindGates,
  unknownRouteUnchanged,
  v1RouteOwnershipUnchanged,
}

enum CallV2ProductionScreenResponsibility {
  genericConnectingState,
  cancelAction,
  mute,
  speaker,
  cameraToggle,
  cameraSwitch,
  leave,
  sanitizedDuration,
  connectionStatus,
  localRenderingBoundary,
  remoteRenderingBoundary,
  lifecycleSafeRendering,
  controlledErrorOnly,
  retryOnlyWhenCoordinatorAllows,
}

class CallV2ProductionRouteSpec {
  const CallV2ProductionRouteSpec({
    required this.destination,
    required this.name,
    required this.argumentPolicies,
    required this.precedencePolicies,
  });

  final CallV2ProductionRouteDestination destination;
  final String name;
  final List<CallV2ProductionRouteArgumentPolicy> argumentPolicies;
  final List<CallV2ProductionRoutePrecedencePolicy> precedencePolicies;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'destination': destination.name,
      'name': name,
      'argumentPolicies':
          argumentPolicies.map((policy) => policy.name).toList(),
      'precedencePolicies':
          precedencePolicies.map((policy) => policy.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteSpec(${toSafeDebugMap()})';
  }
}

class CallV2ProductionScreenSpec {
  const CallV2ProductionScreenSpec({
    required this.destination,
    required this.responsibilities,
    required this.disallowedDetails,
  });

  final CallV2ProductionRouteDestination destination;
  final List<CallV2ProductionScreenResponsibility> responsibilities;
  final List<CallV2ProductionScreenDisallowedDetail> disallowedDetails;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'destination': destination.name,
      'responsibilities': responsibilities
          .map((responsibility) => responsibility.name)
          .toList(),
      'disallowedDetails':
          disallowedDetails.map((detail) => detail.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionScreenSpec(${toSafeDebugMap()})';
  }
}

enum CallV2ProductionScreenDisallowedDetail {
  rawIdentifier,
  providerDetail,
  credentialValue,
  channelValue,
  rawException,
}

enum CallV2ProductionRouteSinkPolicy {
  injectedAppOwnedNavigationAccess,
  noGlobalMutableSingleton,
  noArbitraryRouteStrings,
  trackOwnedRoutes,
  removeOnlyOwnedCallRoutes,
  preserveHostAndUnrelatedRoutes,
  serializeNavigation,
  disposalInvalidatesQueue,
  missingNavigationAccessReturnsControlledError,
  inactiveAppDefersNonCriticalNavigation,
  noNotificationOrDeepLinkHandling,
}

class CallV2ProductionRouteDesign {
  factory CallV2ProductionRouteDesign({
    required List<CallV2ProductionRouteSpec> routes,
    required List<CallV2ProductionScreenSpec> screens,
    required List<CallV2ProductionRouteSinkPolicy> routeSinkPolicies,
  }) {
    return CallV2ProductionRouteDesign._(
      List<CallV2ProductionRouteSpec>.unmodifiable(routes),
      List<CallV2ProductionScreenSpec>.unmodifiable(screens),
      List<CallV2ProductionRouteSinkPolicy>.unmodifiable(routeSinkPolicies),
    );
  }

  const CallV2ProductionRouteDesign._(
    this.routes,
    this.screens,
    this.routeSinkPolicies,
  );

  final List<CallV2ProductionRouteSpec> routes;
  final List<CallV2ProductionScreenSpec> screens;
  final List<CallV2ProductionRouteSinkPolicy> routeSinkPolicies;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'routes': routes.map((route) => route.toSafeDebugMap()).toList(),
      'screens': screens.map((screen) => screen.toSafeDebugMap()).toList(),
      'routeSinkPolicies':
          routeSinkPolicies.map((policy) => policy.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteDesign(${toSafeDebugMap()})';
  }
}

const _callV2RouteArgumentPolicies = <CallV2ProductionRouteArgumentPolicy>[
  CallV2ProductionRouteArgumentPolicy.typedSessionReferenceOnly,
  CallV2ProductionRouteArgumentPolicy.noArbitraryMap,
  CallV2ProductionRouteArgumentPolicy.noCredentialPayload,
  CallV2ProductionRouteArgumentPolicy.noIdentifierInRouteName,
];

const _callV2RoutePrecedencePolicies = <CallV2ProductionRoutePrecedencePolicy>[
  CallV2ProductionRoutePrecedencePolicy.existingAppRoutesFirst,
  CallV2ProductionRoutePrecedencePolicy.callV2RoutesBehindGates,
  CallV2ProductionRoutePrecedencePolicy.unknownRouteUnchanged,
  CallV2ProductionRoutePrecedencePolicy.v1RouteOwnershipUnchanged,
];

const callV2ProductionRouteSpecs = <CallV2ProductionRouteSpec>[
  CallV2ProductionRouteSpec(
    destination: CallV2ProductionRouteDestination.connecting,
    name: '/call-v2/connecting',
    argumentPolicies: _callV2RouteArgumentPolicies,
    precedencePolicies: _callV2RoutePrecedencePolicies,
  ),
  CallV2ProductionRouteSpec(
    destination: CallV2ProductionRouteDestination.activeAudio,
    name: '/call-v2/active-audio',
    argumentPolicies: _callV2RouteArgumentPolicies,
    precedencePolicies: _callV2RoutePrecedencePolicies,
  ),
  CallV2ProductionRouteSpec(
    destination: CallV2ProductionRouteDestination.activeVideo,
    name: '/call-v2/active-video',
    argumentPolicies: _callV2RouteArgumentPolicies,
    precedencePolicies: _callV2RoutePrecedencePolicies,
  ),
  CallV2ProductionRouteSpec(
    destination: CallV2ProductionRouteDestination.controlledFailure,
    name: '/call-v2/unavailable',
    argumentPolicies: _callV2RouteArgumentPolicies,
    precedencePolicies: _callV2RoutePrecedencePolicies,
  ),
  CallV2ProductionRouteSpec(
    destination: CallV2ProductionRouteDestination.incomingReview,
    name: '/call-v2/incoming-review',
    argumentPolicies: _callV2RouteArgumentPolicies,
    precedencePolicies: _callV2RoutePrecedencePolicies,
  ),
];

const callV2ProductionScreenSpecs = <CallV2ProductionScreenSpec>[
  CallV2ProductionScreenSpec(
    destination: CallV2ProductionRouteDestination.connecting,
    responsibilities: <CallV2ProductionScreenResponsibility>[
      CallV2ProductionScreenResponsibility.genericConnectingState,
      CallV2ProductionScreenResponsibility.cancelAction,
    ],
    disallowedDetails: <CallV2ProductionScreenDisallowedDetail>[
      CallV2ProductionScreenDisallowedDetail.rawIdentifier,
      CallV2ProductionScreenDisallowedDetail.providerDetail,
      CallV2ProductionScreenDisallowedDetail.credentialValue,
    ],
  ),
  CallV2ProductionScreenSpec(
    destination: CallV2ProductionRouteDestination.activeAudio,
    responsibilities: <CallV2ProductionScreenResponsibility>[
      CallV2ProductionScreenResponsibility.mute,
      CallV2ProductionScreenResponsibility.speaker,
      CallV2ProductionScreenResponsibility.leave,
      CallV2ProductionScreenResponsibility.sanitizedDuration,
      CallV2ProductionScreenResponsibility.connectionStatus,
    ],
    disallowedDetails: <CallV2ProductionScreenDisallowedDetail>[
      CallV2ProductionScreenDisallowedDetail.rawIdentifier,
      CallV2ProductionScreenDisallowedDetail.channelValue,
      CallV2ProductionScreenDisallowedDetail.credentialValue,
    ],
  ),
  CallV2ProductionScreenSpec(
    destination: CallV2ProductionRouteDestination.activeVideo,
    responsibilities: <CallV2ProductionScreenResponsibility>[
      CallV2ProductionScreenResponsibility.mute,
      CallV2ProductionScreenResponsibility.cameraToggle,
      CallV2ProductionScreenResponsibility.cameraSwitch,
      CallV2ProductionScreenResponsibility.leave,
      CallV2ProductionScreenResponsibility.localRenderingBoundary,
      CallV2ProductionScreenResponsibility.remoteRenderingBoundary,
      CallV2ProductionScreenResponsibility.lifecycleSafeRendering,
    ],
    disallowedDetails: <CallV2ProductionScreenDisallowedDetail>[
      CallV2ProductionScreenDisallowedDetail.rawIdentifier,
      CallV2ProductionScreenDisallowedDetail.channelValue,
      CallV2ProductionScreenDisallowedDetail.credentialValue,
    ],
  ),
  CallV2ProductionScreenSpec(
    destination: CallV2ProductionRouteDestination.controlledFailure,
    responsibilities: <CallV2ProductionScreenResponsibility>[
      CallV2ProductionScreenResponsibility.controlledErrorOnly,
      CallV2ProductionScreenResponsibility.retryOnlyWhenCoordinatorAllows,
    ],
    disallowedDetails: <CallV2ProductionScreenDisallowedDetail>[
      CallV2ProductionScreenDisallowedDetail.rawIdentifier,
      CallV2ProductionScreenDisallowedDetail.providerDetail,
      CallV2ProductionScreenDisallowedDetail.rawException,
    ],
  ),
  CallV2ProductionScreenSpec(
    destination: CallV2ProductionRouteDestination.incomingReview,
    responsibilities: <CallV2ProductionScreenResponsibility>[
      CallV2ProductionScreenResponsibility.genericConnectingState,
      CallV2ProductionScreenResponsibility.cancelAction,
    ],
    disallowedDetails: <CallV2ProductionScreenDisallowedDetail>[
      CallV2ProductionScreenDisallowedDetail.rawIdentifier,
      CallV2ProductionScreenDisallowedDetail.providerDetail,
      CallV2ProductionScreenDisallowedDetail.credentialValue,
    ],
  ),
];

const callV2ProductionRouteSinkPolicies = <CallV2ProductionRouteSinkPolicy>[
  CallV2ProductionRouteSinkPolicy.injectedAppOwnedNavigationAccess,
  CallV2ProductionRouteSinkPolicy.noGlobalMutableSingleton,
  CallV2ProductionRouteSinkPolicy.noArbitraryRouteStrings,
  CallV2ProductionRouteSinkPolicy.trackOwnedRoutes,
  CallV2ProductionRouteSinkPolicy.removeOnlyOwnedCallRoutes,
  CallV2ProductionRouteSinkPolicy.preserveHostAndUnrelatedRoutes,
  CallV2ProductionRouteSinkPolicy.serializeNavigation,
  CallV2ProductionRouteSinkPolicy.disposalInvalidatesQueue,
  CallV2ProductionRouteSinkPolicy.missingNavigationAccessReturnsControlledError,
  CallV2ProductionRouteSinkPolicy.inactiveAppDefersNonCriticalNavigation,
  CallV2ProductionRouteSinkPolicy.noNotificationOrDeepLinkHandling,
];

final callV2ProductionRouteDesign = CallV2ProductionRouteDesign(
  routes: callV2ProductionRouteSpecs,
  screens: callV2ProductionScreenSpecs,
  routeSinkPolicies: callV2ProductionRouteSinkPolicies,
);
