import 'package:firebase_core/firebase_core.dart';

import '../app_check/call_v2_app_check_boundary.dart';
import '../call_v2_api.dart';
import '../call_v2_feature_gate.dart';
import 'call_v2_app_check_transport.dart';

class FirebaseCallV2AppCheckBoundary implements CallV2AppCheckBoundary {
  FirebaseCallV2AppCheckBoundary({
    required CallV2FeatureGate featureGate,
    required CallV2AppCheckTransport transport,
  })  : _featureGate = featureGate,
        _transport = transport;

  final CallV2FeatureGate _featureGate;
  final CallV2AppCheckTransport _transport;

  @override
  Future<void> assertAvailable() async {
    if (!_featureGate.enabled) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }

    try {
      final token = await _transport.getToken();
      if (token == null || token.isEmpty) {
        throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      }
    } on CallV2ClientError {
      rethrow;
    } on FirebaseException catch (error) {
      throw CallV2ClientError(_codeForFirebaseException(error.code));
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  String toString() {
    return 'FirebaseCallV2AppCheckBoundary(featureEnabled: '
        '${_featureGate.enabled})';
  }
}

CallV2ClientErrorCode _codeForFirebaseException(String code) {
  switch (code) {
    case 'unauthenticated':
    case 'permission-denied':
      return CallV2ClientErrorCode.unauthorized;
    case 'unavailable':
    case 'deadline-exceeded':
    case 'internal':
    case 'unknown':
    default:
      return CallV2ClientErrorCode.unavailable;
  }
}
