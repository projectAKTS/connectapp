import 'call_v2_runtime_config.dart';
import 'call_v2_runtime_state.dart';

class CallV2ManualSessionInputs {
  CallV2ManualSessionInputs({
    required String rtcApplicationIdentifier,
    required String sessionIdentifier,
    required String localParticipantIdentifier,
    required String remoteParticipantIdentifier,
    required this.mode,
    required this.useRealAdapters,
    required this.allowPermissionRequests,
    required this.allowTokenRequests,
    required this.allowRtcInitialization,
    required this.allowRtcJoin,
  })  : rtcApplicationIdentifier = _trim(rtcApplicationIdentifier),
        sessionIdentifier = _validateIdentifier(sessionIdentifier),
        localParticipantIdentifier =
            _validateIdentifier(localParticipantIdentifier),
        remoteParticipantIdentifier =
            _validateIdentifier(remoteParticipantIdentifier) {
    if (_validateIdentifier(localParticipantIdentifier) ==
        _validateIdentifier(remoteParticipantIdentifier)) {
      throw const CallV2ManualSessionInputError();
    }
  }

  final String rtcApplicationIdentifier;
  final String sessionIdentifier;
  final String localParticipantIdentifier;
  final String remoteParticipantIdentifier;
  final CallV2RuntimeCallMode mode;
  final bool useRealAdapters;
  final bool allowPermissionRequests;
  final bool allowTokenRequests;
  final bool allowRtcInitialization;
  final bool allowRtcJoin;

  bool get applicationReady => rtcApplicationIdentifier.isNotEmpty;

  bool get canUseRealAdapters => useRealAdapters && applicationReady;

  CallV2RuntimeConfig toRuntimeConfig() {
    return CallV2RuntimeConfig.internalRealDevice(
      allowPermissionRequests: allowPermissionRequests,
      allowTokenRequests: allowTokenRequests,
      allowRtcInitialization: allowRtcInitialization && applicationReady,
      allowRtcJoin: allowRtcJoin && applicationReady,
      exposeDevUi: true,
      useRealAdapters: useRealAdapters,
      rtcApplicationIdentifier: rtcApplicationIdentifier,
    );
  }

  Map<String, Object?> toTokenBackendData() {
    return <String, Object?>{
      'callId': sessionIdentifier,
      'participantUid': localParticipantIdentifier,
      'isVideo': mode == CallV2RuntimeCallMode.video,
    };
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'applicationReady': applicationReady,
      'sessionReady': sessionIdentifier.isNotEmpty,
      'localReady': localParticipantIdentifier.isNotEmpty,
      'remoteReady': remoteParticipantIdentifier.isNotEmpty,
      'mode': mode.name,
      'realAdaptersRequested': useRealAdapters,
      'realAdaptersReady': canUseRealAdapters,
      'permissionStepAllowed': allowPermissionRequests,
      'accessStepAllowed': allowTokenRequests,
      'setupStepAllowed': allowRtcInitialization && applicationReady,
      'joinStepAllowed': allowRtcJoin && applicationReady,
    };
  }

  @override
  String toString() => 'CallV2ManualSessionInputs(${toSafeDebugMap()})';
}

class CallV2ManualSessionInputError implements Exception {
  const CallV2ManualSessionInputError();
}

String _validateIdentifier(String value) {
  final trimmed = _trim(value);
  if (trimmed.isEmpty ||
      trimmed.length > 128 ||
      trimmed.contains('/') ||
      trimmed.contains('\\')) {
    throw const CallV2ManualSessionInputError();
  }
  return trimmed;
}

String _trim(String value) => value.trim();
