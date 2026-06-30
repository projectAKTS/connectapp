import '../call_v2_api.dart';

abstract interface class CallV2RtcAdapter {
  Future<void> initialize(CallV2RtcSessionConfig config);

  Future<void> joinChannel();

  Future<void> leaveChannel();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<void> dispose();

  Stream<CallV2RtcEvent> get events;
}

class CallV2RtcSessionConfig {
  const CallV2RtcSessionConfig({
    required this.callId,
    required this.channelName,
    required this.rtcUid,
    required this.isVideo,
    this.token,
  });

  final String callId;
  final String channelName;
  final int rtcUid;
  final bool isVideo;
  final String? token;

  @override
  bool operator ==(Object other) {
    return other is CallV2RtcSessionConfig &&
        other.callId == callId &&
        other.channelName == channelName &&
        other.rtcUid == rtcUid &&
        other.isVideo == isVideo &&
        other.token == token;
  }

  @override
  int get hashCode => Object.hash(callId, channelName, rtcUid, isVideo, token);
}

sealed class CallV2RtcEvent {
  const CallV2RtcEvent();
}

class CallV2RtcJoinStarted extends CallV2RtcEvent {
  const CallV2RtcJoinStarted();
}

class CallV2RtcJoined extends CallV2RtcEvent {
  const CallV2RtcJoined();
}

class CallV2RtcReconnecting extends CallV2RtcEvent {
  const CallV2RtcReconnecting();
}

class CallV2RtcReconnected extends CallV2RtcEvent {
  const CallV2RtcReconnected();
}

class CallV2RtcDisconnected extends CallV2RtcEvent {
  const CallV2RtcDisconnected();
}

class CallV2RtcRemoteParticipantJoined extends CallV2RtcEvent {
  const CallV2RtcRemoteParticipantJoined();
}

class CallV2RtcRemoteParticipantLeft extends CallV2RtcEvent {
  const CallV2RtcRemoteParticipantLeft();
}

class CallV2RtcFatalError extends CallV2RtcEvent {
  const CallV2RtcFatalError(this.category);

  final CallV2RtcErrorCategory category;
}

enum CallV2RtcErrorCategory {
  unavailable,
  permissionDenied,
  deviceUnavailable,
  unknown;

  CallV2ClientErrorCode get clientErrorCode {
    switch (this) {
      case CallV2RtcErrorCategory.permissionDenied:
        return CallV2ClientErrorCode.unauthorized;
      case CallV2RtcErrorCategory.deviceUnavailable:
        return CallV2ClientErrorCode.rejected;
      case CallV2RtcErrorCategory.unavailable:
      case CallV2RtcErrorCategory.unknown:
        return CallV2ClientErrorCode.unavailable;
    }
  }
}
