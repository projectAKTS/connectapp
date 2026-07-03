import 'package:flutter/widgets.dart';

import 'call_v2_route_registry.dart';

final class DisabledCallV2RouteRegistry implements CallV2RouteRegistry {
  const DisabledCallV2RouteRegistry();

  @override
  Route<dynamic>? resolve(RouteSettings settings) {
    return null;
  }
}
