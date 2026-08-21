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

enum CallV2EngineCleanupOwnershipState {
  normal,
  releaseTimedOut,
  forceDisposed,
  abandoned,
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
    this.unregisterTimedOut = false,
    this.leaveTimedOut = false,
    this.releaseTimedOut = false,
    this.forceDisposeTimedOut = false,
    this.cleanupOwnershipState = CallV2EngineCleanupOwnershipState.normal,
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
  final bool unregisterTimedOut;
  final bool leaveTimedOut;
  final bool releaseTimedOut;
  final bool forceDisposeTimedOut;
  final CallV2EngineCleanupOwnershipState cleanupOwnershipState;

  bool get abandonedAfterReleaseTimeout =>
      cleanupOwnershipState == CallV2EngineCleanupOwnershipState.abandoned;
}

enum CallV2NextEngineBlocker {
  none,
  cleanupInProgress,
  cleanupFailed,
}

class CallV2NextEngineDecision {
  const CallV2NextEngineDecision({
    required this.nextEngineAllowed,
    required this.blocker,
    required this.previousCleanupResult,
    required this.retryAttempted,
    this.previousCleanupAwaited = false,
    this.previousCleanupWaitCompleted = false,
    this.cleanupEscalated = false,
  });

  final bool nextEngineAllowed;
  final CallV2NextEngineBlocker blocker;
  final CallV2EngineCleanupResult? previousCleanupResult;
  final bool retryAttempted;
  final bool previousCleanupAwaited;
  final bool previousCleanupWaitCompleted;
  final bool cleanupEscalated;

  String get blockerCode {
    return switch (blocker) {
      CallV2NextEngineBlocker.none => 'none',
      CallV2NextEngineBlocker.cleanupInProgress => 'cleanup_in_progress',
      CallV2NextEngineBlocker.cleanupFailed => 'cleanup_failed',
    };
  }
}

class CallV2EngineCleanupCoordinator {
  CallV2EngineCleanupCoordinator({
    Duration unregisterTimeout = const Duration(seconds: 1),
    Duration leaveTimeout = const Duration(seconds: 4),
    Duration releaseTimeout = const Duration(seconds: 4),
    Duration forceDisposeTimeout = const Duration(seconds: 4),
  })  : _unregisterTimeout = unregisterTimeout,
        _leaveTimeout = leaveTimeout,
        _releaseTimeout = releaseTimeout,
        _forceDisposeTimeout = forceDisposeTimeout;

  final Duration _unregisterTimeout;
  final Duration _leaveTimeout;
  final Duration _releaseTimeout;
  final Duration _forceDisposeTimeout;
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
    var releaseTimedOut = false;
    var forceDisposeTimedOut = false;
    var cleanupOwnershipState = CallV2EngineCleanupOwnershipState.normal;

    final unregisterResult = await _runBoundedVoidStep(
      operations.unregisterHandler,
      timeout: _unregisterTimeout,
      failureCode: 'handler_unregister_failed',
      timeoutCode: 'handler_unregister_timeout',
    );
    handlerUnregistered = unregisterResult.succeeded;
    if (!unregisterResult.succeeded) {
      errorCode = unregisterResult.errorCode;
    }

    final leaveResult = await _runBoundedVoidStep(
      operations.leaveChannel,
      timeout: _leaveTimeout,
      failureCode: 'leave_failed',
      timeoutCode: 'leave_timeout',
    );
    channelLeft = leaveResult.succeeded;
    if (!leaveResult.succeeded) {
      errorCode = leaveResult.errorCode;
    }

    if (operations.release) {
      final releaseResult = await _runBoundedVoidStep(
        operations.releaseEngine,
        timeout: _releaseTimeout,
        failureCode: 'release_failed',
        timeoutCode: 'release_timeout',
      );
      engineReleased = releaseResult.succeeded;
      releaseTimedOut = releaseResult.timedOut;
      if (!releaseResult.succeeded) {
        errorCode = releaseResult.errorCode;
        forcedDisposalAttempted = true;
        if (releaseTimedOut) {
          cleanupOwnershipState =
              CallV2EngineCleanupOwnershipState.releaseTimedOut;
        }
        // Future.timeout cannot cancel the native Agora release Future. Once a
        // release times out, the old generation has already been invalidated;
        // Iris disposal is the process escape hatch and the same engine must
        // not be released again by retained retry operations.
        final forceDisposeResult = await _runBoundedBoolStep(
          operations.forceDispose,
          timeout: _forceDisposeTimeout,
          failureCode: 'forced_dispose_failed',
          timeoutCode: 'forced_dispose_timeout',
        );
        irisDisposed = forceDisposeResult.succeeded;
        forceDisposeTimedOut = forceDisposeResult.timedOut;
        if (irisDisposed) {
          cleanupOwnershipState =
              CallV2EngineCleanupOwnershipState.forceDisposed;
        } else if (releaseTimedOut) {
          cleanupOwnershipState = CallV2EngineCleanupOwnershipState.abandoned;
        }
        if (!irisDisposed) {
          errorCode = forceDisposeResult.errorCode;
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
      unregisterTimedOut: unregisterResult.timedOut,
      leaveTimedOut: leaveResult.timedOut,
      releaseTimedOut: releaseTimedOut,
      forceDisposeTimedOut: forceDisposeTimedOut,
      cleanupOwnershipState: cleanupOwnershipState,
    );
  }

  Future<_BoundedCleanupStep> _runBoundedVoidStep(
    Future<void> Function() operation, {
    required Duration timeout,
    required String failureCode,
    required String timeoutCode,
  }) async {
    try {
      await operation().timeout(timeout);
      return const _BoundedCleanupStep.succeeded();
    } on TimeoutException {
      return _BoundedCleanupStep.failed(timeoutCode, timedOut: true);
    } catch (_) {
      return _BoundedCleanupStep.failed(failureCode);
    }
  }

  Future<_BoundedCleanupStep> _runBoundedBoolStep(
    Future<bool> Function() operation, {
    required Duration timeout,
    required String failureCode,
    required String timeoutCode,
  }) async {
    try {
      final succeeded = await operation().timeout(timeout);
      if (succeeded) {
        return const _BoundedCleanupStep.succeeded();
      }
      return _BoundedCleanupStep.failed(failureCode);
    } on TimeoutException {
      return _BoundedCleanupStep.failed(timeoutCode, timedOut: true);
    } catch (_) {
      return _BoundedCleanupStep.failed(failureCode);
    }
  }
}

class _BoundedCleanupStep {
  const _BoundedCleanupStep({
    required this.succeeded,
    required this.errorCode,
    required this.timedOut,
  });

  const _BoundedCleanupStep.succeeded()
      : succeeded = true,
        errorCode = 'none',
        timedOut = false;

  const _BoundedCleanupStep.failed(
    this.errorCode, {
    this.timedOut = false,
  }) : succeeded = false;

  final bool succeeded;
  final String errorCode;
  final bool timedOut;
}

class CallV2ProcessEngineCleanupGate {
  CallV2ProcessEngineCleanupGate({
    CallV2EngineCleanupCoordinator? coordinator,
    Duration previousCleanupWaitTimeout = const Duration(seconds: 14),
  })  : _coordinator = coordinator ?? CallV2EngineCleanupCoordinator(),
        _previousCleanupWaitTimeout = previousCleanupWaitTimeout;

  final CallV2EngineCleanupCoordinator _coordinator;
  final Duration _previousCleanupWaitTimeout;
  CallV2EngineCleanupOperations? _retainedOperations;
  Future<CallV2EngineCleanupResult>? _currentCleanup;
  CallV2EngineCleanupResult? _previousResult;

  Future<CallV2EngineCleanupResult>? get currentCleanup => _currentCleanup;
  CallV2EngineCleanupResult? get previousResult => _previousResult;
  int get previousEngineGeneration => _previousResult?.generation ?? 0;
  bool get cleanupInProgress => _currentCleanup != null;
  bool get previousCleanupSucceeded => _previousResult?.succeeded ?? true;
  bool get previousCleanupFailed => _previousResult?.succeeded == false;
  bool get retryPossible =>
      previousCleanupFailed &&
      _retainedOperations != null &&
      !cleanupInProgress;
  bool get nextEngineAllowed => !cleanupInProgress && !previousCleanupFailed;
  int get attemptNumber => _coordinator.attemptNumber;
  int get failureCount => _coordinator.failureCount;

  Future<CallV2EngineCleanupResult> cleanup(
    CallV2EngineCleanupOperations operations,
  ) {
    final active = _currentCleanup;
    if (active != null) return active;

    _retainedOperations = operations;
    final cleanup = _coordinator.cleanup(operations);
    _currentCleanup = cleanup;
    cleanup.then((result) {
      _previousResult = result;
      if (result.succeeded || result.abandonedAfterReleaseTimeout) {
        _retainedOperations = null;
      }
      return result;
    }, onError: (_) {
      _previousResult = CallV2EngineCleanupResult(
        generation: operations.generation,
        attemptNumber: _coordinator.attemptNumber,
        succeeded: false,
        handlerUnregistered: false,
        channelLeft: false,
        engineReleased: false,
        forcedDisposalAttempted: false,
        irisDisposed: false,
        errorCode: 'cleanup_failed',
      );
    }).whenComplete(() {
      if (identical(_currentCleanup, cleanup)) {
        _currentCleanup = null;
      }
    });
    return cleanup;
  }

  Future<CallV2NextEngineDecision> prepareNextEngine() async {
    final activeCleanup = _currentCleanup;
    if (activeCleanup != null) {
      try {
        final activeResult = await activeCleanup.timeout(
          _previousCleanupWaitTimeout,
        );
        _previousResult = activeResult;
        if (activeResult.succeeded ||
            activeResult.abandonedAfterReleaseTimeout) {
          _retainedOperations = null;
        }
        if (identical(_currentCleanup, activeCleanup)) {
          _currentCleanup = null;
        }
        if (!activeResult.succeeded) {
          return _recoverFailedCleanup(
            previousCleanupAwaited: true,
            previousCleanupWaitCompleted: true,
            cleanupEscalated: true,
          );
        }
        return CallV2NextEngineDecision(
          nextEngineAllowed: true,
          blocker: CallV2NextEngineBlocker.none,
          previousCleanupResult: activeResult,
          retryAttempted: false,
          previousCleanupAwaited: true,
          previousCleanupWaitCompleted: true,
          cleanupEscalated: false,
        );
      } on TimeoutException {
        return CallV2NextEngineDecision(
          nextEngineAllowed: false,
          blocker: CallV2NextEngineBlocker.cleanupInProgress,
          previousCleanupResult: _previousResult,
          retryAttempted: false,
          previousCleanupAwaited: true,
          previousCleanupWaitCompleted: false,
          cleanupEscalated: true,
        );
      }
    }

    if (cleanupInProgress) {
      return CallV2NextEngineDecision(
        nextEngineAllowed: false,
        blocker: CallV2NextEngineBlocker.cleanupInProgress,
        previousCleanupResult: _previousResult,
        retryAttempted: false,
      );
    }

    if (!previousCleanupFailed) {
      return CallV2NextEngineDecision(
        nextEngineAllowed: true,
        blocker: CallV2NextEngineBlocker.none,
        previousCleanupResult: _previousResult,
        retryAttempted: false,
      );
    }

    return _recoverFailedCleanup();
  }

  Future<CallV2NextEngineDecision> _recoverFailedCleanup({
    bool previousCleanupAwaited = false,
    bool previousCleanupWaitCompleted = false,
    bool cleanupEscalated = false,
  }) async {
    final previous = _previousResult;
    if (previous?.abandonedAfterReleaseTimeout ?? false) {
      return CallV2NextEngineDecision(
        nextEngineAllowed: false,
        blocker: CallV2NextEngineBlocker.cleanupFailed,
        previousCleanupResult: previous,
        retryAttempted: false,
        previousCleanupAwaited: previousCleanupAwaited,
        previousCleanupWaitCompleted: previousCleanupWaitCompleted,
        cleanupEscalated: cleanupEscalated,
      );
    }

    final retained = _retainedOperations;
    if (retained == null) {
      return CallV2NextEngineDecision(
        nextEngineAllowed: false,
        blocker: CallV2NextEngineBlocker.cleanupFailed,
        previousCleanupResult: _previousResult,
        retryAttempted: false,
        previousCleanupAwaited: previousCleanupAwaited,
        previousCleanupWaitCompleted: previousCleanupWaitCompleted,
        cleanupEscalated: cleanupEscalated,
      );
    }

    final retryResult = await cleanup(retained);
    return CallV2NextEngineDecision(
      nextEngineAllowed: retryResult.succeeded,
      blocker: retryResult.succeeded
          ? CallV2NextEngineBlocker.none
          : CallV2NextEngineBlocker.cleanupFailed,
      previousCleanupResult: retryResult,
      retryAttempted: true,
      previousCleanupAwaited: previousCleanupAwaited,
      previousCleanupWaitCompleted: previousCleanupWaitCompleted,
      cleanupEscalated: cleanupEscalated,
    );
  }
}
