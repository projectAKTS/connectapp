import 'call_v2_permission_adapter.dart';

class FakeCallV2PermissionAdapter implements CallV2PermissionAdapter {
  FakeCallV2PermissionAdapter({
    this.microphone = CallV2PermissionDecision.granted,
    this.camera = CallV2PermissionDecision.granted,
  });

  CallV2PermissionDecision microphone;
  CallV2PermissionDecision camera;
  int checkMicrophoneCount = 0;
  int checkCameraCount = 0;
  int requestMicrophoneCount = 0;
  int requestCameraCount = 0;

  @override
  Future<CallV2PermissionDecision> checkMicrophone() async {
    checkMicrophoneCount += 1;
    return microphone;
  }

  @override
  Future<CallV2PermissionDecision> checkCamera() async {
    checkCameraCount += 1;
    return camera;
  }

  @override
  Future<CallV2PermissionDecision> requestMicrophone() async {
    requestMicrophoneCount += 1;
    return microphone;
  }

  @override
  Future<CallV2PermissionDecision> requestCamera() async {
    requestCameraCount += 1;
    return camera;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'microphone': microphone.name,
      'camera': camera.name,
      'checkMicrophoneCount': checkMicrophoneCount,
      'checkCameraCount': checkCameraCount,
      'requestMicrophoneCount': requestMicrophoneCount,
      'requestCameraCount': requestCameraCount,
    };
  }
}
