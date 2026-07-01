import 'call_v2_rtc_adapter.dart';

class CallV2ResolvedRtcConfig {
  const CallV2ResolvedRtcConfig({
    required this.callId,
    required this.localParticipantUid,
    required this.channelName,
    required this.rtcUid,
    required this.token,
    required this.isVideo,
    required this.issuedAt,
    required this.expiresAt,
    required this.idempotentReplay,
  });

  final String callId;
  final String localParticipantUid;
  final String channelName;
  final int rtcUid;
  final String token;
  final bool isVideo;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool idempotentReplay;

  CallV2RtcSessionConfig toSessionConfig() {
    return CallV2RtcSessionConfig(
      callId: callId,
      channelName: channelName,
      rtcUid: rtcUid,
      isVideo: isVideo,
      token: token,
    );
  }

  @override
  String toString() {
    return 'CallV2ResolvedRtcConfig('
        'callId: $callId, '
        'localParticipantUid: $localParticipantUid, '
        'channelName: $channelName, '
        'rtcUid: $rtcUid, '
        'token: <redacted>, '
        'isVideo: $isVideo, '
        'issuedAt: $issuedAt, '
        'expiresAt: $expiresAt, '
        'idempotentReplay: $idempotentReplay'
        ')';
  }
}
