import '../call_v2_api.dart';
import 'call_v2_token_provider.dart';

class RealCallV2TokenProvider implements CallV2TokenProvider {
  const RealCallV2TokenProvider({
    this.allowRequests = false,
  });

  final bool allowRequests;

  @override
  Future<CallV2TokenResult> resolveToken(CallV2TokenRequest request) async {
    if (!allowRequests) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'requestsAllowed': allowRequests,
      'providerAvailable': false,
    };
  }
}
