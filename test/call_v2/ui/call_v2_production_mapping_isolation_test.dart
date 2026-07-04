import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_presentation_mapper.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_factory.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapper and factory sources have no Flutter or external dependencies',
      () {
    final source = _sources();

    for (final forbidden in <String>[
      'package:flutter',
      'Widget',
      'BuildContext',
      'Navigator',
      'Firebase',
      'Firestore',
      'Agora',
      'RtcEngine',
      'CallKit',
      'Permission',
      'connect_functions',
      'http',
      'StreamController',
      'Timer',
      'Future.delayed',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });

  test('mapper and factory perform no external work on construction', () {
    const mapper = CallV2ProductionPresentationMapper();
    const factory = CallV2ProductionRouteFactory();

    expect(mapper, isA<CallV2ProductionPresentationMapper>());
    expect(factory, isA<CallV2ProductionRouteFactory>());
  });

  test('real app remains isolated and rollout remains false', () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(main, isNot(contains('CallV2ProductionPresentationMapper')));
    expect(main, isNot(contains('CallV2ProductionRouteFactory')));
    expect(router, isNot(contains('call_v2')));
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('no production Widget or Navigator sink is added', () {
    final paths = Directory('lib/call_v2')
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.path)
        .where((path) =>
            path.contains('production') && !path.contains('non_production'))
        .toList();

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('extends StatelessWidget')), reason: path);
      expect(source, isNot(contains('NavigatorState')), reason: path);
    }
  });

  test('disabled owner remains inert and composition factory is unused',
      () async {
    final factory = _SpyCompositionFactory();
    final owner = DisabledCallV2ProductionIntegrationOwner(
      rolloutEnabled: () => false,
      compositionFactory: factory,
    );

    await owner.initialize();

    expect(
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(factory.calls, 0);
  });

  test('mapping debug output is safe', () {
    const reference = CallV2UiSessionReference(
      generation: 1,
      mediaMode: CallV2ProductionMediaMode.audio,
      localLifecycleStatus: CallV2ProductionLocalLifecycleStatus.active,
      connectionPhase: CallV2ProductionConnectionPhase.connected,
    );

    final debug = reference.toString();
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
}

String _sources() {
  return <String>[
    'lib/call_v2/ui/call_v2_production_route_descriptor.dart',
    'lib/call_v2/ui/call_v2_production_route_factory.dart',
    'lib/call_v2/ui/call_v2_production_presentation_mapper.dart',
    'lib/call_v2/ui/call_v2_production_mapping_result.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

final class _SpyCompositionFactory
    implements CallV2ProductionIntegrationCompositionFactory {
  var calls = 0;

  @override
  Object createProductionComposition() {
    calls += 1;
    return Object();
  }
}
