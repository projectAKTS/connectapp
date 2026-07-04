import '../call_v2_api.dart';
import 'call_v2_production_mapping_result.dart';
import 'call_v2_production_presentation_snapshot.dart';
import 'call_v2_production_view_state.dart';
import 'call_v2_ui_session_reference.dart';

enum CallV2ProductionPresentationInputState {
  idle,
  preparing,
  connecting,
  ready,
  reconnecting,
  controlledFailure,
  ended,
  unavailable,
  disposed,
}

class CallV2ProductionPresentationInput {
  const CallV2ProductionPresentationInput({
    required this.generation,
    required this.state,
    this.mediaMode,
    this.connectionPhase = CallV2ProductionConnectionPhase.idle,
    this.muted = false,
    this.speakerEnabled = false,
    this.cameraEnabled = false,
    this.cameraAvailable = false,
    this.remoteVideoAvailable = false,
    this.cameraSwitchAvailable = false,
    this.elapsedSeconds = 0,
    this.renderingState = CallV2ProductionVideoRenderingState.unavailable,
    this.errorCode,
    this.retryPolicy = CallV2ProductionFailureRetryPolicy.retryUnavailable,
    this.dismissPolicy =
        CallV2ProductionFailureDismissPolicy.dismissUnavailable,
    this.retryActionRequested = false,
  });

  final int generation;
  final CallV2ProductionPresentationInputState state;
  final CallV2ProductionMediaMode? mediaMode;
  final CallV2ProductionConnectionPhase connectionPhase;
  final bool muted;
  final bool speakerEnabled;
  final bool cameraEnabled;
  final bool cameraAvailable;
  final bool remoteVideoAvailable;
  final bool cameraSwitchAvailable;
  final int elapsedSeconds;
  final CallV2ProductionVideoRenderingState renderingState;
  final CallV2ClientErrorCode? errorCode;
  final CallV2ProductionFailureRetryPolicy retryPolicy;
  final CallV2ProductionFailureDismissPolicy dismissPolicy;
  final bool retryActionRequested;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'generation': generation,
      'state': state.name,
      'mediaMode': mediaMode?.name,
      'connectionPhase': connectionPhase.name,
      'hasErrorCode': errorCode != null,
      'retryPolicy': retryPolicy.name,
      'dismissPolicy': dismissPolicy.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionPresentationInput(${toSafeDebugMap()})';
  }
}

class CallV2ProductionPresentationMapper {
  const CallV2ProductionPresentationMapper();

  CallV2ProductionMappingResult<CallV2ProductionPresentationSnapshot> map(
    CallV2ProductionPresentationInput input, {
    int minimumGeneration = 0,
  }) {
    final validationError = _validate(input, minimumGeneration);
    if (validationError != null) {
      return CallV2ProductionMappingResult.rejected(validationError);
    }

    return switch (input.state) {
      CallV2ProductionPresentationInputState.preparing ||
      CallV2ProductionPresentationInputState.connecting =>
        CallV2ProductionMappingResult.success(_connecting(input)),
      CallV2ProductionPresentationInputState.ready ||
      CallV2ProductionPresentationInputState.reconnecting =>
        CallV2ProductionMappingResult.success(_active(input)),
      CallV2ProductionPresentationInputState.controlledFailure =>
        CallV2ProductionMappingResult.success(_failure(input)),
      CallV2ProductionPresentationInputState.ended ||
      CallV2ProductionPresentationInputState.idle ||
      CallV2ProductionPresentationInputState.unavailable =>
        CallV2ProductionMappingResult.noRoute(
          CallV2ProductionPresentationSnapshot.none(
            generation: input.generation,
          ),
        ),
      CallV2ProductionPresentationInputState.disposed =>
        CallV2ProductionMappingResult.noRoute(
          CallV2ProductionPresentationSnapshot.none(
            generation: input.generation,
            terminalStatus:
                CallV2ProductionPresentationTerminalStatus.terminalDisposed,
          ),
        ),
    };
  }

  CallV2ProductionMappingError? _validate(
    CallV2ProductionPresentationInput input,
    int minimumGeneration,
  ) {
    if (minimumGeneration < 0 ||
        input.generation < 0 ||
        input.elapsedSeconds < 0) {
      return CallV2ProductionMappingError.invalidInput;
    }
    if (input.generation < minimumGeneration) {
      return CallV2ProductionMappingError.staleGeneration;
    }
    if (input.renderingState !=
            CallV2ProductionVideoRenderingState.unavailable &&
        input.mediaMode != CallV2ProductionMediaMode.video) {
      return CallV2ProductionMappingError.invalidInput;
    }
    if ((input.state == CallV2ProductionPresentationInputState.ready ||
            input.state ==
                CallV2ProductionPresentationInputState.reconnecting ||
            input.state == CallV2ProductionPresentationInputState.preparing ||
            input.state == CallV2ProductionPresentationInputState.connecting) &&
        input.mediaMode == null) {
      return CallV2ProductionMappingError.invalidInput;
    }
    if ((input.state == CallV2ProductionPresentationInputState.ready ||
            input.state ==
                CallV2ProductionPresentationInputState.reconnecting) &&
        input.mediaMode == CallV2ProductionMediaMode.video &&
        !input.cameraAvailable) {
      return CallV2ProductionMappingError.invalidInput;
    }
    if (input.state ==
            CallV2ProductionPresentationInputState.controlledFailure &&
        input.errorCode == null) {
      return CallV2ProductionMappingError.invalidInput;
    }
    if (input.retryActionRequested &&
        input.retryPolicy != CallV2ProductionFailureRetryPolicy.retryAllowed) {
      return CallV2ProductionMappingError.invalidInput;
    }
    if ((input.state == CallV2ProductionPresentationInputState.disposed ||
            input.state == CallV2ProductionPresentationInputState.ended ||
            input.state == CallV2ProductionPresentationInputState.idle ||
            input.state ==
                CallV2ProductionPresentationInputState.unavailable) &&
        _wouldProduceLiveDestination(input)) {
      return CallV2ProductionMappingError.invalidInput;
    }
    return null;
  }

  bool _wouldProduceLiveDestination(CallV2ProductionPresentationInput input) {
    return input.connectionPhase == CallV2ProductionConnectionPhase.connected ||
        input.connectionPhase == CallV2ProductionConnectionPhase.reconnecting ||
        input.mediaMode != null;
  }

  CallV2ProductionPresentationSnapshot _connecting(
    CallV2ProductionPresentationInput input,
  ) {
    final mediaMode = input.mediaMode!;
    return CallV2ProductionPresentationSnapshot.connecting(
      sessionReference: _sessionReference(
        input,
        mediaMode: mediaMode,
        status: CallV2ProductionLocalLifecycleStatus.connecting,
      ),
      screenState: CallV2ProductionConnectingScreenState(
        mediaMode: mediaMode,
        cancelAvailable: true,
        connectionPhase: input.connectionPhase,
      ),
    );
  }

  CallV2ProductionPresentationSnapshot _active(
    CallV2ProductionPresentationInput input,
  ) {
    final mediaMode = input.mediaMode!;
    if (mediaMode == CallV2ProductionMediaMode.audio) {
      return CallV2ProductionPresentationSnapshot.activeAudio(
        sessionReference: _sessionReference(
          input,
          mediaMode: mediaMode,
          status: CallV2ProductionLocalLifecycleStatus.active,
        ),
        screenState: CallV2ProductionActiveAudioScreenState(
          muted: input.muted,
          speakerEnabled: input.speakerEnabled,
          leaveEnabled: true,
          connectionPhase: input.connectionPhase,
          elapsedSeconds: input.elapsedSeconds,
          reconnecting: input.state ==
              CallV2ProductionPresentationInputState.reconnecting,
        ),
      );
    }
    return CallV2ProductionPresentationSnapshot.activeVideo(
      sessionReference: _sessionReference(
        input,
        mediaMode: mediaMode,
        status: CallV2ProductionLocalLifecycleStatus.active,
      ),
      screenState: CallV2ProductionActiveVideoScreenState(
        microphoneMuted: input.muted,
        localCameraEnabled: input.cameraEnabled,
        remoteVideoAvailable: input.remoteVideoAvailable,
        cameraSwitchAvailable: input.cameraSwitchAvailable,
        leaveEnabled: true,
        connectionPhase: input.connectionPhase,
        renderingState: input.renderingState,
        reconnecting:
            input.state == CallV2ProductionPresentationInputState.reconnecting,
      ),
    );
  }

  CallV2ProductionPresentationSnapshot _failure(
    CallV2ProductionPresentationInput input,
  ) {
    return CallV2ProductionPresentationSnapshot.controlledFailure(
      sessionReference: input.mediaMode == null
          ? null
          : _sessionReference(
              input,
              mediaMode: input.mediaMode!,
              status: CallV2ProductionLocalLifecycleStatus.failed,
            ),
      generation: input.generation,
      screenState: CallV2ProductionControlledFailureScreenState(
        errorCode: input.errorCode!,
        retryPolicy: input.retryPolicy,
        dismissPolicy: input.dismissPolicy,
      ),
    );
  }

  CallV2UiSessionReference _sessionReference(
    CallV2ProductionPresentationInput input, {
    required CallV2ProductionMediaMode mediaMode,
    required CallV2ProductionLocalLifecycleStatus status,
  }) {
    return CallV2UiSessionReference(
      generation: input.generation,
      mediaMode: mediaMode,
      localLifecycleStatus: status,
      connectionPhase: input.connectionPhase,
    );
  }
}
