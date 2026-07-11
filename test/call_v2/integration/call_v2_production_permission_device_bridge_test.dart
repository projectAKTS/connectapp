import 'package:connect_app/call_v2/integration/call_v2_production_permission_device_bridge.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_permission_device_bridge_event.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_permission_device_bridge_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_state.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default rollout false initialize is disabled and local only', () async {
    final fixture = _Fixture(rolloutEnabled: false);

    final result = await fixture.bridge.initialize(generation: 1);

    expect(result.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.disabled);
    expect(fixture.runtime.status.lifecycle.name, 'uninitialized');
    expect(fixture.sink.showCount, 0);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.bridge.status.rolloutEnabled, isFalse);
  });

  test('default rollout false events do not call runtime bridge', () async {
    final fixture = _Fixture(rolloutEnabled: false);

    final result = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent
          .microphonePermissionDenied(generation: 2),
    );

    expect(result.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.disabled);
    expect(fixture.sink.showCount, 0);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.runtime.status.lifecycle.name, 'uninitialized');
  });

  test('global rollout remains false', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('rollout true initialize delegates safely when runtime is injected',
      () async {
    final fixture = _Fixture();

    final result = await fixture.bridge.initialize();

    expect(result.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.initialized);
    expect(fixture.runtime.status.rolloutEnabled, isTrue);
  });

  test('rollout true initialize can initialize local state without runtime',
      () async {
    final bridge = CallV2ProductionPermissionDeviceBridge(
      rolloutEnabled: () => true,
    );

    final result = await bridge.initialize(generation: 3);

    expect(result.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.initialized);
    expect(bridge.status.currentGeneration, 3);
  });

  test('permission denied maps to controlled failure without requesting access',
      () async {
    final fixture = _Fixture();

    final result = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent
          .microphonePermissionDenied(generation: 4),
    );

    expect(result.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 1);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.bridge.status.lastRecoveryPolicy,
        CallV2ProductionPermissionDeviceRecoveryPolicy.showControlledFailure);
  });

  test('permanent permission denial requires user action', () async {
    final fixture = _Fixture();

    final mic = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent
          .microphonePermissionPermanentlyDenied(generation: 5),
    );
    final camera = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent
          .cameraPermissionPermanentlyDenied(generation: 6),
    );

    expect(mic.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.rejected);
    expect(camera.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.rejected);
    expect(mic.error,
        CallV2ProductionPermissionDeviceBridgeError.userActionRequired);
    expect(camera.error,
        CallV2ProductionPermissionDeviceBridgeError.userActionRequired);
    expect(fixture.sink.showCount, 0);
  });

  test('camera denied and unavailable are controlled failures', () async {
    final fixture = _Fixture();

    final denied = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.cameraPermissionDenied(
        generation: 7,
      ),
    );
    final unavailable = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.cameraUnavailable(
        generation: 8,
      ),
    );

    expect(denied.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.delegated);
    expect(unavailable.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 2);
  });

  test('microphone unavailable is a controlled failure', () async {
    final fixture = _Fixture();

    final result = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.microphoneUnavailable(
        generation: 9,
      ),
    );

    expect(result.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 1);
  });

  test('device route changed no-ops unless explicit recovery is requested',
      () async {
    final fixture = _Fixture();

    final noOp = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.deviceRouteChanged(
        generation: 10,
      ),
    );
    final recovery = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.deviceRouteChanged(
        generation: 11,
        recoveryPolicy: CallV2ProductionPermissionDeviceRecoveryPolicy
            .showControlledFailure,
      ),
    );

    expect(
        noOp.status, CallV2ProductionPermissionDeviceBridgeResultStatus.noOp);
    expect(recovery.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 1);
  });

  test('toggle failures do not terminate unless explicit policy says so',
      () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final speaker = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.speakerToggleFailed(
        generation: 12,
      ),
    );
    final camera = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.cameraSwitchFailed(
        generation: 13,
      ),
    );
    final terminal = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.speakerToggleFailed(
        generation: 14,
        recoveryPolicy:
            CallV2ProductionPermissionDeviceRecoveryPolicy.terminalClose,
      ),
    );

    expect(speaker.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.noOp);
    expect(
        camera.status, CallV2ProductionPermissionDeviceBridgeResultStatus.noOp);
    expect(terminal.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.terminal);
    expect(fixture.bridge.status.terminal, isTrue);
  });

  test('recovery requested applies explicit policies', () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final retry = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent
          .permissionRecoveryRequested(
        generation: 15,
        recoveryPolicy: CallV2ProductionPermissionDeviceRecoveryPolicy
            .retryBlockedUntilUserAction,
      ),
    );
    final close = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.deviceRecoveryRequested(
        generation: 16,
        recoveryPolicy:
            CallV2ProductionPermissionDeviceRecoveryPolicy.closeCall,
      ),
    );

    expect(retry.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.rejected);
    expect(retry.error,
        CallV2ProductionPermissionDeviceBridgeError.userActionRequired);
    expect(close.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.closed);
  });

  test('closeRequested delegates safe close only when policy says so',
      () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final noOp = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.closeRequested(
        generation: 17,
        recoveryPolicy: CallV2ProductionPermissionDeviceRecoveryPolicy.noOp,
      ),
    );
    final closed = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.closeRequested(
        generation: 18,
      ),
    );

    expect(
        noOp.status, CallV2ProductionPermissionDeviceBridgeResultStatus.noOp);
    expect(closed.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.closed);
    expect(fixture.sink.closeCount, 1);
  });

  test('dispose is idempotent and events after dispose do not delegate',
      () async {
    final fixture = _Fixture();

    final first = fixture.bridge.dispose();
    final statusAfterDispose = fixture.bridge.status;
    final second = fixture.bridge.dispose();
    final afterDispose = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.cameraUnavailable(
        generation: 19,
      ),
    );

    expect(first.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.disposed);
    expect(second.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.disposed);
    expect(afterDispose.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.disposed);
    expect(fixture.bridge.status, same(statusAfterDispose));
    expect(fixture.sink.showCount, 0);
  });

  test('negative and stale generations are controlled rejections', () async {
    final fixture = _Fixture();

    final negative = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.invalid(generation: -1),
    );
    await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.deviceRouteChanged(
        generation: 20,
      ),
    );
    final stale = await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.deviceRouteChanged(
        generation: 19,
      ),
    );

    expect(negative.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.rejected);
    expect(negative.error,
        CallV2ProductionPermissionDeviceBridgeError.invalidGeneration);
    expect(stale.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.rejected);
    expect(stale.error,
        CallV2ProductionPermissionDeviceBridgeError.staleGeneration);
  });

  test('runtime rejection and disabled result map safely', () async {
    final rejectedFixture = _Fixture(
      showResult: const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.routeFactoryRejected,
      ),
    );
    final disabledFixture = _Fixture(runtimeRolloutEnabled: false);

    final rejected = await rejectedFixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.cameraUnavailable(
        generation: 21,
      ),
    );
    final disabled = await disabledFixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent.cameraUnavailable(
        generation: 22,
      ),
    );

    expect(rejected.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.rejected);
    expect(rejected.error,
        CallV2ProductionPermissionDeviceBridgeError.runtimeBridgeRejected);
    expect(disabled.status,
        CallV2ProductionPermissionDeviceBridgeResultStatus.disabled);
  });

  test('debug output is enum and generation only', () async {
    final fixture = _Fixture();

    await fixture.bridge.handleEvent(
      const CallV2ProductionPermissionDeviceBridgeEvent
          .microphonePermissionDenied(generation: 23),
    );
    final eventDebug = const CallV2ProductionPermissionDeviceBridgeEvent
        .deviceRecoveryRequested(
      generation: 24,
      deviceKind: CallV2ProductionPermissionDeviceKind.speaker,
      recoveryPolicy: CallV2ProductionPermissionDeviceRecoveryPolicy.noOp,
    ).toString();
    final resultDebug =
        const CallV2ProductionPermissionDeviceBridgeResult.rejected(
      CallV2ProductionPermissionDeviceBridgeError.runtimeBridgeRejected,
      generation: 25,
    ).toString();
    final statusDebug = fixture.bridge.status.toString();

    for (final text in <String>[eventDebug, resultDebug, statusDebug]) {
      for (final forbidden in <String>[
        '/call-v2',
        'uid',
        'callId',
        'participant',
        'token',
        'channel',
        'credential',
        'Exception',
        'StackTrace',
        'raw',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });
}

final class _Fixture {
  _Fixture({
    bool rolloutEnabled = true,
    bool runtimeRolloutEnabled = true,
    CallV2ProductionRouteSinkResult showResult =
        const CallV2ProductionRouteSinkResult.pushed(
      destination: CallV2ProductionRouteDestination.controlledFailure,
      generation: 1,
    ),
    CallV2ProductionRouteSinkResult closeResult =
        const CallV2ProductionRouteSinkResult.noOp(),
  }) {
    sink = _CountingRouteSink(
      showResult: showResult,
      closeResult: closeResult,
    );
    runtime = CallV2ProductionRuntimeUiBridge(
      owner: CallV2ProductionUiCompositionOwner(
        routeSink: sink,
        rolloutEnabled: () => runtimeRolloutEnabled,
      ),
      rolloutEnabled: () => runtimeRolloutEnabled,
    );
    bridge = CallV2ProductionPermissionDeviceBridge(
      runtimeUiBridge: runtime,
      rolloutEnabled: () => rolloutEnabled,
      disposeRuntimeUiBridge: true,
    );
  }

  late final _CountingRouteSink sink;
  late final CallV2ProductionRuntimeUiBridge runtime;
  late final CallV2ProductionPermissionDeviceBridge bridge;
}

final class _CountingRouteSink implements CallV2ProductionRouteSink {
  _CountingRouteSink({
    this.showResult = const CallV2ProductionRouteSinkResult.pushed(
      destination: CallV2ProductionRouteDestination.controlledFailure,
      generation: 1,
    ),
    this.closeResult = const CallV2ProductionRouteSinkResult.noOp(),
  });

  final CallV2ProductionRouteSinkResult showResult;
  final CallV2ProductionRouteSinkResult closeResult;
  var showCount = 0;
  var closeCount = 0;
  var disposeCount = 0;

  @override
  CallV2ProductionRouteSinkState get state =>
      const CallV2ProductionRouteSinkState();

  @override
  Future<CallV2ProductionRouteSinkResult> show({
    required CallV2ProductionRouteDescriptor descriptor,
    required CallV2ProductionViewModel viewModel,
    ValueChanged<CallV2ProductionUserAction>? onAction,
    int minimumGeneration = 0,
  }) async {
    showCount += 1;
    if (showResult is CallV2ProductionRouteSinkPushed) {
      return CallV2ProductionRouteSinkResult.pushed(
        destination: descriptor.destination,
        generation: descriptor.generation,
      );
    }
    return showResult;
  }

  @override
  Future<CallV2ProductionRouteSinkResult> close() async {
    closeCount += 1;
    return closeResult;
  }

  @override
  CallV2ProductionRouteSinkResult dispose() {
    disposeCount += 1;
    return const CallV2ProductionRouteSinkResult.noOp();
  }
}
