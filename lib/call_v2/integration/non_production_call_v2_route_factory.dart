import 'package:flutter/material.dart';

import 'call_v2_route_factory.dart';
import 'non_production/non_production_call_v2_connecting_placeholder.dart';
import 'non_production/non_production_call_v2_failure_placeholder.dart';
import 'non_production/non_production_call_v2_ready_placeholder.dart';

final class NonProductionCallV2RouteFactory implements CallV2RouteFactory {
  const NonProductionCallV2RouteFactory();

  @override
  Route<dynamic> create(CallV2RouteDestination destination) {
    return switch (destination) {
      CallV2ConnectingRouteDestination() => MaterialPageRoute<dynamic>(
          settings: const RouteSettings(
            name: CallV2RouteFactoryNames.connecting,
          ),
          builder: (_) => const NonProductionCallV2ConnectingPlaceholder(),
        ),
      CallV2ReadyRouteDestination() => MaterialPageRoute<dynamic>(
          settings: const RouteSettings(name: CallV2RouteFactoryNames.ready),
          builder: (_) => const NonProductionCallV2ReadyPlaceholder(),
        ),
      CallV2ControlledFailureRouteDestination(:final errorCode) =>
        MaterialPageRoute<dynamic>(
          settings: const RouteSettings(
            name: CallV2RouteFactoryNames.controlledFailure,
          ),
          builder: (_) => NonProductionCallV2FailurePlaceholder(
            errorCode: errorCode,
          ),
        ),
    };
  }
}
