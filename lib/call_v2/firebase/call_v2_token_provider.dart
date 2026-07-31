import '../runtime/call_v2_runtime_state.dart';

class CallV2TokenRequest {
  const CallV2TokenRequest({
    required this.mode,
  });

  final CallV2RuntimeCallMode mode;
}

class CallV2TokenResult {
  const CallV2TokenResult({
    this.appId = '',
    required this.channelAlias,
    required this.rtcUid,
    required this.expiresInSeconds,
    required String token,
  }) : _token = token;

  final String appId;
  final String channelAlias;
  final int rtcUid;
  final int expiresInSeconds;
  final String _token;

  String get token => _token;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'accessReady': _token.isNotEmpty,
      'appIdReady': _isAgoraAppId(appId),
      'routingReady': channelAlias.isNotEmpty,
      'numericHandleReady': rtcUid > 0,
      'expiresInSeconds': expiresInSeconds,
    };
  }

  @override
  String toString() {
    return 'CallV2AccessResult('
        'accessReady: ${_token.isNotEmpty}, '
        'appIdReady: ${_isAgoraAppId(appId)}, '
        'routingReady: ${channelAlias.isNotEmpty}, '
        'numericHandleReady: ${rtcUid > 0}, '
        'expiresInSeconds: $expiresInSeconds'
        ')';
  }
}

abstract interface class CallV2TokenProvider {
  Future<CallV2TokenResult> resolveToken(CallV2TokenRequest request);
}

bool isCallV2AgoraAppId(String value) => _isAgoraAppId(value);

bool _isAgoraAppId(String value) {
  return RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(value.trim());
}
