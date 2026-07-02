import '../call_v2_rtc_adapter.dart';

abstract interface class CallV2RtcEngineTransport {
  Future<void> initialize(CallV2RtcEngineSession session);

  Future<void> joinChannel();

  Future<void> leaveChannel();

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<void> dispose();

  Stream<CallV2RtcEngineEvent> get events;
}

class CallV2RtcEngineSession {
  const CallV2RtcEngineSession({
    required this.channelName,
    required this.rtcUid,
    required this.isVideo,
    this.token,
  });

  final String channelName;
  final int rtcUid;
  final bool isVideo;
  final String? token;

  @override
  bool operator ==(Object other) {
    return other is CallV2RtcEngineSession &&
        other.channelName == channelName &&
        other.rtcUid == rtcUid &&
        other.isVideo == isVideo &&
        other.token == token;
  }

  @override
  int get hashCode => Object.hash(channelName, rtcUid, isVideo, token);

  @override
  String toString() {
    return 'CallV2RtcEngineSession('
        'isVideo: $isVideo, '
        'hasToken: ${token != null}'
        ')';
  }
}

sealed class CallV2RtcEngineEvent {
  const CallV2RtcEngineEvent();
}

class CallV2RtcEngineJoined extends CallV2RtcEngineEvent {
  const CallV2RtcEngineJoined();
}

class CallV2RtcEngineReconnecting extends CallV2RtcEngineEvent {
  const CallV2RtcEngineReconnecting();
}

class CallV2RtcEngineReconnected extends CallV2RtcEngineEvent {
  const CallV2RtcEngineReconnected();
}

class CallV2RtcEngineDisconnected extends CallV2RtcEngineEvent {
  const CallV2RtcEngineDisconnected();
}

class CallV2RtcEngineRemoteParticipantJoined extends CallV2RtcEngineEvent {
  const CallV2RtcEngineRemoteParticipantJoined();
}

class CallV2RtcEngineRemoteParticipantLeft extends CallV2RtcEngineEvent {
  const CallV2RtcEngineRemoteParticipantLeft();
}

class CallV2RtcEngineFailure extends CallV2RtcEngineEvent implements Exception {
  const CallV2RtcEngineFailure(this.category);

  final CallV2RtcErrorCategory category;

  @override
  String toString() {
    return 'CallV2RtcEngineFailure(category: ${category.name})';
  }
}
