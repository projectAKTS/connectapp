enum CallV2ProductionRouteDestination {
  connecting,
  activeAudio,
  activeVideo,
  controlledFailure,
  incomingReviewReserved,
}

extension CallV2ProductionRouteDestinationAvailability
    on CallV2ProductionRouteDestination {
  bool get isAvailable {
    return switch (this) {
      CallV2ProductionRouteDestination.connecting => true,
      CallV2ProductionRouteDestination.activeAudio => true,
      CallV2ProductionRouteDestination.activeVideo => true,
      CallV2ProductionRouteDestination.controlledFailure => true,
      CallV2ProductionRouteDestination.incomingReviewReserved => false,
    };
  }
}

class CallV2ProductionRouteNames {
  const CallV2ProductionRouteNames._();

  static const String connecting = '/call-v2/connecting';
  static const String activeAudio = '/call-v2/audio';
  static const String activeVideo = '/call-v2/video';
  static const String controlledFailure = '/call-v2/failure';

  static String forDestination(CallV2ProductionRouteDestination destination) {
    return switch (destination) {
      CallV2ProductionRouteDestination.connecting => connecting,
      CallV2ProductionRouteDestination.activeAudio => activeAudio,
      CallV2ProductionRouteDestination.activeVideo => activeVideo,
      CallV2ProductionRouteDestination.controlledFailure => controlledFailure,
      CallV2ProductionRouteDestination.incomingReviewReserved =>
        throw ArgumentError('Reserved Call V2 destination.'),
    };
  }
}
