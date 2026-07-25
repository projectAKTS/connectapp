import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake permission adapter supports checks and explicit requests',
      () async {
    final adapter = FakeCallV2PermissionAdapter(
      microphone: CallV2PermissionDecision.granted,
      camera: CallV2PermissionDecision.denied,
    );

    expect(await adapter.checkMicrophone(), CallV2PermissionDecision.granted);
    expect(await adapter.checkCamera(), CallV2PermissionDecision.denied);
    expect(await adapter.requestMicrophone(), CallV2PermissionDecision.granted);
    expect(await adapter.requestCamera(), CallV2PermissionDecision.denied);

    expect(adapter.checkMicrophoneCount, 1);
    expect(adapter.checkCameraCount, 1);
    expect(adapter.requestMicrophoneCount, 1);
    expect(adapter.requestCameraCount, 1);
  });
}
