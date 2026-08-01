import 'dart:async';

class CallV2EngineCleanupOperations {
  const CallV2EngineCleanupOperations({
    required this.generation,
    required this.unregisterHandler,
    required this.leaveChannel,
    required this.releaseEngine,
    required this.forceDispose,
    required this.invalidateGeneration,
    this.release = true,
  });

  final int generation;
  final bool release;
  final Future<void> Function() unregisterHandler;
  final Future<void> Function() leaveChannel;
  final Future<void> Function() releaseEngine;
  final Future<bool> Function() forceDispose;
  final void Function() invalidateGeneration;
}

class CallV2EngineCleanupResult {
  const CallV2EngineCleanupResult({
    required this.generation,
    required this.attemptNumber,
    required this.succeeded,
    required this.handlerUnregistered,
    required this.channelLeft,
    required this.engineReleased,
    required this.forcedDisposalAttempted,
    required this.irisDisposed,
    required this.errorCode,
  });

  final int generation;
  final int attemptNumber;
  final bool succeeded;
  final bool handlerUnregistered;
  final bool channelLeft;
  final bool engineReleased;
  final bool forcedDisposalAttempted;
  final bool irisDisposed;
  final String errorCode;
}

class CallV2EngineCleanupCoordinator {
  Future<CallV2EngineCleanupResult>? _inFlight;
  int _attemptNumber = 0;
  int _failureCount = 0;
  bool _lastCleanupSucceeded = true;

  bool get cleanupInProgress => _inFlight != null;
  bool get lastCleanupSucceeded => _lastCleanupSucceeded;
  int get attemptNumber => _attemptNumber;
  int get failureCount => _failureCount;
  bool get retryPossible => !cleanupInProgress && !_lastCleanupSucceeded;

  Future<CallV2EngineCleanupResult> cleanup(
    CallV2EngineCleanupOperations operations,
  ) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final attempt = _runCleanup(operations);
    _inFlight = attempt;
    return attempt.whenComplete(() {
      if (identical(_inFlight, attempt)) {
        _inFlight = null;
      }
    });
  }

  Future<CallV2EngineCleanupResult> _runCleanup(
    CallV2EngineCleanupOperations operations,
  ) async {
    _attemptNumber += 1;
    _lastCleanupSucceeded = false;
    operations.invalidateGeneration();

    var handlerUnregistered = false;
    var channelLeft = false;
    var engineReleased = !operations.release;
    var forcedDisposalAttempted = false;
    var irisDisposed = false;
    var errorCode = 'none';

    try {
      await operations.unregisterHandler();
      handlerUnregistered = true;
    } catch (_) {
      errorCode = 'handler_unregister_failed';
    }

    try {
      await operations.leaveChannel();
      channelLeft = true;
    } catch (_) {
      errorCode = 'leave_failed';
    }

    if (operations.release) {
      try {
        await operations.releaseEngine();
        engineReleased = true;
      } catch (_) {
        errorCode = 'release_failed';
        forcedDisposalAttempted = true;
        try {
          irisDisposed = await operations.forceDispose();
        } catch (_) {
          irisDisposed = false;
        }
        if (!irisDisposed) {
          errorCode = 'forced_dispose_failed';
        }
      }
    }

    final succeeded = engineReleased || irisDisposed || !operations.release;
    _lastCleanupSucceeded = succeeded;
    if (!succeeded) {
      _failureCount += 1;
    }

    return CallV2EngineCleanupResult(
      generation: operations.generation,
      attemptNumber: _attemptNumber,
      succeeded: succeeded,
      handlerUnregistered: handlerUnregistered,
      channelLeft: channelLeft,
      engineReleased: engineReleased,
      forcedDisposalAttempted: forcedDisposalAttempted,
      irisDisposed: irisDisposed,
      errorCode: errorCode,
    );
  }
}
