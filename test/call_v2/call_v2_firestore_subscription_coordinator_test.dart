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
  final _callStreams = <String, _TrackedDocumentStream>{};
  final _participantStreams = <_ParticipantRequest, _TrackedDocumentStream>{};
  String? throwForParticipantUid;

  int get activeSubscriptionCount {
    return <_TrackedDocumentStream>[
      ..._callStreams.values,
      ..._participantStreams.values,
    ].where((stream) => stream.isActive).length;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> callFactory(String callId) {
    callRequests.add(callId);
    final stream = _TrackedDocumentStream();
    _callStreams[callId] = stream;
    return stream.stream;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> participantFactory(
    String callId,
    String participantUid,
  ) {
    participantRequests.add(_ParticipantRequest(callId, participantUid));
    if (participantUid == throwForParticipantUid) {
      throw StateError('provider details must not leak');
    }
    final stream = _TrackedDocumentStream();
    _participantStreams[_ParticipantRequest(callId, participantUid)] = stream;
    return stream.stream;
  }

  _TrackedDocumentStream call(String callId) => _callStreams[callId]!;

  _TrackedDocumentStream participant(String callId, String participantUid) {
    return _participantStreams[_ParticipantRequest(callId, participantUid)]!;
  }
}

class _TrackedDocumentStream {
  _TrackedDocumentStream()
      : _controller =
            StreamController<DocumentSnapshot<Map<String, dynamic>>>();

  final StreamController<DocumentSnapshot<Map<String, dynamic>>> _controller;
  bool isActive = false;

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

  void add(DocumentSnapshot<Map<String, dynamic>> document) {
    if (!_controller.isClosed) {
      _controller.add(document);
    }
  }

  void addError(Object error) {
    if (!_controller.isClosed) {
      _controller.addError(error);
    }
  }
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
