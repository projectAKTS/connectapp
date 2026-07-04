import 'call_v2_active_audio_view_model.dart';
import 'call_v2_active_video_view_model.dart';
import 'call_v2_connecting_view_model.dart';
import 'call_v2_controlled_failure_view_model.dart';
import 'call_v2_production_presentation_snapshot.dart';
import 'call_v2_production_route_destination.dart';
import 'call_v2_production_user_action.dart';
import 'call_v2_production_view_model_result.dart';
import 'call_v2_production_view_state.dart';

sealed class CallV2ProductionViewModel {
  const CallV2ProductionViewModel();

  Map<String, Object?> toSafeDebugMap();
}

final class CallV2ConnectingProductionViewModel
    extends CallV2ProductionViewModel {
  const CallV2ConnectingProductionViewModel(this.value);

  final CallV2ConnectingViewModel value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return value.toSafeDebugMap();
  }
}

final class CallV2ActiveAudioProductionViewModel
    extends CallV2ProductionViewModel {
  const CallV2ActiveAudioProductionViewModel(this.value);

  final CallV2ActiveAudioViewModel value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return value.toSafeDebugMap();
  }
}

final class CallV2ActiveVideoProductionViewModel
    extends CallV2ProductionViewModel {
  const CallV2ActiveVideoProductionViewModel(this.value);

  final CallV2ActiveVideoViewModel value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return value.toSafeDebugMap();
  }
}

final class CallV2ControlledFailureProductionViewModel
    extends CallV2ProductionViewModel {
  const CallV2ControlledFailureProductionViewModel(this.value);

  final CallV2ControlledFailureViewModel value;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return value.toSafeDebugMap();
  }
}

class CallV2ProductionViewModelMapper {
  const CallV2ProductionViewModelMapper();

  CallV2ProductionViewModelResult<CallV2ProductionViewModel> map(
    CallV2ProductionPresentationSnapshot snapshot, {
    int minimumGeneration = 0,
  }) {
    if (minimumGeneration < 0 || snapshot.generation < 0) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.invalidInput,
      );
    }
    if (snapshot.generation < minimumGeneration) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.staleGeneration,
      );
    }
    if (snapshot.isTerminal || snapshot.destination == null) {
      return const CallV2ProductionViewModelResult.noView();
    }

    final destination = snapshot.destination!;
    if (!destination.isAvailable ||
        destination ==
            CallV2ProductionRouteDestination.incomingReviewReserved) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.reservedDestination,
      );
    }
    if (!_actionsMatch(destination, snapshot)) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.invalidActions,
      );
    }

    return switch (destination) {
      CallV2ProductionRouteDestination.connecting => _connecting(snapshot),
      CallV2ProductionRouteDestination.activeAudio => _audio(snapshot),
      CallV2ProductionRouteDestination.activeVideo => _video(snapshot),
      CallV2ProductionRouteDestination.controlledFailure => _failure(snapshot),
      CallV2ProductionRouteDestination.incomingReviewReserved =>
        const CallV2ProductionViewModelResult.rejected(
          CallV2ProductionViewModelError.reservedDestination,
        ),
    };
  }

  CallV2ProductionViewModelResult<CallV2ProductionViewModel> _connecting(
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    final state = snapshot.screenState;
    if (state is! CallV2ProductionConnectingScreenState) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.incompatibleState,
      );
    }
    return CallV2ProductionViewModelResult.success(
      CallV2ConnectingProductionViewModel(
        CallV2ConnectingViewModel(
          mediaMode: state.mediaMode,
          connectionPhase: state.connectionPhase,
          cancelEnabled: state.cancelAvailable,
          allowedActions: snapshot.allowedActions,
        ),
      ),
    );
  }

  CallV2ProductionViewModelResult<CallV2ProductionViewModel> _audio(
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    final state = snapshot.screenState;
    if (state is! CallV2ProductionActiveAudioScreenState ||
        state.elapsedSeconds < 0) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.incompatibleState,
      );
    }
    return CallV2ProductionViewModelResult.success(
      CallV2ActiveAudioProductionViewModel(
        CallV2ActiveAudioViewModel(
          muted: state.muted,
          speakerEnabled: state.speakerEnabled,
          leaveEnabled: state.leaveEnabled,
          connectionPhase: state.connectionPhase,
          elapsedSeconds: state.elapsedSeconds,
          reconnecting: state.reconnecting,
          allowedActions: snapshot.allowedActions,
        ),
      ),
    );
  }

  CallV2ProductionViewModelResult<CallV2ProductionViewModel> _video(
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    final state = snapshot.screenState;
    if (state is! CallV2ProductionActiveVideoScreenState) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.incompatibleState,
      );
    }
    return CallV2ProductionViewModelResult.success(
      CallV2ActiveVideoProductionViewModel(
        CallV2ActiveVideoViewModel(
          microphoneMuted: state.microphoneMuted,
          localCameraEnabled: state.localCameraEnabled,
          remoteVideoAvailable: state.remoteVideoAvailable,
          cameraSwitchEnabled: state.cameraSwitchAvailable,
          leaveEnabled: state.leaveEnabled,
          connectionPhase: state.connectionPhase,
          renderingState: state.renderingState,
          reconnecting: state.reconnecting,
          allowedActions: snapshot.allowedActions,
        ),
      ),
    );
  }

  CallV2ProductionViewModelResult<CallV2ProductionViewModel> _failure(
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    final state = snapshot.screenState;
    if (state is! CallV2ProductionControlledFailureScreenState) {
      return const CallV2ProductionViewModelResult.rejected(
        CallV2ProductionViewModelError.incompatibleState,
      );
    }
    return CallV2ProductionViewModelResult.success(
      CallV2ControlledFailureProductionViewModel(
        CallV2ControlledFailureViewModel(
          errorCode: state.errorCode,
          retryEnabled: state.retryPolicy ==
              CallV2ProductionFailureRetryPolicy.retryAllowed,
          dismissEnabled: state.dismissPolicy ==
              CallV2ProductionFailureDismissPolicy.dismissAllowed,
          allowedActions: snapshot.allowedActions,
        ),
      ),
    );
  }

  bool _actionsMatch(
    CallV2ProductionRouteDestination destination,
    CallV2ProductionPresentationSnapshot snapshot,
  ) {
    final expected = callV2ProductionActionsFor(
      destination: destination,
      state: snapshot.screenState,
    );
    return _setEquals(snapshot.allowedActions, expected);
  }

  bool _setEquals(
    Set<CallV2ProductionUserAction> left,
    Set<CallV2ProductionUserAction> right,
  ) {
    return left.length == right.length && left.containsAll(right);
  }
}
