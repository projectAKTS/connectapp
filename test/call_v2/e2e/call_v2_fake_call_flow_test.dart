import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/fake_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/fake_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/runtime/call_v2_dev_call_coordinator.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake outgoing audio call reaches active and ends', () async {
    final coordinator = CallV2DevCallCoordinator();
    addTearDown(coordinator.runtime.dispose);

    await coordinator.startOutgoingFakeCall(mode: CallV2RuntimeCallMode.audio);
    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.active);
    await coordinator.endCall();
    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.ended);
  });

  test('fake outgoing video call reaches active', () async {
    final coordinator = CallV2DevCallCoordinator();
    addTearDown(coordinator.runtime.dispose);

    await coordinator.startOutgoingFakeCall(mode: CallV2RuntimeCallMode.video);

    expect(coordinator.runtime.currentState.phase, CallV2RuntimePhase.active);
    expect(coordinator.runtime.rtcAdapter.lastConfig!.isVideo, isTrue);
  });

  test('permission denied and RTC failure paths are controlled', () async {
    final denied = CallV2DevCallCoordinator(
      permissionAdapter: FakeCallV2PermissionAdapter(
        microphone: CallV2PermissionDecision.denied,
      ),
    );
    final rtcFailure = CallV2DevCallCoordinator(
      rtcAdapter: FakeCallV2RtcAdapter(failJoin: true),
    );
    addTearDown(denied.runtime.dispose);
    addTearDown(rtcFailure.runtime.dispose);

    await denied.startOutgoingFakeCall(mode: CallV2RuntimeCallMode.audio);
    await rtcFailure.startOutgoingFakeCall(mode: CallV2RuntimeCallMode.audio);

    expect(denied.runtime.currentState.errorCategory,
        CallV2RuntimeErrorCategory.permissionDenied);
    expect(rtcFailure.runtime.currentState.errorCategory,
        CallV2RuntimeErrorCategory.rtcUnavailable);
  });

  test('safe debug, rollout, route exposure, and V1 safety remain unchanged',
      () {
    final coordinator = CallV2DevCallCoordinator();
    addTearDown(coordinator.runtime.dispose);
    final debug = coordinator.toSafeDebugMap().toString().toLowerCase();
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(routerSource, isNot(contains('CallV2DevScreen')));
    expect(mainSource, isNot(contains('FakeCallV2Runtime')));
    expect(mainSource, contains('MyApp'));
    for (final forbidden in <String>[
      'fake-token-not-for-production',
      'fake-channel',
      'token',
      'channel',
      'uid',
      'rtcu',
      'userid',
      'callid',
      'deviceid',
      'credential',
      'secret',
      'stack',
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
