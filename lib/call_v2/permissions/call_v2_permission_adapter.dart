enum CallV2PermissionKind {
  microphone,
  camera,
}

enum CallV2PermissionDecision {
  granted,
  denied,
  permanentlyDenied,
  unavailable,
}

abstract interface class CallV2PermissionAdapter {
  Future<CallV2PermissionDecision> checkMicrophone();

  Future<CallV2PermissionDecision> checkCamera();

  Future<CallV2PermissionDecision> requestMicrophone();

  Future<CallV2PermissionDecision> requestCamera();
}
