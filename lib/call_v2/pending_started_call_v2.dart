class PendingStartedCallV2 {
  const PendingStartedCallV2({
    required this.callId,
    required this.version,
    required this.idempotentReplay,
    this.ringingDeadlineAt,
  });

  final String callId;
  final int version;
  final bool idempotentReplay;
  final DateTime? ringingDeadlineAt;
}
