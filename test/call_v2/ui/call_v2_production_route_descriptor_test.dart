import 'dart:io';

import 'package:connect_app/call_v2/ui/call_v2_production_presentation_snapshot.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_descriptor.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('descriptor is immutable and contains only sanitized fields', () {
    const reference = CallV2UiSessionReference(
      generation: 3,
      mediaMode: CallV2ProductionMediaMode.audio,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
    );
    final descriptor = CallV2ProductionRouteDescriptor.forDestination(
      destination: CallV2ProductionRouteDestination.activeAudio,
      sessionReference: reference,
      generation: 3,
      terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
    );

    expect(
        descriptor.destination, CallV2ProductionRouteDestination.activeAudio);
    expect(descriptor.routeName, '/call-v2/audio');
    expect(descriptor.sessionReference, same(reference));
    expect(descriptor.generation, 3);
    expect(descriptor.toSafeDebugMap()['hasSessionReference'], isTrue);
  });

  test('descriptor debug output contains no identifiers or credentials', () {
    final descriptor = CallV2ProductionRouteDescriptor.forDestination(
      destination: CallV2ProductionRouteDestination.connecting,
      sessionReference: null,
      generation: 1,
      terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
    );
    final debug = descriptor.toString();

    for (final forbidden in <String>[
      'uid',
      'callId',
      'participant',
      'token',
      'channel',
      'credential',
      'Exception',
      'StackTrace',
    ]) {
      expect(debug, isNot(contains(forbidden)));
    }
  });

  test('descriptor derives every route name from fixed destinations', () {
    final cases = <CallV2ProductionRouteDestination, String>{
      CallV2ProductionRouteDestination.connecting: '/call-v2/connecting',
      CallV2ProductionRouteDestination.activeAudio: '/call-v2/audio',
      CallV2ProductionRouteDestination.activeVideo: '/call-v2/video',
      CallV2ProductionRouteDestination.controlledFailure: '/call-v2/failure',
    };

    for (final entry in cases.entries) {
      final descriptor = CallV2ProductionRouteDescriptor.forDestination(
        destination: entry.key,
        sessionReference: null,
        generation: 1,
        terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
      );

      expect(descriptor.routeName, entry.value);
    }
  });

  test('public callers cannot supply arbitrary route names', () {
    final source = File(
      'lib/call_v2/ui/call_v2_production_route_descriptor.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('CallV2ProductionRouteDescriptor({')));
    expect(
      source,
      contains('CallV2ProductionRouteNames.forDestination(destination)'),
    );
  });

  test('reserved destinations and negative generation are rejected', () {
    expect(
      () => CallV2ProductionRouteDescriptor.forDestination(
        destination: CallV2ProductionRouteDestination.incomingReviewReserved,
        sessionReference: null,
        generation: 1,
        terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
      ),
      throwsArgumentError,
    );
    expect(
      () => CallV2ProductionRouteDescriptor.forDestination(
        destination: CallV2ProductionRouteDestination.connecting,
        sessionReference: null,
        generation: -1,
        terminalStatus: CallV2ProductionPresentationTerminalStatus.nonterminal,
      ),
      throwsArgumentError,
    );
  });

  test('descriptor source has no Flutter, route object, or arbitrary map field',
      () {
    final source = File(
      'lib/call_v2/ui/call_v2_production_route_descriptor.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'package:flutter',
      'Widget',
      'Route<',
      'BuildContext',
      'Navigator',
      'NavigatorState',
      'Map<String, Object?> Function',
      'Firebase',
      'RtcEngine',
      'token',
      'channel',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });
}
