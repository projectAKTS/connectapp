import 'package:cloud_functions/cloud_functions.dart';

import '../call_v2_api.dart';
import '../call_v2_feature_gate.dart';
import '../rtc/call_v2_rtc_config_provider.dart';
import 'call_v2_callable_transport.dart';

class FirebaseCallV2RtcCredentialProvider implements CallV2RtcConfigProvider {
  FirebaseCallV2RtcCredentialProvider({
    required CallV2FeatureGate featureGate,
    required CallV2CallableTransport transport,
  })  : _featureGate = featureGate,
        _transport = transport;

  final CallV2FeatureGate _featureGate;
  final CallV2CallableTransport _transport;

  @override
  Future<Object?> resolveRtcConfig(CallV2RtcConfigRequest request) async {
    if (!_featureGate.enabled) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }

    final payload = <String, Object?>{
      'callId': _validateIdentifier(request.callId),
      'localParticipantUid': _validateIdentifier(
        request.localParticipantUid,
      ),
      'isVideo': request.isVideo,
      'idempotencyKey': _validateIdentifier(request.idempotencyKey),
    };

    try {
      final raw = await _transport.call(
        CallV2CallableNames.resolveRtcConfig,
        payload,
      );
      return _normalizedCredentialResponse(raw);
    } on CallV2ClientError {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw CallV2ClientError(_codeForFirebaseException(error.code));
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }
}

Object? _normalizedCredentialResponse(Object? raw) {
  if (raw is! Map) {
    throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
  }
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String || !_allowedResponseKeys.contains(key)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    normalized[key] = _normalizedCredentialValue(entry.value);
  }
  return normalized;
}

Object? _normalizedCredentialValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    final copied = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || _privateResponseKeys.contains(key)) {
        throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      }
      copied[key] = _normalizedCredentialValue(entry.value);
    }
    return copied;
  }
  if (value is Iterable) {
    return value.map(_normalizedCredentialValue).toList(growable: false);
  }
  throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
}

String _validateIdentifier(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > _maximumIdentifierLength ||
      value.contains('/')) {
    throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
  }
  return value;
}

CallV2ClientErrorCode _codeForFirebaseException(String code) {
  switch (code) {
    case 'unauthenticated':
    case 'permission-denied':
      return CallV2ClientErrorCode.unauthorized;
    case 'invalid-argument':
      return CallV2ClientErrorCode.invalidRequest;
    case 'failed-precondition':
    case 'not-found':
    case 'already-exists':
      return CallV2ClientErrorCode.rejected;
    case 'resource-exhausted':
    case 'unavailable':
    case 'deadline-exceeded':
    case 'internal':
    case 'unknown':
    default:
      return CallV2ClientErrorCode.unavailable;
  }
}

const _maximumIdentifierLength = 128;

const _allowedResponseKeys = <String>{
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

const _privateResponseKeys = <String>{
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
  'metadata',
  'headers',
  'functionUrl',
  'projectId',
};
