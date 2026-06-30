import 'domain/call_lifecycle.dart';
import 'domain/participant_media_state.dart';

const int callV2MaxCallableIdentifierLength = 160;
const int callV2MaxSafeInteger = 9007199254740991;

class StartCallV2Result {
  const StartCallV2Result({
    required this.callId,
    required this.version,
    required this.idempotentReplay,
    this.ringingDeadlineAt,
  });

  factory StartCallV2Result.fromCallableResult(Object? raw) {
    final data = _responseMap(raw, _startKeys);
    final lifecycle = _requiredLifecycle(data, 'lifecycleState');
    if (lifecycle != CallLifecycle.ringing) {
      throw const FormatException('Invalid lifecycle');
    }
    return StartCallV2Result(
      callId: _requiredIdentifier(data, 'callId'),
      version: _requiredPositiveSafeInt(data, 'version'),
      idempotentReplay: _requiredBool(data, 'idempotentReplay'),
      ringingDeadlineAt: _optionalTimestamp(data, 'ringingDeadlineAt'),
    );
  }

  final String callId;
  final int version;
  final bool idempotentReplay;
  final DateTime? ringingDeadlineAt;
}

class CallV2LifecycleCommandResult {
  const CallV2LifecycleCommandResult({
    required this.callId,
    required this.lifecycle,
    required this.version,
    required this.idempotentReplay,
    this.terminal,
    this.acceptedAt,
    this.acceptedJoinDeadlineAt,
    this.endedAt,
    this.endReason,
    this.failureCode,
  });

  factory CallV2LifecycleCommandResult.fromCallableResult(Object? raw) {
    final data = _responseMap(raw, _lifecycleKeys);
    final lifecycle = _requiredLifecycle(data, 'lifecycleState');
    final terminal = _optionalBool(data, 'terminal');
    if (terminal == true && !lifecycle.isTerminal) {
      throw const FormatException('Invalid terminal lifecycle');
    }
    if (terminal == false && lifecycle.isTerminal) {
      throw const FormatException('Invalid terminal lifecycle');
    }
    return CallV2LifecycleCommandResult(
      callId: _requiredIdentifier(data, 'callId'),
      lifecycle: lifecycle,
      version: _requiredPositiveSafeInt(data, 'version'),
      idempotentReplay: _requiredBool(data, 'idempotentReplay'),
      terminal: terminal,
      acceptedAt: _optionalTimestamp(data, 'acceptedAt'),
      acceptedJoinDeadlineAt:
          _optionalTimestamp(data, 'acceptedJoinDeadlineAt'),
      endedAt: _optionalTimestamp(data, 'endedAt'),
      endReason: _optionalBoundedString(data, 'endReason'),
      failureCode: _optionalBoundedString(data, 'failureCode'),
    );
  }

  final String callId;
  final CallLifecycle lifecycle;
  final int version;
  final bool idempotentReplay;
  final bool? terminal;
  final DateTime? acceptedAt;
  final DateTime? acceptedJoinDeadlineAt;
  final DateTime? endedAt;
  final String? endReason;
  final String? failureCode;
}

class CallV2MediaReportResult {
  const CallV2MediaReportResult({
    required this.callId,
    required this.mediaState,
    required this.mediaVersion,
    required this.mediaChanged,
    required this.lifecycle,
    required this.callVersion,
    required this.promotedToActive,
    required this.idempotentReplay,
    this.participantUid,
    this.activeAt,
    this.reconnectDeadlineAt,
  });

  factory CallV2MediaReportResult.fromCallableResult(Object? raw) {
    final data = _responseMap(raw, _mediaKeys);
    return CallV2MediaReportResult(
      callId: _requiredIdentifier(data, 'callId'),
      participantUid: _optionalIdentifier(data, 'participantUid'),
      mediaState: _requiredBackendMediaState(data, 'mediaState'),
      mediaVersion: _requiredNonNegativeSafeInt(data, 'mediaVersion'),
      mediaChanged: _requiredBool(data, 'mediaChanged'),
      lifecycle: _requiredLifecycle(data, 'lifecycleState'),
      callVersion: _requiredPositiveSafeInt(data, 'callVersion'),
      promotedToActive: _requiredBool(data, 'promotedToActive'),
      activeAt: _optionalTimestamp(data, 'activeAt'),
      reconnectDeadlineAt: _optionalTimestamp(data, 'reconnectDeadlineAt'),
      idempotentReplay: _requiredBool(data, 'idempotentReplay'),
    );
  }

  final String callId;
  final String? participantUid;
  final ParticipantMediaState mediaState;
  final int mediaVersion;
  final bool mediaChanged;
  final CallLifecycle lifecycle;
  final int callVersion;
  final bool promotedToActive;
  final DateTime? activeAt;
  final DateTime? reconnectDeadlineAt;
  final bool idempotentReplay;
}

class CallV2LeaseRenewalResult {
  const CallV2LeaseRenewalResult({
    required this.callId,
    required this.heartbeatVersion,
    required this.lifecycle,
    required this.callVersion,
    required this.idempotentReplay,
    this.participantUid,
    this.lastHeartbeatAt,
    this.leaseExpiresAt,
  });

  factory CallV2LeaseRenewalResult.fromCallableResult(Object? raw) {
    final data = _responseMap(raw, _leaseKeys);
    return CallV2LeaseRenewalResult(
      callId: _requiredIdentifier(data, 'callId'),
      participantUid: _optionalIdentifier(data, 'participantUid'),
      heartbeatVersion: _requiredPositiveSafeInt(data, 'heartbeatVersion'),
      lastHeartbeatAt: _optionalTimestamp(data, 'lastHeartbeatAt'),
      leaseExpiresAt: _optionalTimestamp(data, 'leaseExpiresAt'),
      lifecycle: _requiredLifecycle(data, 'lifecycleState'),
      callVersion: _requiredPositiveSafeInt(data, 'callVersion'),
      idempotentReplay: _requiredBool(data, 'idempotentReplay'),
    );
  }

  final String callId;
  final String? participantUid;
  final int heartbeatVersion;
  final DateTime? lastHeartbeatAt;
  final DateTime? leaseExpiresAt;
  final CallLifecycle lifecycle;
  final int callVersion;
  final bool idempotentReplay;
}

const _privateResultKeys = <String>{
  'callOps',
  'lockClaims',
  'lockReleaseResults',
  'fencingToken',
  'claimToken',
  'claimExpiresAt',
  'commandId',
  'commands',
  'taskId',
  'outboxTaskId',
  'taskOutbox',
  'dispatchAttempt',
  'dispatchAttempts',
  'dispatchDiagnostics',
  'externalTaskName',
  'deterministicExternalTaskId',
  'actorUid',
  'authenticatedUid',
  'rolloutMode',
  'percentage',
  'salt',
  'allowlist',
  'cohort',
};

const _startKeys = <String>{
  'callId',
  'lifecycleState',
  'version',
  'ringingDeadlineAt',
  'callerRtcUid',
  'calleeRtcUid',
  'idempotentReplay',
};

const _lifecycleKeys = <String>{
  'callId',
  'lifecycleState',
  'version',
  'terminal',
  'acceptedAt',
  'acceptedJoinDeadlineAt',
  'endedAt',
  'endReason',
  'failureCode',
  'idempotentReplay',
};

const _mediaKeys = <String>{
  'callId',
  'participantUid',
  'mediaState',
  'mediaVersion',
  'mediaChanged',
  'lifecycleState',
  'callVersion',
  'promotedToActive',
  'activeAt',
  'reconnectDeadlineAt',
  'idempotentReplay',
};

const _leaseKeys = <String>{
  'callId',
  'participantUid',
  'heartbeatVersion',
  'lastHeartbeatAt',
  'leaseExpiresAt',
  'lifecycleState',
  'callVersion',
  'idempotentReplay',
};

Map<String, Object?> _responseMap(Object? raw, Set<String> allowedKeys) {
  if (raw is! Map) {
    throw const FormatException('Invalid callable response');
  }
  final parsed = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException('Invalid callable response');
    }
    if (_privateResultKeys.contains(key) || !allowedKeys.contains(key)) {
      throw const FormatException('Invalid callable response');
    }
    parsed[key] = entry.value;
  }
  return parsed;
}

String _requiredIdentifier(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String && _isValidIdentifier(value)) {
    return value;
  }
  throw const FormatException('Invalid identifier');
}

String? _optionalIdentifier(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is String && _isValidIdentifier(value)) {
    return value;
  }
  throw const FormatException('Invalid identifier');
}

bool _isValidIdentifier(String value) {
  return value.isNotEmpty &&
      value.trim() == value &&
      value.length <= callV2MaxCallableIdentifierLength &&
      !value.contains('/');
}

int _requiredPositiveSafeInt(Map<String, Object?> data, String key) {
  final value = _requiredInt(data, key);
  if (value <= 0 || value > callV2MaxSafeInteger) {
    throw const FormatException('Invalid integer');
  }
  return value;
}

int _requiredNonNegativeSafeInt(Map<String, Object?> data, String key) {
  final value = _requiredInt(data, key);
  if (value < 0 || value > callV2MaxSafeInteger) {
    throw const FormatException('Invalid integer');
  }
  return value;
}

int _requiredInt(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is int) {
    return value;
  }
  throw const FormatException('Invalid integer');
}

bool _requiredBool(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is bool) {
    return value;
  }
  throw const FormatException('Invalid boolean');
}

bool? _optionalBool(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is bool) {
    return value;
  }
  throw const FormatException('Invalid boolean');
}

CallLifecycle _requiredLifecycle(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String) {
    for (final lifecycle in CallLifecycle.values) {
      if (lifecycle.name == value) {
        return lifecycle;
      }
    }
  }
  throw const FormatException('Invalid lifecycle');
}

ParticipantMediaState _requiredBackendMediaState(
  Map<String, Object?> data,
  String key,
) {
  final value = data[key];
  if (value is! String) {
    throw const FormatException('Invalid media state');
  }
  switch (value) {
    case 'not_joined':
      return ParticipantMediaState.notJoined;
    case 'preparing':
      return ParticipantMediaState.preparing;
    case 'joining':
      return ParticipantMediaState.joining;
    case 'joined':
      return ParticipantMediaState.joined;
    case 'reconnecting':
      return ParticipantMediaState.reconnecting;
    case 'disconnected':
      return ParticipantMediaState.disconnected;
    case 'left':
      return ParticipantMediaState.left;
    case 'media_failed':
      return ParticipantMediaState.mediaFailed;
    default:
      throw const FormatException('Invalid media state');
  }
}

DateTime? _optionalTimestamp(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) {
      return parsed;
    }
    throw const FormatException('Invalid timestamp');
  }
  try {
    final dynamic dynamicValue = value;
    final parsed = dynamicValue.toDate();
    if (parsed is DateTime) {
      return parsed;
    }
  } catch (_) {
    throw const FormatException('Invalid timestamp');
  }
  throw const FormatException('Invalid timestamp');
}

String? _optionalBoundedString(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value == null) {
    return null;
  }
  if (value is String &&
      value.trim() == value &&
      value.isNotEmpty &&
      value.length <= callV2MaxCallableIdentifierLength) {
    return value;
  }
  throw const FormatException('Invalid string');
}
