import 'package:flutter/widgets.dart';

import '../ui/call_v2_production_route_destination.dart';
import 'call_v2_rollout_policy.dart';
import 'disabled_call_v2_route_registry.dart';

abstract interface class CallV2RouteRegistry {
  Route<dynamic>? resolve(RouteSettings settings);
}

class CallV2RouteNames {
  const CallV2RouteNames._();

  static const String connecting = CallV2ProductionRouteNames.connecting;
  static const String activeAudio = CallV2ProductionRouteNames.activeAudio;
  static const String activeVideo = CallV2ProductionRouteNames.activeVideo;
  static const String controlledFailure =
      CallV2ProductionRouteNames.controlledFailure;

  static const Set<String> production = <String>{
    connecting,
    activeAudio,
    activeVideo,
    controlledFailure,
  };

  @Deprecated('Legacy non-production harness route. Not a production route.')
  static const String ready = '/call-v2/ready';
}

Route<dynamic>? resolveCallV2Route(RouteSettings settings) {
  if (!CallV2RolloutPolicy.productionEnabled) return null;

  return const DisabledCallV2RouteRegistry().resolve(settings);
}
