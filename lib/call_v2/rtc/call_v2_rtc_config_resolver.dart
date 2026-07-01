import '../call_v2_api.dart';
import '../call_v2_callable_results.dart';
import '../call_v2_feature_gate.dart';
import '../call_v2_harness.dart';
import '../domain/call_lifecycle.dart';
import '../domain/call_snapshot.dart';
import 'call_v2_resolved_rtc_config.dart';
import 'call_v2_rtc_config_provider.dart';

typedef CallV2Clock = DateTime Function();

class CallV2RtcConfigResolver {
  CallV2RtcConfigResolver({
    required CallV2FeatureGate featureGate,
    required CallV2RtcConfigProvider provider,
    required CallV2Harness harness,
    required String Function() localParticipantUid,
    CallV2Clock? clock,
  })  : _featureGate = featureGate,
        _provider = provider,
        _harness = harness,
        _localParticipantUid = localParticipantUid,
        _clock = clock ?? DateTime.now;

  final CallV2FeatureGate _featureGate;
  final CallV2RtcConfigProvider _provider;
  final CallV2Harness _harness;
  final String Function() _localParticipantUid;
  final CallV2Clock _clock;

  int _generation = 0;
  CallV2ResolvedRtcConfig? _cachedConfig;
  _ResolutionIdentity? _inFlightIdentity;
  Future<CallV2ResolvedRtcConfig>? _inFlightFuture;

  Future<CallV2ResolvedRtcConfig> resolve({
    required bool isVideo,
    required String idempotencyKey,
  }) {
    return Future<CallV2ResolvedRtcConfig>.sync(() {
      _validateIdentifier(idempotencyKey, invalidRequest: true);
      if (!_featureGate.enabled) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      final snapshot = _harness.snapshot;
      if (snapshot == null || !_canResolveFrom(snapshot.lifecycle)) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      final localUid = _validateIdentifier(
        _localParticipantUid(),
        invalidRequest: true,
      );
      if (!_isParticipant(snapshot, localUid)) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      final identity = _ResolutionIdentity(
        callId: _validateIdentifier(snapshot.callId, invalidRequest: true),
        localParticipantUid: localUid,
        isVideo: isVideo,
        idempotencyKey: idempotencyKey,
      );
      final cached = _cachedConfig;
      if (cached != null && _isCacheUsable(cached, identity)) return cached;

      final inFlight = _inFlightFuture;
      final inFlightIdentity = _inFlightIdentity;
      if (inFlight != null && inFlightIdentity != null) {
        if (inFlightIdentity == identity) return inFlight;
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final generation = _generation;
      final request = CallV2RtcConfigRequest(
        callId: identity.callId,
        localParticipantUid: identity.localParticipantUid,
        isVideo: identity.isVideo,
        idempotencyKey: identity.idempotencyKey,
      );
      _inFlightIdentity = identity;
      final fresh = _resolveFresh(generation, identity, request);
      _inFlightFuture = fresh;
      return fresh;
    });
  }

  void invalidate() {
    _generation += 1;
    _cachedConfig = null;
    _inFlightIdentity = null;
    _inFlightFuture = null;
  }

  void handleAuthoritativeSnapshot(CallSnapshot snapshot) {
    final cached = _cachedConfig;
    final inFlight = _inFlightIdentity;
    final ownedCallId = cached?.callId ?? inFlight?.callId;
    if (ownedCallId == null) return;
    if (snapshot.callId != ownedCallId || snapshot.lifecycle.isTerminal) {
      invalidate();
    }
  }

  Future<CallV2ResolvedRtcConfig> _resolveFresh(
    int generation,
    _ResolutionIdentity identity,
    CallV2RtcConfigRequest request,
  ) async {
    try {
      final Object? raw;
      try {
        raw = await _provider.resolveRtcConfig(request);
      } on CallV2ClientError {
        rethrow;
      } catch (_) {
        throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      }
      _requireCurrentGeneration(generation, identity);
      _requireCurrentSnapshot(identity);
      final resolved = _parseResolvedConfig(raw, identity);
      _requireCurrentGeneration(generation, identity);
      _cachedConfig = resolved;
      return resolved;
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    } finally {
      if (_inFlightIdentity == identity) {
        _inFlightIdentity = null;
        _inFlightFuture = null;
      }
    }
  }

  void _requireCurrentGeneration(
    int generation,
    _ResolutionIdentity identity,
  ) {
    if (generation != _generation || _inFlightIdentity != identity) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  void _requireCurrentSnapshot(_ResolutionIdentity identity) {
    final snapshot = _harness.snapshot;
    if (snapshot == null ||
        snapshot.callId != identity.callId ||
        !_canResolveFrom(snapshot.lifecycle) ||
        !_isParticipant(snapshot, identity.localParticipantUid) ||
        _localParticipantUid() != identity.localParticipantUid) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
  }

  bool _isCacheUsable(
    CallV2ResolvedRtcConfig config,
    _ResolutionIdentity identity,
  ) {
    if (config.callId != identity.callId ||
        config.localParticipantUid != identity.localParticipantUid ||
        config.isVideo != identity.isVideo) {
      return false;
    }
    final snapshot = _harness.snapshot;
    if (snapshot == null ||
        snapshot.callId != config.callId ||
        !_canResolveFrom(snapshot.lifecycle) ||
        !_isParticipant(snapshot, config.localParticipantUid)) {
      return false;
    }
    return config.expiresAt.difference(_now()) >= _minimumRemainingValidity;
  }

  CallV2ResolvedRtcConfig _parseResolvedConfig(
    Object? raw,
    _ResolutionIdentity identity,
  ) {
    final data = _responseMap(raw);
    for (final key in _requiredKeys) {
      if (!data.containsKey(key)) {
        throw const FormatException('Invalid RTC config response');
      }
    }

    final callId = _requiredIdentifier(data, 'callId');
    final localParticipantUid = _requiredIdentifier(
      data,
      'localParticipantUid',
    );
    final channelName = _requiredIdentifier(data, 'channelName');
    final rtcUid = _requiredRtcUid(data, 'rtcUid');
    final token = _requiredToken(data, 'token');
    final isVideo = _requiredBool(data, 'isVideo');
    final issuedAt = _requiredTimestamp(data, 'issuedAt');
    final expiresAt = _requiredTimestamp(data, 'expiresAt');
    final idempotentReplay = _requiredBool(data, 'idempotentReplay');

    if (callId != identity.callId ||
        localParticipantUid != identity.localParticipantUid ||
        isVideo != identity.isVideo) {
      throw const FormatException('RTC config identity mismatch');
    }
    final now = _now();
    if (issuedAt.isAfter(now.add(_clockSkew)) ||
        !expiresAt.isAfter(now) ||
        !expiresAt.isAfter(issuedAt) ||
        expiresAt.difference(issuedAt) > _maximumCredentialLifetime) {
      throw const FormatException('Invalid RTC config lifetime');
    }

    return CallV2ResolvedRtcConfig(
      callId: callId,
      localParticipantUid: localParticipantUid,
      channelName: channelName,
      rtcUid: rtcUid,
      token: token,
      isVideo: isVideo,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      idempotentReplay: idempotentReplay,
    );
  }

  DateTime _now() => _clock().toUtc();
}

class _ResolutionIdentity {
  const _ResolutionIdentity({
    required this.callId,
    required this.localParticipantUid,
    required this.isVideo,
    required this.idempotencyKey,
  });

  final String callId;
  final String localParticipantUid;
  final bool isVideo;
  final String idempotencyKey;

  @override
  bool operator ==(Object other) {
    return other is _ResolutionIdentity &&
        other.callId == callId &&
        other.localParticipantUid == localParticipantUid &&
        other.isVideo == isVideo &&
        other.idempotencyKey == idempotencyKey;
  }

  @override
  int get hashCode {
    return Object.hash(callId, localParticipantUid, isVideo, idempotencyKey);
  }
}

const _maximumIdentifierLength = 128;
const _maximumTokenLength = 4096;
const _maximumCredentialLifetime = Duration(minutes: 15);
const _minimumRemainingValidity = Duration(seconds: 60);
const _clockSkew = Duration(seconds: 30);

const _requiredKeys = <String>{
  'callId',
  'localParticipantUid',
  'channelName',
  'rtcUid',
  'token',
  'isVideo',
  'issuedAt',
  'expiresAt',
  'idempotentReplay',
};

const _privateKeys = <String>{
  'actorUid',
  'authenticatedUid',
  'providerAppId',
  'appCertificate',
  'signingSecret',
  'secret',
  'privateKey',
  'channelKey',
  'rawTokenPayload',
  'claims',
  'fencingToken',
  'commandId',
  'taskId',
  'callOps',
  'lockClaims',
  'diagnostics',
};

Map<String, Object?> _responseMap(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('Invalid RTC config response');
  }
  final parsed = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String ||
        _privateKeys.contains(key) ||
        !_requiredKeys.contains(key)) {
      throw const FormatException('Invalid RTC config response');
    }
    parsed[key] = entry.value;
  }
  return parsed;
}

bool _canResolveFrom(CallLifecycle lifecycle) {
  return lifecycle == CallLifecycle.accepted ||
      lifecycle == CallLifecycle.active;
}

bool _isParticipant(CallSnapshot snapshot, String uid) {
  return snapshot.callerUid == uid || snapshot.calleeUid == uid;
}

String _validateIdentifier(String value, {required bool invalidRequest}) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > _maximumIdentifierLength ||
      value.contains('/')) {
    throw CallV2ClientError(
      invalidRequest
          ? CallV2ClientErrorCode.invalidRequest
          : CallV2ClientErrorCode.rejected,
    );
  }
  return value;
}

String _requiredIdentifier(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String) {
    return _validateIdentifier(value, invalidRequest: false);
  }
  throw const FormatException('Invalid RTC config identifier');
}

String _requiredToken(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is String &&
      value.isNotEmpty &&
      value.trim() == value &&
      value.length <= _maximumTokenLength) {
    return value;
  }
  throw const FormatException('Invalid RTC config token');
}

int _requiredRtcUid(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is int && value > 0 && value <= callV2MaxSafeInteger) {
    return value;
  }
  throw const FormatException('Invalid RTC uid');
}

bool _requiredBool(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is bool) return value;
  throw const FormatException('Invalid RTC config bool');
}

DateTime _requiredTimestamp(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is DateTime) return value.toUtc();
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  throw const FormatException('Invalid RTC config timestamp');
}
