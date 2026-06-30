import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_firestore_snapshot_adapter.dart';
import 'package:connect_app/call_v2/call_v2_firestore_subscription_coordinator.dart';
import 'package:connect_app/call_v2/call_v2_harness.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor creates no subscriptions', () {
    final streams = _TrackedStreams();
    _coordinator(streams: streams);

    expect(streams.callRequests, isEmpty);
    expect(streams.participantRequests, isEmpty);
  });

  test('disabled gate start is a no-op before factory invocation', () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(
      streams: streams,
      enabled: false,
    );

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );

    expect(coordinator.isRunning, isFalse);
    expect(coordinator.status, CallV2SubscriptionStatus.idle);
    expect(streams.callRequests, isEmpty);
    expect(streams.participantRequests, isEmpty);
  });

  test('identifier validation occurs before stream factory invocation',
      () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    for (final identity in <({String callId, String caller, String callee})>[
      (callId: '', caller: 'caller', callee: 'callee'),
      (callId: ' call_a', caller: 'caller', callee: 'callee'),
      (callId: 'calls/call_a', caller: 'caller', callee: 'callee'),
      (callId: 'call_a', caller: 'caller/', callee: 'callee'),
      (callId: 'call_a', caller: 'caller', callee: ' callee'),
      (callId: 'x' * 129, caller: 'caller', callee: 'callee'),
    ]) {
      await expectLater(
        coordinator.start(
          callId: identity.callId,
          callerUid: identity.caller,
          calleeUid: identity.callee,
        ),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    }

    expect(streams.callRequests, isEmpty);
    expect(streams.participantRequests, isEmpty);
  });

  test('same caller and callee UID is rejected before subscriptions', () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'same',
        calleeUid: 'same',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(streams.callRequests, isEmpty);
    expect(streams.participantRequests, isEmpty);
  });

  test('enabled start creates exactly the three injected document streams',
      () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );

    expect(coordinator.isRunning, isTrue);
    expect(coordinator.activeCallId, 'call_a');
    expect(streams.callRequests, <String>['call_a']);
    expect(streams.participantRequests, <_ParticipantRequest>[
      const _ParticipantRequest('call_a', 'caller'),
      const _ParticipantRequest('call_a', 'callee'),
    ]);
    expect(streams.activeSubscriptionCount, 3);
  });

  test('two concurrent same-identity starts share one startup', () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    final first = coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    final second = coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );

    await Future.wait(<Future<void>>[first, second]);

    expect(streams.callRequests, <String>['call_a']);
    expect(streams.participantRequests, <_ParticipantRequest>[
      const _ParticipantRequest('call_a', 'caller'),
      const _ParticipantRequest('call_a', 'callee'),
    ]);
    expect(streams.activeSubscriptionCount, 3);
    expect(coordinator.status, CallV2SubscriptionStatus.listening);
  });

  test('concurrent different-identity start is rejected locally', () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    final first = coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    await expectLater(
      coordinator.start(
        callId: 'call_b',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await first;

    expect(streams.callRequests, <String>['call_a']);
    expect(streams.participantRequests, <_ParticipantRequest>[
      const _ParticipantRequest('call_a', 'caller'),
      const _ParticipantRequest('call_a', 'callee'),
    ]);
    expect(streams.activeSubscriptionCount, 3);
  });

  test('three concurrent mixed starts create only the first identity',
      () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    final first = coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    final same = coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    final conflicting = expectLater(
      coordinator.start(
        callId: 'call_b',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    await Future.wait(<Future<void>>[first, same, conflicting]);

    expect(streams.callRequests, <String>['call_a']);
    expect(streams.participantRequests.length, 2);
    expect(streams.activeSubscriptionCount, 3);
  });

  test('synchronous call-document emission during listen is retained',
      () async {
    final docs = await _documents();
    final streams = _TrackedStreams()
      ..callStreamFor(
          'call_a', _SynchronousDocumentStream(onListenData: docs.call));
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    streams.participant('call_a', 'caller').add(docs.caller);
    streams.participant('call_a', 'callee').add(docs.callee);
    await _pump();

    expect(harness.snapshot!.callId, 'call_a');
    expect(harness.snapshot!.version, 7);
  });

  test('synchronous participant emissions during listen are retained',
      () async {
    final docs = await _documents();
    final streams = _TrackedStreams()
      ..participantStreamFor(
        'call_a',
        'caller',
        _SynchronousDocumentStream(onListenData: docs.caller),
      )
      ..participantStreamFor(
        'call_a',
        'callee',
        _SynchronousDocumentStream(onListenData: docs.callee),
      );
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    streams.call('call_a').add(docs.call);
    await _pump();

    expect(harness.snapshot!.callerUid, 'caller');
    expect(harness.snapshot!.calleeUid, 'callee');
  });

  test('all three synchronous startup emissions inject one snapshot', () async {
    final docs = await _documents();
    final streams = _TrackedStreams()
      ..callStreamFor(
          'call_a', _SynchronousDocumentStream(onListenData: docs.call))
      ..participantStreamFor(
        'call_a',
        'caller',
        _SynchronousDocumentStream(onListenData: docs.caller),
      )
      ..participantStreamFor(
        'call_a',
        'callee',
        _SynchronousDocumentStream(onListenData: docs.callee),
      );
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );

    expect(coordinator.status, CallV2SubscriptionStatus.listening);
    expect(harness.snapshot!.callId, 'call_a');
    expect(harness.snapshot!.version, 7);
  });

  test('coordinator source has no Firebase singleton or private path access',
      () {
    final source = File(
      'lib/call_v2/call_v2_firestore_subscription_coordinator.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'FirebaseFirestore.instance',
      'FirebaseFirestore.instanceFor',
      'FirebaseAuth.instance',
      'FirebaseAppCheck.instance',
      '.collection(',
      '.doc(',
      '.snapshots(',
      '.get(',
      '.set(',
      '.update(',
      '.delete(',
      'callOps',
      'activeCallLocks',
      'callCommandKeys',
      'taskOutbox',
      'commands',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test('combines only after call and both participant documents emit',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final docs = await _documents();

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );

    streams.call('call_a').add(docs.call);
    await _pump();
    expect(harness.snapshot, isNull);

    streams.participant('call_a', 'caller').add(docs.caller);
    await _pump();
    expect(harness.snapshot, isNull);

    streams.participant('call_a', 'callee').add(docs.callee);
    await _pump();
    expect(harness.snapshot!.callId, 'call_a');
    expect(harness.snapshot!.version, 7);
    expect(harness.snapshot!.callerUid, 'caller');
    expect(harness.snapshot!.calleeUid, 'callee');
  });

  test('later call and participant emissions recombine latest documents',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final initial = await _documents();
    final updatedCall = await _documents(
      callData: _callData(version: 8, lifecycleState: 'accepted'),
    );
    final updatedCaller = await _documents(
      callData: _callData(version: 9, lifecycleState: 'accepted'),
      callerData: _participantData(
        uid: 'caller',
        role: 'caller',
        mediaState: 'reconnecting',
        mediaVersion: 9,
      ),
    );

    await _startReady(coordinator, streams, initial);
    expect(harness.snapshot!.version, 7);

    streams.call('call_a').add(updatedCall.call);
    await _pump();
    expect(harness.snapshot!.version, 8);
    expect(harness.snapshot!.lifecycle, CallLifecycle.accepted);

    streams.participant('call_a', 'caller').add(updatedCaller.caller);
    streams.call('call_a').add(updatedCaller.call);
    await _pump();
    expect(
        harness.snapshot!.callerMediaState, ParticipantMediaState.reconnecting);
    expect(harness.snapshot!.callerMediaVersion, 9);
  });

  test('participant stream order does not affect accepted domain roles',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final docs = await _documents(
      callerData: _participantData(
        uid: 'caller',
        role: 'caller',
        mediaState: 'preparing',
      ),
      calleeData: _participantData(
        uid: 'callee',
        role: 'callee',
        mediaState: 'joined',
      ),
    );

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    streams.participant('call_a', 'callee').add(docs.callee);
    streams.call('call_a').add(docs.call);
    streams.participant('call_a', 'caller').add(docs.caller);
    await _pump();

    expect(harness.snapshot!.callerMediaState, ParticipantMediaState.preparing);
    expect(harness.snapshot!.calleeMediaState, ParticipantMediaState.joined);
  });

  test('malformed emissions do not replace prior valid snapshot and recover',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final valid = await _documents();
    final malformedCall = await _documents(
      callData: _callData(version: 8, lifecycleState: 'unknown'),
    );
    final malformedParticipant = await _documents(
      callerData: _participantData(
        uid: 'caller',
        role: 'caller',
        mediaState: 'invalid',
        mediaVersion: 9,
      ),
    );
    final recovered = await _documents(
      callData: _callData(version: 9, lifecycleState: 'accepted'),
      callerData: _participantData(
        uid: 'caller',
        role: 'caller',
        mediaState: 'joining',
        mediaVersion: 10,
      ),
    );
    final recoveredParticipant = await _documents(
      callData: _callData(version: 10, lifecycleState: 'accepted'),
      callerData: _participantData(
        uid: 'caller',
        role: 'caller',
        mediaState: 'joining',
        mediaVersion: 10,
      ),
    );

    await _startReady(coordinator, streams, valid);
    final accepted = harness.snapshot;

    streams.call('call_a').add(malformedCall.call);
    await _pump();
    expect(harness.snapshot, same(accepted));
    expect(coordinator.lastErrorCode, CallV2ClientErrorCode.rejected);

    streams.call('call_a').add(recovered.call);
    streams.participant('call_a', 'caller').add(malformedParticipant.caller);
    await _pump();
    expect(harness.snapshot!.version, 9);
    expect(harness.snapshot!.callerMediaState, ParticipantMediaState.joined);
    expect(coordinator.lastErrorCode, CallV2ClientErrorCode.rejected);

    streams.call('call_a').add(recoveredParticipant.call);
    streams.participant('call_a', 'caller').add(recoveredParticipant.caller);
    await _pump();
    expect(harness.snapshot!.version, 10);
    expect(harness.snapshot!.callerMediaState, ParticipantMediaState.joining);
    expect(coordinator.lastErrorCode, isNull);
  });

  test('private fields follow adapter contract without exposing raw data',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final valid = await _documents();
    final privateCall = await _documents(
      callData: _callData()
        ..addAll(<String, Object?>{
          'actorUid': 'raw_private_value',
        }),
    );

    await _startReady(coordinator, streams, valid);
    streams.call('call_a').add(privateCall.call);
    await _pump();

    expect(harness.snapshot!.version, 7);
    expect(coordinator.lastErrorCode, isNull);
    expect(coordinator.lastErrorCode.toString(),
        isNot(contains('raw_private_value')));
  });

  test('manager monotonicity remains authoritative for accepted snapshots',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final high = await _documents(
      callData: _callData(version: 9, lifecycleState: 'active'),
    );
    final lower = await _documents(
      callData: _callData(version: 8, lifecycleState: 'accepted'),
    );
    final equal = await _documents(
      callData: _callData(version: 9, lifecycleState: 'completed'),
    );
    final newer = await _documents(
      callData: _callData(version: 10, lifecycleState: 'completed'),
    );
    final nonTerminalAfterTerminal = await _documents(
      callData: _callData(version: 11, lifecycleState: 'active'),
    );

    await _startReady(coordinator, streams, high);
    expect(harness.snapshot!.version, 9);
    expect(harness.snapshot!.lifecycle, CallLifecycle.active);

    streams.call('call_a').add(lower.call);
    await _pump();
    expect(harness.snapshot!.version, 9);
    expect(harness.snapshot!.lifecycle, CallLifecycle.active);

    streams.call('call_a').add(equal.call);
    await _pump();
    expect(harness.snapshot!.version, 9);
    expect(harness.snapshot!.lifecycle, CallLifecycle.active);

    streams.call('call_a').add(newer.call);
    await _pump();
    expect(harness.snapshot!.version, 10);
    expect(harness.snapshot!.lifecycle, CallLifecycle.completed);

    streams.call('call_a').add(nonTerminalAfterTerminal.call);
    await _pump();
    expect(harness.snapshot!.version, 10);
    expect(harness.snapshot!.lifecycle, CallLifecycle.completed);
  });

  test('matching authoritative snapshot clears pending start through harness',
      () async {
    final streams = _TrackedStreams();
    final fakeApi = _FakeApi();
    final harness = _harness(fakeApi: fakeApi);
    final coordinator = _coordinator(streams: streams, harness: harness);
    final docs = await _documents(callId: 'server_call');

    await harness.startCall(const StartCallV2Request(
      calleeUid: 'callee',
      isVideo: true,
      idempotencyKey: 'start_key',
    ));
    expect(harness.pendingStartedCall!.callId, 'server_call');

    await coordinator.start(
      callId: 'server_call',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    expect(harness.pendingStartedCall, isNotNull);

    streams.call('server_call').add(docs.call);
    streams.participant('server_call', 'caller').add(docs.caller);
    streams.participant('server_call', 'callee').add(docs.callee);
    await _pump();

    expect(harness.snapshot!.callId, 'server_call');
    expect(harness.pendingStartedCall, isNull);
  });

  test('different call cannot start while coordinator session is active',
      () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );

    await expectLater(
      coordinator.start(
        callId: 'call_b',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    expect(streams.callRequests, <String>['call_a']);
  });

  test('different-call emissions cannot replace owned snapshot', () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final callA = await _documents(
      callId: 'call_a',
      callData: _callData(lifecycleState: 'completed'),
    );
    final callB = await _documents(callId: 'call_b');

    await _startReady(coordinator, streams, callA);
    expect(harness.snapshot!.callId, 'call_a');

    streams.call('call_a').add(callB.call);
    await _pump();
    expect(harness.snapshot!.callId, 'call_a');
    expect(coordinator.lastErrorCode, CallV2ClientErrorCode.rejected);
  });

  test('stop cancels subscriptions, is idempotent, and fresh start works',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final callA = await _documents(
      callId: 'call_a',
      callData: _callData(lifecycleState: 'completed'),
    );
    final callB = await _documents(callId: 'call_b');

    await _startReady(coordinator, streams, callA);
    expect(streams.activeSubscriptionCount, 3);
    await harness.cleanupIfTerminal();
    expect(harness.snapshot, isNull);

    final oldCall = streams.call('call_a');
    await coordinator.stop();
    await coordinator.stop();
    expect(coordinator.isRunning, isFalse);
    expect(streams.activeSubscriptionCount, 0);

    oldCall.add(await _callDocument(callId: 'call_a', version: 8));
    await _pump();
    expect(harness.snapshot, isNull);

    await coordinator.start(
      callId: 'call_b',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    streams.call('call_b').add(callB.call);
    streams.participant('call_b', 'caller').add(callB.caller);
    streams.participant('call_b', 'callee').add(callB.callee);
    await _pump();
    expect(harness.snapshot!.callId, 'call_b');
  });

  test('old-generation events cannot mutate a later new-call session',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final callA = await _documents(
      callId: 'call_a',
      callData: _callData(lifecycleState: 'completed'),
    );
    final callB = await _documents(callId: 'call_b');

    await _startReady(coordinator, streams, callA);
    final oldCall = streams.call('call_a');
    await harness.cleanupIfTerminal();
    await coordinator.stop();
    await _startReady(coordinator, streams, callB);

    oldCall.add(await _callDocument(callId: 'call_a', version: 99));
    await _pump();

    expect(harness.snapshot!.callId, 'call_b');
    expect(harness.snapshot!.version, 7);
  });

  test('stream errors expose controlled unavailable and cancel listeners',
      () async {
    final streams = _TrackedStreams();
    final coordinator = _coordinator(streams: streams);

    await coordinator.start(
      callId: 'call_a',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    streams.participant('call_a', 'caller').addError(StateError('raw secret'));
    await _pump();

    expect(coordinator.status, CallV2SubscriptionStatus.failed);
    expect(coordinator.lastErrorCode, CallV2ClientErrorCode.unavailable);
    expect(coordinator.lastErrorCode.toString(), isNot(contains('raw secret')));
    expect(streams.activeSubscriptionCount, 0);
  });

  test('partial subscription creation failure cleans up existing listener',
      () async {
    final streams = _TrackedStreams()..throwForParticipantUid = 'callee';
    final coordinator = _coordinator(streams: streams);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(coordinator.status, CallV2SubscriptionStatus.failed);
    expect(coordinator.lastErrorCode, CallV2ClientErrorCode.unavailable);
    expect(streams.callRequests, <String>['call_a']);
    expect(streams.participantRequests, <_ParticipantRequest>[
      const _ParticipantRequest('call_a', 'caller'),
      const _ParticipantRequest('call_a', 'callee'),
    ]);
    expect(streams.activeSubscriptionCount, 0);
  });

  test('synchronous stream error during first subscription fails startup',
      () async {
    final streams = _TrackedStreams()
      ..callStreamFor(
        'call_a',
        _SynchronousDocumentStream(onListenError: StateError('raw secret')),
      );
    final coordinator = _coordinator(streams: streams);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(coordinator.status, CallV2SubscriptionStatus.failed);
    expect(coordinator.lastErrorCode, CallV2ClientErrorCode.unavailable);
    expect(streams.activeSubscriptionCount, 0);
  });

  test('synchronous stream error during second subscription cancels first',
      () async {
    final streams = _TrackedStreams()
      ..participantStreamFor(
        'call_a',
        'caller',
        _SynchronousDocumentStream(onListenError: StateError('raw secret')),
      );
    final coordinator = _coordinator(streams: streams);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(streams.call('call_a').isActive, isFalse);
    expect(streams.activeSubscriptionCount, 0);
    expect(coordinator.status, CallV2SubscriptionStatus.failed);
  });

  test('synchronous stream error during third subscription cancels prior two',
      () async {
    final streams = _TrackedStreams()
      ..participantStreamFor(
        'call_a',
        'callee',
        _SynchronousDocumentStream(onListenError: StateError('raw secret')),
      );
    final coordinator = _coordinator(streams: streams);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(streams.call('call_a').isActive, isFalse);
    expect(streams.participant('call_a', 'caller').isActive, isFalse);
    expect(streams.activeSubscriptionCount, 0);
    expect(coordinator.status, CallV2SubscriptionStatus.failed);
  });

  test('factory throw and listen throw both clean up partial listeners',
      () async {
    final factoryThrow = _TrackedStreams()..throwForParticipantUid = 'callee';
    final factoryCoordinator = _coordinator(streams: factoryThrow);

    await expectLater(
      factoryCoordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    expect(factoryThrow.activeSubscriptionCount, 0);

    final listenThrow = _TrackedStreams()
      ..participantStreamFor(
        'call_a',
        'callee',
        _SynchronousDocumentStream(throwOnListen: true),
      );
    final listenCoordinator = _coordinator(streams: listenThrow);

    await expectLater(
      listenCoordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    expect(listenThrow.call('call_a').isActive, isFalse);
    expect(listenThrow.participant('call_a', 'caller').isActive, isFalse);
    expect(listenThrow.activeSubscriptionCount, 0);
  });

  test('stop during startup prevents later listening and ignores old callbacks',
      () async {
    final docs = await _documents();
    late CallV2FirestoreSubscriptionCoordinator coordinator;
    final streams = _TrackedStreams()
      ..callStreamFor(
        'call_a',
        _SynchronousDocumentStream(onBeforeListenReturn: () {
          unawaited(coordinator.stop());
        }),
      );
    final harness = _harness();
    coordinator = _coordinator(streams: streams, harness: harness);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await _pump();

    expect(coordinator.status, CallV2SubscriptionStatus.stopped);
    expect(streams.activeSubscriptionCount, 0);
    streams.call('call_a').add(docs.call);
    await _pump();
    expect(harness.snapshot, isNull);
  });

  test('fresh start after failed startup succeeds', () async {
    final docs = await _documents(callId: 'call_b');
    final streams = _TrackedStreams()
      ..callStreamFor(
        'call_a',
        _SynchronousDocumentStream(onListenError: StateError('raw secret')),
      );
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await coordinator.stop();
    await coordinator.start(
      callId: 'call_b',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    streams.call('call_b').add(docs.call);
    streams.participant('call_b', 'caller').add(docs.caller);
    streams.participant('call_b', 'callee').add(docs.callee);
    await _pump();

    expect(coordinator.status, CallV2SubscriptionStatus.listening);
    expect(harness.snapshot!.callId, 'call_b');
  });

  test('fresh start after stop during startup succeeds', () async {
    final docs = await _documents(callId: 'call_b');
    late CallV2FirestoreSubscriptionCoordinator coordinator;
    final streams = _TrackedStreams()
      ..callStreamFor(
        'call_a',
        _SynchronousDocumentStream(onBeforeListenReturn: () {
          unawaited(coordinator.stop());
        }),
      );
    final harness = _harness();
    coordinator = _coordinator(streams: streams, harness: harness);

    await expectLater(
      coordinator.start(
        callId: 'call_a',
        callerUid: 'caller',
        calleeUid: 'callee',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await coordinator.start(
      callId: 'call_b',
      callerUid: 'caller',
      calleeUid: 'callee',
    );
    streams.call('call_b').add(docs.call);
    streams.participant('call_b', 'caller').add(docs.caller);
    streams.participant('call_b', 'callee').add(docs.callee);
    await _pump();

    expect(coordinator.status, CallV2SubscriptionStatus.listening);
    expect(harness.snapshot!.callId, 'call_b');
  });

  test(
      'presenter navigation remains snapshot-driven and Firebase uninitialized',
      () async {
    final streams = _TrackedStreams();
    final harness = _harness();
    final coordinator = _coordinator(streams: streams, harness: harness);
    final docs = await _documents();

    await _startReady(coordinator, streams, docs);

    expect(harness.openNavigationIntentFor(harness.snapshot!), isNotNull);
    expect(harness.openNavigationIntentFor(harness.snapshot!), isNull);
    expect(Firebase.apps, isEmpty);
  });
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

CallV2FirestoreSubscriptionCoordinator _coordinator({
  _TrackedStreams? streams,
  CallV2Harness? harness,
  bool enabled = true,
}) {
  final tracked = streams ?? _TrackedStreams();
  return CallV2FirestoreSubscriptionCoordinator(
    featureGate: CallV2FeatureGate(enabled: enabled),
    harness: harness ?? _harness(enabled: enabled),
    adapter: const CallV2FirestoreSnapshotAdapter(),
    callDocumentStream: tracked.callFactory,
    participantDocumentStream: tracked.participantFactory,
  );
}

CallV2Harness _harness({
  _FakeApi? fakeApi,
  bool enabled = true,
}) {
  return CallV2Harness(
    featureGate: CallV2FeatureGate(enabled: enabled),
    api: CallV2Api(fakeApi ?? _FakeApi()),
    localParticipantRole: () => CallParticipantRole.caller,
  );
}

Future<void> _startReady(
  CallV2FirestoreSubscriptionCoordinator coordinator,
  _TrackedStreams streams,
  _Documents documents,
) async {
  await coordinator.start(
    callId: documents.call.id,
    callerUid: 'caller',
    calleeUid: 'callee',
  );
  streams.call(documents.call.id).add(documents.call);
  streams.participant(documents.call.id, 'caller').add(documents.caller);
  streams.participant(documents.call.id, 'callee').add(documents.callee);
  await _pump();
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _TrackedStreams {
  final callRequests = <String>[];
  final participantRequests = <_ParticipantRequest>[];
  final _callStreams = <String, _TrackedDocumentSource>{};
  final _participantStreams = <_ParticipantRequest, _TrackedDocumentSource>{};
  String? throwForParticipantUid;

  int get activeSubscriptionCount {
    return <_TrackedDocumentSource>[
      ..._callStreams.values,
      ..._participantStreams.values,
    ].where((stream) => stream.isActive).length;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> callFactory(String callId) {
    callRequests.add(callId);
    return (_callStreams[callId] ??= _TrackedDocumentStream()).stream;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> participantFactory(
    String callId,
    String participantUid,
  ) {
    participantRequests.add(_ParticipantRequest(callId, participantUid));
    if (participantUid == throwForParticipantUid) {
      throw StateError('provider details must not leak');
    }
    return (_participantStreams[_ParticipantRequest(callId, participantUid)] ??=
            _TrackedDocumentStream())
        .stream;
  }

  void callStreamFor(String callId, _TrackedDocumentSource stream) {
    _callStreams[callId] = stream;
  }

  void participantStreamFor(
    String callId,
    String participantUid,
    _TrackedDocumentSource stream,
  ) {
    _participantStreams[_ParticipantRequest(callId, participantUid)] = stream;
  }

  _TrackedDocumentSource call(String callId) => _callStreams[callId]!;

  _TrackedDocumentSource participant(String callId, String participantUid) {
    return _participantStreams[_ParticipantRequest(callId, participantUid)]!;
  }
}

abstract class _TrackedDocumentSource {
  Stream<DocumentSnapshot<Map<String, dynamic>>> get stream;
  bool get isActive;
  void add(DocumentSnapshot<Map<String, dynamic>> document);
  void addError(Object error);
}

class _TrackedDocumentStream implements _TrackedDocumentSource {
  _TrackedDocumentStream()
      : _controller =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();

  final StreamController<DocumentSnapshot<Map<String, dynamic>>> _controller;
  @override
  bool isActive = false;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> get stream {
    _controller
      ..onListen = () {
        isActive = true;
      }
      ..onCancel = () {
        isActive = false;
      };
    return _controller.stream;
  }

  @override
  void add(DocumentSnapshot<Map<String, dynamic>> document) {
    if (!_controller.isClosed) {
      _controller.add(document);
    }
  }

  @override
  void addError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }
}

class _SynchronousDocumentStream
    extends Stream<DocumentSnapshot<Map<String, dynamic>>>
    implements _TrackedDocumentSource {
  _SynchronousDocumentStream({
    this.onListenData,
    this.onListenError,
    this.onBeforeListenReturn,
    this.throwOnListen = false,
  });

  final DocumentSnapshot<Map<String, dynamic>>? onListenData;
  final Object? onListenError;
  final void Function()? onBeforeListenReturn;
  final bool throwOnListen;
  final _subscriptions = <_SynchronousDocumentSubscription>[];

  @override
  bool get isActive {
    return _subscriptions.any((subscription) => subscription.isActive);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> get stream => this;

  @override
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> listen(
    void Function(DocumentSnapshot<Map<String, dynamic>> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (throwOnListen) {
      throw StateError('listen details must not leak');
    }
    final subscription = _SynchronousDocumentSubscription();
    subscription.setDataHandler(onData);
    subscription.setErrorHandler(onError);
    subscription.setDoneHandler(onDone);
    _subscriptions.add(subscription);
    final data = onListenData;
    if (data != null && subscription.isActive) {
      onData?.call(data);
    }
    final error = onListenError;
    if (error != null && subscription.isActive) {
      if (onError != null) {
        Function.apply(onError, <Object>[error]);
      }
      if (cancelOnError ?? false) {
        unawaited(subscription.cancel());
      }
    }
    onBeforeListenReturn?.call();
    return subscription;
  }

  @override
  void add(DocumentSnapshot<Map<String, dynamic>> document) {
    for (final subscription in _subscriptions) {
      if (subscription.isActive) {
        subscription.handleData?.call(document);
      }
    }
  }

  @override
  void addError(Object error) {
    for (final subscription in _subscriptions) {
      if (subscription.isActive) {
        subscription.handleError?.call(error);
      }
    }
  }
}

class _SynchronousDocumentSubscription
    implements StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> {
  bool isActive = true;
  void Function(DocumentSnapshot<Map<String, dynamic>> event)? handleData;
  void Function(Object error)? handleError;
  void Function()? handleDone;

  void setDataHandler(
    void Function(DocumentSnapshot<Map<String, dynamic>> event)? handler,
  ) {
    handleData = handler;
  }

  void setErrorHandler(Function? handler) {
    if (handler == null) {
      handleError = null;
    } else {
      handleError = (Object error) => Function.apply(handler, <Object>[error]);
    }
  }

  void setDoneHandler(void Function()? handler) {
    handleDone = handler;
  }

  @override
  Future<void> cancel() async {
    isActive = false;
  }

  @override
  void onData(
      void Function(DocumentSnapshot<Map<String, dynamic>> data)? handleData) {
    this.handleData = handleData;
  }

  @override
  void onError(Function? handleError) {
    setErrorHandler(handleError);
  }

  @override
  void onDone(void Function()? handleDone) {
    this.handleDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);

  @override
  bool get isPaused => false;
}

class _ParticipantRequest {
  const _ParticipantRequest(this.callId, this.participantUid);

  final String callId;
  final String participantUid;

  @override
  bool operator ==(Object other) {
    return other is _ParticipantRequest &&
        other.callId == callId &&
        other.participantUid == participantUid;
  }

  @override
  int get hashCode => Object.hash(callId, participantUid);

  @override
  String toString() => '$callId/$participantUid';
}

Future<_Documents> _documents({
  String callId = 'call_a',
  Map<String, Object?>? callData,
  Map<String, Object?>? callerData,
  Map<String, Object?>? calleeData,
}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.doc('calls/$callId').set(callData ?? _callData());
  await firestore.doc('calls/$callId/participants/caller').set(
        callerData ?? _participantData(uid: 'caller', role: 'caller'),
      );
  await firestore.doc('calls/$callId/participants/callee').set(
        calleeData ?? _participantData(uid: 'callee', role: 'callee'),
      );
  return _Documents(
    call: await firestore.doc('calls/$callId').get(),
    caller: await firestore.doc('calls/$callId/participants/caller').get(),
    callee: await firestore.doc('calls/$callId/participants/callee').get(),
  );
}

Future<DocumentSnapshot<Map<String, dynamic>>> _callDocument({
  required String callId,
  required int version,
}) async {
  final docs = await _documents(
    callId: callId,
    callData: _callData(version: version),
  );
  return docs.call;
}

Map<String, Object?> _callData({
  int schemaVersion = 2,
  String callSystem = 'v2',
  String lifecycleState = 'active',
  int version = 7,
  String callerUid = 'caller',
  String calleeUid = 'callee',
  List<String> participantUids = const <String>['caller', 'callee'],
  Object? createdAt,
  Object? acceptedAt,
  Object? activeAt,
  Object? endedAt,
  String? endReason,
  String? failureCode,
}) {
  return <String, Object?>{
    'schemaVersion': schemaVersion,
    'callSystem': callSystem,
    'lifecycleState': lifecycleState,
    'version': version,
    'callerUid': callerUid,
    'calleeUid': calleeUid,
    'participantUids': participantUids,
    'createdAt': createdAt ?? Timestamp.fromDate(DateTime.utc(2026, 6, 25, 12)),
    'acceptedAt': acceptedAt,
    'activeAt': activeAt,
    'endedAt': endedAt,
    'endReason': endReason,
    'failureCode': failureCode,
    'agoraChannel': 'call_v2_public_extra',
    'mediaProvider': 'agora',
    'isVideo': true,
    'acceptedByUid': null,
    'endedByUid': null,
  };
}

Map<String, Object?> _participantData({
  String uid = 'caller',
  String role = 'caller',
  String mediaState = 'joined',
  Object? mediaVersion = 1,
  Object? lastMediaStateAt,
}) {
  return <String, Object?>{
    'uid': uid,
    'role': role,
    'mediaState': mediaState,
    'mediaVersion': mediaVersion,
    'lastMediaStateAt':
        lastMediaStateAt ?? Timestamp.fromDate(DateTime.utc(2026, 6, 25, 12)),
    'rtcUid': 123,
    'heartbeatVersion': 0,
    'lastHeartbeatAt': null,
  };
}

class _Documents {
  const _Documents({
    required this.call,
    required this.caller,
    required this.callee,
  });

  final DocumentSnapshot<Map<String, dynamic>> call;
  final DocumentSnapshot<Map<String, dynamic>> caller;
  final DocumentSnapshot<Map<String, dynamic>> callee;
}

class _FakeApi implements CallableCallV2Api {
  Object? startResult = _startResult(callId: 'server_call');

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> endCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> startCallV2(Map<String, Object?> request) async =>
      startResult;
}

Map<String, Object?> _startResult({
  required String callId,
  int version = 1,
  bool idempotentReplay = false,
}) {
  return <String, Object?>{
    'callId': callId,
    'lifecycleState': 'ringing',
    'version': version,
    'idempotentReplay': idempotentReplay,
    'ringingDeadlineAt': '2026-06-25T12:00:30.000Z',
  };
}
