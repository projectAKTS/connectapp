import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_model_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('view model sources have no Flutter runtime or service dependencies',
      () {
    final source = _sources();

    for (final forbidden in <String>[
      'package:flutter',
      'Widget',
      'BuildContext',
      'Navigator',
      'Route<',
      'Firebase',
      'Firestore',
      'Agora',
      'RtcEngine',
      'CallKit',
      'Permission',
      'connect_functions',
      'http',
      'Future<',
      'async',
      'StreamController',
      'Timer',
      'VoidCallback',
      'Function ',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });

  test('real app and router remain isolated and rollout remains false', () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(main, isNot(contains('CallV2ProductionViewModelMapper')));
    expect(router, isNot(contains('CallV2ProductionViewModelMapper')));
    expect(router, isNot(contains('/call-v2/audio')));
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
      owner.status.lifecycle,
      CallV2ProductionIntegrationLifecycle.disabled,
    );
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(factory.calls, 0);
  });

  test('mapper construction is side effect free', () {
    const mapper = CallV2ProductionViewModelMapper();

    expect(mapper, isA<CallV2ProductionViewModelMapper>());
  });
}

String _sources() {
  return <String>[
    'lib/call_v2/ui/call_v2_connecting_view_model.dart',
    'lib/call_v2/ui/call_v2_active_audio_view_model.dart',
    'lib/call_v2/ui/call_v2_active_video_view_model.dart',
    'lib/call_v2/ui/call_v2_controlled_failure_view_model.dart',
    'lib/call_v2/ui/call_v2_production_view_model_result.dart',
    'lib/call_v2/ui/call_v2_production_view_model_mapper.dart',
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
