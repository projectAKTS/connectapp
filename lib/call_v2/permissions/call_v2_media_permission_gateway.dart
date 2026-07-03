enum CallV2MediaPermission {
  microphone,
  camera,
}

enum CallV2PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

class CallV2MediaPermissionRequest {
  const CallV2MediaPermissionRequest({
    required this.requiresMicrophone,
    required this.requiresCamera,
  });

  final bool requiresMicrophone;
  final bool requiresCamera;

  @override
  String toString() {
    return 'CallV2MediaPermissionRequest('
        'requiresMicrophone: $requiresMicrophone, '
        'requiresCamera: $requiresCamera'
        ')';
  }
}

class CallV2MediaPermissionResult {
  const CallV2MediaPermissionResult({
    required this.requiresMicrophone,
    required this.requiresCamera,
    required this.microphone,
    required this.camera,
  });

  final bool requiresMicrophone;
  final bool requiresCamera;
  final CallV2PermissionStatus microphone;
  final CallV2PermissionStatus camera;

  bool get allRequiredGranted {
    return (!requiresMicrophone ||
            microphone == CallV2PermissionStatus.granted) &&
        (!requiresCamera || camera == CallV2PermissionStatus.granted);
  }

  @override
  String toString() {
    return 'CallV2MediaPermissionResult('
        'requiresMicrophone: $requiresMicrophone, '
        'requiresCamera: $requiresCamera, '
        'microphone: ${microphone.name}, '
        'camera: ${camera.name}, '
        'allRequiredGranted: $allRequiredGranted'
        ')';
  }
}

abstract interface class CallV2MediaPermissionGateway {
  Future<CallV2MediaPermissionResult> request(
    CallV2MediaPermissionRequest request,
  );
}
