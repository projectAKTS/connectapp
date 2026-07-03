import '../call_v2_api.dart';
import '../call_v2_callable_results.dart';

abstract interface class CallV2AuthIdentityProvider {
  Future<CallV2AuthenticatedIdentity> requireAuthenticatedIdentity();
}

class CallV2AuthenticatedIdentity {
  CallV2AuthenticatedIdentity({
    required String uid,
  }) : uid = _validatedUid(uid);

  final String uid;

  @override
  String toString() {
    return 'CallV2AuthenticatedIdentity(hasUid: ${uid.isNotEmpty})';
  }
}

String _validatedUid(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > callV2MaxCallableIdentifierLength ||
      value.contains('/')) {
    throw const CallV2ClientError(CallV2ClientErrorCode.unauthorized);
  }
  return value;
}
