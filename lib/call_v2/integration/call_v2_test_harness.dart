abstract interface class CallV2TestHarness {
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
