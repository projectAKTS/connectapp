import '../call_v2_api.dart';
import 'call_v2_callable_transport.dart';
import 'call_v2_token_provider.dart';

const String callV2RtcTokenCallableName = 'callV2RtcToken';

class RealCallV2TokenProvider implements CallV2TokenProvider {
  const RealCallV2TokenProvider({
    this.allowRequests = false,
    this.transport,
    this.defaultRequest = const CallV2TokenBackendRequest.disabled(),
  });

  final bool allowRequests;
  final CallV2CallableTransport? transport;
  final CallV2TokenBackendRequest defaultRequest;

  @override
  Future<CallV2TokenResult> resolveToken(CallV2TokenRequest request) async {
    final transport = this.transport;
    if (!allowRequests || transport == null) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    try {
      final raw = await transport.call(
        callV2RtcTokenCallableName,
        defaultRequest.toBackendData(isVideo: request.mode.name == 'video'),
      );
      return _tokenResultFromResponse(raw);
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'requestsAllowed': allowRequests,
      'providerAvailable': transport != null,
      'requestShapeReady': defaultRequest.isReady,
    };
  }
}

class CallV2TokenBackendRequest {
  const CallV2TokenBackendRequest({
    required this.callId,
    required this.localParticipantUid,
  });

  const CallV2TokenBackendRequest.disabled()
      : callId = '',
        localParticipantUid = '';

  final String callId;
  final String localParticipantUid;

  bool get isReady {
    return callId.isNotEmpty && localParticipantUid.isNotEmpty;
  }

  Map<String, Object?> toBackendData({required bool isVideo}) {
    return <String, Object?>{
      'callId': _validateIdentifier(callId),
      'participantUid': _validateIdentifier(localParticipantUid),
      'isVideo': isVideo,
    };
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'ready': isReady,
    };
  }
}

CallV2TokenResult _tokenResultFromResponse(Object? raw) {
  if (raw is! Map) {
    throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
  }
  final data = _normalizeResponseMap(raw);
  final result = data['result'];
  if (data['status'] == 'disabled') {
    throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
  }
  if (data.containsKey('status') && data['status'] != 'ok') {
    throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
  }
  final source = result is Map<String, Object?> ? result : data;
  final alias = source['channelAlias'];
  final handle = source['rtcUid'];
  final access = source['token'];
  final expiresInSeconds = source['expiresInSeconds'];
  final expiresAtMillis = source['expiresAtMillis'];
  if (alias is! String ||
      alias.isEmpty ||
      handle is! num ||
      access is! String ||
      access.isEmpty) {
    throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
  }
  return CallV2TokenResult(
    channelAlias: alias,
    rtcUid: handle.toInt(),
    expiresInSeconds: _expiresInSeconds(
      expiresInSeconds: expiresInSeconds,
      expiresAtMillis: expiresAtMillis,
    ),
    token: access,
  );
}

Map<String, Object?> _normalizeResponseMap(Map raw) {
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    normalized[key] = _normalizeResponseValue(entry.value);
  }
  return normalized;
}

Object? _normalizeResponseValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return _normalizeResponseMap(value);
  }
  if (value is Iterable) {
    return value.map(_normalizeResponseValue).toList(growable: false);
  }
  throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
}

int _expiresInSeconds({
  required Object? expiresInSeconds,
  required Object? expiresAtMillis,
}) {
  if (expiresInSeconds is num && expiresInSeconds > 0) {
    return expiresInSeconds.toInt();
  }
  if (expiresAtMillis is num && expiresAtMillis > 0) {
    final delta =
        expiresAtMillis.toInt() - DateTime.now().toUtc().millisecondsSinceEpoch;
    return delta > 0 ? (delta / 1000).ceil() : 1;
  }
  return 3600;
}

String _validateIdentifier(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > 128 ||
      value.contains('/')) {
    throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
  }
  return value;
}
