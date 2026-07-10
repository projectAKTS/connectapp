import 'package:connect_app/call_v2/integration/call_v2_production_route_sink.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_state.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge_event.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default rollout false initialize returns disabled without owner call',
      () {
    final owner = CallV2ProductionUiCompositionOwner(
      routeSink: _CountingRouteSink(),
    );
    final bridge = CallV2ProductionRuntimeUiBridge(owner: owner);

    final result = bridge.initialize();

    expect(result.status, CallV2ProductionRuntimeUiBridgeResultStatus.disabled);
    expect(owner.status.rolloutEnabled, isFalse);
    expect(owner.status.lifecycle.name, 'uninitialized');
    expect(bridge.status.lifecycle,
        CallV2ProductionRuntimeUiBridgeLifecycle.disabled);
  });

  test('default rollout false handleEvent does not call owner', () async {
    final sink = _CountingRouteSink();
    final owner = CallV2ProductionUiCompositionOwner(routeSink: sink);
    final bridge = CallV2ProductionRuntimeUiBridge(owner: owner);

    final result = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(
        _connecting(1),
      ),
    );

    expect(result.status, CallV2ProductionRuntimeUiBridgeResultStatus.disabled);
    expect(sink.showCount, 0);
    expect(sink.closeCount, 0);
  });

  test('global rollout remains false', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('rollout true isolated bridge initialize delegates to owner', () {
    final owner = CallV2ProductionUiCompositionOwner(
      routeSink: _CountingRouteSink(),
      rolloutEnabled: () => true,
    );
    final bridge = _enabledBridge(owner);

    final result = bridge.initialize();

    expect(
      result.status,
      CallV2ProductionRuntimeUiBridgeResultStatus.initialized,
    );
    expect(owner.status.rolloutEnabled, isTrue);
  });

  test('presentation snapshot event delegates to owner renderSnapshot',
      () async {
    final sink = _CountingRouteSink();
    final bridge = _enabledBridge(_enabledOwner(sink));

    final result = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(
        _connecting(1),
      ),
    );

    expect(
      result.status,
      CallV2ProductionRuntimeUiBridgeResultStatus.delegated,
    );
    expect(result.destination, CallV2ProductionRouteDestination.connecting);
    expect(sink.showCount, 1);
  });

  test('close event delegates to owner close', () async {
    final sink = _CountingRouteSink(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final bridge = _enabledBridge(_enabledOwner(sink));

    final result = await bridge.handleEvent(
      const CallV2ProductionRuntimeUiBridgeEvent.close(generation: 2),
    );

    expect(result.status, CallV2ProductionRuntimeUiBridgeResultStatus.closed);
    expect(sink.closeCount, 1);
  });

  test('runtime terminated event closes and marks terminal', () async {
    final sink = _CountingRouteSink(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final bridge = _enabledBridge(_enabledOwner(sink));

    final result = await bridge.handleEvent(
      const CallV2ProductionRuntimeUiBridgeEvent.runtimeTerminated(
        generation: 3,
      ),
    );
    final afterTerminal = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(4)),
    );

    expect(result.status, CallV2ProductionRuntimeUiBridgeResultStatus.terminal);
    expect(afterTerminal.status,
        CallV2ProductionRuntimeUiBridgeResultStatus.terminal);
    expect(bridge.status.terminal, isTrue);
    expect(sink.closeCount, 1);
    expect(sink.showCount, 0);
  });

  test('controlled failure event maps to safe failure snapshot', () async {
    final sink = _CountingRouteSink();
    final bridge = _enabledBridge(_enabledOwner(sink));

    final result = await bridge.handleEvent(
      const CallV2ProductionRuntimeUiBridgeEvent.runtimeFailedControlled(
        failure: CallV2ProductionRuntimeUiBridgeControlledFailure.unavailable,
        generation: 4,
      ),
    );

    expect(
      result.status,
      CallV2ProductionRuntimeUiBridgeResultStatus.delegated,
    );
    expect(
      result.destination,
      CallV2ProductionRouteDestination.controlledFailure,
    );
    expect(sink.showCount, 1);
  });

  test('invalid event is a controlled rejection', () async {
    final bridge = _enabledBridge(_enabledOwner(_CountingRouteSink()));

    final result = await bridge.handleEvent(
      const CallV2ProductionRuntimeUiBridgeEvent.invalid(generation: 1),
    );

    expect(result.status, CallV2ProductionRuntimeUiBridgeResultStatus.rejected);
    expect(result.error, CallV2ProductionRuntimeUiBridgeError.invalidEvent);
  });

  test('stale generation is controlled rejection', () async {
    final bridge = _enabledBridge(_enabledOwner(_CountingRouteSink()));

    await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(2)),
    );
    final stale = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(1)),
    );

    expect(stale.status, CallV2ProductionRuntimeUiBridgeResultStatus.rejected);
    expect(stale.error, CallV2ProductionRuntimeUiBridgeError.staleGeneration);
  });

  test('duplicate generation snapshot preserves lower-level no-op', () async {
    final sink = _CountingRouteSink(
      showResults: <CallV2ProductionRouteSinkResult>[
        const CallV2ProductionRouteSinkResult.pushed(
          destination: CallV2ProductionRouteDestination.connecting,
          generation: 1,
        ),
        const CallV2ProductionRouteSinkResult.noOp(
          destination: CallV2ProductionRouteDestination.connecting,
          generation: 1,
        ),
      ],
    );
    final bridge = _enabledBridge(_enabledOwner(sink));
    final snapshot = _connecting(1);

    final first = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(snapshot),
    );
    final duplicate = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(snapshot),
    );

    expect(first.status, CallV2ProductionRuntimeUiBridgeResultStatus.delegated);
    expect(duplicate.status, CallV2ProductionRuntimeUiBridgeResultStatus.noOp);
    expect(sink.showCount, 2);
  });

  test('owner rejected result maps to controlled bridge rejection', () async {
    final sink = _CountingRouteSink(
      showResult: const CallV2ProductionRouteSinkResult.rejected(
        CallV2ProductionRouteSinkError.routeFactoryRejected,
      ),
    );
    final bridge = _enabledBridge(_enabledOwner(sink));

    final result = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(1)),
    );

    expect(result.status, CallV2ProductionRuntimeUiBridgeResultStatus.rejected);
    expect(result.error, CallV2ProductionRuntimeUiBridgeError.ownerRejected);
  });

  test('owner disabled result maps to bridge disabled', () async {
    final owner = CallV2ProductionUiCompositionOwner(
      routeSink: _CountingRouteSink(),
    );
    final bridge = _enabledBridge(owner);

    final result = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(1)),
    );

    expect(result.status, CallV2ProductionRuntimeUiBridgeResultStatus.disabled);
  });

  test('owner closed and rendered results map to bridge status', () async {
    final closeSink = _CountingRouteSink(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final closeBridge = _enabledBridge(_enabledOwner(closeSink));
    final close = await closeBridge.close(generation: 1);

    final renderSink = _CountingRouteSink();
    final renderBridge = _enabledBridge(_enabledOwner(renderSink));
    final render = await renderBridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(2)),
    );

    expect(close.status, CallV2ProductionRuntimeUiBridgeResultStatus.closed);
    expect(
        render.status, CallV2ProductionRuntimeUiBridgeResultStatus.delegated);
  });

  test('dispose is idempotent and later events do not mutate state', () async {
    final sink = _CountingRouteSink();
    final bridge = _enabledBridge(_enabledOwner(sink));

    final firstDispose = bridge.dispose();
    final disposedStatus = bridge.status;
    final secondDispose = bridge.dispose();
    final afterDispose = await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(1)),
    );
    final closeAfterDispose = await bridge.close(generation: 1);

    expect(firstDispose.status,
        CallV2ProductionRuntimeUiBridgeResultStatus.disposed);
    expect(secondDispose.status,
        CallV2ProductionRuntimeUiBridgeResultStatus.disposed);
    expect(afterDispose.status,
        CallV2ProductionRuntimeUiBridgeResultStatus.disposed);
    expect(closeAfterDispose.status,
        CallV2ProductionRuntimeUiBridgeResultStatus.disposed);
    expect(bridge.status, same(disposedStatus));
    expect(sink.showCount, 0);
  });

  test('status and debug output are safe', () async {
    final bridge = _enabledBridge(_enabledOwner(_CountingRouteSink()));

    await bridge.handleEvent(
      CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(_connecting(7)),
    );
    final statusDebug = bridge.status.toString();
    final resultDebug = const CallV2ProductionRuntimeUiBridgeResult.rejected(
      CallV2ProductionRuntimeUiBridgeError.ownerRejected,
      destination: CallV2ProductionRouteDestination.activeAudio,
      generation: 3,
    ).toString();
    final eventDebug =
        CallV2ProductionRuntimeUiBridgeEvent.presentationSnapshot(
      _connecting(9),
    ).toString();

    expect(bridge.status.currentDestination,
        CallV2ProductionRouteDestination.connecting);
    expect(bridge.status.currentGeneration, 7);
    for (final text in <String>[statusDebug, resultDebug, eventDebug]) {
      for (final forbidden in <String>[
        '/call-v2',
        'uid',
        'callId',
        'participant',
        'token',
        'channel',
        'credential',
        'StackTrace',
        'raw',
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });
}

CallV2ProductionRuntimeUiBridge _enabledBridge(
  CallV2ProductionUiCompositionOwner owner,
) {
  return CallV2ProductionRuntimeUiBridge(
    owner: owner,
    rolloutEnabled: () => true,
  );
}

CallV2ProductionUiCompositionOwner _enabledOwner(_CountingRouteSink sink) {
  return CallV2ProductionUiCompositionOwner(
    routeSink: sink,
    rolloutEnabled: () => true,
  );
}

CallV2ProductionPresentationSnapshot _connecting(int generation) {
  return CallV2ProductionPresentationSnapshot.connecting(
    sessionReference: _session(
      generation,
      mediaMode: CallV2ProductionMediaMode.audio,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.connecting,
      connectionPhase: CallV2ProductionConnectionPhase.connecting,
    ),
    screenState: const CallV2ProductionConnectingScreenState(
      mediaMode: CallV2ProductionMediaMode.audio,
      cancelAvailable: true,
      connectionPhase: CallV2ProductionConnectionPhase.connecting,
    ),
  );
}

CallV2UiSessionReference _session(
  int generation, {
  required CallV2ProductionMediaMode mediaMode,
  required CallV2ProductionLocalLifecycleStatus localLifecycleStatus,
  required CallV2ProductionConnectionPhase connectionPhase,
}) {
  return CallV2UiSessionReference(
    generation: generation,
    mediaMode: mediaMode,
    localLifecycleStatus: localLifecycleStatus,
    connectionPhase: connectionPhase,
  );
}

final class _CountingRouteSink implements CallV2ProductionRouteSink {
  _CountingRouteSink({
    this.showResult = const CallV2ProductionRouteSinkResult.pushed(
      destination: CallV2ProductionRouteDestination.connecting,
      generation: 1,
    ),
    this.closeResult = const CallV2ProductionRouteSinkResult.noOp(),
    List<CallV2ProductionRouteSinkResult>? showResults,
  }) : _showResults = showResults ?? const <CallV2ProductionRouteSinkResult>[];

  final CallV2ProductionRouteSinkResult showResult;
  final CallV2ProductionRouteSinkResult closeResult;
  final List<CallV2ProductionRouteSinkResult> _showResults;
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
    final index = showCount - 1;
    if (index < _showResults.length) return _showResults[index];
    final destination = descriptor.destination;
    final generation = descriptor.generation;
    if (showResult is CallV2ProductionRouteSinkPushed) {
      return CallV2ProductionRouteSinkResult.pushed(
        destination: destination,
        generation: generation,
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
