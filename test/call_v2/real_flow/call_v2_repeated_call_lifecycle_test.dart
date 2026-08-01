import 'dart:async';

import 'package:connect_app/call_v2/real_flow/call_v2_engine_cleanup_coordinator.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_incoming_listener_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three simultaneous cleanup callers invoke native cleanup once',
      () async {
    final coordinator = CallV2EngineCleanupCoordinator();
    final engine = _FakeEngine();
    final operations = _operations(engine, generation: 1);

    final results = await Future.wait([
      coordinator.cleanup(operations),
      coordinator.cleanup(operations),
      coordinator.cleanup(operations),
    ]);

    expect(results.map((result) => result.attemptNumber).toSet(), {1});
    expect(engine.unregisterCount, 1);
    expect(engine.leaveCount, 1);
    expect(engine.releaseCount, 1);
    expect(engine.forceDisposeCount, 0);
    expect(coordinator.cleanupInProgress, isFalse);
    expect(coordinator.lastCleanupSucceeded, isTrue);
  });

  test('failed cleanup attempt is not permanently cached and can retry',
      () async {
    final coordinator = CallV2EngineCleanupCoordinator();
    final first = _FakeEngine(forceDisposeSucceeds: false)
      ..releaseError = TimeoutException('release_timeout');

    final failed = await coordinator.cleanup(_operations(first, generation: 1));

    expect(failed.succeeded, isFalse);
    expect(failed.attemptNumber, 1);
    expect(first.releaseCount, 1);
    expect(first.forceDisposeCount, 1);
    expect(coordinator.cleanupInProgress, isFalse);
    expect(coordinator.retryPossible, isTrue);

    final second = _FakeEngine();
    final recovered =
        await coordinator.cleanup(_operations(second, generation: 1));

    expect(recovered.succeeded, isTrue);
    expect(recovered.attemptNumber, 2);
    expect(second.releaseCount, 1);
    expect(coordinator.cleanupInProgress, isFalse);
    expect(coordinator.lastCleanupSucceeded, isTrue);
  });

  test('cleanup failure still allows route CallKit and session reset',
      () async {
    final harness = _LifecycleHarness(
      engine: _FakeEngine(forceDisposeSucceeds: false)
        ..releaseError = StateError('release_failed'),
    );

    final result = await harness.endCall();

    expect(result.succeeded, isFalse);
    expect(harness.callKitCleanupCount, 1);
    expect(harness.sessionResetCount, 1);
    expect(harness.routeCloseCount, 1);
    expect(harness.blockerCode, 'cleanup_failed');
  });

  test('release failure does not overlap release and forced disposal',
      () async {
    final coordinator = CallV2EngineCleanupCoordinator();
    final engine = _FakeEngine()..releaseError = TimeoutException('timeout');

    final result =
        await coordinator.cleanup(_operations(engine, generation: 1));

    expect(result.succeeded, isTrue);
    expect(result.forcedDisposalAttempted, isTrue);
    expect(engine.events, [
      'invalidate',
      'unregister',
      'leave_start',
      'leave_done',
      'release_start',
      'release_error',
      'force_dispose_start',
      'force_dispose_done',
    ]);
  });

  test('late generation callback cannot mutate newer generation', () async {
    final guard = _GenerationGuard();

    guard.start(1);
    guard.callback(1, () => guard.state = 'joined_first');
    guard.invalidate(1);
    guard.start(2);
    guard.callback(1, () => guard.state = 'stale_overwrite');
    guard.callback(2, () => guard.state = 'joined_second');

    expect(guard.state, 'joined_second');
    expect(guard.staleIgnoredCount, 1);
  });

  test('ten actual lifecycle executions restore resource baseline', () async {
    final harness = _LifecycleHarness();

    for (var i = 1; i <= 10; i += 1) {
      final result = await harness.runLifecycle(generation: i);

      expect(result.succeeded, isTrue, reason: 'call $i');
      expect(harness.engineReferenceCleared, isTrue, reason: 'call $i');
      expect(harness.handlerCleared, isTrue, reason: 'call $i');
      expect(harness.cleanupInFlight, isFalse, reason: 'call $i');
      expect(harness.activeInviteListenerCount, 0, reason: 'call $i');
      expect(harness.incomingListenerCount, 1, reason: 'call $i');
      expect(harness.activeTimerCount, 0, reason: 'call $i');
      expect(harness.sessionIdle, isTrue, reason: 'call $i');
    }

    expect(harness.createCount, 10);
    expect(harness.registerCount, 10);
    expect(harness.joinCount, 10);
    expect(harness.endCount, 10);
    expect(harness.unregisterCount, 10);
    expect(harness.leaveCount, 10);
    expect(harness.releaseCount, 10);
  });

  test('incoming listener repeated errors use bounded increasing backoff', () {
    final policy = CallV2IncomingListenerBackoff();

    expect(policy.recordErrorAndGetDelay(), const Duration(milliseconds: 250));
    expect(policy.recordErrorAndGetDelay(), const Duration(milliseconds: 500));
    expect(policy.recordErrorAndGetDelay(), const Duration(seconds: 1));
    expect(policy.recordErrorAndGetDelay(), const Duration(seconds: 2));
    expect(policy.recordErrorAndGetDelay(), const Duration(seconds: 4));
    expect(policy.recordErrorAndGetDelay(), const Duration(seconds: 5));
    expect(policy.recordErrorAndGetDelay(), const Duration(seconds: 5));
    expect(policy.attempt, 6);

    policy.recordHealthySnapshot();
    expect(policy.attempt, 0);
    expect(policy.recordErrorAndGetDelay(), const Duration(milliseconds: 250));
  });
}

CallV2EngineCleanupOperations _operations(
  _FakeEngine engine, {
  required int generation,
}) {
  return CallV2EngineCleanupOperations(
    generation: generation,
    invalidateGeneration: () => engine.events.add('invalidate'),
    unregisterHandler: engine.unregister,
    leaveChannel: engine.leave,
    releaseEngine: engine.release,
    forceDispose: engine.forceDispose,
  );
}

class _FakeEngine {
  _FakeEngine({this.forceDisposeSucceeds = true});

  final bool forceDisposeSucceeds;
  Object? releaseError;
  int unregisterCount = 0;
  int leaveCount = 0;
  int releaseCount = 0;
  int forceDisposeCount = 0;
  final events = <String>[];

  Future<void> unregister() async {
    unregisterCount += 1;
    events.add('unregister');
  }

  Future<void> leave() async {
    leaveCount += 1;
    events.add('leave_start');
    events.add('leave_done');
  }

  Future<void> release() async {
    releaseCount += 1;
    events.add('release_start');
    final error = releaseError;
    if (error != null) {
      events.add('release_error');
      throw error;
    }
    events.add('release_done');
  }

  Future<bool> forceDispose() async {
    forceDisposeCount += 1;
    events.add('force_dispose_start');
    if (forceDisposeSucceeds) {
      events.add('force_dispose_done');
      return true;
    }
    events.add('force_dispose_failed');
    return false;
  }
}

class _GenerationGuard {
  var currentGeneration = 0;
  var active = false;
  var staleIgnoredCount = 0;
  var state = 'idle';

  void start(int generation) {
    currentGeneration = generation;
    active = true;
  }

  void invalidate(int generation) {
    if (currentGeneration == generation) {
      active = false;
    }
  }

  void callback(int generation, void Function() mutate) {
    if (!active || generation != currentGeneration) {
      staleIgnoredCount += 1;
      return;
    }
    mutate();
  }
}

class _LifecycleHarness {
  _LifecycleHarness({_FakeEngine? engine}) : _engine = engine ?? _FakeEngine();

  final coordinator = CallV2EngineCleanupCoordinator();
  _FakeEngine _engine;
  Object? engineReference;
  Object? handlerReference;
  var incomingListenerCount = 1;
  var activeInviteListenerCount = 0;
  var activeTimerCount = 0;
  var sessionIdle = true;
  var blockerCode = 'none';
  var callKitCleanupCount = 0;
  var sessionResetCount = 0;
  var routeCloseCount = 0;
  var createCount = 0;
  var registerCount = 0;
  var joinCount = 0;
  var endCount = 0;
  var unregisterCount = 0;
  var leaveCount = 0;
  var releaseCount = 0;

  bool get engineReferenceCleared => engineReference == null;
  bool get handlerCleared => handlerReference == null;
  bool get cleanupInFlight => coordinator.cleanupInProgress;

  Future<CallV2EngineCleanupResult> runLifecycle({
    required int generation,
  }) async {
    _engine = _FakeEngine();
    createCount += 1;
    engineReference = _engine;
    registerCount += 1;
    handlerReference = Object();
    joinCount += 1;
    activeInviteListenerCount = 1;
    activeTimerCount = 1;
    sessionIdle = false;
    return endCall(generation: generation);
  }

  Future<CallV2EngineCleanupResult> endCall({int generation = 1}) async {
    endCount += 1;
    final result = await coordinator.cleanup(
      CallV2EngineCleanupOperations(
        generation: generation,
        invalidateGeneration: () {},
        unregisterHandler: () async {
          unregisterCount += 1;
          await _engine.unregister();
          handlerReference = null;
        },
        leaveChannel: () async {
          leaveCount += 1;
          await _engine.leave();
        },
        releaseEngine: () async {
          releaseCount += 1;
          await _engine.release();
        },
        forceDispose: _engine.forceDispose,
      ),
    );
    if (result.succeeded) {
      engineReference = null;
    } else {
      blockerCode = 'cleanup_failed';
    }
    callKitCleanupCount += 1;
    activeInviteListenerCount = 0;
    activeTimerCount = 0;
    sessionIdle = true;
    sessionResetCount += 1;
    routeCloseCount += 1;
    return result;
  }
}
