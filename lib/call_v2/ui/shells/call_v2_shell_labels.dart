import '../../call_v2_api.dart';

enum CallV2ScreenShellLabel {
  connecting,
  reconnecting,
  audioCall,
  videoCall,
  callUnavailable,
  permissionRequired,
  retry,
  dismiss,
  leave,
  mute,
  speaker,
  camera,
  switchCamera,
  cancel,
}

String callV2ScreenShellText(CallV2ScreenShellLabel label) {
  return switch (label) {
    CallV2ScreenShellLabel.connecting => 'Connecting',
    CallV2ScreenShellLabel.reconnecting => 'Reconnecting',
    CallV2ScreenShellLabel.audioCall => 'Audio call',
    CallV2ScreenShellLabel.videoCall => 'Video call',
    CallV2ScreenShellLabel.callUnavailable => 'Call unavailable',
    CallV2ScreenShellLabel.permissionRequired => 'Permission required',
    CallV2ScreenShellLabel.retry => 'Retry',
    CallV2ScreenShellLabel.dismiss => 'Dismiss',
    CallV2ScreenShellLabel.leave => 'Leave',
    CallV2ScreenShellLabel.mute => 'Mute',
    CallV2ScreenShellLabel.speaker => 'Speaker',
    CallV2ScreenShellLabel.camera => 'Camera',
    CallV2ScreenShellLabel.switchCamera => 'Switch camera',
    CallV2ScreenShellLabel.cancel => 'Cancel',
  };
}

CallV2ScreenShellLabel callV2FailureLabelFor(CallV2ClientErrorCode code) {
  return switch (code) {
    CallV2ClientErrorCode.unauthorized =>
      CallV2ScreenShellLabel.permissionRequired,
    CallV2ClientErrorCode.unavailable ||
    CallV2ClientErrorCode.rejected ||
    CallV2ClientErrorCode.invalidRequest =>
      CallV2ScreenShellLabel.callUnavailable,
  };
}
