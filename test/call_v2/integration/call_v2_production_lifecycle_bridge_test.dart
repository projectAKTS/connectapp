import 'package:connect_app/call_v2/integration/call_v2_production_lifecycle_bridge.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_lifecycle_bridge_event.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_lifecycle_bridge_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_state.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_runtime_ui_bridge_event.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default rollout false initialize returns disabled without runtime call',
      () {
    final fixture = _Fixture(lifecycleRollout: false);

    final result = fixture.lifecycle.initialize();

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.disabled);
    expect(fixture.runtime.status.lifecycle.name, 'uninitialized');
    expect(fixture.sink.closeCount, 0);
  });

  test('default rollout false handleEvent does not call runtime UI bridge',
      () async {
    final fixture = _Fixture(lifecycleRollout: false);

    final result = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 1),
    );

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.disabled);
    expect(fixture.sink.closeCount, 0);
  });

  test('global rollout remains false', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('rollout true isolated initialize delegates to runtime UI bridge', () {
    final fixture = _Fixture();

    final result = fixture.lifecycle.initialize();

    expect(
      result.status,
      CallV2ProductionLifecycleBridgeResultStatus.initialized,
    );
    expect(fixture.runtime.status.rolloutEnabled, isTrue);
  });

  test('closeRequested delegates to runtime UI bridge close', () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final result = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 2),
    );

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.closed);
    expect(fixture.sink.closeCount, 1);
  });

  test('dispose event delegates dispose safely', () async {
    final fixture = _Fixture();

    final result = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.dispose(),
    );
    final duplicate = fixture.lifecycle.dispose();

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.disposed);
    expect(
        duplicate.status, CallV2ProductionLifecycleBridgeResultStatus.disposed);
    expect(fixture.sink.disposeCount, 1);
  });

  test('appResumed no-ops', () async {
    final fixture = _Fixture();

    final result = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appResumed(generation: 1),
    );

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.noOp);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.sink.disposeCount, 0);
  });

  test('pause inactive and hidden are non-destructive by default', () async {
    final fixture = _Fixture();

    final paused = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appPaused(generation: 1),
    );
    final inactive = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appInactive(generation: 2),
    );
    final hidden = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appHidden(generation: 3),
    );

    expect(paused.status, CallV2ProductionLifecycleBridgeResultStatus.noOp);
    expect(inactive.status, CallV2ProductionLifecycleBridgeResultStatus.noOp);
    expect(hidden.status, CallV2ProductionLifecycleBridgeResultStatus.noOp);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.sink.disposeCount, 0);
  });

  test('pause inactive and hidden close only with explicit policy', () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final paused = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appPaused(
        generation: 1,
        cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeOnly,
      ),
    );
    final inactive = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appInactive(
        generation: 2,
        cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeOnly,
      ),
    );
    final hidden = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appHidden(
        generation: 3,
        cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeOnly,
      ),
    );

    expect(paused.status, CallV2ProductionLifecycleBridgeResultStatus.closed);
    expect(inactive.status, CallV2ProductionLifecycleBridgeResultStatus.closed);
    expect(hidden.status, CallV2ProductionLifecycleBridgeResultStatus.closed);
    expect(fixture.sink.closeCount, 3);
    expect(fixture.sink.disposeCount, 0);
  });

  test('appDetached closes and terminal-disposes safely', () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final result = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appDetached(generation: 4),
    );

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.terminal);
    expect(fixture.lifecycle.status.terminal, isTrue);
    expect(fixture.lifecycle.status.disposed, isTrue);
    expect(fixture.sink.closeCount, 1);
    expect(fixture.sink.disposeCount, 1);
  });

  test('signOutStarted closes and terminal-disposes safely', () async {
    final fixture = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final result = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.signOutStarted(generation: 5),
    );

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.terminal);
    expect(fixture.sink.closeCount, 1);
    expect(fixture.sink.disposeCount, 1);
  });

  test('authChanged signedOut and authInvalid terminal-dispose safely',
      () async {
    final signedOut = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final invalid = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final signedOutResult = await signedOut.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.authChanged(
        reason: CallV2ProductionLifecycleAuthChangeReason.signedOut,
        generation: 6,
      ),
    );
    final invalidResult = await invalid.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.authChanged(
        reason: CallV2ProductionLifecycleAuthChangeReason.authInvalid,
        generation: 7,
      ),
    );

    expect(signedOutResult.status,
        CallV2ProductionLifecycleBridgeResultStatus.terminal);
    expect(invalidResult.status,
        CallV2ProductionLifecycleBridgeResultStatus.terminal);
    expect(signedOut.sink.disposeCount, 1);
    expect(invalid.sink.disposeCount, 1);
  });

  test('authChanged stillSignedIn and noChange no-op', () async {
    final fixture = _Fixture();

    final stillSignedIn = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.authChanged(
        reason: CallV2ProductionLifecycleAuthChangeReason.stillSignedIn,
        generation: 1,
      ),
    );
    final noChange = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.authChanged(
        reason: CallV2ProductionLifecycleAuthChangeReason.noChange,
        generation: 2,
      ),
    );

    expect(
        stillSignedIn.status, CallV2ProductionLifecycleBridgeResultStatus.noOp);
    expect(noChange.status, CallV2ProductionLifecycleBridgeResultStatus.noOp);
    expect(fixture.sink.closeCount, 0);
    expect(fixture.sink.disposeCount, 0);
  });

  test('cleanupRequested applies explicit cleanup policy', () async {
    final closeOnly = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final destructive = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );

    final closed = await closeOnly.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.cleanupRequested(
        reason: CallV2ProductionLifecycleCleanupReason.explicitUserRequest,
        cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeOnly,
        generation: 1,
      ),
    );
    final cleaned = await destructive.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.cleanupRequested(
        reason: CallV2ProductionLifecycleCleanupReason.explicitUserRequest,
        cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeAndDispose,
        generation: 2,
      ),
    );

    expect(closed.status, CallV2ProductionLifecycleBridgeResultStatus.closed);
    expect(closeOnly.sink.disposeCount, 0);
    expect(
        cleaned.status, CallV2ProductionLifecycleBridgeResultStatus.cleanedUp);
    expect(destructive.sink.disposeCount, 1);
  });

  test('duplicate cleanup and events after terminal or dispose are idempotent',
      () async {
    final terminal = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final disposed = _Fixture();

    final firstTerminal = await terminal.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appDetached(generation: 1),
    );
    final duplicateTerminal = await terminal.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appDetached(generation: 1),
    );
    disposed.lifecycle.dispose();
    final afterDispose = await disposed.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 1),
    );

    expect(firstTerminal.status,
        CallV2ProductionLifecycleBridgeResultStatus.terminal);
    expect(duplicateTerminal.status,
        CallV2ProductionLifecycleBridgeResultStatus.disposed);
    expect(terminal.sink.closeCount, 1);
    expect(terminal.sink.disposeCount, 1);
    expect(afterDispose.status,
        CallV2ProductionLifecycleBridgeResultStatus.disposed);
    expect(disposed.sink.closeCount, 0);
  });

  test('negative generation and invalid event are controlled rejections',
      () async {
    final fixture = _Fixture();

    final negative = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: -1),
    );
    final invalid = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.invalid(generation: 1),
    );

    expect(
        negative.status, CallV2ProductionLifecycleBridgeResultStatus.rejected);
    expect(
        negative.error, CallV2ProductionLifecycleBridgeError.invalidGeneration);
    expect(
        invalid.status, CallV2ProductionLifecycleBridgeResultStatus.rejected);
    expect(invalid.error, CallV2ProductionLifecycleBridgeError.invalidEvent);
  });

  test('lower-level runtime rejection maps to lifecycle rejection', () async {
    final fixture = _Fixture.withOwner(
      CallV2ProductionUiCompositionOwner(rolloutEnabled: () => true),
      lifecycleRollout: true,
      runtimeRollout: true,
    );

    final result = await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 1),
    );

    expect(result.status, CallV2ProductionLifecycleBridgeResultStatus.rejected);
    expect(result.error,
        CallV2ProductionLifecycleBridgeError.runtimeBridgeRejected);
  });

  test('runtime disabled closed terminal and disposed results map safely',
      () async {
    final runtimeDisabled = _Fixture(runtimeRollout: false);
    final closed = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final terminal = _Fixture(
      closeResult: const CallV2ProductionRouteSinkResult.popped(),
    );
    final disposed = _Fixture();

    final disabled = await runtimeDisabled.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 1),
    );
    final closedResult = await closed.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 2),
    );
    await terminal.runtime.handleEvent(
      const CallV2ProductionRuntimeUiBridgeEvent.runtimeTerminated(
        generation: 3,
      ),
    );
    final terminalResult = await terminal.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 3),
    );
    disposed.runtime.dispose();
    final disposedResult = await disposed.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.closeRequested(generation: 4),
    );

    expect(
        disabled.status, CallV2ProductionLifecycleBridgeResultStatus.disabled);
    expect(closedResult.status,
        CallV2ProductionLifecycleBridgeResultStatus.closed);
    expect(terminalResult.status,
        CallV2ProductionLifecycleBridgeResultStatus.terminal);
    expect(disposedResult.status,
        CallV2ProductionLifecycleBridgeResultStatus.disposed);
  });

  test('status and debug output are safe', () async {
    final fixture = _Fixture();

    await fixture.lifecycle.handleEvent(
      const CallV2ProductionLifecycleBridgeEvent.appResumed(generation: 8),
    );
    final statusDebug = fixture.lifecycle.status.toString();
    final resultDebug = const CallV2ProductionLifecycleBridgeResult.rejected(
      CallV2ProductionLifecycleBridgeError.cleanupFailed,
      generation: 9,
    ).toString();
    final eventDebug =
        const CallV2ProductionLifecycleBridgeEvent.cleanupRequested(
      reason: CallV2ProductionLifecycleCleanupReason.explicitUserRequest,
      cleanupPolicy: CallV2ProductionLifecycleCleanupPolicy.closeOnly,
      generation: 10,
    ).toString();

    expect(fixture.lifecycle.status.currentGeneration, 8);
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
      ]) {
        expect(text, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });
}

final class _Fixture {
  _Fixture({
    bool lifecycleRollout = true,
    bool runtimeRollout = true,
    CallV2ProductionRouteSinkResult closeResult =
        const CallV2ProductionRouteSinkResult.noOp(),
  }) : sink = _CountingRouteSink(closeResult: closeResult) {
    final runtimeSink = sink;
    runtime = CallV2ProductionRuntimeUiBridge(
      owner: CallV2ProductionUiCompositionOwner(
        routeSink: runtimeSink,
        rolloutEnabled: () => true,
      ),
      rolloutEnabled: () => runtimeRollout,
    );
    lifecycle = CallV2ProductionLifecycleBridge(
      runtimeUiBridge: runtime,
      rolloutEnabled: () => lifecycleRollout,
    );
  }

  _Fixture.withOwner(
    CallV2ProductionUiCompositionOwner owner, {
    required bool lifecycleRollout,
    required bool runtimeRollout,
  })  : sink = _CountingRouteSink(),
        runtime = CallV2ProductionRuntimeUiBridge(
          owner: owner,
          rolloutEnabled: () => runtimeRollout,
        ) {
    lifecycle = CallV2ProductionLifecycleBridge(
      runtimeUiBridge: runtime,
      rolloutEnabled: () => lifecycleRollout,
    );
  }

  final _CountingRouteSink sink;
  late CallV2ProductionRuntimeUiBridge runtime;
  late CallV2ProductionLifecycleBridge lifecycle;
}

final class _CountingRouteSink implements CallV2ProductionRouteSink {
  _CountingRouteSink({
    this.closeResult = const CallV2ProductionRouteSinkResult.noOp(),
  });

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
    return CallV2ProductionRouteSinkResult.pushed(
      destination: descriptor.destination,
      generation: descriptor.generation,
    );
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
