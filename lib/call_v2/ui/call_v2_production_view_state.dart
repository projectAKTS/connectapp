import '../call_v2_api.dart';
import 'call_v2_ui_session_reference.dart';

enum CallV2ProductionVideoRenderingState {
  unavailable,
  waiting,
  rendering,
  interrupted,
}

enum CallV2ProductionFailureRetryPolicy {
  retryUnavailable,
  retryAllowed,
}

enum CallV2ProductionFailureDismissPolicy {
  dismissUnavailable,
  dismissAllowed,
}

sealed class CallV2ProductionScreenState {
  const CallV2ProductionScreenState();

  Map<String, Object?> toSafeDebugMap();
}

final class CallV2ProductionConnectingScreenState
    extends CallV2ProductionScreenState {
  const CallV2ProductionConnectingScreenState({
    required this.mediaMode,
    required this.cancelAvailable,
    required this.connectionPhase,
  });

  final CallV2ProductionMediaMode mediaMode;
  final bool cancelAvailable;
  final CallV2ProductionConnectionPhase connectionPhase;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'screen': 'connecting',
      'mediaMode': mediaMode.name,
      'cancelAvailable': cancelAvailable,
      'connectionPhase': connectionPhase.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionConnectingScreenState(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionActiveAudioScreenState
    extends CallV2ProductionScreenState {
  const CallV2ProductionActiveAudioScreenState({
    required this.muted,
    required this.speakerEnabled,
    required this.leaveEnabled,
    required this.connectionPhase,
    required this.elapsedSeconds,
    required this.reconnecting,
  }) : assert(elapsedSeconds >= 0);

  final bool muted;
  final bool speakerEnabled;
  final bool leaveEnabled;
  final CallV2ProductionConnectionPhase connectionPhase;
  final int elapsedSeconds;
  final bool reconnecting;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'screen': 'activeAudio',
      'muted': muted,
      'speakerEnabled': speakerEnabled,
      'leaveEnabled': leaveEnabled,
      'connectionPhase': connectionPhase.name,
      'elapsedSeconds': elapsedSeconds,
      'reconnecting': reconnecting,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionActiveAudioScreenState(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionActiveVideoScreenState
    extends CallV2ProductionScreenState {
  const CallV2ProductionActiveVideoScreenState({
    required this.microphoneMuted,
    required this.localCameraEnabled,
    required this.remoteVideoAvailable,
    required this.cameraSwitchAvailable,
    required this.leaveEnabled,
    required this.connectionPhase,
    required this.renderingState,
    required this.reconnecting,
  });

  final bool microphoneMuted;
  final bool localCameraEnabled;
  final bool remoteVideoAvailable;
  final bool cameraSwitchAvailable;
  final bool leaveEnabled;
  final CallV2ProductionConnectionPhase connectionPhase;
  final CallV2ProductionVideoRenderingState renderingState;
  final bool reconnecting;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'screen': 'activeVideo',
      'microphoneMuted': microphoneMuted,
      'localCameraEnabled': localCameraEnabled,
      'remoteVideoAvailable': remoteVideoAvailable,
      'cameraSwitchAvailable': cameraSwitchAvailable,
      'leaveEnabled': leaveEnabled,
      'connectionPhase': connectionPhase.name,
      'renderingState': renderingState.name,
      'reconnecting': reconnecting,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionActiveVideoScreenState(${toSafeDebugMap()})';
  }
}

final class CallV2ProductionControlledFailureScreenState
    extends CallV2ProductionScreenState {
  const CallV2ProductionControlledFailureScreenState({
    required this.errorCode,
    required this.retryPolicy,
    required this.dismissPolicy,
  });

  final CallV2ClientErrorCode errorCode;
  final CallV2ProductionFailureRetryPolicy retryPolicy;
  final CallV2ProductionFailureDismissPolicy dismissPolicy;

  @override
  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'screen': 'controlledFailure',
      'errorCode': errorCode.name,
      'retryPolicy': retryPolicy.name,
      'dismissPolicy': dismissPolicy.name,
    };
  }

  @override
  String toString() {
    return 'CallV2ProductionControlledFailureScreenState(${toSafeDebugMap()})';
  }
}
