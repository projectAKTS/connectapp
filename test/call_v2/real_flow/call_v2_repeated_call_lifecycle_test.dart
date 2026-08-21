import 'dart:async';

import 'package:connect_app/call_v2/real_flow/call_v2_call_lifecycle_arbiter.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_engine_cleanup_coordinator.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_incoming_listener_backoff.dart';
import 'package:connect_app/screens/call/agora_call_screen.dart';
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

  test('never-completing release settles through force disposal', () async {
    final gate = _boundedGate();
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
    expect(decision.nextEngineAllowed, isTrue);
    expect(decision.blockerCode, 'none');
    expect(decision.previousCleanupAwaited, isTrue);
    expect(decision.previousCleanupWaitCompleted, isTrue);
    expect(engine.releaseCount, 1);
    expect(engine.forceDisposeCount, 1);
    expect(gate.cleanupInProgress, isFalse);
    expect(gate.previousResult?.releaseTimedOut, isTrue);
    expect(gate.previousResult?.forcedDisposalAttempted, isTrue);
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

  test('cleanup longer than UI wait lets immediate Call B wait and proceed',
      () async {
    final gate = _patientGate();
    final engineA = _FakeEngine()..releaseCompleter = Completer<void>();
    final harness = _ProcessLifecycleHarness(gate: gate);

    final endA = harness.endCall(
      operations: _operations(engineA, generation: 1),
      uiWait: Duration.zero,
    );
    final cleanupUiResult = await endA;
    expect(cleanupUiResult, isNull);
    expect(harness.routeCloseCount, 1);
    expect(harness.sessionResetCount, 1);
    expect(gate.cleanupInProgress, isTrue);

    var callBEngineCreated = false;
    final callB = gate.prepareNextEngine().then((decision) {
      if (decision.nextEngineAllowed) {
        callBEngineCreated = true;
      }
      return decision;
    });
    await Future<void>.delayed(Duration.zero);
    expect(callBEngineCreated, isFalse);

    engineA.releaseCompleter!.complete();
    final decision = await callB;

    expect(decision.nextEngineAllowed, isTrue);
    expect(decision.blockerCode, 'none');
    expect(decision.previousCleanupAwaited, isTrue);
    expect(decision.previousCleanupWaitCompleted, isTrue);
    expect(callBEngineCreated, isTrue);
    expect(engineA.releaseCount, 1);
    expect(gate.cleanupInProgress, isFalse);
    expect(gate.nextEngineAllowed, isTrue);
  });

  test('never-completing leave times out and cleanup still settles', () async {
    final gate = _boundedGate();
    final engine = _FakeEngine()..leaveCompleter = Completer<void>();

    final result = await gate.cleanup(_operations(engine, generation: 1));
    final decision = await gate.prepareNextEngine();

    expect(result.succeeded, isTrue);
    expect(result.leaveTimedOut, isTrue);
    expect(result.releaseTimedOut, isFalse);
    expect(engine.leaveCount, 1);
    expect(engine.releaseCount, 1);
    expect(engine.forceDisposeCount, 0);
    expect(gate.cleanupInProgress, isFalse);
    expect(decision.nextEngineAllowed, isTrue);
  });

  test('fast cleanup keeps unchanged immediate next-call path', () async {
    final gate = _boundedGate();
    final engine = _FakeEngine();

    final result = await gate.cleanup(_operations(engine, generation: 1));
    final decision = await gate.prepareNextEngine();

    expect(result.succeeded, isTrue);
    expect(result.unregisterTimedOut, isFalse);
    expect(result.leaveTimedOut, isFalse);
    expect(result.releaseTimedOut, isFalse);
    expect(result.forceDisposeTimedOut, isFalse);
    expect(decision.previousCleanupAwaited, isFalse);
    expect(decision.nextEngineAllowed, isTrue);
    expect(engine.events, [
      'invalidate',
      'unregister',
      'leave_start',
      'leave_done',
      'release_start',
      'release_done',
    ]);
  });

  test('immediate double next-call attempts share cleanup barrier', () async {
    final gate = _patientGate();
    final engineA = _FakeEngine()..releaseCompleter = Completer<void>();
    final cleanup = gate.cleanup(_operations(engineA, generation: 1));
    await Future<void>.delayed(Duration.zero);

    var engineCreations = 0;
    final first = gate.prepareNextEngine().then((decision) {
      if (decision.nextEngineAllowed && engineCreations == 0) {
        engineCreations += 1;
      }
      return decision;
    });
    final second = gate.prepareNextEngine().then((decision) {
      if (decision.nextEngineAllowed && engineCreations == 0) {
        engineCreations += 1;
      }
      return decision;
    });
    await Future<void>.delayed(Duration.zero);
    expect(engineCreations, 0);

    engineA.releaseCompleter!.complete();
    final decisions = await Future.wait([first, second]);
    await cleanup;

    expect(decisions.every((decision) => decision.nextEngineAllowed), isTrue);
    expect(
      decisions.every((decision) => decision.previousCleanupAwaited),
      isTrue,
    );
    expect(engineCreations, 1);
    expect(engineA.releaseCount, 1);
    expect(gate.cleanupInProgress, isFalse);
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

  test('twenty rapid sequential calls always restore reusable cleanup gate',
      () async {
    final gate = _patientGate();

    for (var i = 1; i <= 20; i += 1) {
      final before = await gate.prepareNextEngine();
      expect(before.nextEngineAllowed, isTrue, reason: 'before call $i');
      expect(gate.cleanupInProgress, isFalse, reason: 'before cleanup $i');

      final engine = _FakeEngine();
      final cleanup = gate.cleanup(_operations(engine, generation: i));
      Future<CallV2NextEngineDecision>? nextDecision;

      switch (i % 5) {
        case 0:
          engine.releaseCompleter = Completer<void>();
          nextDecision = gate.prepareNextEngine();
          await Future<void>.delayed(Duration.zero);
          expect(gate.cleanupInProgress, isTrue, reason: 'slow call $i');
          engine.releaseCompleter!.complete();
          break;
        case 1:
          break;
        case 2:
          engine.releaseError = StateError('release_failed');
          break;
        case 3:
          engine.leaveCompleter = Completer<void>();
          break;
        case 4:
          engine.releaseError = TimeoutException('release_failed');
          break;
      }

      final result = await cleanup;
      final after = nextDecision == null
          ? await gate.prepareNextEngine()
          : await nextDecision;

      expect(result.succeeded, isTrue, reason: 'cleanup $i');
      expect(after.nextEngineAllowed, isTrue, reason: 'after call $i');
      expect(gate.cleanupInProgress, isFalse, reason: 'settled $i');
      expect(gate.previousEngineGeneration, i, reason: 'generation $i');
      expect(engine.releaseCount, 1, reason: 'release $i');
      if (i % 5 == 2 || i % 5 == 4) {
        expect(engine.forceDisposeCount, 1, reason: 'force dispose $i');
      }
      if (i % 5 == 3) {
        expect(result.leaveTimedOut, isTrue, reason: 'leave timeout $i');
      }
      if (i % 5 == 0) {
        expect(after.previousCleanupAwaited, isTrue, reason: 'waited $i');
      }
    }

    expect(gate.previousEngineGeneration, 20);
    expect(gate.nextEngineAllowed, isTrue);
    expect(gate.cleanupInProgress, isFalse);
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

  test('terminal during token fetch prevents engine creation and join',
      () async {
    final harness = _SetupCancellationHarness();
    final token = Completer<void>();

    final setup = harness.runTokenThenJoin(token.future);
    harness.end();
    token.complete();
    await setup;

    expect(harness.engineCreateCount, 0);
    expect(harness.joinCount, 0);
    expect(harness.callbackAcceptance, isFalse);
    expect(harness.owner.setupCancelledCount, 1);
    expect(harness.owner.cancelledBeforeEngineCount, 1);
  });

  test('terminal immediately before engine creation blocks factory use',
      () async {
    final harness = _SetupCancellationHarness();
    final epoch = harness.begin();

    harness.end();
    expect(
      () => harness.cancelIfStale(
        epoch,
        CallV2ScreenSetupCancellationStage.beforeEngineCreation,
      ),
      throwsA(isA<_SetupCancelled>()),
    );

    expect(harness.engineCreateCount, 0);
    expect(harness.joinCount, 0);
    expect(harness.owner.cancelledBeforeEngineCount, 1);
  });

  test('terminal immediately after engine creation never enables callbacks',
      () async {
    final harness = _SetupCancellationHarness();
    final epoch = harness.begin();

    harness.createEngine();
    harness.end();
    expect(
      () => harness.cancelIfStale(
        epoch,
        CallV2ScreenSetupCancellationStage.afterEngineCreation,
      ),
      throwsA(isA<_SetupCancelled>()),
    );
    await harness.cleanup();

    expect(harness.engineCreateCount, 1);
    expect(harness.callbackAcceptance, isFalse);
    expect(harness.cleanupCount, 1);
    expect(harness.owner.terminalShutdownStarted, isTrue);
  });

  test('terminal while initialize is pending cleans once and never joins',
      () async {
    final harness = _SetupCancellationHarness();
    final initialize = Completer<void>();

    final setup = harness.runInitializeThenJoin(initialize.future);
    harness.end();
    initialize.complete();
    await setup;

    expect(harness.initializeCount, 1);
    expect(harness.joinCount, 0);
    expect(harness.cleanupCount, 1);
    expect(harness.callbackAcceptance, isFalse);
  });

  test('terminal while media setup is pending prevents join', () async {
    final harness = _SetupCancellationHarness();
    final media = Completer<void>();

    final setup = harness.runMediaThenJoin(media.future);
    harness.end();
    media.complete();
    await setup;

    expect(harness.mediaSetupCount, 1);
    expect(harness.joinCount, 0);
    expect(harness.cleanupCount, 1);
    expect(harness.owner.cancelledBeforeJoinCount, 1);
  });

  test('terminal while join is pending ignores late completion', () async {
    final harness = _SetupCancellationHarness();
    final join = Completer<void>();

    final setup = harness.runJoin(join.future);
    harness.end();
    join.complete();
    await setup;

    expect(harness.joinCount, 1);
    expect(harness.watchdogStartCount, 0);
    expect(harness.connectionPollCount, 0);
    expect(harness.managerProgressCount, 0);
    expect(harness.cleanupCount, 1);
    expect(harness.owner.lateSetupCompletionIgnoredCount, 1);
  });

  test('terminal callback quiesce cannot later be undone by engine attempt',
      () {
    final harness = _SetupCancellationHarness();
    final epoch = harness.begin();

    harness.end();
    harness.tryEnableCallbacks(epoch);

    expect(harness.callbackAcceptance, isFalse);
    expect(
      harness.owner.terminalShutdownStarted && harness.callbackAcceptance,
      isFalse,
    );
  });

  test('fifteen mixed setup cancellations keep next generation available',
      () async {
    for (var i = 0; i < 15; i += 1) {
      final harness = _SetupCancellationHarness();
      final held = Completer<void>();
      final setup = switch (i % 5) {
        0 => harness.runTokenThenJoin(held.future),
        1 => harness.runInitializeThenJoin(held.future),
        2 => harness.runMediaThenJoin(held.future),
        3 => harness.runJoin(held.future),
        _ => harness.runConnectedThenEnd(),
      };
      harness.end();
      if (!held.isCompleted) {
        held.complete();
      }
      await setup;

      expect(harness.callbackAcceptance, isFalse, reason: 'call $i');
      expect(harness.cleanupCount, lessThanOrEqualTo(1), reason: 'call $i');
      expect(harness.duplicateIncomingPromptCount, 0, reason: 'call $i');
      expect(harness.nextGenerationAvailable, isTrue, reason: 'call $i');
    }
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

  test('invite during teardown transfers directly into one prompt claim', () {
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

    final claimed = arbiter.completeTeardownAndClaimPending(
      outgoing.generation,
    );

    expect(claimed.claimed, isTrue);
    expect(claimed.inviteId, 'invite_b');
    expect(claimed.generation, greaterThan(outgoing.generation));
    expect(
        arbiter.ownsIncoming(
          generation: claimed.generation,
          inviteId: 'invite_b',
        ),
        isTrue);
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

    final pendingB = arbiter.reserveIncoming('invite_b');
    expect(pendingB.action, CallV2CallReservationAction.pending);
    expect(
      arbiter.reserveIncoming('invite_c').action,
      CallV2CallReservationAction.pending,
    );

    final claim = arbiter.completeTeardownAndClaimPending(outgoing.generation);
    expect(claim.claimed, isTrue);
    expect(claim.inviteId, 'invite_c');
    expect(arbiter.pendingIncomingCount, 0);
    expect(arbiter.displacedPendingSupersededCount, 1);
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
      expect(
        arbiter.completeTeardownAndClaimPending(reservation.generation).claimed,
        isFalse,
      );
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

  test('production lifecycle reset is monotonic and prevents ABA reuse', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final first = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: first.generation,
      inviteId: 'invite_a',
    );
    arbiter.markConnected(first.generation);

    arbiter.invalidateForProductionReset();
    final second = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: second.generation,
      inviteId: 'invite_b',
    );
    arbiter.incomingAccepted(
      generation: first.generation,
      inviteId: 'invite_a',
    );

    expect(second.generation, greaterThan(first.generation));
    expect(arbiter.state, CallV2CallLifecycleState.outgoingRinging);
    expect(arbiter.generation, second.generation);
  });

  test('ending suppresses same-generation late connected transition', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final active = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: active.generation,
      inviteId: 'invite_a',
    );
    arbiter.markJoining(active.generation);
    arbiter.markConnected(active.generation);
    arbiter.beginEnding(active.generation);

    final accepted = arbiter.markConnected(active.generation);

    expect(accepted, isFalse);
    expect(arbiter.state, CallV2CallLifecycleState.ending);
    expect(arbiter.lifecycleRegressionSuppressedCount, 1);
  });

  test('teardown suppresses same-generation late joining transition', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final active = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: active.generation,
      inviteId: 'invite_a',
    );
    arbiter.markJoining(active.generation);
    arbiter.markConnected(active.generation);
    arbiter.beginTeardown(active.generation);

    final accepted = arbiter.markJoining(active.generation);

    expect(accepted, isFalse);
    expect(arbiter.state, CallV2CallLifecycleState.teardown);
    expect(arbiter.lifecycleRegressionSuppressedCount, 1);
  });

  test('teardown cannot regress back to ending', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final active = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: active.generation,
      inviteId: 'invite_a',
    );
    arbiter.markJoining(active.generation);
    arbiter.markConnected(active.generation);
    arbiter.beginEnding(active.generation);
    arbiter.beginTeardown(active.generation);

    final accepted = arbiter.beginEnding(active.generation);

    expect(accepted, isFalse);
    expect(arbiter.state, CallV2CallLifecycleState.teardown);
    expect(arbiter.lifecycleRegressionSuppressedCount, 1);
  });

  test('connected suppresses same-generation late joining transition', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final active = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: active.generation,
      inviteId: 'invite_a',
    );
    arbiter.markJoining(active.generation);
    arbiter.markConnected(active.generation);

    final accepted = arbiter.markJoining(active.generation);

    expect(accepted, isFalse);
    expect(arbiter.state, CallV2CallLifecycleState.connected);
    expect(arbiter.lifecycleRegressionSuppressedCount, 1);
  });

  test('old pending cannot win after newer pending is atomically claimed', () {
    final arbiter = CallV2CallLifecycleArbiter();

    final active = arbiter.reserveOutgoing();
    arbiter.outgoingInviteCreated(
      generation: active.generation,
      inviteId: 'invite_a',
    );
    arbiter.markConnected(active.generation);
    arbiter.beginTeardown(active.generation);
    arbiter.reserveIncoming('invite_b');
    arbiter.reserveIncoming('invite_c');

    final claim = arbiter.completeTeardownAndClaimPending(active.generation);
    final old = arbiter.reserveIncoming('invite_b');

    expect(claim.claimed, isTrue);
    expect(claim.inviteId, 'invite_c');
    expect(old.action, CallV2CallReservationAction.busyDecline);
    expect(
        arbiter.ownsIncoming(
          generation: claim.generation,
          inviteId: 'invite_c',
        ),
        isTrue);
    expect(arbiter.pendingIncomingCount, 0);
  });

  test('fifteen rapid lifecycles keep one owner through handoff points', () {
    final arbiter = CallV2CallLifecycleArbiter();

    for (var i = 1; i <= 15; i += 1) {
      final active = arbiter.reserveOutgoing();
      arbiter.outgoingInviteCreated(
        generation: active.generation,
        inviteId: 'active_$i',
      );
      arbiter.markConnected(active.generation);
      arbiter.beginEnding(active.generation);

      expect(
        arbiter.reserveIncoming('ending_next_$i').action,
        CallV2CallReservationAction.pending,
      );
      arbiter.beginTeardown(active.generation);
      expect(
        arbiter.reserveIncoming('teardown_next_$i').action,
        CallV2CallReservationAction.pending,
      );

      final claim = arbiter.completeTeardownAndClaimPending(active.generation);
      expect(claim.claimed, isTrue, reason: 'handoff $i');
      expect(claim.inviteId, 'teardown_next_$i');
      expect(arbiter.activePromptCount, 1, reason: 'handoff $i');
      expect(arbiter.pendingIncomingCount, 0, reason: 'handoff $i');
      arbiter.incomingDeclined(
        generation: claim.generation,
        inviteId: claim.inviteId!,
      );
      expect(arbiter.isIdle, isTrue, reason: 'after handoff $i');
    }
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

CallV2ProcessEngineCleanupGate _boundedGate() {
  return CallV2ProcessEngineCleanupGate(
    coordinator: CallV2EngineCleanupCoordinator(
      unregisterTimeout: const Duration(milliseconds: 10),
      leaveTimeout: const Duration(milliseconds: 10),
      releaseTimeout: const Duration(milliseconds: 10),
      forceDisposeTimeout: const Duration(milliseconds: 10),
    ),
    previousCleanupWaitTimeout: const Duration(milliseconds: 80),
  );
}

CallV2ProcessEngineCleanupGate _patientGate() {
  return CallV2ProcessEngineCleanupGate(
    coordinator: CallV2EngineCleanupCoordinator(
      unregisterTimeout: const Duration(milliseconds: 50),
      leaveTimeout: const Duration(milliseconds: 50),
      releaseTimeout: const Duration(seconds: 1),
      forceDisposeTimeout: const Duration(milliseconds: 50),
    ),
    previousCleanupWaitTimeout: const Duration(seconds: 2),
  );
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
  Completer<void>? leaveCompleter;
  Completer<void>? releaseCompleter;
  Completer<bool>? forceDisposeCompleter;
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
    final completer = leaveCompleter;
    if (completer != null) {
      await completer.future;
    }
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
    final completer = forceDisposeCompleter;
    if (completer != null) {
      final completed = await completer.future;
      if (completed) {
        events.add('force_dispose_done');
      } else {
        events.add('force_dispose_failed');
      }
      return completed;
    }
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

class _SetupCancellationHarness {
  final owner = CallV2ScreenSetupCancellationOwner();
  var callbackAcceptance = false;
  var engineCreateCount = 0;
  var initializeCount = 0;
  var mediaSetupCount = 0;
  var joinCount = 0;
  var cleanupCount = 0;
  var watchdogStartCount = 0;
  var connectionPollCount = 0;
  var managerProgressCount = 0;
  var duplicateIncomingPromptCount = 0;
  var nextGenerationAvailable = false;
  var _enginePresent = false;

  int begin() => owner.beginSetup();

  void end() {
    owner.beginTerminalShutdown();
    callbackAcceptance = false;
  }

  void cancelIfStale(
    int epoch,
    CallV2ScreenSetupCancellationStage stage,
  ) {
    if (owner.cancelIfStale(epoch, stage)) {
      throw const _SetupCancelled();
    }
  }

  Future<void> runTokenThenJoin(Future<void> token) async {
    final epoch = begin();
    try {
      await token;
      cancelIfStale(epoch, CallV2ScreenSetupCancellationStage.tokenFetch);
      createEngine();
      tryEnableCallbacks(epoch);
      await _joinIfCurrent(epoch, Future<void>.value());
    } on _SetupCancelled {
      await cleanup();
    }
  }

  Future<void> runInitializeThenJoin(Future<void> initialize) async {
    final epoch = begin();
    try {
      createEngine();
      tryEnableCallbacks(epoch);
      initializeCount += 1;
      await initialize;
      cancelIfStale(
        epoch,
        CallV2ScreenSetupCancellationStage.engineInitialize,
      );
      await _joinIfCurrent(epoch, Future<void>.value());
    } on _SetupCancelled {
      await cleanup();
    }
  }

  Future<void> runMediaThenJoin(Future<void> mediaSetup) async {
    final epoch = begin();
    try {
      createEngine();
      tryEnableCallbacks(epoch);
      mediaSetupCount += 1;
      await mediaSetup;
      cancelIfStale(epoch, CallV2ScreenSetupCancellationStage.mediaSetup);
      await _joinIfCurrent(epoch, Future<void>.value());
    } on _SetupCancelled {
      await cleanup();
    }
  }

  Future<void> runJoin(Future<void> join) async {
    final epoch = begin();
    try {
      createEngine();
      tryEnableCallbacks(epoch);
      cancelIfStale(epoch, CallV2ScreenSetupCancellationStage.beforeJoin);
      await _joinIfCurrent(epoch, join);
      cancelIfStale(epoch, CallV2ScreenSetupCancellationStage.afterJoin);
      connectionPollCount += 1;
      watchdogStartCount += 1;
      managerProgressCount += 1;
    } on _SetupCancelled {
      await cleanup();
    }
  }

  Future<void> runConnectedThenEnd() async {
    final epoch = begin();
    try {
      createEngine();
      tryEnableCallbacks(epoch);
      await _joinIfCurrent(epoch, Future<void>.value());
      managerProgressCount += 1;
      cancelIfStale(epoch, CallV2ScreenSetupCancellationStage.postJoin);
    } on _SetupCancelled {
      await cleanup();
    }
  }

  void createEngine() {
    engineCreateCount += 1;
    _enginePresent = true;
  }

  void tryEnableCallbacks(int epoch) {
    if (!owner.setupStillCurrent(epoch)) {
      owner.cancelIfStale(
        epoch,
        CallV2ScreenSetupCancellationStage.afterEngineCreation,
      );
      callbackAcceptance = false;
      return;
    }
    callbackAcceptance = true;
  }

  Future<void> _joinIfCurrent(int epoch, Future<void> join) async {
    cancelIfStale(epoch, CallV2ScreenSetupCancellationStage.beforeJoin);
    joinCount += 1;
    await join;
  }

  Future<void> cleanup() async {
    if (!_enginePresent) {
      nextGenerationAvailable = true;
      return;
    }
    if (cleanupCount == 0) {
      cleanupCount += 1;
      _enginePresent = false;
    }
    nextGenerationAvailable = true;
  }
}

class _SetupCancelled implements Exception {
  const _SetupCancelled();
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
