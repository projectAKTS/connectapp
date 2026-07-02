import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_callable_results.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/firebase/call_v2_document_snapshot_transport.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_snapshot_source.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and opens no Firestore listener', () {
      final transport = _FakeSnapshotTransport();

      _source(transport: transport);

      expect(transport.callRequests, isEmpty);
      expect(transport.participantRequests, isEmpty);
      expect(transport.listenCount, 0);
      expect(Firebase.apps, isEmpty);
    });

    test('source contains no singleton, runtime, startup, UI, or writes', () {
      final sources = _phase4Sources();

      for (final forbidden in <String>[
        'FirebaseFirestore.instance',
        'FirebaseFirestore.instanceFor',
        'FirebaseAuth.instance',
        'FirebaseAppCheck.instance',
        'CallV2Runtime(',
        'CallV2Harness(',
        'Navigator',
        'MaterialPageRoute',
        'runApp',
        'register',
        'serviceLocator',
        'getIt',
        '.set(',
        '.update(',
        '.delete(',
        '.add(',
        'print(',
        'debugPrint',
        'developer.log',
      ]) {
        expect(sources.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('production capability declaration remains false', () {
      expect(
        callV2NoProductionCapabilities.firestoreSnapshotSourceAvailable,
        isFalse,
      );
    });
  });

  group('feature gate', () {
    test('disabled streams reject and perform zero transport calls', () async {
      final transport = _FakeSnapshotTransport();
      final source = _source(
        enabled: false,
        transport: transport,
      );

      await expectLater(
        source.callDocumentStream('call_a'),
        emitsError(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        source.participantDocumentStream('call_a', 'caller'),
        emitsError(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(transport.callRequests, isEmpty);
      expect(transport.participantRequests, isEmpty);
      expect(transport.listenCount, 0);
    });

    test('disabled streams do not inspect invalid request identifiers',
        () async {
      final source = _source(
        enabled: false,
        transport: _FakeSnapshotTransport(),
      );

      await expectLater(
        source.callDocumentStream('calls/call_a'),
        emitsError(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        source.participantDocumentStream('calls/call_a', ' users/caller'),
        emitsError(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });
  });

  group('path routing and validation', () {
    test('routes exact injected collections and preserves identifiers',
        () async {
      final transport = _FakeSnapshotTransport();
      final source = _source(
        transport: transport,
        callCollectionName: 'custom_calls',
        participantSubcollectionName: 'members',
      );

      await source.callDocumentStream('call_exact').listen((_) {}).cancel();
      await source
          .participantDocumentStream('call_exact', 'participant_exact')
          .listen((_) {})
          .cancel();

      expect(transport.callRequests, <_CallRequest>[
        const _CallRequest('custom_calls', 'call_exact'),
      ]);
      expect(transport.participantRequests, <_ParticipantRequest>[
        const _ParticipantRequest(
          'custom_calls',
          'call_exact',
          'members',
          'participant_exact',
        ),
      ]);
    });

    test('does not accept full paths or arbitrary collection overrides',
        () async {
      final transport = _FakeSnapshotTransport();
      final source = _source(transport: transport);

      await expectLater(
        () => source.callDocumentStream('calls/call_a'),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
      await expectLater(
        () => source.participantDocumentStream(
          'calls/call_a',
          'participants/caller',
        ),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
      await source.callDocumentStream('call_a').listen((_) {}).cancel();

      expect(transport.callRequests.single.collectionName, 'calls');
      expect(transport.callRequests.single.callId, 'call_a');
    });

    test('invalid identifiers are rejected without transport calls', () {
      for (final invalidCallId in <String>[
        '',
        ' call_a',
        'call_a ',
        'calls/call_a',
        'x' * (callV2MaxCallableIdentifierLength + 1),
      ]) {
        final transport = _FakeSnapshotTransport();
        final source = _source(transport: transport);

        expect(
          () => source.callDocumentStream(invalidCallId),
          throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
          reason: invalidCallId,
        );
        expect(transport.callRequests, isEmpty);
      }

      for (final invalidParticipantUid in <String>[
        '',
        ' caller',
        'caller ',
        'users/caller',
        'x' * (callV2MaxCallableIdentifierLength + 1),
      ]) {
        final transport = _FakeSnapshotTransport();
        final source = _source(transport: transport);

        expect(
          () => source.participantDocumentStream(
            'call_a',
            invalidParticipantUid,
          ),
          throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
          reason: invalidParticipantUid,
        );
        expect(transport.participantRequests, isEmpty);
      }
    });

    test('unsafe collection names are rejected without raw values in errors',
        () {
      for (final invalidCollection in <String>[
        '',
        ' calls',
        'calls ',
        'private/calls',
        'x' * (callV2MaxCallableIdentifierLength + 1),
      ]) {
        Object? caught;
        try {
          _source(callCollectionName: invalidCollection);
        } catch (error) {
          caught = error;
        }

        expect(caught, isA<CallV2ClientError>());
        if (invalidCollection.isNotEmpty) {
          expect(caught.toString().contains(invalidCollection), isFalse);
        }
      }

      for (final invalidCollection in <String>[
        '',
        ' participants',
        'participants ',
        'private/participants',
        'x' * (callV2MaxCallableIdentifierLength + 1),
      ]) {
        Object? caught;
        try {
          _source(participantSubcollectionName: invalidCollection);
        } catch (error) {
          caught = error;
        }

        expect(caught, isA<CallV2ClientError>());
        if (invalidCollection.isNotEmpty) {
          expect(caught.toString().contains(invalidCollection), isFalse);
        }
      }
    });
  });

  group('stream semantics', () {
    test('valid factories return transport streams and preserve event order',
        () async {
      final docs = await _documents();
      final transport = _FakeSnapshotTransport();
      final callStream = transport.callStream('calls', 'call_a');
      final participantStream = transport.participantStream(
        'calls',
        'call_a',
        'participants',
        'caller',
      );
      final source = _source(transport: transport);

      final callExpectation = expectLater(
        source.callDocumentStream('call_a'),
        emitsInOrder(<Object>[docs.call, docs.deletedCall, emitsDone]),
      );
      await Future<void>.delayed(Duration.zero);
      callStream.add(docs.call);
      callStream.add(docs.deletedCall);
      await callStream.close();
      await callExpectation;

      final participantExpectation = expectLater(
        source.participantDocumentStream('call_a', 'caller'),
        emitsInOrder(<Object>[docs.caller, emitsDone]),
      );
      await Future<void>.delayed(Duration.zero);
      participantStream.add(docs.caller);
      await participantStream.close();
      await participantExpectation;

      expect(transport.listenCount, 2);
    });

    test('stream errors are not retried or normalized by the source', () async {
      final transport = _FakeSnapshotTransport();
      final source = _source(transport: transport);
      final stream = transport.callStream('calls', 'call_a');
      final rawError = StateError('listener failed');

      final expectation = expectLater(
        source.callDocumentStream('call_a'),
        emitsError(same(rawError)),
      );
      await Future<void>.delayed(Duration.zero);
      stream.addError(rawError);
      await stream.close();
      await expectation;

      expect(transport.callRequests, hasLength(1));
    });

    test('duplicate factory calls create separate requests and no cache',
        () async {
      final transport = _FakeSnapshotTransport();
      final source = _source(transport: transport);

      await source.callDocumentStream('call_a').listen((_) {}).cancel();
      await source.callDocumentStream('call_a').listen((_) {}).cancel();

      expect(transport.callRequests, <_CallRequest>[
        const _CallRequest('calls', 'call_a'),
        const _CallRequest('calls', 'call_a'),
      ]);
      expect(transport.streamsCreated, 2);
    });

    test('cancellation reaches the underlying stream', () async {
      final transport = _FakeSnapshotTransport();
      final source = _source(transport: transport);

      final subscription = source.callDocumentStream('call_a').listen((_) {});
      await subscription.cancel();

      expect(transport.cancelCount, 1);
    });

    test('source does not parse lifecycle or perform writes', () async {
      final source = File(
        'lib/call_v2/firebase/firebase_call_v2_snapshot_source.dart',
      ).readAsStringSync();

      for (final forbidden in <String>[
        'CallSnapshot',
        'lifecycle',
        '.set(',
        '.update(',
        '.delete(',
        '.add(',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('production transport', () {
    test('uses injected FirebaseFirestore and exact document paths', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.doc('calls/call_a').set(<String, Object?>{
        'schemaVersion': 2,
      });
      await firestore.doc('calls/call_a/participants/caller').set(
        <String, Object?>{'uid': 'caller'},
      );
      final source = FirebaseCallV2SnapshotSource.fromFirebaseFirestore(
        featureGate: const CallV2FeatureGate(enabled: true),
        firestore: firestore,
        callCollectionName: 'calls',
        participantSubcollectionName: 'participants',
      );

      final callDoc = await source.callDocumentStream('call_a').first;
      final participantDoc =
          await source.participantDocumentStream('call_a', 'caller').first;

      expect(callDoc.reference.path, 'calls/call_a');
      expect(participantDoc.reference.path, 'calls/call_a/participants/caller');
    });

    test('transport source uses only injected document snapshot reads', () {
      final source = File(
        'lib/call_v2/firebase/firebase_firestore_call_v2_snapshot_transport.dart',
      ).readAsStringSync();

      expect(source.contains('required FirebaseFirestore firestore'), isTrue);
      expect(source.contains('_firestore.collection(collectionName)'), isTrue);
      expect(source.contains('.doc(callId)'), isTrue);
      expect(source.contains('.collection(participantCollectionName)'), isTrue);
      expect(source.contains('.doc(participantUid)'), isTrue);
      expect(source.contains('.snapshots()'), isTrue);

      for (final forbidden in <String>[
        'FirebaseFirestore.instance',
        'FirebaseFirestore.instanceFor',
        '.where(',
        '.orderBy(',
        '.limit(',
        '.set(',
        '.update(',
        '.delete(',
        '.add(',
        'print(',
        'debugPrint',
        'developer.log',
        'secret',
        'token',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });
}

FirebaseCallV2SnapshotSource _source({
  bool enabled = true,
  _FakeSnapshotTransport? transport,
  String callCollectionName = 'calls',
  String participantSubcollectionName = 'participants',
}) {
  return FirebaseCallV2SnapshotSource(
    featureGate: CallV2FeatureGate(enabled: enabled),
    transport: transport ?? _FakeSnapshotTransport(),
    callCollectionName: callCollectionName,
    participantSubcollectionName: participantSubcollectionName,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

String _phase4Sources() {
  return <String>[
    'lib/call_v2/firebase/call_v2_document_snapshot_transport.dart',
    'lib/call_v2/firebase/firebase_call_v2_snapshot_source.dart',
    'lib/call_v2/firebase/firebase_firestore_call_v2_snapshot_transport.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

Future<_Documents> _documents() async {
  final firestore = FakeFirebaseFirestore();
  await firestore.doc('calls/call_a').set(<String, Object?>{
    'schemaVersion': 2,
  });
  await firestore.doc('calls/call_a/participants/caller').set(
    <String, Object?>{'uid': 'caller'},
  );
  final call = await firestore.doc('calls/call_a').get();
  final caller = await firestore.doc('calls/call_a/participants/caller').get();
  await firestore.doc('calls/deleted_call').delete();
  final deletedCall = await firestore.doc('calls/deleted_call').get();
  return _Documents(
    call: call,
    caller: caller,
    deletedCall: deletedCall,
  );
}

class _Documents {
  const _Documents({
    required this.call,
    required this.caller,
    required this.deletedCall,
  });

  final DocumentSnapshot<Map<String, dynamic>> call;
  final DocumentSnapshot<Map<String, dynamic>> caller;
  final DocumentSnapshot<Map<String, dynamic>> deletedCall;
}

class _FakeSnapshotTransport implements CallV2DocumentSnapshotTransport {
  final callRequests = <_CallRequest>[];
  final participantRequests = <_ParticipantRequest>[];
  final _streams = <_TrackedDocumentStream>[];
  final _preparedStreams = <String, List<_TrackedDocumentStream>>{};

  int get listenCount {
    return _streams.fold<int>(0, (total, stream) => total + stream.listenCount);
  }

  int get cancelCount {
    return _streams.fold<int>(0, (total, stream) => total + stream.cancelCount);
  }

  int get streamsCreated => _streams.length;

  _TrackedDocumentStream callStream(String collectionName, String callId) {
    return _prepareStream(_CallRequest(collectionName, callId).key);
  }

  _TrackedDocumentStream participantStream(
    String collectionName,
    String callId,
    String participantCollectionName,
    String participantUid,
  ) {
    return _prepareStream(
      _ParticipantRequest(
        collectionName,
        callId,
        participantCollectionName,
        participantUid,
      ).key,
    );
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> callDocument(
    String collectionName,
    String callId,
  ) {
    callRequests.add(_CallRequest(collectionName, callId));
    return _stream(_CallRequest(collectionName, callId).key);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> participantDocument(
    String collectionName,
    String callId,
    String participantCollectionName,
    String participantUid,
  ) {
    final request = _ParticipantRequest(
      collectionName,
      callId,
      participantCollectionName,
      participantUid,
    );
    participantRequests.add(request);
    return _stream(request.key);
  }

  _TrackedDocumentStream _stream(String key) {
    final prepared = _preparedStreams[key];
    if (prepared != null && prepared.isNotEmpty) {
      final stream = prepared.removeAt(0);
      if (prepared.isEmpty) _preparedStreams.remove(key);
      return stream;
    }
    final stream = _TrackedDocumentStream();
    _streams.add(stream);
    return stream;
  }

  _TrackedDocumentStream _prepareStream(String key) {
    final stream = _TrackedDocumentStream();
    _streams.add(stream);
    (_preparedStreams[key] ??= <_TrackedDocumentStream>[]).add(stream);
    return stream;
  }
}

class _TrackedDocumentStream
    extends Stream<DocumentSnapshot<Map<String, dynamic>>> {
  final _controller =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>();

  int listenCount = 0;
  int cancelCount = 0;

  void add(DocumentSnapshot<Map<String, dynamic>> document) {
    _controller.add(document);
  }

  void addError(Object error) {
    _controller.addError(error);
  }

  Future<void> close() {
    return _controller.close();
  }

  @override
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> listen(
    void Function(DocumentSnapshot<Map<String, dynamic>> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    listenCount += 1;
    late StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
        subscription;
    subscription = _controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    return _TrackedSubscription(
      subscription,
      onCancel: () {
        cancelCount += 1;
      },
    );
  }
}

class _TrackedSubscription
    implements StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> {
  _TrackedSubscription(this._delegate, {required this.onCancel});

  final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> _delegate;
  final void Function() onCancel;
  bool _cancelled = false;

  @override
  Future<void> cancel() {
    if (!_cancelled) {
      _cancelled = true;
      onCancel();
    }
    return _delegate.cancel();
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    return _delegate.asFuture<E>(futureValue);
  }

  @override
  bool get isPaused => _delegate.isPaused;

  @override
  void onData(
      void Function(DocumentSnapshot<Map<String, dynamic>> data)? handleData) {
    _delegate.onData(handleData);
  }

  @override
  void onDone(void Function()? handleDone) {
    _delegate.onDone(handleDone);
  }

  @override
  void onError(Function? handleError) {
    _delegate.onError(handleError);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _delegate.pause(resumeSignal);
  }

  @override
  void resume() {
    _delegate.resume();
  }
}

class _CallRequest {
  const _CallRequest(this.collectionName, this.callId);

  final String collectionName;
  final String callId;

  String get key => '$collectionName/$callId';

  @override
  bool operator ==(Object other) {
    return other is _CallRequest &&
        other.collectionName == collectionName &&
        other.callId == callId;
  }

  @override
  int get hashCode => Object.hash(collectionName, callId);

  @override
  String toString() => 'CallRequest($key)';
}

class _ParticipantRequest {
  const _ParticipantRequest(
    this.collectionName,
    this.callId,
    this.participantCollectionName,
    this.participantUid,
  );

  final String collectionName;
  final String callId;
  final String participantCollectionName;
  final String participantUid;

  String get key {
    return '$collectionName/$callId/$participantCollectionName/$participantUid';
  }

  @override
  bool operator ==(Object other) {
    return other is _ParticipantRequest &&
        other.collectionName == collectionName &&
        other.callId == callId &&
        other.participantCollectionName == participantCollectionName &&
        other.participantUid == participantUid;
  }

  @override
  int get hashCode => Object.hash(
        collectionName,
        callId,
        participantCollectionName,
        participantUid,
      );

  @override
  String toString() => 'ParticipantRequest($key)';
}
