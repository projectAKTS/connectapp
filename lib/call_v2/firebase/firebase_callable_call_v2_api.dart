import 'package:cloud_functions/cloud_functions.dart';

import '../call_v2_api.dart';
import '../call_v2_feature_gate.dart';
import 'call_v2_callable_transport.dart';
import 'firebase_functions_call_v2_transport.dart';

class FirebaseCallableCallV2Api implements CallableCallV2Api {
  FirebaseCallableCallV2Api({
    required CallV2FeatureGate featureGate,
    required CallV2CallableTransport transport,
  })  : _featureGate = featureGate,
        _transport = transport;

  factory FirebaseCallableCallV2Api.fromFirebaseFunctions({
    required CallV2FeatureGate featureGate,
    required FirebaseFunctions functions,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return FirebaseCallableCallV2Api(
      featureGate: featureGate,
      transport: FirebaseFunctionsCallV2Transport(
        functions: functions,
        timeout: timeout,
      ),
    );
  }

  final CallV2FeatureGate _featureGate;
  final CallV2CallableTransport _transport;

  @override
  Future<Object?> startCallV2(Map<String, Object?> request) {
    return _invokeCallable(CallV2CallableNames.start, request);
  }

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) {
    return _invokeCallable(CallV2CallableNames.accept, request);
  }

  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) {
    return _invokeCallable(CallV2CallableNames.decline, request);
  }

  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) {
    return _invokeCallable(CallV2CallableNames.cancel, request);
  }

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) {
    return _invokeCallable(CallV2CallableNames.end, request);
  }

  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) {
    return _invokeCallable(CallV2CallableNames.reportParticipantMedia, request);
  }

  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) {
    return _invokeCallable(CallV2CallableNames.renewActiveCallLease, request);
  }

  Future<Object?> _invokeCallable(
    String callableName,
    Map<String, Object?> request,
  ) async {
    if (!_featureGate.enabled) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }

    final copiedRequest = _jsonCompatibleMapCopy(request);
    try {
      final raw = await _transport.call(callableName, copiedRequest);
      return _normalizedResponse(raw);
    } on CallV2ClientError {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw CallV2ClientError(_codeForFirebaseException(error.code));
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }
}

Map<String, Object?> _jsonCompatibleMapCopy(Map<String, Object?> source) {
  final copied = <String, Object?>{};
  for (final entry in source.entries) {
    copied[entry.key] = _jsonCompatibleValueCopy(entry.value);
  }
  return copied;
}

Object? _jsonCompatibleValueCopy(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    final copied = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
      }
      copied[key] = _jsonCompatibleValueCopy(entry.value);
    }
    return copied;
  }
  if (value is Iterable) {
    return value.map(_jsonCompatibleValueCopy).toList(growable: false);
  }
  throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
}

Object? _normalizedResponse(Object? raw) {
  if (raw is! Map) {
    throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
  }
  return _normalizedResponseMap(raw);
}

Object? _normalizedResponseValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return _normalizedResponseMap(value);
  }
  if (value is Iterable) {
    return value.map(_normalizedResponseValue).toList(growable: false);
  }
  throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
}

Map<String, Object?> _normalizedResponseMap(Map<dynamic, dynamic> raw) {
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String || _firebaseMetadataKeys.contains(key)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    normalized[key] = _normalizedResponseValue(entry.value);
  }
  return normalized;
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

const _firebaseMetadataKeys = <String>{
  'metadata',
  'headers',
  'functionUrl',
  'projectId',
};
