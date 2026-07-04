import 'call_v2_production_presentation_snapshot.dart';
import 'call_v2_production_route_destination.dart';
import 'call_v2_production_view_state.dart';
import 'call_v2_production_user_action.dart';

enum CallV2ProductionPresentationTransition {
  openConnecting,
  becomeActiveAudio,
  becomeActiveVideo,
  failControlled,
  cancel,
  leaveOrEnd,
  retry,
  dismiss,
}

class CallV2ProductionTransitionPolicy {
  const CallV2ProductionTransitionPolicy();

  bool canTransition({
    required CallV2ProductionPresentationSnapshot? from,
    required CallV2ProductionPresentationSnapshot to,
    required CallV2ProductionPresentationTransition transition,
  }) {
    if (from != null) {
      if (from.isTerminal) return false;
      if (to.generation < from.generation) return false;
    }
    if (to.destination ==
        CallV2ProductionRouteDestination.incomingReviewReserved) {
      return false;
    }

    final fromDestination = from?.destination;
    final toDestination = to.destination;
    if (fromDestination == null) {
      return transition ==
              CallV2ProductionPresentationTransition.openConnecting &&
          toDestination == CallV2ProductionRouteDestination.connecting;
    }

    return switch (fromDestination) {
      CallV2ProductionRouteDestination.connecting =>
        _canLeaveConnecting(toDestination, transition),
      CallV2ProductionRouteDestination.activeAudio =>
        _canLeaveActiveAudio(toDestination, transition),
      CallV2ProductionRouteDestination.activeVideo =>
        _canLeaveActiveVideo(toDestination, transition),
      CallV2ProductionRouteDestination.controlledFailure =>
        _canLeaveFailure(from!, toDestination, transition),
      CallV2ProductionRouteDestination.incomingReviewReserved => false,
    };
  }

  bool _canLeaveConnecting(
    CallV2ProductionRouteDestination? toDestination,
    CallV2ProductionPresentationTransition transition,
  ) {
    return switch (transition) {
      CallV2ProductionPresentationTransition.becomeActiveAudio =>
        toDestination == CallV2ProductionRouteDestination.activeAudio,
      CallV2ProductionPresentationTransition.becomeActiveVideo =>
        toDestination == CallV2ProductionRouteDestination.activeVideo,
      CallV2ProductionPresentationTransition.failControlled =>
        toDestination == CallV2ProductionRouteDestination.controlledFailure,
      CallV2ProductionPresentationTransition.cancel => toDestination == null,
      _ => false,
    };
  }

  bool _canLeaveActiveAudio(
    CallV2ProductionRouteDestination? toDestination,
    CallV2ProductionPresentationTransition transition,
  ) {
    return switch (transition) {
      CallV2ProductionPresentationTransition.failControlled =>
        toDestination == CallV2ProductionRouteDestination.controlledFailure,
      CallV2ProductionPresentationTransition.leaveOrEnd =>
        toDestination == null,
      _ => false,
    };
  }

  bool _canLeaveActiveVideo(
    CallV2ProductionRouteDestination? toDestination,
    CallV2ProductionPresentationTransition transition,
  ) {
    return switch (transition) {
      CallV2ProductionPresentationTransition.failControlled =>
        toDestination == CallV2ProductionRouteDestination.controlledFailure,
      CallV2ProductionPresentationTransition.leaveOrEnd =>
        toDestination == null,
      _ => false,
    };
  }

  bool _canLeaveFailure(
    CallV2ProductionPresentationSnapshot from,
    CallV2ProductionRouteDestination? toDestination,
    CallV2ProductionPresentationTransition transition,
  ) {
    final state = from.screenState;
    if (state is! CallV2ProductionControlledFailureScreenState) return false;
    return switch (transition) {
      CallV2ProductionPresentationTransition.retry =>
        toDestination == CallV2ProductionRouteDestination.connecting &&
            from.allowedActions.contains(
              CallV2ProductionUserAction.retryControlledFailure,
            ),
      CallV2ProductionPresentationTransition.dismiss => toDestination == null &&
          from.allowedActions.contains(
            CallV2ProductionUserAction.dismissControlledFailure,
          ),
      _ => false,
    };
  }
}
