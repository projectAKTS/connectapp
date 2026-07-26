import 'package:permission_handler/permission_handler.dart';

import 'call_v2_permission_adapter.dart';

abstract interface class RealCallV2PermissionClient {
  Future<CallV2PermissionDecision> check(CallV2PermissionKind permission);

  Future<CallV2PermissionDecision> request(CallV2PermissionKind permission);
}

class PermissionHandlerCallV2PermissionClient
    implements RealCallV2PermissionClient {
  const PermissionHandlerCallV2PermissionClient();

  @override
  Future<CallV2PermissionDecision> check(
    CallV2PermissionKind permission,
  ) async {
    return _decisionFor(await _permissionFor(permission).status);
  }

  @override
  Future<CallV2PermissionDecision> request(
    CallV2PermissionKind permission,
  ) async {
    return _decisionFor(await _permissionFor(permission).request());
  }
}

class RealCallV2PermissionAdapter implements CallV2PermissionAdapter {
  const RealCallV2PermissionAdapter({
    this.allowRequests = false,
    this.client = const PermissionHandlerCallV2PermissionClient(),
  });

  final bool allowRequests;
  final RealCallV2PermissionClient client;

  @override
  Future<CallV2PermissionDecision> checkMicrophone() async {
    return client.check(CallV2PermissionKind.microphone);
  }

  @override
  Future<CallV2PermissionDecision> checkCamera() async {
    return client.check(CallV2PermissionKind.camera);
  }

  @override
  Future<CallV2PermissionDecision> requestMicrophone() async {
    if (!allowRequests) return CallV2PermissionDecision.denied;
    return client.request(CallV2PermissionKind.microphone);
  }

  @override
  Future<CallV2PermissionDecision> requestCamera() async {
    if (!allowRequests) return CallV2PermissionDecision.denied;
    return client.request(CallV2PermissionKind.camera);
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'requestsAllowed': allowRequests,
      'realPromptAvailable': true,
    };
  }
}

Permission _permissionFor(CallV2PermissionKind permission) {
  switch (permission) {
    case CallV2PermissionKind.microphone:
      return Permission.microphone;
    case CallV2PermissionKind.camera:
      return Permission.camera;
  }
}

CallV2PermissionDecision _decisionFor(PermissionStatus status) {
  if (status.isGranted || status.isLimited) {
    return CallV2PermissionDecision.granted;
  }
  if (status.isPermanentlyDenied) {
    return CallV2PermissionDecision.permanentlyDenied;
  }
  if (status.isDenied || status.isRestricted) {
    return CallV2PermissionDecision.denied;
  }
  return CallV2PermissionDecision.unavailable;
}
