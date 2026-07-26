import 'package:connect_app/call_v2/runtime/call_v2_dev_control_state.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/runtime/call_v2_runtime_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idle internal config can start only', () {
    final control = CallV2DevControlState.fromRuntime(
      config: _config,
      state: CallV2RuntimeState.idle,
      hasAccess: false,
      isRtcInitialized: false,
      isRtcJoined: false,
      isDisposed: false,
    );

    expect(control.canStart, isTrue);
    expect(control.canRequestPermissions, isFalse);
    expect(control.canRequestAccess, isFalse);
    expect(control.blockedReason, CallV2DevControlBlockedReason.none);
  });

  test('control state enables each explicit step in order', () {
    expect(
      _control(
        const CallV2RuntimeState(
          phase: CallV2RuntimePhase.permissionPreflight,
        ),
      ).canRequestPermissions,
      isTrue,
    );
    expect(
      _control(
        const CallV2RuntimeState(phase: CallV2RuntimePhase.connecting),
      ).canRequestAccess,
      isTrue,
    );
    expect(
      _control(
        const CallV2RuntimeState(phase: CallV2RuntimePhase.connecting),
        hasAccess: true,
      ).canInitializeRtc,
      isTrue,
    );
    expect(
      _control(
        const CallV2RuntimeState(phase: CallV2RuntimePhase.connecting),
        hasAccess: true,
        isRtcInitialized: true,
      ).canJoinRtc,
      isTrue,
    );
    expect(
      _control(
        const CallV2RuntimeState(phase: CallV2RuntimePhase.ready),
        hasAccess: true,
        isRtcInitialized: true,
        isRtcJoined: true,
      ).canActivate,
      isTrue,
    );
  });

  test('production disabled control state blocks all actions', () {
    final control = CallV2DevControlState.fromRuntime(
      config: const CallV2RuntimeConfig.productionDisabled(),
      state: CallV2RuntimeState.idle,
      hasAccess: false,
      isRtcInitialized: false,
      isRtcJoined: false,
      isDisposed: false,
    );

    expect(control.canStart, isFalse);
    expect(control.canEnd, isFalse);
    expect(
      control.blockedReason,
      CallV2DevControlBlockedReason.productionDisabled,
    );
  });

  test('safe debug contains no unsafe words', () {
    final output = _control(
      const CallV2RuntimeState(phase: CallV2RuntimePhase.connecting),
    ).toSafeDebugMap().toString().toLowerCase();

    for (final forbidden in <String>[
      'token',
      'channel',
      'uid',
      'user',
      'participant',
      'callid',
      'device',
      'credential',
      'secret',
      'raw',
      'payload',
      'stack',
    ]) {
      expect(output, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

const _config = CallV2RuntimeConfig.internalRealDevice(
  allowPermissionRequests: true,
  allowTokenRequests: true,
  allowRtcInitialization: true,
  allowRtcJoin: true,
);

CallV2DevControlState _control(
  CallV2RuntimeState state, {
  bool hasAccess = false,
  bool isRtcInitialized = false,
  bool isRtcJoined = false,
}) {
  return CallV2DevControlState.fromRuntime(
    config: _config,
    state: state,
    hasAccess: hasAccess,
    isRtcInitialized: isRtcInitialized,
    isRtcJoined: isRtcJoined,
    isDisposed: false,
  );
}
