import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production UI contracts are pure Dart and do not perform work', () {
    final sources = _contractSources();
    for (final forbidden in <String>[
      'package:flutter',
      'Widget',
      'Route<',
      'BuildContext',
      'Navigator',
      'Firebase',
      'Firestore',
      'Agora',
      'RtcEngine',
      'CallKit',
      'Permission',
      'StreamController',
      'Timer',
      'Future.delayed',
      'http',
      'Function ',
      'VoidCallback',
    ]) {
      expect(sources, isNot(contains(forbidden)));
    }
  });

  test('real app files remain without production Call V2 route registration',
      () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    for (final source in <String>[main, router]) {
      expect(source, isNot(contains('call_v2_production_route_destination')));
      expect(source, isNot(contains('CallV2ProductionRouteDestination')));
      expect(source, isNot(contains('/call-v2/audio')));
      expect(source, isNot(contains('/call-v2/video')));
      expect(source, isNot(contains('/call-v2/failure')));
    }
  });

  test('production widgets and Navigator sink are not added', () {
    final files = Directory('lib/call_v2').listSync(recursive: true);
    final productionWidgetFiles = files.where((entry) {
      final path = entry.path;
      return path.contains('production') &&
          !path.contains('non_production') &&
          path.endsWith('.dart') &&
          File(path).readAsStringSync().contains('extends StatelessWidget');
    }).toList();

    expect(productionWidgetFiles, isEmpty);
    final routeSink = File(
      'lib/call_v2/integration/call_v2_route_sink.dart',
    ).readAsStringSync();
    expect(routeSink, isNot(contains('ProductionCallV2')));
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

  test('rollout flag remains false and route registry remains closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      resolveCallV2Route(const RouteSettings(name: '/call-v2/audio')),
      isNull,
    );
  });

  test('runtime, V1, and backend surfaces remain untouched by contract files',
      () {
    final sources = _contractSources();

    expect(sources, isNot(contains('CallV2Runtime(')));
    expect(sources, isNot(contains('connect_functions')));
    expect(sources, isNot(contains('legacy')));
    expect(sources, isNot(contains('VideoCallScreen')));
  });
}

String _contractSources() {
  return <String>[
    'lib/call_v2/ui/call_v2_production_route_destination.dart',
    'lib/call_v2/ui/call_v2_ui_session_reference.dart',
    'lib/call_v2/ui/call_v2_production_view_state.dart',
    'lib/call_v2/ui/call_v2_production_user_action.dart',
    'lib/call_v2/ui/call_v2_production_presentation_snapshot.dart',
    'lib/call_v2/ui/call_v2_production_transition_policy.dart',
    'lib/call_v2/ui/call_v2_production_route_contract.dart',
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
