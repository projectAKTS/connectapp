import 'call_v2_production_presentation_snapshot.dart';
import 'call_v2_production_route_destination.dart';
import 'call_v2_ui_session_reference.dart';

class CallV2ProductionRouteDescriptor {
  const CallV2ProductionRouteDescriptor({
    required this.destination,
    required this.routeName,
    required this.sessionReference,
    required this.generation,
    required this.terminalStatus,
  }) : assert(generation >= 0);

  final CallV2ProductionRouteDestination destination;
  final String routeName;
  final CallV2UiSessionReference? sessionReference;
  final int generation;
  final CallV2ProductionPresentationTerminalStatus terminalStatus;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'destination': destination.name,
      'routeName': routeName,
      'hasSessionReference': sessionReference != null,
      'generation': generation,
      'terminalStatus': terminalStatus.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionRouteDescriptor(${toSafeDebugMap()})';
  }
}
