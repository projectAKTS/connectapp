import 'dart:async';

import 'package:connect_app/call_v2/integration/call_v2_production_route_sink.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_adapter.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_sink_result.dart';
import 'package:connect_app/call_v2/ui/call_v2_active_audio_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navigation in progress rejects concurrent navigation', () async {
    final adapter = _DelayedRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);

    final first = sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );
    await Future<void>.delayed(Duration.zero);

    final second = await sink.show(
      descriptor: _descriptor(
        CallV2ProductionRouteDestination.activeAudio,
        generation: 5,
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );
    adapter.complete();

    expect(
      (second as CallV2ProductionRouteSinkRejected).error,
      CallV2ProductionRouteSinkError.navigationInProgress,
    );
    expect(await first, isA<CallV2ProductionRouteSinkPushed>());
    expect(sink.state.currentGeneration, 4);
  });

  test('dispose during async navigation prevents stale state mutation',
      () async {
    final adapter = _DelayedRouteSinkAdapter();
    final sink = CallV2ProductionRouteSink(adapter: adapter);

    final pending = sink.show(
      descriptor: _descriptor(CallV2ProductionRouteDestination.activeAudio),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );
    await Future<void>.delayed(Duration.zero);
    final disposeResult = sink.dispose();
    adapter.complete();

    expect(disposeResult, isA<CallV2ProductionRouteSinkNoOp>());
    expect(
      (await pending as CallV2ProductionRouteSinkRejected).error,
      CallV2ProductionRouteSinkError.disposed,
    );
    expect(sink.state.disposed, isTrue);
    expect(sink.state.currentDestination, isNull);
    expect(sink.state.currentGeneration, isNull);
  });
}

final class _DelayedRouteSinkAdapter
    implements CallV2ProductionRouteSinkAdapter {
  final List<String> operations = <String>[];
  Completer<void>? _pending;

  @override
  bool get isDisposed => false;

  @override
  Future<void> push(Route<dynamic> route) {
    operations.add('push');
    _pending = Completer<void>();
    return _pending!.future;
  }

  @override
  Future<void> replace(Route<dynamic> route) {
    operations.add('replace');
    _pending = Completer<void>();
    return _pending!.future;
  }

  @override
  Future<void> popCallV2Route() {
    operations.add('popCallV2Route');
    _pending = Completer<void>();
    return _pending!.future;
  }

  void complete() {
    _pending?.complete();
  }
}

CallV2ProductionRouteDescriptor _descriptor(
  CallV2ProductionRouteDestination destination, {
  int generation = 4,
}) {
  return CallV2ProductionRouteDescriptor.forDestination(
    destination: destination,
    sessionReference: CallV2UiSessionReference(
      generation: generation,
      mediaMode: CallV2ProductionMediaMode.audio,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
    ),
    generation: generation,
    terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
  );
}

CallV2ActiveAudioViewModel _audioModel() {
  return CallV2ActiveAudioViewModel(
    muted: false,
    speakerEnabled: true,
    leaveEnabled: true,
    connectionPhase: CallV2ProductionConnectionPhase.connected,
    elapsedSeconds: 12,
    reconnecting: false,
    allowedActions: const <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleSpeaker,
      CallV2ProductionUserAction.leave,
    },
  );
}
