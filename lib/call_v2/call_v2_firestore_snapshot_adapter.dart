import 'package:cloud_firestore/cloud_firestore.dart';

import 'domain/call_snapshot.dart';

class CallV2FirestoreSnapshotAdapter {
  const CallV2FirestoreSnapshotAdapter();

  CallSnapshot fromPublicDocuments({
    required DocumentSnapshot<Map<String, dynamic>> callDocument,
    required Iterable<DocumentSnapshot<Map<String, dynamic>>>
        participantDocuments,
  }) {
    final callId = _validateCallPath(callDocument);
    if (!callDocument.exists) {
      throw const FormatException('Missing call document');
    }
    final callData = callDocument.data();
    if (callData == null) {
      throw const FormatException('Missing call document data');
    }
    final redundantCallId = callData['callId'];
    if (redundantCallId != null && redundantCallId != callId) {
      throw const FormatException('Conflicting call identity');
    }
    if (callData['schemaVersion'] != 2) {
      throw const FormatException('Unsupported call schema');
    }
    if (callData['callSystem'] != 'v2') {
      throw const FormatException('Unsupported call system');
    }

    final participantDocs = participantDocuments.toList(growable: false);
    if (participantDocs.length != 2) {
      throw const FormatException('Invalid participant document count');
    }

    final callerUid = callData['callerUid'];
    final calleeUid = callData['calleeUid'];
    if (callerUid is! String || callerUid.trim().isEmpty) {
      throw const FormatException('Missing caller identity');
    }
    if (calleeUid is! String || calleeUid.trim().isEmpty) {
      throw const FormatException('Missing callee identity');
    }

    final participants = <Map<String, Object?>>[];
    final participantIds = <String>{};
    for (final participantDocument in participantDocs) {
      final participantUid = _validateParticipantPath(
        participantDocument,
        callId: callId,
      );
      if (!participantDocument.exists) {
        throw const FormatException('Missing participant document');
      }
      final participantData = participantDocument.data();
      if (participantData == null) {
        throw const FormatException('Missing participant document data');
      }
      if (participantData['uid'] != participantUid) {
        throw const FormatException('Conflicting participant identity');
      }
      if (!participantIds.add(participantUid)) {
        throw const FormatException('Duplicate participant document');
      }
      participants.add(<String, Object?>{
        'uid': participantData['uid'],
        'role': participantData['role'],
        'mediaState': _mediaStateName(participantData['mediaState']),
        'mediaVersion': participantData['mediaVersion'],
        'updatedAt': _timestampValue(participantData['lastMediaStateAt']),
      });
    }
    if (participantIds.length != 2 ||
        !participantIds.contains(callerUid.trim()) ||
        !participantIds.contains(calleeUid.trim())) {
      throw const FormatException('Participant documents do not match call');
    }

    return CallSnapshot.fromPublicData(<String, Object?>{
      'callSystem': 'v2',
      'callId': callId,
      'version': callData['version'],
      'lifecycle': _lifecycleName(callData['lifecycleState']),
      'callerUid': callData['callerUid'],
      'calleeUid': callData['calleeUid'],
      'participantUids': callData['participantUids'],
      'createdAt': _timestampValue(callData['createdAt']),
      'acceptedAt': _timestampValue(callData['acceptedAt']),
      'activeAt': _timestampValue(callData['activeAt']),
      'endedAt': _timestampValue(callData['endedAt']),
      'terminalReason': callData['endReason'],
      'failureCode': callData['failureCode'],
      'participants': participants,
    });
  }

  String _validateCallPath(DocumentSnapshot<Map<String, dynamic>> document) {
    final segments = document.reference.path.split('/');
    if (segments.length != 2 || segments[0] != 'calls') {
      throw const FormatException('Invalid call document path');
    }
    final callId = segments[1].trim();
    if (callId.isEmpty || callId.contains('/')) {
      throw const FormatException('Invalid call document id');
    }
    if (document.id != callId) {
      throw const FormatException('Conflicting call document id');
    }
    return callId;
  }

  String _validateParticipantPath(
    DocumentSnapshot<Map<String, dynamic>> document, {
    required String callId,
  }) {
    final segments = document.reference.path.split('/');
    if (segments.length != 4 ||
        segments[0] != 'calls' ||
        segments[1] != callId ||
        segments[2] != 'participants') {
      throw const FormatException('Invalid participant document path');
    }
    final participantUid = segments[3].trim();
    if (participantUid.isEmpty || document.id != participantUid) {
      throw const FormatException('Conflicting participant document id');
    }
    return participantUid;
  }

  String _lifecycleName(Object? value) {
    if (value is! String) {
      throw const FormatException('Unknown lifecycle state');
    }
    switch (value) {
      case 'ringing':
      case 'accepted':
      case 'active':
      case 'completed':
      case 'declined':
      case 'cancelled':
      case 'missed':
      case 'failed':
        return value;
      default:
        throw const FormatException('Unknown lifecycle state');
    }
  }

  String _mediaStateName(Object? value) {
    if (value is! String) {
      throw const FormatException('Unknown participant media state');
    }
    switch (value) {
      case 'not_joined':
        return 'notJoined';
      case 'preparing':
        return 'preparing';
      case 'joining':
        return 'joining';
      case 'joined':
        return 'joined';
      case 'reconnecting':
        return 'reconnecting';
      case 'disconnected':
        return 'disconnected';
      case 'left':
        return 'left';
      case 'media_failed':
        return 'mediaFailed';
      default:
        throw const FormatException('Unknown participant media state');
    }
  }

  Object? _timestampValue(Object? value) {
    if (value == null || value is Timestamp || value is DateTime) {
      return value;
    }
    if (value is String && DateTime.tryParse(value.trim()) != null) {
      return value;
    }
    throw const FormatException('Invalid timestamp');
  }
}
