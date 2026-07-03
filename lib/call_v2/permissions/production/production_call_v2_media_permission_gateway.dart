import '../../call_v2_api.dart';
import '../../call_v2_feature_gate.dart';
import '../call_v2_media_permission_gateway.dart';
import 'call_v2_permission_transport.dart';

class ProductionCallV2MediaPermissionGateway
    implements CallV2MediaPermissionGateway {
  ProductionCallV2MediaPermissionGateway({
    required CallV2FeatureGate featureGate,
    required CallV2PermissionTransport transport,
  })  : _featureGate = featureGate,
        _transport = transport;

  final CallV2FeatureGate _featureGate;
  final CallV2PermissionTransport _transport;

  @override
  Future<CallV2MediaPermissionResult> request(
    CallV2MediaPermissionRequest request,
  ) async {
    if (!_featureGate.enabled) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }

    try {
      final microphone = request.requiresMicrophone
          ? await _transport.request(CallV2MediaPermission.microphone)
          : CallV2PermissionStatus.granted;
      final camera = request.requiresCamera
          ? await _transport.request(CallV2MediaPermission.camera)
          : CallV2PermissionStatus.granted;
      return CallV2MediaPermissionResult(
        requiresMicrophone: request.requiresMicrophone,
        requiresCamera: request.requiresCamera,
        microphone: microphone,
        camera: camera,
      );
    } on CallV2ClientError {
      rethrow;
    } catch (_) {
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
  }

  @override
  String toString() {
    return 'ProductionCallV2MediaPermissionGateway(featureEnabled: '
        '${_featureGate.enabled})';
  }
}
