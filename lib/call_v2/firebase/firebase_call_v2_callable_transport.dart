import 'package:cloud_functions/cloud_functions.dart';

import '../call_v2_api.dart';
import 'call_v2_callable_transport.dart';

abstract interface class FirebaseCallV2CallableClient {
  Future<Object?> call(String name, Map<String, Object?> data);
}

class CloudFunctionsCallV2CallableClient
    implements FirebaseCallV2CallableClient {
  CloudFunctionsCallV2CallableClient({
    FirebaseFunctions? functions,
    this.timeout = const Duration(seconds: 30),
  }) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final Duration timeout;

  @override
  Future<Object?> call(String name, Map<String, Object?> data) async {
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: timeout),
    );
    final result = await callable.call<Object?>(Map<String, Object?>.of(data));
    return result.data;
  }
}

class FirebaseCallV2CallableTransport implements CallV2CallableTransport {
  const FirebaseCallV2CallableTransport({
    required FirebaseCallV2CallableClient client,
  }) : _client = client;

  factory FirebaseCallV2CallableTransport.cloudFunctions({
    FirebaseFunctions? functions,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return FirebaseCallV2CallableTransport(
      client: CloudFunctionsCallV2CallableClient(
        functions: functions,
        timeout: timeout,
      ),
    );
  }

  final FirebaseCallV2CallableClient _client;

  @override
  Future<Map<String, Object?>> call(
    String callableName,
    Map<String, Object?> request,
  ) async {
    try {
      final result = await _client.call(
        callableName,
        _copyRequestMap(request),
      );
      if (result is! Map) {
        throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      }
      return _normalizeResponseMap(result);
    } on CallV2ClientError {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw CallV2ClientError(_codeForFirebaseException(error.code));
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }
}

Map<String, Object?> _copyRequestMap(Map<String, Object?> source) {
  final copied = <String, Object?>{};
  for (final entry in source.entries) {
    copied[entry.key] = _copyRequestValue(entry.value);
  }
  return copied;
}

Object? _copyRequestValue(Object? value) {
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
      copied[key] = _copyRequestValue(entry.value);
    }
    return copied;
  }
  if (value is Iterable) {
    return value.map(_copyRequestValue).toList(growable: false);
  }
  throw const CallV2ClientError(CallV2ClientErrorCode.invalidRequest);
}

Map<String, Object?> _normalizeResponseMap(Map<dynamic, dynamic> raw) {
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final key = entry.key;
    if (key is! String || _firebaseMetadataKeys.contains(key)) {
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
