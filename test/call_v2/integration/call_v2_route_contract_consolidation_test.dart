import 'package:connect_app/call_v2/ui/call_v2_active_audio_view_model.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_object_factory.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_route_object_factory_result.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('integration route names match canonical production route names', () {
    expect(CallV2RouteNames.connecting, CallV2ProductionRouteNames.connecting);
    expect(
        CallV2RouteNames.activeAudio, CallV2ProductionRouteNames.activeAudio);
    expect(
        CallV2RouteNames.activeVideo, CallV2ProductionRouteNames.activeVideo);
    expect(
      CallV2RouteNames.controlledFailure,
      CallV2ProductionRouteNames.controlledFailure,
    );
    expect(CallV2RouteNames.production, <String>{
      CallV2ProductionRouteNames.connecting,
      CallV2ProductionRouteNames.activeAudio,
      CallV2ProductionRouteNames.activeVideo,
      CallV2ProductionRouteNames.controlledFailure,
    });
  });

  test('/call-v2/ready is not an accepted production route', () {
    expect(CallV2RouteNames.ready, '/call-v2/ready');
    expect(CallV2RouteNames.production, isNot(contains('/call-v2/ready')));

    const factory = CallV2ProductionRouteObjectFactory();
    final result = factory.createRoute(
      descriptor: _FakeDescriptor(
        destination: CallV2ProductionRouteDestination.activeAudio,
        routeName: '/call-v2/ready',
      ),
      viewModel: CallV2ActiveAudioProductionViewModel(_audioModel()),
    );

    expect(result, isA<CallV2ProductionRouteObjectFactoryRejected>());
    expect(
      (result as CallV2ProductionRouteObjectFactoryRejected).error,
      CallV2ProductionRouteObjectFactoryError.routeNameMismatch,
    );
  });

  test('rollout false keeps resolveCallV2Route returning null', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    for (final name in <String>{
      ...CallV2RouteNames.production,
      '/call-v2/ready',
      '/call-v2/audio?uid=abc',
    }) {
      expect(resolveCallV2Route(RouteSettings(name: name)), isNull);
    }
  });

  test('disabled registry still returns null', () {
    const registry = DisabledCallV2RouteRegistry();

    for (final name in <String>{
      ...CallV2RouteNames.production,
      '/call-v2/ready',
    }) {
      expect(registry.resolve(RouteSettings(name: name)), isNull);
    }
  });
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

final class _FakeDescriptor implements CallV2ProductionRouteDescriptor {
  const _FakeDescriptor({
    required this.destination,
    required this.routeName,
  });

  @override
  final CallV2ProductionRouteDestination destination;

  @override
  final String routeName;

  @override
  int get generation => 1;

  @override
  CallV2ProductionPresentationTerminalStatus get terminalStatus =>
      CallV2ProductionPresentationTerminalStatus.nonterminal;

  @override
  CallV2UiSessionReference? get sessionReference => null;

  @override
  Map<String, Object?> toSafeDebugMap() => <String, Object?>{};
}
