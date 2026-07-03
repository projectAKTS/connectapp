import 'package:firebase_auth/firebase_auth.dart';

import '../call_v2_api.dart';
import '../call_v2_feature_gate.dart';
import '../identity/call_v2_auth_identity_provider.dart';

class FirebaseCallV2AuthIdentityProvider implements CallV2AuthIdentityProvider {
  FirebaseCallV2AuthIdentityProvider({
    required CallV2FeatureGate featureGate,
    required FirebaseAuth auth,
  })  : _featureGate = featureGate,
        _auth = auth;

  final CallV2FeatureGate _featureGate;
  final FirebaseAuth _auth;

  @override
  Future<CallV2AuthenticatedIdentity> requireAuthenticatedIdentity() async {
    if (!_featureGate.enabled) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const CallV2ClientError(CallV2ClientErrorCode.unauthorized);
      }
      return CallV2AuthenticatedIdentity(uid: user.uid);
    } on CallV2ClientError {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw CallV2ClientError(_codeForFirebaseAuthException(error.code));
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  String toString() {
    return 'FirebaseCallV2AuthIdentityProvider(featureEnabled: '
        '${_featureGate.enabled})';
  }
}

CallV2ClientErrorCode _codeForFirebaseAuthException(String code) {
  switch (code) {
    case 'unauthenticated':
    case 'permission-denied':
    case 'user-disabled':
      return CallV2ClientErrorCode.unauthorized;
    case 'network-request-failed':
    case 'too-many-requests':
    case 'internal-error':
    default:
      return CallV2ClientErrorCode.unavailable;
  }
}
