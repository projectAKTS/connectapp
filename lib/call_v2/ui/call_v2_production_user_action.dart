import 'call_v2_production_route_destination.dart';
import 'call_v2_production_view_state.dart';

enum CallV2ProductionUserAction {
  cancelConnecting,
  toggleMute,
  toggleSpeaker,
  toggleCamera,
  switchCamera,
  leave,
  retryControlledFailure,
  dismissControlledFailure,
}

Set<CallV2ProductionUserAction> callV2ProductionActionsFor({
  required CallV2ProductionRouteDestination destination,
  required CallV2ProductionScreenState? state,
}) {
  final actions = switch (destination) {
    CallV2ProductionRouteDestination.connecting =>
      state is CallV2ProductionConnectingScreenState && state.cancelAvailable
          ? <CallV2ProductionUserAction>{
              CallV2ProductionUserAction.cancelConnecting,
            }
          : <CallV2ProductionUserAction>{},
    CallV2ProductionRouteDestination.activeAudio =>
      state is CallV2ProductionActiveAudioScreenState && state.leaveEnabled
          ? <CallV2ProductionUserAction>{
              CallV2ProductionUserAction.toggleMute,
              CallV2ProductionUserAction.toggleSpeaker,
              CallV2ProductionUserAction.leave,
            }
          : <CallV2ProductionUserAction>{},
    CallV2ProductionRouteDestination.activeVideo =>
      state is CallV2ProductionActiveVideoScreenState && state.leaveEnabled
          ? <CallV2ProductionUserAction>{
              CallV2ProductionUserAction.toggleMute,
              CallV2ProductionUserAction.toggleCamera,
              if (state.cameraSwitchAvailable)
                CallV2ProductionUserAction.switchCamera,
              CallV2ProductionUserAction.leave,
            }
          : <CallV2ProductionUserAction>{},
    CallV2ProductionRouteDestination.controlledFailure =>
      state is CallV2ProductionControlledFailureScreenState
          ? <CallV2ProductionUserAction>{
              if (state.retryPolicy ==
                  CallV2ProductionFailureRetryPolicy.retryAllowed)
                CallV2ProductionUserAction.retryControlledFailure,
              if (state.dismissPolicy ==
                  CallV2ProductionFailureDismissPolicy.dismissAllowed)
                CallV2ProductionUserAction.dismissControlledFailure,
            }
          : <CallV2ProductionUserAction>{},
    CallV2ProductionRouteDestination.incomingReviewReserved =>
      <CallV2ProductionUserAction>{},
  };
  return Set<CallV2ProductionUserAction>.unmodifiable(actions);
}
