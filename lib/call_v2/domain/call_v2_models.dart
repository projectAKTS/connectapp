enum CallV2Lifecycle {
  ringing,
  accepted,
  active,
  completed,
  declined,
  cancelled,
  missed,
  failed;

  bool get isTerminal {
    switch (this) {
      case CallV2Lifecycle.completed:
      case CallV2Lifecycle.declined:
      case CallV2Lifecycle.cancelled:
      case CallV2Lifecycle.missed:
      case CallV2Lifecycle.failed:
        return true;
      case CallV2Lifecycle.ringing:
      case CallV2Lifecycle.accepted:
      case CallV2Lifecycle.active:
        return false;
    }
  }
}

enum CallV2LocalPhase {
  idle,
  incomingRinging,
  outgoingRinging,
  openingRoute,
  inCall,
  closing,
}

enum CallV2ParticipantRole {
  caller,
  callee;

  CallV2ParticipantRole get peer => this == CallV2ParticipantRole.caller
      ? CallV2ParticipantRole.callee
      : CallV2ParticipantRole.caller;
}

enum CallV2ParticipantMediaState {
  notJoined,
  preparing,
  joining,
  joined,
  reconnecting,
  disconnected,
  left,
  mediaFailed;
}

class CallV2Participant {
  const CallV2Participant({
    required this.uid,
    required this.role,
    required this.mediaState,
    required this.mediaVersion,
    this.updatedAt,
  });

  final String uid;
  final CallV2ParticipantRole role;
  final CallV2ParticipantMediaState mediaState;
  final int mediaVersion;
  final DateTime? updatedAt;
}

class CallV2Snapshot {
  const CallV2Snapshot({
    required this.callId,
    required this.version,
    required this.lifecycle,
    required this.callSystem,
    required this.callerUid,
    required this.calleeUid,
    required this.participants,
    this.createdAt,
    this.acceptedAt,
    this.activeAt,
    this.endedAt,
    this.terminalReason,
  });

  final String callId;
  final int version;
  final CallV2Lifecycle lifecycle;
  final String callSystem;
  final String callerUid;
  final String calleeUid;
  final Map<String, CallV2Participant> participants;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? activeAt;
  final DateTime? endedAt;
  final String? terminalReason;

  factory CallV2Snapshot.fromPublicData(Map<String, Object?> data) {
    _expectString(data['callSystem'], 'v2', field: 'callSystem');
    final callId = _requireId(data['callId'], field: 'callId');
    final version = _requirePositiveInt(data['version'], field: 'version');
    final lifecycle = _readLifecycle(data['lifecycle']);
    final callerUid = _requireId(data['callerUid'], field: 'callerUid');
    final calleeUid = _requireId(data['calleeUid'], field: 'calleeUid');
    if (callerUid == calleeUid) {
      throw const FormatException('callerUid and calleeUid must differ');
    }
    final participants = _readParticipants(data['participants']);
    if (participants.length != 2 ||
        participants[callerUid] == null ||
        participants[calleeUid] == null) {
      throw const FormatException('Participant set must equal caller/callee');
    }
    final caller = participants[callerUid]!;
    final callee = participants[calleeUid]!;
    if (caller.role != CallV2ParticipantRole.caller ||
        callee.role != CallV2ParticipantRole.callee) {
      throw const FormatException('Participant roles must match caller/callee');
    }
    _rejectPrivateFields(data);
    return CallV2Snapshot(
      callId: callId,
      version: version,
      lifecycle: lifecycle,
      callSystem: 'v2',
      callerUid: callerUid,
      calleeUid: calleeUid,
      participants: participants,
      createdAt: _readTimestamp(data['createdAt']),
      acceptedAt: _readTimestamp(data['acceptedAt']),
      activeAt: _readTimestamp(data['activeAt']),
      endedAt: _readTimestamp(data['endedAt']),
      terminalReason: _readOptionalString(data['terminalReason']),
    );
  }
}

CallV2Lifecycle _readLifecycle(Object? value) {
  if (value is! String) throw const FormatException('Unknown lifecycle');
  return CallV2Lifecycle.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw const FormatException('Unknown lifecycle'),
  );
}

Map<String, CallV2Participant> _readParticipants(Object? value) {
  if (value is! Iterable) throw const FormatException('Missing participants');
  final parsed = <String, CallV2Participant>{};
  for (final item in value) {
    if (item is! Map) throw const FormatException('Invalid participant entry');
    final data = item.cast<String, Object?>();
    final uid = _requireId(data['uid'], field: 'uid');
    if (parsed.containsKey(uid))
      throw const FormatException('Duplicate participant UID');
    parsed[uid] = CallV2Participant(
      uid: uid,
      role: _readRole(data['role']),
      mediaState: _readMediaState(data['mediaState']),
      mediaVersion:
          _requirePositiveInt(data['mediaVersion'], field: 'mediaVersion'),
      updatedAt: _readTimestamp(data['updatedAt']),
    );
  }
  return parsed;
}

CallV2ParticipantRole _readRole(Object? value) {
  if (value is! String) throw const FormatException('Unknown participant role');
  return CallV2ParticipantRole.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw const FormatException('Unknown participant role'),
  );
}

CallV2ParticipantMediaState _readMediaState(Object? value) {
  if (value is! String)
    throw const FormatException('Unknown participant media');
  return CallV2ParticipantMediaState.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw const FormatException('Unknown participant media'),
  );
}

String _requireId(Object? value, {required String field}) {
  final text = value is String ? value.trim() : '';
  if (text.isEmpty || text.contains('/')) {
    throw FormatException('Invalid $field');
  }
  return text;
}

int _requirePositiveInt(Object? value, {required String field}) {
  if (value is int && value >= 0) return value;
  throw FormatException('Missing or invalid $field');
}

String? _readOptionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

DateTime? _readTimestamp(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  throw const FormatException('Invalid timestamp');
}

void _expectString(Object? value, String expected, {required String field}) {
  if (value != expected) {
    throw FormatException('Expected $field to equal $expected');
  }
}

void _rejectPrivateFields(Map<String, Object?> data) {
  const privateKeys = <String>{
    'authenticatedUid',
    'staffRollout',
    'cohort',
    'lock',
    'fencing',
    'task',
    'command',
    'operation',
  };
  for (final key in privateKeys) {
    if (data.containsKey(key)) {
      throw FormatException('Private field not allowed: $key');
    }
  }
}
