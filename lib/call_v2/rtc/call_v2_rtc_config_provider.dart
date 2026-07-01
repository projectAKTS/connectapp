abstract interface class CallV2RtcConfigProvider {
  Future<Object?> resolveRtcConfig(CallV2RtcConfigRequest request);
}

class CallV2RtcConfigRequest {
  const CallV2RtcConfigRequest({
    required this.callId,
    required this.localParticipantUid,
    required this.isVideo,
    required this.idempotencyKey,
  });

  final String callId;
  final String localParticipantUid;
  final bool isVideo;
  final String idempotencyKey;
}
