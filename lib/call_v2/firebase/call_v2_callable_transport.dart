abstract interface class CallV2CallableTransport {
  Future<Object?> call(
    String callableName,
    Map<String, Object?> request,
  );
}

abstract final class CallV2CallableNames {
  static const start = 'startCallV2';
  static const accept = 'acceptCallV2';
  static const decline = 'declineCallV2';
  static const cancel = 'cancelCallV2';
  static const end = 'endCallV2';
  static const reportParticipantMedia = 'reportParticipantMediaV2';
  static const renewActiveCallLease = 'renewActiveCallLeaseV2';
}
