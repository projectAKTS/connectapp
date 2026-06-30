class PendingStartedCallV2 {
  const PendingStartedCallV2({
    required this.callId,
    required this.calleeUid,
    required this.idempotencyKey,
    required this.version,
    required this.idempotentReplay,
    this.ringingDeadlineAt,
  });

  final String callId;
  final String calleeUid;
  final String idempotencyKey;
  final int version;
  final bool idempotentReplay;
  final DateTime? ringingDeadlineAt;
}
