import 'call_v2_production_route_destination.dart';
import 'call_v2_production_view_state.dart';
import 'call_v2_production_user_action.dart';
import 'call_v2_ui_session_reference.dart';

enum CallV2ProductionPresentationTerminalStatus {
  nonterminal,
  terminalDisposed,
}

class CallV2ProductionPresentationSnapshot {
  factory CallV2ProductionPresentationSnapshot.none({
    required int generation,
    CallV2ProductionPresentationTerminalStatus terminalStatus =
        CallV2ProductionPresentationTerminalStatus.nonterminal,
  }) {
    return CallV2ProductionPresentationSnapshot._(
      destination: null,
      sessionReference: null,
      screenState: null,
      allowedActions: const <CallV2ProductionUserAction>{},
      generation: generation,
      terminalStatus: terminalStatus,
    );
  }

  factory CallV2ProductionPresentationSnapshot.connecting({
    required CallV2UiSessionReference sessionReference,
    required CallV2ProductionConnectingScreenState screenState,
  }) {
    return CallV2ProductionPresentationSnapshot._forDestination(
      destination: CallV2ProductionRouteDestination.connecting,
      sessionReference: sessionReference,
      screenState: screenState,
    );
  }

  factory CallV2ProductionPresentationSnapshot.activeAudio({
    required CallV2UiSessionReference sessionReference,
    required CallV2ProductionActiveAudioScreenState screenState,
  }) {
    return CallV2ProductionPresentationSnapshot._forDestination(
      destination: CallV2ProductionRouteDestination.activeAudio,
      sessionReference: sessionReference,
      screenState: screenState,
    );
  }

  factory CallV2ProductionPresentationSnapshot.activeVideo({
    required CallV2UiSessionReference sessionReference,
    required CallV2ProductionActiveVideoScreenState screenState,
  }) {
    return CallV2ProductionPresentationSnapshot._forDestination(
      destination: CallV2ProductionRouteDestination.activeVideo,
      sessionReference: sessionReference,
      screenState: screenState,
    );
  }

  factory CallV2ProductionPresentationSnapshot.controlledFailure({
    required CallV2UiSessionReference? sessionReference,
    required CallV2ProductionControlledFailureScreenState screenState,
  }) {
    final generation = sessionReference?.generation ?? 0;
    return CallV2ProductionPresentationSnapshot._(
      destination: CallV2ProductionRouteDestination.controlledFailure,
      sessionReference: sessionReference,
      screenState: screenState,
      allowedActions: callV2ProductionActionsFor(
        destination: CallV2ProductionRouteDestination.controlledFailure,
        state: screenState,
      ),
      generation: generation,
      terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
    );
  }

  factory CallV2ProductionPresentationSnapshot.reservedIncomingReview({
    required int generation,
  }) {
    throw ArgumentError('Reserved Call V2 destination.');
  }

  factory CallV2ProductionPresentationSnapshot._forDestination({
    required CallV2ProductionRouteDestination destination,
    required CallV2UiSessionReference sessionReference,
    required CallV2ProductionScreenState screenState,
  }) {
    _validateDestinationState(destination, screenState);
    return CallV2ProductionPresentationSnapshot._(
      destination: destination,
      sessionReference: sessionReference,
      screenState: screenState,
      allowedActions: callV2ProductionActionsFor(
        destination: destination,
        state: screenState,
      ),
      generation: sessionReference.generation,
      terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
    );
  }

  const CallV2ProductionPresentationSnapshot._({
    required this.destination,
    required this.sessionReference,
    required this.screenState,
    required this.allowedActions,
    required this.generation,
    required this.terminalStatus,
  }) : assert(generation >= 0);

  final CallV2ProductionRouteDestination? destination;
  final CallV2UiSessionReference? sessionReference;
  final CallV2ProductionScreenState? screenState;
  final Set<CallV2ProductionUserAction> allowedActions;
  final int generation;
  final CallV2ProductionPresentationTerminalStatus terminalStatus;

  bool get isTerminal {
    return terminalStatus ==
        CallV2ProductionPresentationTerminalStatus.terminalDisposed;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'destination': destination?.name,
      'sessionReference': sessionReference?.toSafeDebugMap(),
      'screenState': screenState?.toSafeDebugMap(),
      'allowedActions': allowedActions.map((action) => action.name).toList(),
      'generation': generation,
      'terminalStatus': terminalStatus.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionPresentationSnapshot(${toSafeDebugMap()})';
  }
}

void _validateDestinationState(
  CallV2ProductionRouteDestination destination,
  CallV2ProductionScreenState state,
) {
  final valid = switch (destination) {
    CallV2ProductionRouteDestination.connecting =>
      state is CallV2ProductionConnectingScreenState,
    CallV2ProductionRouteDestination.activeAudio =>
      state is CallV2ProductionActiveAudioScreenState,
    CallV2ProductionRouteDestination.activeVideo =>
      state is CallV2ProductionActiveVideoScreenState,
    CallV2ProductionRouteDestination.controlledFailure =>
      state is CallV2ProductionControlledFailureScreenState,
    CallV2ProductionRouteDestination.incomingReviewReserved => false,
  };
  if (!valid) {
    throw ArgumentError('Incompatible Call V2 presentation state.');
  }
}
