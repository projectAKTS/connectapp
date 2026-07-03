import 'package:flutter/widgets.dart';

import 'call_v2_rollout_policy.dart';
import 'disabled_call_v2_route_registry.dart';

abstract interface class CallV2RouteRegistry {
  Route<dynamic>? resolve(RouteSettings settings);
}

class CallV2RouteNames {
  const CallV2RouteNames._();

  static const String connecting = '/call-v2/connecting';
  static const String ready = '/call-v2/ready';
}

Route<dynamic>? resolveCallV2Route(RouteSettings settings) {
  if (!CallV2RolloutPolicy.productionEnabled) return null;

  return const DisabledCallV2RouteRegistry().resolve(settings);
}
