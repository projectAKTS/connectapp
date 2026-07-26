import '../firebase/call_v2_token_provider.dart';
import '../runtime/call_v2_internal_session.dart';
import '../runtime/call_v2_runtime_state.dart';
import 'call_v2_rtc_adapter.dart';

class CallV2RtcSessionConfigMapping {
  const CallV2RtcSessionConfigMapping({
    required this.config,
  });

  final CallV2RtcSessionConfig config;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'setupReady': true,
      'accessReady': config.token != null && config.token!.isNotEmpty,
      'routingReady': config.channelName.isNotEmpty,
      'numericHandleReady': config.rtcUid > 0,
      'videoReady': config.isVideo,
    };
  }

  @override
  String toString() => 'CallV2RtcSessionConfigMapping(${toSafeDebugMap()})';
}

class CallV2RtcSessionConfigMapper {
  const CallV2RtcSessionConfigMapper();

  CallV2RtcSessionConfigMapping map({
    required CallV2InternalSession session,
    required CallV2TokenResult access,
  }) {
    return CallV2RtcSessionConfigMapping(
      config: CallV2RtcSessionConfig(
        callId: session.callIdentifier,
        channelName: access.channelAlias,
        rtcUid: access.rtcUid,
        isVideo: session.mode == CallV2RuntimeCallMode.video,
        token: access.token,
      ),
    );
  }
}
