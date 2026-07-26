import '../runtime/call_v2_internal_session.dart';
import 'call_v2_token_provider.dart';

class CallV2AccessRequestMapping {
  const CallV2AccessRequestMapping({
    required this.request,
    required this.backendData,
  });

  final CallV2TokenRequest request;
  final Map<String, Object?> backendData;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'requestReady': true,
      'videoReady': request.mode.name == 'video',
      'shapeReady': backendData.length == 3,
    };
  }

  @override
  String toString() => 'CallV2AccessRequestMapping(${toSafeDebugMap()})';
}

class CallV2TokenRequestMapper {
  const CallV2TokenRequestMapper();

  CallV2AccessRequestMapping map(CallV2InternalSession session) {
    return CallV2AccessRequestMapping(
      request: CallV2TokenRequest(mode: session.mode),
      backendData: Map<String, Object?>.unmodifiable(<String, Object?>{
        'callId': session.callIdentifier,
        'participantUid': session.localHandle.value,
        'isVideo': session.mode.name == 'video',
      }),
    );
  }
}
