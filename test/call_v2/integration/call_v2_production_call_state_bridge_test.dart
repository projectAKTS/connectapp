import 'package:connect_app/call_v2/integration/call_v2_production_call_state_bridge.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_call_state_bridge_event.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_call_state_bridge_result.dart';
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

    expect(result.status, CallV2ProductionCallStateBridgeResultStatus.disabled);
    expect(fixture.runtime.status.lifecycle.name, 'uninitialized');
    expect(fixture.sink.showCount, 0);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.bridge.status.rolloutEnabled, isFalse);
  });

  test('default rollout false events do not call runtime bridge', () async {
    final fixture = _Fixture(rolloutEnabled: false);

    final result = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendConnected(
        generation: 2,
      ),
    );

    expect(result.status, CallV2ProductionCallStateBridgeResultStatus.disabled);
    expect(fixture.sink.showCount, 0);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.runtime.status.lifecycle.name, 'uninitialized');
  });

  test('global rollout remains false', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('rollout true initialize delegates safely or initializes local state',
      () async {
    final delegatedFixture = _Fixture();
    final localBridge = CallV2ProductionCallStateBridge(
      rolloutEnabled: () => true,
    );

    final delegated = await delegatedFixture.bridge.initialize();
    final local = await localBridge.initialize(generation: 3);

    expect(delegated.status,
        CallV2ProductionCallStateBridgeResultStatus.initialized);
    expect(
        local.status, CallV2ProductionCallStateBridgeResultStatus.initialized);
    expect(localBridge.status.currentGeneration, 3);
  });

  test('ringing accepted and connected delegate only safe snapshots', () async {
    final fixture = _Fixture();

    final ringing = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendRinging(
        generation: 4,
      ),
    );
    final accepted = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendAccepted(
        generation: 5,
      ),
    );
    final connected = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendConnected(
        generation: 6,
      ),
    );

    expect(
        ringing.status, CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(
        accepted.status, CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(connected.status,
        CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 3);
    expect(fixture.sink.lastDestinations, <CallV2ProductionRouteDestination>[
      CallV2ProductionRouteDestination.connecting,
      CallV2ProductionRouteDestination.connecting,
      CallV2ProductionRouteDestination.activeAudio,
    ]);
  });

  test('backend terminal states terminal-close safely', () async {
    for (final event in <CallV2ProductionCallStateBridgeEvent>[
      const CallV2ProductionCallStateBridgeEvent.backendEnded(generation: 7),
      const CallV2ProductionCallStateBridgeEvent.backendRejected(generation: 8),
      const CallV2ProductionCallStateBridgeEvent.backendExpired(generation: 9),
      const CallV2ProductionCallStateBridgeEvent.backendCancelled(
        generation: 10,
      ),
    ]) {
      final fixture = _Fixture(
        closeResult: const CallV2ProductionRouteSinkResult.popped(),
      );

      final result = await fixture.bridge.handleEvent(event);

      expect(
          result.status, CallV2ProductionCallStateBridgeResultStatus.terminal);
      expect(fixture.bridge.status.terminal, isTrue);
      expect(fixture.sink.closeCount, 1);
    }
  });

  test(
      'controlled backend and credential failures map to controlled runtime failure',
      () async {
    final fixture = _Fixture();

    final backend = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendFailedControlled(
        generation: 11,
      ),
    );
    final credential = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.credentialRefreshFailed(
        generation: 12,
      ),
    );

    expect(
        backend.status, CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(credential.status,
        CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 2);
    expect(
      fixture.sink.lastDestinations,
      everyElement(CallV2ProductionRouteDestination.controlledFailure),
    );
  });

  test('remote disconnected and reconnected obey explicit policy', () async {
    final fixture = _Fixture();

    final disconnectedNoOp = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.remoteDisconnected(
        generation: 13,
      ),
    );
    final disconnectedFailure = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.remoteDisconnected(
        generation: 14,
        consistencyPolicy:
            CallV2ProductionCallStateConsistencyPolicy.controlledFailure,
      ),
    );
    final reconnectedNoOp = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.remoteReconnected(
        generation: 15,
      ),
    );
    final reconnectedDelegated = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.remoteReconnected(
        generation: 16,
        consistencyPolicy:
            CallV2ProductionCallStateConsistencyPolicy.delegateSnapshot,
      ),
    );

    expect(disconnectedNoOp.status,
        CallV2ProductionCallStateBridgeResultStatus.noOp);
    expect(disconnectedFailure.status,
        CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(reconnectedNoOp.status,
        CallV2ProductionCallStateBridgeResultStatus.noOp);
    expect(reconnectedDelegated.status,
        CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 2);
  });

  test('credential expired requires refresh without refreshing credentials',
      () async {
    final fixture = _Fixture();

    final refresh = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.credentialExpired(
        generation: 17,
      ),
    );
    final failure = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.credentialExpired(
        generation: 18,
        consistencyPolicy:
            CallV2ProductionCallStateConsistencyPolicy.controlledFailure,
      ),
    );

    expect(
      refresh.error,
      CallV2ProductionCallStateBridgeError.credentialRefreshRequired,
    );
    expect(
        failure.status, CallV2ProductionCallStateBridgeResultStatus.delegated);
    expect(fixture.sink.showCount, 1);
  });

  test('ownership mismatch stale and duplicate snapshots do not delegate',
      () async {
    final fixture = _Fixture();

    final mismatch = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.ownershipMismatch(
        generation: 19,
      ),
    );
    final stale = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.staleSnapshot(
        generation: 20,
      ),
    );
    final duplicate = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.duplicateSnapshot(
        generation: 21,
      ),
    );

    expect(
        mismatch.error, CallV2ProductionCallStateBridgeError.ownershipMismatch);
    expect(stale.error, CallV2ProductionCallStateBridgeError.staleGeneration);
    expect(duplicate.status, CallV2ProductionCallStateBridgeResultStatus.noOp);
    expect(fixture.sink.showCount, 0);
  });

  test('close requested delegates safe close only when policy says so',
      () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final noOp = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.closeRequested(
        generation: 22,
        consistencyPolicy: CallV2ProductionCallStateConsistencyPolicy.noOp,
      ),
    );
    final closed = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.closeRequested(
        generation: 23,
      ),
    );

    expect(noOp.status, CallV2ProductionCallStateBridgeResultStatus.noOp);
    expect(closed.status, CallV2ProductionCallStateBridgeResultStatus.closed);
    expect(fixture.sink.closeCount, 1);
  });

  test('dispose is idempotent and events after dispose do not delegate',
      () async {
    final fixture = _Fixture();

    final first = fixture.bridge.dispose();
    final statusAfterDispose = fixture.bridge.status;
    final second = fixture.bridge.dispose();
    final afterDispose = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendConnected(
        generation: 24,
      ),
    );

    expect(first.status, CallV2ProductionCallStateBridgeResultStatus.disposed);
    expect(second.status, CallV2ProductionCallStateBridgeResultStatus.disposed);
    expect(afterDispose.status,
        CallV2ProductionCallStateBridgeResultStatus.disposed);
    expect(fixture.bridge.status, same(statusAfterDispose));
    expect(fixture.sink.showCount, 0);
  });

  test('events after terminal are rejected as terminal and do not delegate',
      () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendEnded(generation: 25),
    );
    final afterTerminal = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendConnected(
        generation: 26,
      ),
    );

    expect(afterTerminal.status,
        CallV2ProductionCallStateBridgeResultStatus.terminal);
    expect(fixture.sink.showCount, 0);
  });

  test('negative and stale generations are controlled rejections', () async {
    final fixture = _Fixture();

    final negative = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.invalid(generation: -1),
    );
    await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.remoteReconnected(
        generation: 27,
      ),
    );
    final stale = await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.remoteReconnected(
        generation: 26,
      ),
    );

    expect(
        negative.status, CallV2ProductionCallStateBridgeResultStatus.rejected);
    expect(
      negative.error,
      CallV2ProductionCallStateBridgeError.invalidGeneration,
    );
    expect(stale.status, CallV2ProductionCallStateBridgeResultStatus.rejected);
    expect(stale.error, CallV2ProductionCallStateBridgeError.staleGeneration);
  });

  test('runtime rejection and disabled result map safely', () async {
    final rejectedFixture = _Fixture(
      showResult: const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.routeFactoryRejected,
      ),
    );
    final disabledFixture = _Fixture(runtimeRolloutEnabled: false);

    final rejected = await rejectedFixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendConnected(
        generation: 28,
      ),
    );
    final disabled = await disabledFixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendConnected(
        generation: 29,
      ),
    );

    expect(
        rejected.status, CallV2ProductionCallStateBridgeResultStatus.rejected);
    expect(
      rejected.error,
      CallV2ProductionCallStateBridgeError.runtimeBridgeRejected,
    );
    expect(
        disabled.status, CallV2ProductionCallStateBridgeResultStatus.disabled);
  });

  test('debug output is enum boolean and generation only', () async {
    final fixture = _Fixture();

    await fixture.bridge.handleEvent(
      const CallV2ProductionCallStateBridgeEvent.backendFailedControlled(
        generation: 30,
      ),
    );
    final eventDebug =
        const CallV2ProductionCallStateBridgeEvent.backendAccepted(
      generation: 31,
      localRole: CallV2ProductionCallStateLocalRole.callee,
    ).toString();
    final resultDebug = const CallV2ProductionCallStateBridgeResult.rejected(
      CallV2ProductionCallStateBridgeError.runtimeBridgeRejected,
      generation: 32,
    ).toString();
    final statusDebug = fixture.bridge.status.toString();

    for (final text in <String>[eventDebug, resultDebug, statusDebug]) {
      for (final forbidden in <String>[
        '/call-v2',
        'uid',
        'callId',
        'token',
        'channel',
        'credential=',
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
      destination: CallV2ProductionRouteDestination.connecting,
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
    bridge = CallV2ProductionCallStateBridge(
      runtimeUiBridge: runtime,
      rolloutEnabled: () => rolloutEnabled,
      disposeRuntimeUiBridge: true,
    );
  }

  late final _CountingRouteSink sink;
  late final CallV2ProductionRuntimeUiBridge runtime;
  late final CallV2ProductionCallStateBridge bridge;
}

final class _CountingRouteSink implements CallV2ProductionRouteSink {
  _CountingRouteSink({
    this.showResult = const CallV2ProductionRouteSinkResult.pushed(
      destination: CallV2ProductionRouteDestination.connecting,
      generation: 1,
    ),
    this.closeResult = const CallV2ProductionRouteSinkResult.noOp(),
  });

  final CallV2ProductionRouteSinkResult showResult;
  final CallV2ProductionRouteSinkResult closeResult;
  var showCount = 0;
  var closeCount = 0;
  var disposeCount = 0;
  final lastDestinations = <CallV2ProductionRouteDestination>[];

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
    lastDestinations.add(descriptor.destination);
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
