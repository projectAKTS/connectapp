enum CallV2ProductionPermissionDeviceBridgeEventType {
  initialize,
  microphonePermissionDenied,
  microphonePermissionPermanentlyDenied,
  cameraPermissionDenied,
  cameraPermissionPermanentlyDenied,
  microphoneUnavailable,
  cameraUnavailable,
  deviceRouteChanged,
  speakerToggleFailed,
  cameraSwitchFailed,
  permissionRecoveryRequested,
  deviceRecoveryRequested,
  closeRequested,
  dispose,
  invalid,
}

enum CallV2ProductionPermissionDeviceMediaMode {
  audioOnly,
  video,
}

enum CallV2ProductionPermissionDeviceKind {
  microphone,
  camera,
  speaker,
  route,
  unknown,
}

enum CallV2ProductionPermissionDeviceRecoveryPolicy {
  noOp,
  showControlledFailure,
  closeCall,
  terminalClose,
  retryAllowed,
  retryBlockedUntilUserAction,
}

final class CallV2ProductionPermissionDeviceBridgeEvent {
  const CallV2ProductionPermissionDeviceBridgeEvent._({
    required this.type,
    this.generation,
    this.mediaMode,
    this.deviceKind,
    this.recoveryPolicy,
    this.userActionRequired = false,
  });

  const factory CallV2ProductionPermissionDeviceBridgeEvent.initialize({
    int? generation,
  }) = _InitializeCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.microphonePermissionDenied({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _MicrophonePermissionDeniedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.microphonePermissionPermanentlyDenied({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) =
      _MicrophonePermissionPermanentlyDeniedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.cameraPermissionDenied({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _CameraPermissionDeniedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.cameraPermissionPermanentlyDenied({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) =
      _CameraPermissionPermanentlyDeniedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.microphoneUnavailable({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _MicrophoneUnavailableCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.cameraUnavailable({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _CameraUnavailableCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.deviceRouteChanged({
    required int generation,
    CallV2ProductionPermissionDeviceKind deviceKind,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _DeviceRouteChangedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.speakerToggleFailed({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _SpeakerToggleFailedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.cameraSwitchFailed({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _CameraSwitchFailedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.permissionRecoveryRequested({
    required int generation,
    required CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
    CallV2ProductionPermissionDeviceMediaMode? mediaMode,
  }) = _PermissionRecoveryRequestedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.deviceRecoveryRequested({
    required int generation,
    required CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
    CallV2ProductionPermissionDeviceKind deviceKind,
  }) = _DeviceRecoveryRequestedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.closeRequested({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
  }) = _CloseRequestedCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.dispose() =
      _DisposeCallV2ProductionPermissionDeviceBridgeEvent;

  const factory CallV2ProductionPermissionDeviceBridgeEvent.invalid({
    int? generation,
  }) = _InvalidCallV2ProductionPermissionDeviceBridgeEvent;

  final CallV2ProductionPermissionDeviceBridgeEventType type;
  final int? generation;
  final CallV2ProductionPermissionDeviceMediaMode? mediaMode;
  final CallV2ProductionPermissionDeviceKind? deviceKind;
  final CallV2ProductionPermissionDeviceRecoveryPolicy? recoveryPolicy;
  final bool userActionRequired;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'type': type.name,
      if (generation != null) 'generation': generation,
      if (mediaMode != null) 'mediaMode': mediaMode!.name,
      if (deviceKind != null) 'deviceKind': deviceKind!.name,
      if (recoveryPolicy != null) 'recoveryPolicy': recoveryPolicy!.name,
      'userActionRequired': userActionRequired,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionPermissionDeviceBridgeEvent(${toSafeDebugMap()})';
  }
}

final class _InitializeCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _InitializeCallV2ProductionPermissionDeviceBridgeEvent({
    int? generation,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType.initialize,
          generation: generation,
        );
}

final class _MicrophonePermissionDeniedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _MicrophonePermissionDeniedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.showControlledFailure,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .microphonePermissionDenied,
          generation: generation,
          mediaMode: CallV2ProductionPermissionDeviceMediaMode.audioOnly,
          deviceKind: CallV2ProductionPermissionDeviceKind.microphone,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _MicrophonePermissionPermanentlyDeniedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _MicrophonePermissionPermanentlyDeniedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy
            .retryBlockedUntilUserAction,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .microphonePermissionPermanentlyDenied,
          generation: generation,
          mediaMode: CallV2ProductionPermissionDeviceMediaMode.audioOnly,
          deviceKind: CallV2ProductionPermissionDeviceKind.microphone,
          recoveryPolicy: recoveryPolicy,
          userActionRequired: true,
        );
}

final class _CameraPermissionDeniedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _CameraPermissionDeniedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.showControlledFailure,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .cameraPermissionDenied,
          generation: generation,
          mediaMode: CallV2ProductionPermissionDeviceMediaMode.video,
          deviceKind: CallV2ProductionPermissionDeviceKind.camera,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _CameraPermissionPermanentlyDeniedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _CameraPermissionPermanentlyDeniedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy
            .retryBlockedUntilUserAction,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .cameraPermissionPermanentlyDenied,
          generation: generation,
          mediaMode: CallV2ProductionPermissionDeviceMediaMode.video,
          deviceKind: CallV2ProductionPermissionDeviceKind.camera,
          recoveryPolicy: recoveryPolicy,
          userActionRequired: true,
        );
}

final class _MicrophoneUnavailableCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _MicrophoneUnavailableCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.showControlledFailure,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .microphoneUnavailable,
          generation: generation,
          mediaMode: CallV2ProductionPermissionDeviceMediaMode.audioOnly,
          deviceKind: CallV2ProductionPermissionDeviceKind.microphone,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _CameraUnavailableCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _CameraUnavailableCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.showControlledFailure,
  }) : super._(
          type:
              CallV2ProductionPermissionDeviceBridgeEventType.cameraUnavailable,
          generation: generation,
          mediaMode: CallV2ProductionPermissionDeviceMediaMode.video,
          deviceKind: CallV2ProductionPermissionDeviceKind.camera,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _DeviceRouteChangedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _DeviceRouteChangedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceKind deviceKind =
        CallV2ProductionPermissionDeviceKind.route,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.noOp,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .deviceRouteChanged,
          generation: generation,
          deviceKind: deviceKind,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _SpeakerToggleFailedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _SpeakerToggleFailedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.noOp,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .speakerToggleFailed,
          generation: generation,
          deviceKind: CallV2ProductionPermissionDeviceKind.speaker,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _CameraSwitchFailedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _CameraSwitchFailedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.noOp,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .cameraSwitchFailed,
          generation: generation,
          mediaMode: CallV2ProductionPermissionDeviceMediaMode.video,
          deviceKind: CallV2ProductionPermissionDeviceKind.camera,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _PermissionRecoveryRequestedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _PermissionRecoveryRequestedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    required CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
    CallV2ProductionPermissionDeviceMediaMode? mediaMode,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .permissionRecoveryRequested,
          generation: generation,
          mediaMode: mediaMode,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _DeviceRecoveryRequestedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _DeviceRecoveryRequestedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    required CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy,
    CallV2ProductionPermissionDeviceKind deviceKind =
        CallV2ProductionPermissionDeviceKind.unknown,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType
              .deviceRecoveryRequested,
          generation: generation,
          deviceKind: deviceKind,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _CloseRequestedCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _CloseRequestedCallV2ProductionPermissionDeviceBridgeEvent({
    required int generation,
    CallV2ProductionPermissionDeviceRecoveryPolicy recoveryPolicy =
        CallV2ProductionPermissionDeviceRecoveryPolicy.closeCall,
  }) : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType.closeRequested,
          generation: generation,
          recoveryPolicy: recoveryPolicy,
        );
}

final class _DisposeCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _DisposeCallV2ProductionPermissionDeviceBridgeEvent()
      : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType.dispose,
          recoveryPolicy:
              CallV2ProductionPermissionDeviceRecoveryPolicy.terminalClose,
        );
}

final class _InvalidCallV2ProductionPermissionDeviceBridgeEvent
    extends CallV2ProductionPermissionDeviceBridgeEvent {
  const _InvalidCallV2ProductionPermissionDeviceBridgeEvent({int? generation})
      : super._(
          type: CallV2ProductionPermissionDeviceBridgeEventType.invalid,
          generation: generation,
        );
}
