import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/diagnostics/call_v2_durable_boundary_diagnostics.dart';
import 'package:connect_app/services/call_session_manager.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';

class _MemoryStore implements CallV2DurableDiagnosticStore {
  String? encoded;
  bool failWrites = false;

  @override
  Future<String?> read() async => encoded;

  @override
  Future<void> write(String value) async {
    if (failWrites) throw StateError('simulated diagnostics failure');
    encoded = value;
  }
}

class _BlockingStore implements CallV2DurableDiagnosticStore {
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> releaseWrite = Completer<void>();
  String? encoded;

  @override
  Future<String?> read() async => encoded;

  @override
  Future<void> write(String value) async {
    if (!writeStarted.isCompleted) writeStarted.complete();
    await releaseWrite.future;
    encoded = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('file durable store atomic replacement', () {
    late Directory temporaryDirectory;
    late File target;

    setUp(() async {
      temporaryDirectory =
          await Directory.systemTemp.createTemp('call-v2-diagnostics-');
      target = File('${temporaryDirectory.path}/diagnostics.json');
    });

    tearDown(() async {
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test('replacement failure before commit preserves previous valid file',
        () async {
      const previous = '{"version":1,"events":[{"sequence":1}]}';
      const replacement = '{"version":1,"events":[{"sequence":2}]}';
      await target.writeAsString(previous, flush: true);
      final store = CallV2FileDurableDiagnosticStore.debugForTest(
        targetFile: target,
        beforeReplace: (preparedSnapshot, targetFile) async {
          expect(await preparedSnapshot.readAsString(), replacement);
          expect(await targetFile.readAsString(), previous);
          throw StateError('simulated pre-commit replacement failure');
        },
      );

      await expectLater(store.write(replacement), throwsStateError);

      expect(await target.readAsString(), previous);
      expect(jsonDecode(await target.readAsString()), isA<Map>());
      expect(
        (await temporaryDirectory.list().toList())
            .where((entity) => entity.path != target.path),
        isEmpty,
      );
    });

    test('partial prepared write cannot expose a truncated target', () async {
      const previous = '{"version":1,"events":[{"sequence":1}]}';
      const replacement =
          '{"version":1,"events":[{"sequence":1},{"sequence":2}]}';
      await target.writeAsString(previous, flush: true);
      final store = CallV2FileDurableDiagnosticStore.debugForTest(
        targetFile: target,
        beforeReplace: (preparedSnapshot, targetFile) async {
          await preparedSnapshot.writeAsString('{"version":', flush: true);
          expect(await targetFile.readAsString(), previous);
          throw StateError('simulated interrupted staging write');
        },
      );

      await expectLater(store.write(replacement), throwsStateError);

      final persisted = await target.readAsString();
      expect(persisted, previous);
      expect(jsonDecode(persisted), isA<Map>());
      expect(persisted, isNot(equals('{"version":')));
      expect(
        (await temporaryDirectory.list().toList())
            .where((entity) => entity.path != target.path),
        isEmpty,
      );
    });

    test('successful real filesystem replacement publishes full snapshot',
        () async {
      const previous = '{"version":1,"events":[{"sequence":1}]}';
      const replacement =
          '{"version":1,"events":[{"sequence":1},{"sequence":2}]}';
      await target.writeAsString(previous, flush: true);
      final store = CallV2FileDurableDiagnosticStore.debugForTest(
        targetFile: target,
      );

      await store.write(replacement);

      expect(await target.readAsString(), replacement);
      expect(
        (jsonDecode(await target.readAsString())
            as Map<String, dynamic>)['events'],
        hasLength(2),
      );
    });

    test('terminal route outcome timeline survives recorder restart', () async {
      final store = CallV2FileDurableDiagnosticStore.debugForTest(
        targetFile: target,
      );
      final recorder = CallV2DurableDiagnosticRecorder(
        store: store,
        appLifecycleState: () => 'resumed',
      );
      const inviteId = 'private-terminal-invite';
      const exactId = 'private-terminal-callkit';

      recorder.record(
        CallV2DurableDiagnosticStage.terminalRouteExitRequested,
        inviteIdentity: inviteId,
        exactCallkitIdentity: exactId,
        outcome: CallV2DurableDiagnosticOutcome.allowed,
        attempt: 0,
        lifecycleGeneration: 12,
        generationCurrent: true,
      );
      recorder.record(
        CallV2DurableDiagnosticStage.terminalRouteCovered,
        inviteIdentity: inviteId,
        exactCallkitIdentity: exactId,
        outcome: CallV2DurableDiagnosticOutcome.routeCovered,
        lifecycleGeneration: 12,
        generationCurrent: true,
      );
      recorder.record(
        CallV2DurableDiagnosticStage.terminalExactRouteRemovalRequested,
        inviteIdentity: inviteId,
        exactCallkitIdentity: exactId,
        outcome: CallV2DurableDiagnosticOutcome.allowed,
        lifecycleGeneration: 12,
        generationCurrent: true,
      );
      recorder.record(
        CallV2DurableDiagnosticStage.terminalExactRouteRemovalCompleted,
        inviteIdentity: inviteId,
        exactCallkitIdentity: exactId,
        outcome: CallV2DurableDiagnosticOutcome.completed,
        lifecycleGeneration: 12,
        generationCurrent: true,
      );
      recorder.record(
        CallV2DurableDiagnosticStage.terminalRouteDisposed,
        inviteIdentity: inviteId,
        exactCallkitIdentity: exactId,
        outcome: CallV2DurableDiagnosticOutcome.completed,
        lifecycleGeneration: 12,
        generationCurrent: true,
      );
      await recorder.flush();

      final restarted = CallV2DurableDiagnosticRecorder(
        store: store,
        appLifecycleState: () => 'unknown',
      );
      final events = await restarted.readPersisted();
      expect(
        events.map((event) => event.stage),
        orderedEquals(<CallV2DurableDiagnosticStage>[
          CallV2DurableDiagnosticStage.terminalRouteExitRequested,
          CallV2DurableDiagnosticStage.terminalRouteCovered,
          CallV2DurableDiagnosticStage.terminalExactRouteRemovalRequested,
          CallV2DurableDiagnosticStage.terminalExactRouteRemovalCompleted,
          CallV2DurableDiagnosticStage.terminalRouteDisposed,
        ]),
      );
      expect(events.map((event) => event.sequence),
          orderedEquals(<int>[1, 2, 3, 4, 5]));
      expect(
          events.map((event) => event.lifecycleGeneration).toSet(), <int?>{12});
      expect(events.map((event) => event.generationCurrent).toSet(),
          <bool?>{true});
      expect(
          events.map((event) => event.callFingerprint).toSet(), hasLength(1));
      expect(events.map((event) => event.exactCallkitFingerprint).toSet(),
          hasLength(1));

      final persisted = await target.readAsString();
      expect(persisted, isNot(contains(inviteId)));
      expect(persisted, isNot(contains(exactId)));
      expect(persisted, isNot(contains('token')));
      expect(persisted, isNot(contains('channel')));
      expect(persisted, isNot(contains('payload')));
    });
  });

  test('process restart preserves ordered A B C histories independently',
      () async {
    final store = _MemoryStore();
    var now = DateTime.utc(2026, 10, 15, 1, 11, 40);
    final first = CallV2DurableDiagnosticRecorder(
      store: store,
      now: () => now,
      appLifecycleState: () => 'paused',
    );

    for (final call in <String>['invite-a', 'invite-b', 'invite-c']) {
      first.record(
        CallV2DurableDiagnosticStage.flutterAcceptBridgeReceived,
        inviteIdentity: call,
        exactCallkitIdentity: 'exact-$call',
      );
      now = now.add(const Duration(milliseconds: 10));
      first.record(
        CallV2DurableDiagnosticStage.acceptedRecoveryHandoffStarted,
        inviteIdentity: call,
        exactCallkitIdentity: 'exact-$call',
      );
      now = now.add(const Duration(seconds: 1));
    }
    await first.flush();

    final restarted = CallV2DurableDiagnosticRecorder(
      store: store,
      now: () => now,
      appLifecycleState: () => 'resumed',
    );
    final events = await restarted.readPersisted();

    expect(events.map((event) => event.sequence),
        orderedEquals(<int>[1, 2, 3, 4, 5, 6]));
    expect(events.map((event) => event.callFingerprint).toSet(), hasLength(3));
    expect(
      events.map((event) => event.exactCallkitFingerprint).toSet(),
      hasLength(3),
    );
    expect(events.take(2).map((event) => event.callFingerprint).toSet(),
        hasLength(1));
    expect(events.skip(2).take(2).map((event) => event.callFingerprint).toSet(),
        hasLength(1));
    expect(events.skip(4).map((event) => event.callFingerprint).toSet(),
        hasLength(1));
  });

  test('blocked transaction retains its last entered checkpoint', () async {
    final store = _MemoryStore();
    final recorder = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'paused',
    );

    recorder.record(
      CallV2DurableDiagnosticStage.transactionRunInvoked,
      inviteIdentity: 'private-invite',
      exactCallkitIdentity: 'private-exact',
      attempt: 1,
      lifecycleGeneration: 7,
      generationCurrent: true,
    );
    recorder.record(
      CallV2DurableDiagnosticStage.transactionCallbackEntered,
      inviteIdentity: 'private-invite',
      exactCallkitIdentity: 'private-exact',
      attempt: 1,
      lifecycleGeneration: 7,
      generationCurrent: true,
    );
    await recorder.flush();

    final events = await recorder.readPersisted();
    expect(events.last.stage,
        CallV2DurableDiagnosticStage.transactionCallbackEntered);
    expect(events.last.attempt, 1);
    expect(events.last.lifecycleGeneration, 7);
    expect(events.last.generationCurrent, isTrue);
  });

  test('completed transaction retains authoritative result', () async {
    final recorder = CallV2DurableDiagnosticRecorder(
      store: _MemoryStore(),
      appLifecycleState: () => 'resumed',
    );

    recorder.record(
      CallV2DurableDiagnosticStage.transactionSnapshotObtained,
      inviteIdentity: 'private-invite',
      outcome: CallV2DurableDiagnosticOutcome.ringing,
    );
    recorder.record(
      CallV2DurableDiagnosticStage.transactionCompleted,
      inviteIdentity: 'private-invite',
      outcome: CallV2DurableDiagnosticOutcome.accepted,
    );
    recorder.record(
      CallV2DurableDiagnosticStage.transactionResultReturned,
      inviteIdentity: 'private-invite',
      outcome: CallV2DurableDiagnosticOutcome.accepted,
    );

    final events = await recorder.readPersisted();
    expect(events.last.stage,
        CallV2DurableDiagnosticStage.transactionResultReturned);
    expect(events.last.outcome, CallV2DurableDiagnosticOutcome.accepted);
  });

  test('explicit lifecycle checkpoint preserves the observed safe state',
      () async {
    final recorder = CallV2DurableDiagnosticRecorder(
      store: _MemoryStore(),
      appLifecycleState: () => 'resumed',
    );

    recorder.record(
      CallV2DurableDiagnosticStage.appLifecycleChanged,
      inviteIdentity: 'private-invite',
      exactCallkitIdentity: 'private-exact',
      appLifecycleState: 'paused',
    );

    final event = (await recorder.readPersisted()).single;
    expect(event.stage, CallV2DurableDiagnosticStage.appLifecycleChanged);
    expect(event.appLifecycleState, 'paused');
  });

  test('timeout and exception categories contain no raw sensitive values',
      () async {
    final store = _MemoryStore();
    final recorder = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'background-invalid-value',
    );

    recorder.record(
      CallV2DurableDiagnosticStage.transactionFailed,
      inviteIdentity: 'invite-secret-value',
      exactCallkitIdentity: 'uuid-secret-value',
      outcome: CallV2DurableDiagnosticOutcome.timeout,
    );
    recorder.record(
      CallV2DurableDiagnosticStage.transactionRetryEntered,
      inviteIdentity: 'invite-secret-value',
      exactCallkitIdentity: 'uuid-secret-value',
      outcome: CallV2DurableDiagnosticOutcome.firebaseUnavailable,
    );
    await recorder.flush();

    final encoded = store.encoded!;
    expect(encoded, isNot(contains('invite-secret-value')));
    expect(encoded, isNot(contains('uuid-secret-value')));
    expect(encoded, isNot(contains('token')));
    expect(encoded, isNot(contains('channel')));
    expect(encoded, isNot(contains('payload')));
    expect(encoded, isNot(contains('credential')));
    final events = await recorder.readPersisted();
    expect(
      events.map((event) => event.appLifecycleState).toSet(),
      <String>{'unknown'},
    );
    expect(events.last.outcome,
        CallV2DurableDiagnosticOutcome.firebaseUnavailable);
  });

  test('count age and encoded size retention remain bounded', () async {
    final store = _MemoryStore();
    var now = DateTime.utc(2026, 1, 1);
    final recorder = CallV2DurableDiagnosticRecorder(
      store: store,
      now: () => now,
      appLifecycleState: () => 'resumed',
      maximumEvents: 4,
      maximumEncodedBytes: 900,
      maximumAge: const Duration(days: 2),
    );

    recorder.record(
      CallV2DurableDiagnosticStage.flutterAcceptBridgeReceived,
      inviteIdentity: 'expired-call',
    );
    now = now.add(const Duration(days: 3));
    for (var index = 0; index < 8; index += 1) {
      recorder.record(
        CallV2DurableDiagnosticStage.acceptedRecoveryHandoffStarted,
        inviteIdentity: 'call-$index',
      );
    }
    await recorder.flush();

    final events = await recorder.readPersisted();
    expect(events.length, lessThanOrEqualTo(4));
    expect(store.encoded!.length, lessThanOrEqualTo(900));
    expect(
      events.map((event) => event.callFingerprint),
      isNot(contains(CallV2DurableDiagnosticRecorder.fingerprint(
        'expired-call',
        namespace: 'call',
      ))),
    );
  });

  test('old cleanup append cannot overwrite newer call identity', () async {
    final recorder = CallV2DurableDiagnosticRecorder(
      store: _MemoryStore(),
      appLifecycleState: () => 'resumed',
    );
    recorder.record(
      CallV2DurableDiagnosticStage.mediaRuntimeStarted,
      inviteIdentity: 'call-b',
      exactCallkitIdentity: 'exact-b',
    );
    recorder.record(
      CallV2DurableDiagnosticStage.mediaCleanupCompleted,
      inviteIdentity: 'call-a',
      exactCallkitIdentity: 'exact-a',
    );

    final events = await recorder.readPersisted();
    expect(events, hasLength(2));
    expect(events.first.callFingerprint, isNot(events.last.callFingerprint));
    expect(
      events.first.exactCallkitFingerprint,
      isNot(events.last.exactCallkitFingerprint),
    );
  });

  test('failed storage is not reported as persisted in memory or after restart',
      () async {
    final store = _MemoryStore()..failWrites = true;
    final recorder = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'resumed',
    );
    var acceptanceContinued = false;

    expect(
      () => recorder.record(
        CallV2DurableDiagnosticStage.flutterAcceptBridgeReceived,
        inviteIdentity: 'private-invite',
      ),
      returnsNormally,
    );
    acceptanceContinued = true;
    await recorder.flush();

    expect(acceptanceContinued, isTrue);
    expect(await recorder.readPersisted(), isEmpty);
    final restarted = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'resumed',
    );
    expect(await restarted.readPersisted(), isEmpty);
  });

  test('failed append preserves A B C and a later write continues from commit',
      () async {
    final store = _MemoryStore();
    final recorder = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'resumed',
    );
    for (final identity in <String>['call-a', 'call-b', 'call-c']) {
      recorder.record(
        CallV2DurableDiagnosticStage.acceptedContinuationClaimed,
        inviteIdentity: identity,
      );
    }
    await recorder.flush();
    final committedBeforeFailure = store.encoded;

    store.failWrites = true;
    recorder.record(
      CallV2DurableDiagnosticStage.transactionFailed,
      inviteIdentity: 'failed-call',
    );
    await recorder.flush();

    expect(store.encoded, committedBeforeFailure);
    var events = await recorder.readPersisted();
    expect(
        events.map((event) => event.sequence), orderedEquals(<int>[1, 2, 3]));
    expect(
      events.map((event) => event.callFingerprint),
      orderedEquals(<String>[
        CallV2DurableDiagnosticRecorder.fingerprint(
          'call-a',
          namespace: 'call',
        ),
        CallV2DurableDiagnosticRecorder.fingerprint(
          'call-b',
          namespace: 'call',
        ),
        CallV2DurableDiagnosticRecorder.fingerprint(
          'call-c',
          namespace: 'call',
        ),
      ]),
    );

    store.failWrites = false;
    recorder.record(
      CallV2DurableDiagnosticStage.transactionCompleted,
      inviteIdentity: 'call-d',
    );
    await recorder.flush();

    events = await recorder.readPersisted();
    expect(
      events.map((event) => event.sequence),
      orderedEquals(<int>[1, 2, 3, 4]),
    );
    final restarted = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'resumed',
    );
    expect(
      (await restarted.readPersisted()).map((event) => event.sequence),
      orderedEquals(<int>[1, 2, 3, 4]),
    );
  });

  test('record returns while durable storage is still blocked', () async {
    final store = _BlockingStore();
    final recorder = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'resumed',
    );

    var callPathContinued = false;
    recorder.record(
      CallV2DurableDiagnosticStage.flutterAcceptBridgeReceived,
      inviteIdentity: 'private-invite',
    );
    callPathContinued = true;
    await store.writeStarted.future;

    expect(callPathContinued, isTrue);
    expect(store.encoded, isNull);
    store.releaseWrite.complete();
    await recorder.flush();
    expect(store.encoded, isNotNull);
  });

  testWidgets(
      'native Flutter receipt and blocked transaction entry persist independently',
      (tester) async {
    const inviteId = 'durable-blocked-invite';
    const exactId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final firestore = FakeFirebaseFirestore();
    final store = _MemoryStore();
    final recorder = CallV2DurableDiagnosticRecorder(
      store: store,
      appLifecycleState: () => 'inactive',
    );
    CallV2DurableDiagnosticRecorder.debugOverrideForTest(recorder);
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'callee',
      currentDisplayName: 'Callee',
    );
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': 'caller',
      'fromName': 'Caller',
      'toUid': 'callee',
      'channel': 'channel-value',
      'isVideo': true,
      'status': CallInviteStatus.ringing.name,
    });
    final manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'callee',
      currentDisplayName: 'Callee',
    );
    final notifications = NotificationService();
    notifications.debugBeginPushBindingForTest('callee');
    final navigatorKey = GlobalKey<NavigatorState>();
    final callbackEntered = Completer<void>();
    final releaseCallback = Completer<void>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: ({
        required inviteId,
        required channel,
        required acceptedCallkitId,
        required isVideo,
        required otherUserName,
        required otherUserId,
        required isCaller,
        required connectionSystem,
        required callV2FallbackUsed,
        required callV2BlockerCode,
      }) async {},
      skipActiveInviteBindingForTest: true,
      skipAcceptedNativeWatchBindingForTest: true,
      afterAcceptTransactionCallbackEnteredForTest: (_) async {
        if (!callbackEntered.isCompleted) callbackEntered.complete();
        await releaseCallback.future;
      },
    );

    await notifications.debugSimulateNativeAcceptedCallkitBridgeForTest(
      inviteId: inviteId,
      channel: 'channel-value',
      isVideo: true,
      fromName: 'Caller',
      fromUid: 'caller',
      callkitId: exactId,
      drainMicrotasks: false,
    );
    await callbackEntered.future;
    await recorder.flush();

    var events = await recorder.readPersisted();
    expect(
      events.map((event) => event.stage),
      containsAllInOrder(<CallV2DurableDiagnosticStage>[
        CallV2DurableDiagnosticStage.flutterAcceptBridgeReceived,
        CallV2DurableDiagnosticStage.acceptedRecoveryIdentityClassified,
        CallV2DurableDiagnosticStage.acceptedRecoveryHandoffStarted,
        CallV2DurableDiagnosticStage.acceptedContinuationClaimed,
        CallV2DurableDiagnosticStage.lifecycleGenerationChecked,
        CallV2DurableDiagnosticStage.transactionAttemptStarted,
        CallV2DurableDiagnosticStage.transactionRunInvoked,
        CallV2DurableDiagnosticStage.transactionCallbackEntered,
      ]),
    );
    expect(
      events.map((event) => event.stage),
      isNot(contains(CallV2DurableDiagnosticStage.transactionCompleted)),
    );

    releaseCallback.complete();
    for (var index = 0; index < 12; index += 1) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await recorder.flush();
    events = await recorder.readPersisted();
    expect(
      events.map((event) => event.stage),
      containsAll(<CallV2DurableDiagnosticStage>[
        CallV2DurableDiagnosticStage.transactionSnapshotObtained,
        CallV2DurableDiagnosticStage.transactionStatusClassified,
        CallV2DurableDiagnosticStage.transactionCompleted,
        CallV2DurableDiagnosticStage.transactionResultReturned,
      ]),
    );
    expect(store.encoded, isNot(contains(inviteId)));
    expect(store.encoded, isNot(contains(exactId)));

    await notifications.dispose();
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
    CallV2DurableDiagnosticRecorder.debugOverrideForTest(null);
  });

  testWidgets('non-native accepted recovery never fabricates Flutter receipt',
      (tester) async {
    const inviteId = 'durable-plugin-invite';
    final firestore = FakeFirebaseFirestore();
    final recorder = CallV2DurableDiagnosticRecorder(
      store: _MemoryStore(),
      appLifecycleState: () => 'resumed',
    );
    CallV2DurableDiagnosticRecorder.debugOverrideForTest(recorder);
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'callee',
      currentDisplayName: 'Callee',
    );
    await firestore.collection('callInvites').doc(inviteId).set({
      'fromUid': 'caller',
      'fromName': 'Caller',
      'toUid': 'callee',
      'channel': 'channel-value',
      'isVideo': true,
      'status': CallInviteStatus.ringing.name,
    });
    final manager = CallSessionManager.instance;
    await manager.clearForSignedOut();
    await manager.forceIdleForTest();
    HelperlyTestRuntime.configureForTest(
      firestore: firestore,
      currentUid: 'callee',
      currentDisplayName: 'Callee',
    );
    final notifications = NotificationService();
    notifications.debugBeginPushBindingForTest('callee');
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ));
    manager.configure(
      navigatorKey: navigatorKey,
      listNativeCalls: () async => const <NativeCallSnapshot>[],
      endNativeCall: (_) async {},
      appForegroundProvider: () async => true,
      callScreenOpenRecorderForTest: ({
        required inviteId,
        required channel,
        required acceptedCallkitId,
        required isVideo,
        required otherUserName,
        required otherUserId,
        required isCaller,
        required connectionSystem,
        required callV2FallbackUsed,
        required callV2BlockerCode,
      }) async {},
      skipActiveInviteBindingForTest: true,
      skipAcceptedNativeWatchBindingForTest: true,
    );

    await notifications.debugSimulateAcceptedCallkitEventForTest(
      inviteId: inviteId,
      channel: 'channel-value',
      isVideo: true,
      fromName: 'Caller',
      fromUid: 'caller',
      callkitId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    );
    await recorder.flush();
    final stages = (await recorder.readPersisted())
        .map((event) => event.stage)
        .toList(growable: false);

    expect(
      stages,
      isNot(contains(
        CallV2DurableDiagnosticStage.flutterAcceptBridgeReceived,
      )),
    );
    expect(
      stages,
      contains(CallV2DurableDiagnosticStage.acceptedRecoveryHandoffStarted),
    );

    await notifications.dispose();
    await manager.clearForSignedOut();
    HelperlyTestRuntime.clear();
    CallV2DurableDiagnosticRecorder.debugOverrideForTest(null);
  });
}
