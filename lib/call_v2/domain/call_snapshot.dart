import 'call_lifecycle.dart';
import 'participant_media_state.dart';

enum CallParticipantRole {
  caller,
  callee;

  CallParticipantRole get peer {
    switch (this) {
      case CallParticipantRole.caller:
        return CallParticipantRole.callee;
      case CallParticipantRole.callee:
        return CallParticipantRole.caller;
    }
  }
}

class CallParticipantSnapshot {
  const CallParticipantSnapshot({
    required this.uid,
    required this.role,
    required this.mediaState,
    required this.mediaVersion,
    this.updatedAt,
  });

  final String uid;
  final CallParticipantRole role;
  final ParticipantMediaState mediaState;
  final int mediaVersion;
  final DateTime? updatedAt;

  factory CallParticipantSnapshot.fromPublicData(
    Map<String, Object?> data, {
    required String expectedUid,
    required CallParticipantRole expectedRole,
  }) {
    final uid = _readRequiredString(data, 'uid');
    final role = _readRole(data['role']);
    if (uid != expectedUid || role != expectedRole) {
      throw const FormatException('Invalid participant identity');
    }

    return CallParticipantSnapshot(
      uid: uid,
      role: role,
      mediaState: _readMediaState(data['mediaState']),
      mediaVersion: _readRequiredInt(data, 'mediaVersion'),
      updatedAt: _readOptionalTimestamp(data['updatedAt']),
    );
  }
}

class CallSnapshot {
  const CallSnapshot({
    required this.callId,
    required this.version,
    required this.lifecycle,
    required this.callerUid,
    required this.calleeUid,
    this.callerMediaState = ParticipantMediaState.notJoined,
    this.calleeMediaState = ParticipantMediaState.notJoined,
    this.callerMediaVersion = 0,
    this.calleeMediaVersion = 0,
    this.createdAt,
    this.acceptedAt,
    this.activeAt,
    this.endedAt,
    this.terminalReason,
    this.failureCode,
  });

  factory CallSnapshot.fromPublicData(Map<String, Object?> data) {
    _requireString(data, 'callSystem', expected: 'v2');
    final callId = _readCallId(_readRequiredString(data, 'callId'));
    final version = _readRequiredInt(data, 'version');
    final lifecycle = _readLifecycle(data['lifecycle']);
    final callerUid = _readParticipantUid(data, 'callerUid');
    final calleeUid = _readParticipantUid(data, 'calleeUid');
    if (callerUid == calleeUid) {
      throw const FormatException('callerUid and calleeUid must differ');
    }

    final participantUids = _readParticipantUids(data);
    if (participantUids.length != 2 ||
        !participantUids.contains(callerUid) ||
        !participantUids.contains(calleeUid)) {
      throw const FormatException('Participant set must match caller/callee');
    }

    final publicParticipants = _readPublicParticipants(data);
    final callerParticipant = publicParticipants[callerUid];
    final calleeParticipant = publicParticipants[calleeUid];
    if (callerParticipant == null || calleeParticipant == null) {
      throw const FormatException('Missing caller/callee participant');
    }

    if (publicParticipants.length != 2) {
      throw const FormatException('Participant set must contain two entries');
    }

    return CallSnapshot(
      callId: callId,
      version: version,
      lifecycle: lifecycle,
      callerUid: callerUid,
      calleeUid: calleeUid,
      callerMediaState: callerParticipant.mediaState,
      calleeMediaState: calleeParticipant.mediaState,
      callerMediaVersion: callerParticipant.mediaVersion,
      calleeMediaVersion: calleeParticipant.mediaVersion,
      createdAt: _readOptionalTimestamp(data['createdAt']),
      acceptedAt: _readOptionalTimestamp(data['acceptedAt']),
      activeAt: _readOptionalTimestamp(data['activeAt']),
      endedAt: _readOptionalTimestamp(data['endedAt']),
      terminalReason: _readOptionalString(data['terminalReason']),
      failureCode: _readOptionalString(data['failureCode']),
    );
  }

  final String callId;
  final int version;
  final CallLifecycle lifecycle;
  final String callerUid;
  final String calleeUid;
  final ParticipantMediaState callerMediaState;
  final ParticipantMediaState calleeMediaState;
  final int callerMediaVersion;
  final int calleeMediaVersion;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? activeAt;
  final DateTime? endedAt;
  final String? terminalReason;
  final String? failureCode;

  ParticipantMediaState mediaStateFor(CallParticipantRole role) {
    switch (role) {
      case CallParticipantRole.caller:
        return callerMediaState;
      case CallParticipantRole.callee:
        return calleeMediaState;
    }
  }

  ParticipantMediaState peerMediaStateFor(CallParticipantRole role) {
    return mediaStateFor(role.peer);
  }

  int mediaVersionFor(CallParticipantRole role) {
    switch (role) {
      case CallParticipantRole.caller:
        return callerMediaVersion;
      case CallParticipantRole.callee:
        return calleeMediaVersion;
    }
  }

  int peerMediaVersionFor(CallParticipantRole role) {
    return mediaVersionFor(role.peer);
  }
}

String _readRequiredString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('Missing or invalid $key');
}

String? _readOptionalString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int _readRequiredInt(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) {
      return parsed;
    }
  }
  throw FormatException('Missing or invalid $key');
}

String _readCallId(String callId) {
  if (callId.isEmpty || callId.contains('/')) {
    throw const FormatException('Invalid callId');
  }
  return callId;
}

void _requireString(
  Map<String, Object?> data,
  String key, {
  required String expected,
}) {
  if (_readRequiredString(data, key) != expected) {
    throw FormatException('Expected $key to equal $expected');
  }
}

CallLifecycle _readLifecycle(Object? value) {
  if (value is String) {
    return CallLifecycle.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unknown lifecycle'),
    );
  }
  throw const FormatException('Unknown lifecycle');
}

ParticipantMediaState _readMediaState(Object? value) {
  if (value is String) {
    return ParticipantMediaState.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unknown participant media'),
    );
  }
  throw const FormatException('Unknown participant media');
}

CallParticipantRole _readRole(Object? value) {
  if (value is String) {
    return CallParticipantRole.values.firstWhere(
      (item) => item.name == value,
      orElse: () => throw const FormatException('Unknown participant role'),
    );
  }
  throw const FormatException('Unknown participant role');
}

DateTime? _readOptionalTimestamp(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value.trim());
  }
  try {
    final dynamic dynamicValue = value;
    final parsed = dynamicValue.toDate();
    if (parsed is DateTime) {
      return parsed;
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _readParticipantUid(Map<String, Object?> data, String key) {
  final value = _readRequiredString(data, key);
  if (value == '__placeholder__') {
    throw FormatException('Invalid $key');
  }
  return value;
}

Set<String> _readParticipantUids(Map<String, Object?> data) {
  final value = data['participantUids'];
  if (value is List) {
    final parsed = <String>[];
    for (final item in value) {
      final uid = item is String ? item.trim() : '';
      if (uid.isEmpty) {
        throw const FormatException('Invalid participant UID');
      }
      parsed.add(uid);
    }
    if (parsed.length != parsed.toSet().length) {
      throw const FormatException('Duplicate participant UID');
    }
    return parsed.toSet();
  }
  final participants = _readPublicParticipants(data);
  return participants.keys.toSet();
}

Map<String, CallParticipantSnapshot> _readPublicParticipants(
  Map<String, Object?> data,
) {
  final raw = data['participants'];
  if (raw is Map) {
    final parsed = <String, CallParticipantSnapshot>{};
    raw.forEach((key, value) {
      if (key is! String || value is! Map) {
        throw const FormatException('Invalid participant entry');
      }
      final participant = CallParticipantSnapshot.fromPublicData(
        value.cast<String, Object?>(),
        expectedUid: key,
        expectedRole: key == data['callerUid']
            ? CallParticipantRole.caller
            : key == data['calleeUid']
                ? CallParticipantRole.callee
                : throw const FormatException('Unexpected participant UID'),
      );
      parsed[key] = participant;
    });
    return parsed;
  }
  if (raw is List) {
    final parsed = <String, CallParticipantSnapshot>{};
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('Invalid participant entry');
      }
      final participantData = item.cast<String, Object?>();
      final uid = _readRequiredString(participantData, 'uid');
      final expectedRole = uid == data['callerUid']
          ? CallParticipantRole.caller
          : uid == data['calleeUid']
              ? CallParticipantRole.callee
              : throw const FormatException('Unexpected participant UID');
      final participant = CallParticipantSnapshot.fromPublicData(
        participantData,
        expectedUid: uid,
        expectedRole: expectedRole,
      );
      if (parsed.containsKey(uid)) {
        throw const FormatException('Duplicate participant UID');
      }
      parsed[uid] = participant;
    }
    return parsed;
  }
  throw const FormatException('Missing participants');
}
