import '../runtime/call_v2_runtime_state.dart';

class CallV2TokenRequest {
  const CallV2TokenRequest({
    required this.mode,
  });

  final CallV2RuntimeCallMode mode;
}

class CallV2TokenResult {
  const CallV2TokenResult({
    required this.channelAlias,
    required this.rtcUid,
    required this.expiresInSeconds,
    required String token,
  }) : _token = token;

  final String channelAlias;
  final int rtcUid;
  final int expiresInSeconds;
  final String _token;

  String get token => _token;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'hasToken': _token.isNotEmpty,
      'channelAlias': channelAlias,
      'rtcUidPresent': rtcUid > 0,
      'expiresInSeconds': expiresInSeconds,
    };
  }

  @override
  String toString() {
    return 'CallV2TokenResult('
        'hasToken: ${_token.isNotEmpty}, '
        'channelAlias: $channelAlias, '
        'rtcUidPresent: ${rtcUid > 0}, '
        'expiresInSeconds: $expiresInSeconds'
        ')';
  }
}

abstract interface class CallV2TokenProvider {
  Future<CallV2TokenResult> resolveToken(CallV2TokenRequest request);
}
