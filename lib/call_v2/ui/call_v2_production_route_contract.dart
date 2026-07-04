import 'call_v2_production_route_destination.dart';

abstract interface class CallV2ProductionRouteContract {
  String routeNameFor(CallV2ProductionRouteDestination destination);
}

final class CallV2FixedProductionRouteContract
    implements CallV2ProductionRouteContract {
  const CallV2FixedProductionRouteContract();

  @override
  String routeNameFor(CallV2ProductionRouteDestination destination) {
    return CallV2ProductionRouteNames.forDestination(destination);
  }
}
