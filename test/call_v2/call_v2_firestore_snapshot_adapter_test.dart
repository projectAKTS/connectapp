import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/call_v2/call_v2_firestore_snapshot_adapter.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = CallV2FirestoreSnapshotAdapter();

  test('maps a valid backend public call and participant documents', () async {
    final docs = await _documents(
      callData: _callData(
        lifecycleState: 'completed',
        endReason: 'caller_ended',
        failureCode: 'none',
        acceptedAt: Timestamp.fromDate(DateTime.utc(2026, 6, 25, 12, 1)),
        activeAt: Timestamp.fromDate(DateTime.utc(2026, 6, 25, 12, 2)),
        endedAt: Timestamp.fromDate(DateTime.utc(2026, 6, 25, 12, 3)),
      ),
      callerData: _participantData(
        uid: 'caller',
        role: 'caller',
        mediaState: 'not_joined',
        mediaVersion: 4,
      ),
      calleeData: _participantData(
        uid: 'callee',
        role: 'callee',
        mediaState: 'media_failed',
        mediaVersion: 5,
      ),
    );

    final snapshot = adapter.fromPublicDocuments(
      callDocument: docs.call,
      participantDocuments: docs.participants,
    );

    expect(snapshot.callId, 'call_a');
    expect(snapshot.lifecycle, CallLifecycle.completed);
    expect(snapshot.version, 7);
    expect(snapshot.callerUid, 'caller');
    expect(snapshot.calleeUid, 'callee');
    expect(snapshot.terminalReason, 'caller_ended');
    expect(snapshot.failureCode, 'none');
    expect(snapshot.createdAt!.toUtc(), DateTime.utc(2026, 6, 25, 12));
    expect(snapshot.acceptedAt!.toUtc(), DateTime.utc(2026, 6, 25, 12, 1));
    expect(snapshot.activeAt!.toUtc(), DateTime.utc(2026, 6, 25, 12, 2));
    expect(snapshot.endedAt!.toUtc(), DateTime.utc(2026, 6, 25, 12, 3));
    expect(snapshot.callerMediaState, ParticipantMediaState.notJoined);
    expect(snapshot.calleeMediaState, ParticipantMediaState.mediaFailed);
    expect(snapshot.callerMediaVersion, 4);
    expect(snapshot.calleeMediaVersion, 5);
  });

  test('derives callId from document ID and accepts matching redundant callId',
      () async {
    final docs = await _documents(
      callData: _callData()..['callId'] = 'call_a',
    );

    final snapshot = adapter.fromPublicDocuments(
      callDocument: docs.call,
      participantDocuments: docs.participants,
    );

    expect(snapshot.callId, 'call_a');
  });

  test('maps lifecycleState and Firestore timestamps through the domain parser',
      () async {
    final createdAt = Timestamp.fromDate(DateTime.utc(2026, 6, 25, 12));
    final docs = await _documents(
      callData: _callData(
        lifecycleState: 'accepted',
        createdAt: createdAt,
      ),
    );

    final snapshot = adapter.fromPublicDocuments(
      callDocument: docs.call,
      participantDocuments: docs.participants,
    );

    expect(snapshot.lifecycle, CallLifecycle.accepted);
    expect(snapshot.createdAt!.toUtc(), DateTime.utc(2026, 6, 25, 12));
  });

  test('rejects missing call document', () async {
    final database = FakeFirebaseFirestore();
    final docs = await _documents(database: database);
    final missingCall = await database.doc('calls/missing_call').get();

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: missingCall,
        participantDocuments: docs.participants,
      ),
      throwsFormatException,
    );
  });

  test('rejects null call data', () async {
    final docs = await _documents();

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: _DocumentSnapshotFake(
          id: 'call_a',
          path: 'calls/call_a',
          exists: true,
          data: null,
        ),
        participantDocuments: docs.participants,
      ),
      throwsFormatException,
    );
  });

  test('rejects a call document path outside calls/{callId}', () async {
    final database = FakeFirebaseFirestore();
    await database.doc('users/call_a').set(_callData());
    final docs = await _documents(database: database);
    final wrongPathCall = await database.doc('users/call_a').get();

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: wrongPathCall,
        participantDocuments: docs.participants,
      ),
      throwsFormatException,
    );
  });

  test('rejects unsupported schema and call systems', () async {
    final wrongSchema = await _documents(callData: _callData(schemaVersion: 1));
    final wrongSystem = await _documents(callData: _callData(callSystem: 'v1'));

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: wrongSchema.call,
        participantDocuments: wrongSchema.participants,
      ),
      throwsFormatException,
    );
    expect(
      () => adapter.fromPublicDocuments(
        callDocument: wrongSystem.call,
        participantDocuments: wrongSystem.participants,
      ),
      throwsFormatException,
    );
  });

  test('rejects unknown lifecycleState', () async {
    final docs = await _documents(
      callData: _callData(lifecycleState: 'waiting'),
    );

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: docs.call,
        participantDocuments: docs.participants,
      ),
      throwsFormatException,
    );
  });

  test('rejects missing caller or callee identity and matching identities',
      () async {
    final missingCaller =
        await _documents(callData: _callData()..remove('callerUid'));
    final missingCallee =
        await _documents(callData: _callData()..remove('calleeUid'));
    final sameIdentity = await _documents(
      callData: _callData(
        callerUid: 'caller',
        calleeUid: 'caller',
        participantUids: <String>['caller', 'caller'],
      ),
    );

    for (final docs in <_Documents>[
      missingCaller,
      missingCallee,
      sameIdentity,
    ]) {
      expect(
        () => adapter.fromPublicDocuments(
          callDocument: docs.call,
          participantDocuments: docs.participants,
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects missing or third participant documents', () async {
    final docs = await _documents();
    final database = FakeFirebaseFirestore();
    final thirdDocs = await _documents(database: database);
    await database.doc('calls/call_a/participants/other').set(_participantData(
          uid: 'other',
          role: 'callee',
        ));
    final other = await database.doc('calls/call_a/participants/other').get();

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: docs.call,
        participantDocuments: docs.participants.take(1),
      ),
      throwsFormatException,
    );
    expect(
      () => adapter.fromPublicDocuments(
        callDocument: thirdDocs.call,
        participantDocuments: <DocumentSnapshot<Map<String, dynamic>>>[
          ...thirdDocs.participants,
          other,
        ],
      ),
      throwsFormatException,
    );
  });

  test('rejects participant id, path, and set mismatches', () async {
    final idMismatch = await _documents(
      callerData: _participantData(uid: 'someone_else', role: 'caller'),
    );
    final database = FakeFirebaseFirestore();
    final pathMismatch = await _documents(database: database);
    await database
        .doc('calls/other_call/participants/callee')
        .set(_participantData(uid: 'callee', role: 'callee'));
    final otherCallParticipant =
        await database.doc('calls/other_call/participants/callee').get();
    final unrelated = await _documents(
      callData: _callData(participantUids: <String>['caller', 'callee']),
      calleeData: _participantData(uid: 'other', role: 'callee'),
    );

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: idMismatch.call,
        participantDocuments: idMismatch.participants,
      ),
      throwsFormatException,
    );
    expect(
      () => adapter.fromPublicDocuments(
        callDocument: pathMismatch.call,
        participantDocuments: <DocumentSnapshot<Map<String, dynamic>>>[
          pathMismatch.participants.first,
          otherCallParticipant,
        ],
      ),
      throwsFormatException,
    );
    expect(
      () => adapter.fromPublicDocuments(
        callDocument: unrelated.call,
        participantDocuments: unrelated.participants,
      ),
      throwsFormatException,
    );
  });

  test('rejects duplicate and swapped participant roles', () async {
    final duplicateRoles = await _documents(
      calleeData: _participantData(uid: 'callee', role: 'caller'),
    );
    final swappedRoles = await _documents(
      callerData: _participantData(uid: 'caller', role: 'callee'),
      calleeData: _participantData(uid: 'callee', role: 'caller'),
    );

    for (final docs in <_Documents>[duplicateRoles, swappedRoles]) {
      expect(
        () => adapter.fromPublicDocuments(
          callDocument: docs.call,
          participantDocuments: docs.participants,
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects malformed participant media data', () async {
    final unknownState = await _documents(
      callerData: _participantData(mediaState: 'muted'),
    );
    final malformedVersion = await _documents(
      callerData: _participantData(mediaVersion: 'not-an-int'),
    );

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: unknownState.call,
        participantDocuments: unknownState.participants,
      ),
      throwsFormatException,
    );
    expect(
      () => adapter.fromPublicDocuments(
        callDocument: malformedVersion.call,
        participantDocuments: malformedVersion.participants,
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed timestamp values', () async {
    final callTimestamp = await _documents(
      callData: _callData(createdAt: 'not-a-date'),
    );
    final participantTimestamp = await _documents(
      callerData: _participantData(lastMediaStateAt: 'not-a-date'),
    );

    expect(
      () => adapter.fromPublicDocuments(
        callDocument: callTimestamp.call,
        participantDocuments: callTimestamp.participants,
      ),
      throwsFormatException,
    );
    expect(
      () => adapter.fromPublicDocuments(
        callDocument: participantTimestamp.call,
        participantDocuments: participantTimestamp.participants,
      ),
      throwsFormatException,
    );
  });

  test('does not copy private operational fields into the domain map',
      () async {
    final docs = await _documents(
      callData: _callData()
        ..addAll(<String, Object?>{
          'fencingToken': 1,
          'lockClaims': <String, Object?>{'caller': 1},
          'commandId': 'private',
          'taskId': 'private',
          'rolloutSalt': 'private',
          'allowlist': <String>['private'],
        }),
      callerData: _participantData()
        ..addAll(<String, Object?>{
          'rtcUid': 1,
          'heartbeatVersion': 2,
          'lastHeartbeatAt': Timestamp.now(),
        }),
    );

    final snapshot = adapter.fromPublicDocuments(
      callDocument: docs.call,
      participantDocuments: docs.participants,
    );

    expect(snapshot.callId, 'call_a');
    expect(snapshot.callerMediaState, ParticipantMediaState.joined);
  });

  test('uses fake Firestore only and does not initialize production Firebase',
      () async {
    final docs = await _documents();

    adapter.fromPublicDocuments(
      callDocument: docs.call,
      participantDocuments: docs.participants,
    );

    expect(Firebase.apps, isEmpty);
  });

  test('adapter source stays mapping-only without private collection paths',
      () {
    final source = File(
      'lib/call_v2/call_v2_firestore_snapshot_adapter.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'FirebaseFirestore.instance',
      '.get(',
      '.snapshots(',
      '.set(',
      '.update(',
      '.delete(',
      '.collection(',
      'callOps',
      'activeCallLocks',
      'callCommandKeys',
      'taskOutbox',
      'commands',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}

Future<_Documents> _documents({
  FakeFirebaseFirestore? database,
  Map<String, Object?>? callData,
  Map<String, Object?>? callerData,
  Map<String, Object?>? calleeData,
}) async {
  final firestore = database ?? FakeFirebaseFirestore();
  await firestore.doc('calls/call_a').set(callData ?? _callData());
  await firestore
      .doc('calls/call_a/participants/caller')
      .set(callerData ?? _participantData(uid: 'caller', role: 'caller'));
  await firestore
      .doc('calls/call_a/participants/callee')
      .set(calleeData ?? _participantData(uid: 'callee', role: 'callee'));

  return _Documents(
    call: await firestore.doc('calls/call_a').get(),
    participants: <DocumentSnapshot<Map<String, dynamic>>>[
      await firestore.doc('calls/call_a/participants/caller').get(),
      await firestore.doc('calls/call_a/participants/callee').get(),
    ],
  );
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
    required this.participants,
  });

  final DocumentSnapshot<Map<String, dynamic>> call;
  final List<DocumentSnapshot<Map<String, dynamic>>> participants;
}

// ignore: subtype_of_sealed_class
class _DocumentSnapshotFake implements DocumentSnapshot<Map<String, dynamic>> {
  const _DocumentSnapshotFake({
    required this.id,
    required this.path,
    required this.exists,
    required Map<String, dynamic>? data,
  }) : _data = data;

  final String path;
  final Map<String, dynamic>? _data;

  @override
  final String id;

  @override
  final bool exists;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      _DocumentReferenceFake(path);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _DocumentReferenceFake
    implements DocumentReference<Map<String, dynamic>> {
  const _DocumentReferenceFake(this.path);

  @override
  final String path;

  @override
  String get id => path.split('/').last;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
