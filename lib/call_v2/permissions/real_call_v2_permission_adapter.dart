import 'call_v2_permission_adapter.dart';

class RealCallV2PermissionAdapter implements CallV2PermissionAdapter {
  const RealCallV2PermissionAdapter({
    this.allowRequests = false,
  });

  final bool allowRequests;

  @override
  Future<CallV2PermissionDecision> checkMicrophone() async {
    return CallV2PermissionDecision.unavailable;
  }

  @override
  Future<CallV2PermissionDecision> checkCamera() async {
    return CallV2PermissionDecision.unavailable;
  }

  @override
  Future<CallV2PermissionDecision> requestMicrophone() async {
    return allowRequests
        ? CallV2PermissionDecision.unavailable
        : CallV2PermissionDecision.denied;
  }

  @override
  Future<CallV2PermissionDecision> requestCamera() async {
    return allowRequests
        ? CallV2PermissionDecision.unavailable
        : CallV2PermissionDecision.denied;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'requestsAllowed': allowRequests,
      'realPromptAvailable': false,
    };
  }
}
