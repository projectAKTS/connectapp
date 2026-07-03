import 'package:permission_handler/permission_handler.dart';

import '../call_v2_media_permission_gateway.dart';

abstract interface class CallV2PermissionTransport {
  Future<CallV2PermissionStatus> request(CallV2MediaPermission permission);
}

class PermissionHandlerCallV2PermissionTransport
    implements CallV2PermissionTransport {
  const PermissionHandlerCallV2PermissionTransport();

  @override
  Future<CallV2PermissionStatus> request(CallV2MediaPermission permission) {
    switch (permission) {
      case CallV2MediaPermission.microphone:
        return _requestPermission(Permission.microphone);
      case CallV2MediaPermission.camera:
        return _requestPermission(Permission.camera);
    }
  }

  @override
  String toString() {
    return 'PermissionHandlerCallV2PermissionTransport()';
  }
}

Future<CallV2PermissionStatus> _requestPermission(
  Permission permission,
) async {
  final status = await permission.request();
  if (status.isGranted || status.isLimited) {
    return CallV2PermissionStatus.granted;
  }
  if (status.isPermanentlyDenied) {
    return CallV2PermissionStatus.permanentlyDenied;
  }
  if (status.isRestricted) {
    return CallV2PermissionStatus.restricted;
  }
  if (status.isDenied) {
    return CallV2PermissionStatus.denied;
  }
  return CallV2PermissionStatus.unavailable;
}
