class CallV2IncomingListenerBackoff {
  CallV2IncomingListenerBackoff({
    this.initialDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 5),
    this.maxAttemptExponent = 6,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final int maxAttemptExponent;
  int _attempt = 0;

  int get attempt => _attempt;

  Duration recordErrorAndGetDelay() {
    _attempt = (_attempt + 1).clamp(1, maxAttemptExponent);
    final multiplier = 1 << (_attempt - 1);
    final delayMs = initialDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: delayMs.clamp(
        initialDelay.inMilliseconds,
        maxDelay.inMilliseconds,
      ),
    );
  }

  void recordHealthySnapshot() {
    _attempt = 0;
  }

  void reset() {
    _attempt = 0;
  }
}
