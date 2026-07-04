import 'call_v2_production_presentation_snapshot.dart';
import 'call_v2_production_route_destination.dart';
import 'call_v2_ui_session_reference.dart';

class CallV2ProductionRouteDescriptor {
  factory CallV2ProductionRouteDescriptor.forDestination({
    required CallV2ProductionRouteDestination destination,
    required CallV2UiSessionReference? sessionReference,
    required int generation,
    required CallV2ProductionPresentationTerminalStatus terminalStatus,
  }) {
    if (!destination.isAvailable) {
      throw ArgumentError('Unavailable Call V2 destination.');
    }
    if (generation < 0) {
      throw ArgumentError('Invalid Call V2 presentation generation.');
    }
    return CallV2ProductionRouteDescriptor._(
      destination: destination,
      routeName: CallV2ProductionRouteNames.forDestination(destination),
      sessionReference: sessionReference,
      generation: generation,
      terminalStatus: terminalStatus,
    );
  }

  const CallV2ProductionRouteDescriptor._({
    required this.destination,
    required this.routeName,
    required this.sessionReference,
    required this.generation,
    required this.terminalStatus,
  });

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
