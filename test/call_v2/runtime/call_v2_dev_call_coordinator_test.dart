import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_dev_call_coordinator.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coordinator drives end-to-end fake audio call to active', () async {
    final coordinator = CallV2DevCallCoordinator();
    addTearDown(coordinator.runtime.dispose);

    await coordinator.startOutgoingFakeCall(mode: CallV2RuntimeCallMode.audio);

    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.active);
    await coordinator.endCall();
    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.ended);
  });

  test('coordinator preserves permission denied path', () async {
    final coordinator = CallV2DevCallCoordinator(
      permissionAdapter: FakeCallV2PermissionAdapter(
        microphone: CallV2PermissionDecision.denied,
      ),
    );
    addTearDown(coordinator.runtime.dispose);

    await coordinator.startOutgoingFakeCall(mode: CallV2RuntimeCallMode.audio);

    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.failed);
    expect(
      coordinator.runtime.currentState.errorCategory,
      CallV2RuntimeErrorCategory.permissionDenied,
    );
  });
}
