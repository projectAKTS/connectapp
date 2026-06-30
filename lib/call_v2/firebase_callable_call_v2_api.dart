import 'package:cloud_functions/cloud_functions.dart';

import 'call_v2_api.dart';

typedef CallV2CallableInvocation = Future<Object?> Function(
  String functionName,
  Map<String, Object?> data,
);

class FirebaseCallableCallV2Api implements CallableCallV2Api {
  FirebaseCallableCallV2Api({
    required CallV2CallableInvocation invoke,
  }) : _invoke = invoke;

  factory FirebaseCallableCallV2Api.fromFirebaseFunctions({
    required FirebaseFunctions functions,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return FirebaseCallableCallV2Api(
      invoke: (functionName, data) async {
        final callable = functions.httpsCallable(
          functionName,
          options: HttpsCallableOptions(timeout: timeout),
        );
        final result = await callable.call<Object?>(data);
        return result.data;
      },
    );
  }

  final CallV2CallableInvocation _invoke;

  @override
  Future<Object?> startCallV2(Map<String, Object?> request) {
    return _invokeCallable('startCallV2', request);
  }

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) {
    return _invokeCallable('acceptCallV2', request);
  }

  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) {
    return _invokeCallable('declineCallV2', request);
  }

  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) {
    return _invokeCallable('cancelCallV2', request);
  }

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) {
    return _invokeCallable('endCallV2', request);
  }

  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) {
    return _invokeCallable('reportParticipantMediaV2', request);
  }

  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) {
    return _invokeCallable('renewActiveCallLeaseV2', request);
  }

  Future<Object?> _invokeCallable(
    String functionName,
    Map<String, Object?> request,
  ) async {
    try {
      return await _invoke(functionName, request);
    } on FirebaseFunctionsException catch (error) {
      throw CallV2ClientError(_codeForFirebaseException(error.code));
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
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
      case 'aborted':
      case 'out-of-range':
        return CallV2ClientErrorCode.rejected;
      case 'deadline-exceeded':
      case 'unavailable':
      case 'internal':
      case 'unknown':
      case 'resource-exhausted':
      case 'data-loss':
      default:
        return CallV2ClientErrorCode.unavailable;
    }
  }
}
