import 'call_v2_production_mapping_result.dart';
import 'call_v2_production_presentation_snapshot.dart';
import 'call_v2_production_route_contract.dart';
import 'call_v2_production_route_descriptor.dart';
import 'call_v2_production_route_destination.dart';
import 'call_v2_production_view_state.dart';

class CallV2ProductionRouteFactory {
  const CallV2ProductionRouteFactory({
    CallV2ProductionRouteContract routeContract =
        const CallV2FixedProductionRouteContract(),
  }) : _routeContract = routeContract;

  final CallV2ProductionRouteContract _routeContract;

  CallV2ProductionMappingResult<CallV2ProductionRouteDescriptor>
      createDescriptor(
    CallV2ProductionPresentationSnapshot snapshot, {
    int minimumGeneration = 0,
  }) {
    if (minimumGeneration < 0 || snapshot.generation < 0) {
      return const CallV2ProductionMappingResult.rejected(
        CallV2ProductionMappingError.invalidInput,
      );
    }
    if (snapshot.generation < minimumGeneration) {
      return const CallV2ProductionMappingResult.rejected(
        CallV2ProductionMappingError.staleGeneration,
      );
    }
    if (snapshot.isTerminal || snapshot.destination == null) {
      return CallV2ProductionMappingResult.noRoute(null);
    }

    final destination = snapshot.destination!;
    if (!destination.isAvailable ||
        destination ==
            CallV2ProductionRouteDestination.incomingReviewReserved) {
      return const CallV2ProductionMappingResult.rejected(
        CallV2ProductionMappingError.reservedDestination,
      );
    }
    if (!_snapshotDestinationMatchesState(snapshot)) {
      return const CallV2ProductionMappingResult.rejected(
        CallV2ProductionMappingError.invalidInput,
      );
    }

    final expectedRouteName =
        CallV2ProductionRouteNames.forDestination(destination);
    final candidateRouteName = _routeContract.routeNameFor(destination);
    if (candidateRouteName != expectedRouteName) {
      return const CallV2ProductionMappingResult.rejected(
        CallV2ProductionMappingError.invalidRouteName,
      );
    }

    return CallV2ProductionMappingResult.success(
      CallV2ProductionRouteDescriptor.forDestination(
        destination: destination,
        sessionReference: snapshot.sessionReference,
        generation: snapshot.generation,
        terminalStatus: snapshot.terminalStatus,
      ),
    );
  }

  bool _snapshotDestinationMatchesState(
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    return switch (snapshot.destination) {
      CallV2ProductionRouteDestination.connecting =>
        snapshot.screenState is CallV2ProductionConnectingScreenState,
      CallV2ProductionRouteDestination.activeAudio =>
        snapshot.screenState is CallV2ProductionActiveAudioScreenState,
      CallV2ProductionRouteDestination.activeVideo =>
        snapshot.screenState is CallV2ProductionActiveVideoScreenState,
      CallV2ProductionRouteDestination.controlledFailure =>
        snapshot.screenState is CallV2ProductionControlledFailureScreenState,
      CallV2ProductionRouteDestination.incomingReviewReserved => false,
      null => true,
    };
  }
}
