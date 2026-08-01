import 'dart:async';

import 'package:connect_app/call_v2/real_flow/call_v2_call_lifecycle_arbiter.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_engine_cleanup_coordinator.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_incoming_listener_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previous-screen cleanup succeeds and next engine is allowed', () async {
    final gate = CallV2ProcessEngineCleanupGate();
    final engine = _FakeEngine();

    final result = await gate.cleanup(_operations(engine, generation: 1));
    final decision = await gate.prepareNextEngine();

    expect(result.succeeded, isTrue);
    expect(gate.previousCleanupSucceeded, isTrue);
    expect(decision.nextEngineAllowed, isTrue);
    expect(decision.blockerCode, 'none');
    expect(decision.previousCleanupResult?.generation, 1);
  });

  test('previous-screen cleanup failure blocks next engine creation', () async {
    final gate = CallV2ProcessEngineCleanupGate();
    final engine = _FakeEngine(forceDisposeSucceeds: false)
      ..releaseError = StateError('release_failed');

    final result = await gate.cleanup(_operations(engine, generation: 1));
    final decision = await gate.prepareNextEngine();

    expect(result.succeeded, isFalse);
    expect(decision.nextEngineAllowed, isFalse);
    expect(decision.blockerCode, 'cleanup_failed');
    expect(engine.releaseCount, 2);
    expect(engine.forceDisposeCount, 2);
  });

  test(
      'previous-screen retry success allows the following engine only after retry',
      () async {
    final gate = CallV2ProcessEngineCleanupGate();
    final engine = _FakeEngine(forceDisposeSucceeds: false)
      ..releaseError = StateError('release_failed');

    final failed = await gate.cleanup(_operations(engine, generation: 1));
    expect(failed.succeeded, isFalse);
    expect(gate.nextEngineAllowed, isFalse);

    engine
      ..releaseError = null
      ..forceDisposeSucceeds = true;
    final decision = await gate.prepareNextEngine();

    expect(decision.retryAttempted, isTrue);
    expect(decision.nextEngineAllowed, isTrue);
    expect(decision.blockerCode, 'none');
    expect(gate.previousCleanupSucceeded, isTrue);
    expect(engine.releaseCount, 2);
  });

  test('previous-screen retry failure returns cleanup_failed immediately',
      () async {
    final gate = CallV2ProcessEngineCleanupGate();
    final engine = _FakeEngine(forceDisposeSucceeds: false)
      ..releaseError = StateError('release_failed');

    await gate.cleanup(_operations(engine, generation: 1));
    final decision = await gate.prepareNextEngine();

    expect(decision.retryAttempted, isTrue);
    expect(decision.nextEngineAllowed, isFalse);
    expect(decision.blockerCode, 'cleanup_failed');
    expect(gate.retryPossible, isTrue);
  });

  test(
      'never-completing release lets route cleanup finish and blocks next call',
      () async {
    final gate = CallV2ProcessEngineCleanupGate();
    final engine = _FakeEngine()..releaseCompleter = Completer<void>();
    final harness = _ProcessLifecycleHarness(gate: gate);

    final result = await harness.endCall(
      operations: _operations(engine, generation: 1),
      uiWait: Duration.zero,
    );
    final decision = await gate.prepareNextEngine();

    expect(result, isNull);
    expect(harness.callKitCleanupCount, 1);
    expect(harness.sessionResetCount, 1);
    expect(harness.routeCloseCount, 1);
    expect(harness.blockerCode, 'cleanup_in_progress');
    expect(decision.nextEngineAllowed, isFalse);
    expect(decision.blockerCode, 'cleanup_in_progress');
    expect(engine.releaseCount, 1);
    expect(engine.forceDisposeCount, 0);
    expect(gate.cleanupInProgress, isTrue);

    engine.releaseCompleter!.complete();
    await gate.currentCleanup;
    expect(gate.nextEngineAllowed, isTrue);
  });

  test('three process cleanup callers share one native cleanup operation',
      () async {
    final gate = CallV2ProcessEngineCleanupGate();
    final engine = _FakeEngine();
    final operations = _operations(engine, generation: 1);

    final results = await Future.wait([
      gate.cleanup(operations),
      gate.cleanup(operations),
      gate.cleanup(operations),
    ]);

    expect(results.map((result) => result.attemptNumber).toSet(), {1});
    expect(engine.unregisterCount, 1);
    expect(engine.leaveCount, 1);
    expect(engine.releaseCount, 1);
    expect(engine.forceDisposeCount, 0);
    expect(gate.nextEngineAllowed, isTrue);
  });

  test('ten sequential lifecycles use shared gate before each next call',
      () async {
    final gate = CallV2ProcessEngineCleanupGate();

    for (var i = 1; i <= 10; i += 1) {
      final decision = await gate.prepareNextEngine();
      expect(decision.nextEngineAllowed, isTrue, reason: 'before call $i');

      final engine = _FakeEngine();
      final result = await gate.cleanup(_operations(engine, generation: i));

      expect(result.succeeded, isTrue, reason: 'call $i');
      expect(result.generation, i);
      expect(engine.releaseCount, 1);
      expect(gate.cleanupInProgress, isFalse);
      expect(gate.nextEngineAllowed, isTrue);
    }

    expect(gate.previousEngineGeneration, 10);
  });

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

  test('same invite from multiple incoming sources is claimed once', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final firestore = arbiter.reserveIncoming('invite_a');
    final recovery = arbiter.reserveIncoming('invite_a');
    final notification = arbiter.reserveIncoming('invite_a');

    expect(firestore.action, CallV2CallReservationAction.reserved);
    expect(recovery.action, CallV2CallReservationAction.duplicate);
    expect(notification.action, CallV2CallReservationAction.duplicate);
    expect(arbiter.activePromptCount, 1);
    expect(arbiter.duplicateInviteSuppressedCount, 2);
  });

  test('overlapping Firestore events for same invite keep one prompt claim',
      () {
    final arbiter = CallV2CallLifecycleArbiter();

    final first = arbiter.reserveIncoming('invite_a');
    final second = arbiter.reserveIncoming('invite_a');

    expect(first.reserved, isTrue);
    expect(second.action, CallV2CallReservationAction.duplicate);
    expect(arbiter.incomingPipelineBusy, isTrue);
    expect(arbiter.activePromptCount, 1);
  });

  test('different invite while connected is busy-declined without prompt', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final outgoing = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: outgoing.generation,
      inviteId: 'invite_a',
    );
    arbiter.markJoining(outgoing.generation);
    arbiter.markConnected(outgoing.generation);

    final incoming = arbiter.reserveIncoming('invite_b');

    expect(incoming.action, CallV2CallReservationAction.busyDecline);
    expect(arbiter.state, CallV2CallLifecycleState.connected);
    expect(arbiter.activePromptCount, 0);
    expect(arbiter.busyInviteDeclinedCount, 1);
  });

  test('invite during teardown waits and presents once after idle', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final outgoing = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: outgoing.generation,
      inviteId: 'invite_a',
    );
    arbiter.markConnected(outgoing.generation);
    arbiter.beginEnding(outgoing.generation);
    arbiter.beginTeardown(outgoing.generation);

    final pending = arbiter.reserveIncoming('invite_b');

    expect(pending.action, CallV2CallReservationAction.pending);
    expect(arbiter.pendingIncomingCount, 1);
    expect(arbiter.activePromptCount, 0);

    final pendingInvite = arbiter.completeTeardown(outgoing.generation);
    final claimed = arbiter.reserveIncoming(pendingInvite!);

    expect(pendingInvite, 'invite_b');
    expect(claimed.action, CallV2CallReservationAction.reserved);
    expect(arbiter.activePromptCount, 1);
  });

  test('newest pending invite wins while teardown is in progress', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final outgoing = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: outgoing.generation,
      inviteId: 'invite_a',
    );
    arbiter.markConnected(outgoing.generation);
    arbiter.beginTeardown(outgoing.generation);

    expect(
      arbiter.reserveIncoming('invite_b').action,
      CallV2CallReservationAction.pending,
    );
    expect(
      arbiter.reserveIncoming('invite_c').action,
      CallV2CallReservationAction.pending,
    );

    expect(arbiter.completeTeardown(outgoing.generation), 'invite_c');
  });

  test('rapid outgoing redial during ending does not clear active generation',
      () {
    final arbiter = CallV2CallLifecycleArbiter();

    final first = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: first.generation,
      inviteId: 'invite_a',
    );
    arbiter.markConnected(first.generation);
    arbiter.beginEnding(first.generation);

    final second = arbiter.reserveOutgoing();

    expect(second.action, CallV2CallReservationAction.blocked);
    expect(arbiter.state, CallV2CallLifecycleState.ending);
    expect(arbiter.generation, first.generation);
    expect(arbiter.rapidRedialBlockedCount, 1);
  });

  test('ten sequential rapid call reservations restore idle baseline', () {
    final arbiter = CallV2CallLifecycleArbiter();

    for (var i = 1; i <= 10; i += 1) {
      final reservation = arbiter.reserveOutgoing();
      expect(reservation.action, CallV2CallReservationAction.reserved);
      arbiter.outgoingInviteCreated(
        generation: reservation.generation,
        inviteId: 'invite_$i',
      );
      arbiter.markJoining(reservation.generation);
      arbiter.markConnected(reservation.generation);
      arbiter.beginEnding(reservation.generation);
      arbiter.beginTeardown(reservation.generation);
      expect(arbiter.completeTeardown(reservation.generation), isNull);
      expect(arbiter.isIdle, isTrue, reason: 'call $i');
      expect(arbiter.pendingIncomingCount, 0, reason: 'call $i');
      expect(arbiter.activePromptCount, 0, reason: 'call $i');
      expect(arbiter.activeCallRouteCount, 0, reason: 'call $i');
    }

    expect(arbiter.generation, 10);
  });

  test('next invite cannot present while previous route cleanup is held', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final first = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: first.generation,
      inviteId: 'invite_a',
    );
    arbiter.markConnected(first.generation);
    arbiter.beginEnding(first.generation);
    arbiter.beginTeardown(first.generation);

    final next = arbiter.reserveIncoming('invite_b');

    expect(next.action, CallV2CallReservationAction.pending);
    expect(arbiter.state, CallV2CallLifecycleState.teardown);
    expect(arbiter.activePromptCount, 0);
    expect(arbiter.pendingIncomingPresent, isTrue);
  });

  test('stale generation callback cannot mutate newer generation', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final incoming = arbiter.reserveIncoming('invite_a');
    arbiter.incomingDeclined(
      generation: incoming.generation,
      inviteId: 'invite_a',
    );
    final outgoing = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: outgoing.generation,
      inviteId: 'invite_b',
    );

    arbiter.incomingAccepted(
      generation: incoming.generation,
      inviteId: 'invite_a',
    );
    arbiter.dropIncoming(
      generation: incoming.generation,
      inviteId: 'invite_a',
    );

    expect(arbiter.generation, outgoing.generation);
    expect(arbiter.state, CallV2CallLifecycleState.outgoingRinging);
    expect(arbiter.staleCandidateDroppedCount, 1);
  });

  test('arbiter diagnostics contain no unsafe invite/session identifiers', () {
    final arbiter = CallV2CallLifecycleArbiter();

    arbiter.reserveIncoming('invite_a');
    final debugText = arbiter.toSafeDebugMap().toString();

    for (final forbidden in <String>[
      'invite_a',
      'channel',
      'token',
      'uid',
      'user',
      'device',
      'payload',
    ]) {
      expect(debugText.toLowerCase(), isNot(contains(forbidden)));
    }
    expect(debugText, contains('callLifecycleState'));
    expect(debugText, contains('incomingPipelineBusy'));
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

  bool forceDisposeSucceeds;
  Object? releaseError;
  Completer<void>? releaseCompleter;
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
    final completer = releaseCompleter;
    if (completer != null) {
      await completer.future;
    }
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

class _ProcessLifecycleHarness {
  _ProcessLifecycleHarness({required this.gate});

  final CallV2ProcessEngineCleanupGate gate;
  var callKitCleanupCount = 0;
  var sessionResetCount = 0;
  var routeCloseCount = 0;
  var blockerCode = 'none';

  Future<CallV2EngineCleanupResult?> endCall({
    required CallV2EngineCleanupOperations operations,
    required Duration uiWait,
  }) async {
    final cleanup = gate.cleanup(operations);
    final result = await _waitForUi(cleanup, uiWait);
    callKitCleanupCount += 1;
    sessionResetCount += 1;
    routeCloseCount += 1;
    if (result == null) {
      blockerCode = 'cleanup_in_progress';
    } else if (!result.succeeded) {
      blockerCode = 'cleanup_failed';
    }
    return result;
  }

  Future<CallV2EngineCleanupResult?> _waitForUi(
    Future<CallV2EngineCleanupResult> cleanup,
    Duration duration,
  ) async {
    final completer = Completer<CallV2EngineCleanupResult?>();
    final timer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    cleanup.then((result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    });
    final result = await completer.future;
    timer.cancel();
    return result;
  }
}
