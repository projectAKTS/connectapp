import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_adapter.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_state.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_result.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_ui_composition_status.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_mapping_result.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_factory.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_result.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'default rollout false initializes disabled and render does not navigate',
      () async {
    final adapter = _RecordingRouteSinkAdapter();
    final owner = CallV2ProductionUiCompositionOwner(
      routeSinkAdapter: adapter,
    );

    final initialized = owner.initialize();
    final rendered = await owner.renderSnapshot(_connecting(1));

    expect(
        initialized.status, CallV2ProductionUiCompositionResultStatus.disabled);
    expect(rendered.status, CallV2ProductionUiCompositionResultStatus.disabled);
    expect(adapter.pushed, isEmpty);
    expect(owner.status.lifecycle,
        CallV2ProductionUiCompositionLifecycle.disabled);
    expect(owner.status.rolloutEnabled, isFalse);
  });

  test('global rollout remains false', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('rollout true isolated owner renders every available destination',
      () async {
    final adapter = _RecordingRouteSinkAdapter();
    final owner = _enabledOwner(adapter: adapter);

    final connecting = await owner.renderSnapshot(_connecting(1));
    final audio = await owner.renderSnapshot(_audio(2));
    final failure = await owner.renderSnapshot(_failure(3));

    expect(
        connecting.status, CallV2ProductionUiCompositionResultStatus.rendered);
    expect(connecting.destination, CallV2ProductionRouteDestination.connecting);
    expect(audio.status, CallV2ProductionUiCompositionResultStatus.rendered);
    expect(audio.destination, CallV2ProductionRouteDestination.activeAudio);
    expect(failure.status, CallV2ProductionUiCompositionResultStatus.rendered);
    expect(failure.destination,
        CallV2ProductionRouteDestination.controlledFailure);
    expect(adapter.pushed, <String>[CallV2ProductionRouteNames.connecting]);
    expect(adapter.replaced, <String>[
      CallV2ProductionRouteNames.activeAudio,
      CallV2ProductionRouteNames.controlledFailure,
    ]);
  });

  test('rollout true isolated owner renders video destination', () async {
    final adapter = _RecordingRouteSinkAdapter();
    final owner = _enabledOwner(adapter: adapter);

    final connecting = await owner.renderSnapshot(_connecting(1));
    final video = await owner.renderSnapshot(_video(2));

    expect(
        connecting.status, CallV2ProductionUiCompositionResultStatus.rendered);
    expect(video.status, CallV2ProductionUiCompositionResultStatus.rendered);
    expect(video.destination, CallV2ProductionRouteDestination.activeVideo);
    expect(adapter.replaced, <String>[CallV2ProductionRouteNames.activeVideo]);
  });

  test('terminal snapshot closes through route sink', () async {
    final sink = _ScriptedRouteSink(
        closeResult: const CallV2ProductionRouteSinkResult.popped());
    final owner = CallV2ProductionUiCompositionOwner(
      routeSink: sink,
      rolloutEnabled: () => true,
    );

    final result = await owner.renderSnapshot(
      CallV2ProductionPresentationSnapshot.none(
        generation: 4,
        terminalStatus:
            CallV2ProductionPresentationTerminalStatus.terminalDisposed,
      ),
    );

    expect(result.status, CallV2ProductionUiCompositionResultStatus.closed);
    expect(sink.closeCount, 1);
  });

  test('duplicate same destination generation is no-op', () async {
    final adapter = _RecordingRouteSinkAdapter();
    final owner = _enabledOwner(adapter: adapter);
    final snapshot = _connecting(1);

    final first = await owner.renderSnapshot(snapshot);
    final duplicate = await owner.renderSnapshot(snapshot);

    expect(first.status, CallV2ProductionUiCompositionResultStatus.rendered);
    expect(duplicate.status, CallV2ProductionUiCompositionResultStatus.noOp);
    expect(duplicate.destination, CallV2ProductionRouteDestination.connecting);
    expect(adapter.pushed.length, 1);
  });

  test('stale generation and invalid transitions are controlled rejections',
      () async {
    final adapter = _RecordingRouteSinkAdapter();
    final owner = _enabledOwner(adapter: adapter);

    await owner.renderSnapshot(_audio(2));
    final stale = await owner.renderSnapshot(_connecting(1));
    final invalidTransition = await owner.renderSnapshot(_video(3));

    expect(stale.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(stale.error, CallV2ProductionUiCompositionError.staleGeneration);
    expect(invalidTransition.status,
        CallV2ProductionUiCompositionResultStatus.rejected);
    expect(invalidTransition.error,
        CallV2ProductionUiCompositionError.invalidTransition);
  });

  test('lower-level route mapping rejection maps to controlled owner rejection',
      () async {
    final owner = CallV2ProductionUiCompositionOwner(
      routeSinkAdapter: _RecordingRouteSinkAdapter(),
      routeFactory: _RejectingRouteFactory(
        CallV2ProductionMappingError.invalidRouteName,
      ),
      rolloutEnabled: () => true,
    );

    final result = await owner.renderSnapshot(_connecting(1));

    expect(result.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(
        result.error, CallV2ProductionUiCompositionError.routeMappingRejected);
  });

  test('reserved destination maps to controlled owner rejection', () async {
    final owner = CallV2ProductionUiCompositionOwner(
      routeSinkAdapter: _RecordingRouteSinkAdapter(),
      routeFactory: _RejectingRouteFactory(
        CallV2ProductionMappingError.reservedDestination,
      ),
      rolloutEnabled: () => true,
    );

    final result = await owner.renderSnapshot(_connecting(1));

    expect(result.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(
        result.error, CallV2ProductionUiCompositionError.reservedDestination);
  });

  test('lower-level view model rejection maps to controlled owner rejection',
      () async {
    final owner = CallV2ProductionUiCompositionOwner(
      routeSinkAdapter: _RecordingRouteSinkAdapter(),
      viewModelMapper: _RejectingViewModelMapper(
        CallV2ProductionViewModelError.incompatibleState,
      ),
      rolloutEnabled: () => true,
    );

    final result = await owner.renderSnapshot(_connecting(1));

    expect(result.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(result.error,
        CallV2ProductionUiCompositionError.viewModelMappingRejected);
  });

  test('lower-level route sink rejection maps to controlled owner rejection',
      () async {
    final owner = CallV2ProductionUiCompositionOwner(
      routeSink: _ScriptedRouteSink(
        showResult: const CallV2ProductionRouteSinkResult.rejected(
          CallV2ProductionRouteSinkError.routeFactoryRejected,
        ),
      ),
      rolloutEnabled: () => true,
    );

    final result = await owner.renderSnapshot(_connecting(1));

    expect(result.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(result.error, CallV2ProductionUiCompositionError.routeSinkRejected);
  });

  test('missing route sink in enabled owner is a controlled rejection',
      () async {
    final owner = CallV2ProductionUiCompositionOwner(
      rolloutEnabled: () => true,
    );

    final result = await owner.renderSnapshot(_connecting(1));

    expect(result.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(result.error, CallV2ProductionUiCompositionError.routeSinkRejected);
  });

  test('action callback is not called during construction initialize or render',
      () async {
    final calls = <CallV2ProductionUserAction>[];
    final owner = _enabledOwner(
      adapter: _RecordingRouteSinkAdapter(),
      onAction: calls.add,
    );

    final initialized = owner.initialize();
    final rendered = await owner.renderSnapshot(_connecting(1));

    expect(initialized.status,
        CallV2ProductionUiCompositionResultStatus.initialized);
    expect(rendered.status, CallV2ProductionUiCompositionResultStatus.rendered);
    expect(calls, isEmpty);
  });

  test('dispose is idempotent and render or close after dispose reject',
      () async {
    final owner = _enabledOwner(adapter: _RecordingRouteSinkAdapter());

    final firstDispose = owner.dispose();
    final secondDispose = owner.dispose();
    final render = await owner.renderSnapshot(_connecting(1));
    final close = await owner.close();

    expect(firstDispose.status,
        CallV2ProductionUiCompositionResultStatus.disposed);
    expect(secondDispose.status,
        CallV2ProductionUiCompositionResultStatus.disposed);
    expect(render.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(render.error, CallV2ProductionUiCompositionError.disposed);
    expect(close.status, CallV2ProductionUiCompositionResultStatus.rejected);
    expect(close.error, CallV2ProductionUiCompositionError.disposed);
  });

  test('status and debug output are safe', () async {
    final owner = _enabledOwner(adapter: _RecordingRouteSinkAdapter());

    await owner.renderSnapshot(_connecting(7));
    final statusDebug = owner.status.toString();
    final resultDebug = const CallV2ProductionUiCompositionResult.rejected(
      CallV2ProductionUiCompositionError.routeSinkRejected,
      destination: CallV2ProductionRouteDestination.activeAudio,
      generation: 3,
    ).toString();

    expect(owner.status.currentDestination,
        CallV2ProductionRouteDestination.connecting);
    expect(owner.status.currentGeneration, 7);
    for (final text in <String>[statusDebug, resultDebug]) {
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

CallV2ProductionUiCompositionOwner _enabledOwner({
  required CallV2ProductionRouteSinkAdapter adapter,
  ValueChanged<CallV2ProductionUserAction>? onAction,
}) {
  return CallV2ProductionUiCompositionOwner(
    routeSinkAdapter: adapter,
    rolloutEnabled: () => true,
    onAction: onAction,
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

CallV2ProductionPresentationSnapshot _audio(int generation) {
  return CallV2ProductionPresentationSnapshot.activeAudio(
    sessionReference: _session(
      generation,
      mediaMode: CallV2ProductionMediaMode.audio,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
    ),
    screenState: const CallV2ProductionActiveAudioScreenState(
      muted: false,
      speakerEnabled: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      elapsedSeconds: 12,
      reconnecting: false,
    ),
  );
}

CallV2ProductionPresentationSnapshot _video(int generation) {
  return CallV2ProductionPresentationSnapshot.activeVideo(
    sessionReference: _session(
      generation,
      mediaMode: CallV2ProductionMediaMode.video,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
    ),
    screenState: const CallV2ProductionActiveVideoScreenState(
      microphoneMuted: false,
      localCameraEnabled: true,
      remoteVideoAvailable: true,
      cameraSwitchAvailable: true,
      leaveEnabled: true,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
      renderingState: CallV2ProductionVideoRenderingState.rendering,
      reconnecting: false,
    ),
  );
}

CallV2ProductionPresentationSnapshot _failure(int generation) {
  return CallV2ProductionPresentationSnapshot.controlledFailure(
    sessionReference: _session(
      generation,
      mediaMode: CallV2ProductionMediaMode.audio,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.failed,
      connectionPhase: CallV2ProductionConnectionPhase.failed,
    ),
    screenState: const CallV2ProductionControlledFailureScreenState(
      errorCode: CallV2ClientErrorCode.unavailable,
      retryPolicy: CallV2ProductionFailureRetryPolicy.retryAllowed,
      dismissPolicy: CallV2ProductionFailureDismissPolicy.dismissAllowed,
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

final class _RecordingRouteSinkAdapter
    implements CallV2ProductionRouteSinkAdapter {
  final List<String> pushed = <String>[];
  final List<String> replaced = <String>[];
  var popCount = 0;

  @override
  bool get isDisposed => false;

  @override
  Future<void> push(Route<dynamic> route) async {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
  }

  @override
  Future<void> replace(Route<dynamic> route) async {
    final name = route.settings.name;
    if (name != null) replaced.add(name);
  }

  @override
  Future<void> popCallV2Route() async {
    popCount += 1;
  }
}

final class _ScriptedRouteSink implements CallV2ProductionRouteSink {
  _ScriptedRouteSink({
    this.showResult = const CallV2ProductionRouteSinkResult.noOp(),
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

final class _RejectingRouteFactory implements CallV2ProductionRouteFactory {
  const _RejectingRouteFactory(this.error);

  final CallV2ProductionMappingError error;

  @override
  CallV2ProductionMappingResult<CallV2ProductionRouteDescriptor>
      createDescriptor(
    CallV2ProductionPresentationSnapshot snapshot, {
    int minimumGeneration = 0,
  }) {
    return CallV2ProductionMappingResult<
        CallV2ProductionRouteDescriptor>.rejected(error);
  }
}

final class _RejectingViewModelMapper
    implements CallV2ProductionViewModelMapper {
  const _RejectingViewModelMapper(this.error);

  final CallV2ProductionViewModelError error;

  @override
  CallV2ProductionViewModelResult<CallV2ProductionViewModel> map(
    CallV2ProductionPresentationSnapshot snapshot, {
    int minimumGeneration = 0,
  }) {
    return CallV2ProductionViewModelResult<CallV2ProductionViewModel>.rejected(
      error,
    );
  }
}
