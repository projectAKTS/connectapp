import 'dart:io';

import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_route_destination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route object factory source uses canonical route names only', () {
    final source = _factorySources();

    expect(source, contains('CallV2ProductionRouteNames.forDestination'));
    expect(source, isNot(contains("'/call-v2/ready'")));
    expect(source, isNot(contains('CallV2RouteNames.ready')));
    expect(CallV2ProductionRouteNames.connecting, '/call-v2/connecting');
    expect(CallV2ProductionRouteNames.activeAudio, '/call-v2/audio');
    expect(CallV2ProductionRouteNames.activeVideo, '/call-v2/video');
    expect(CallV2ProductionRouteNames.controlledFailure, '/call-v2/failure');
  });

  test('route object factory has no registration or external work', () {
    final source = _factorySources();

    for (final forbidden in <String>[
      'Navigator.',
      'push(',
      'pop(',
      'replace',
      'removeRoute',
      'onGenerateRoute',
      'routes:',
      'Firebase',
      'Firestore',
      'Agora',
      'RtcEngine',
      'CallKit',
      'permission_handler',
      'Permission.',
      'connect_functions',
      'Timer',
      'Stream',
      'StreamController',
      'postFrameCallback',
      'addPostFrameCallback',
      'initState',
      'dispose()',
      'GlobalKey',
      'runtime.start',
      'compositionFactory',
      'routeSink',
      'backend',
      'transport',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app files remain isolated and rollout remains false', () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(main, isNot(contains('CallV2ProductionRouteObjectFactory')));
    expect(router, isNot(contains('CallV2ProductionRouteObjectFactory')));
    expect(router, isNot(contains('/call-v2/audio')));
    expect(router, isNot(contains('/call-v2/ready')));
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
  });

  test('disabled owner remains inert and composition remains unconstructed',
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
}

String _factorySources() {
  return <String>[
    'lib/call_v2/integration/call_v2_production_route_object_factory.dart',
    'lib/call_v2/integration/call_v2_production_route_object_factory_result.dart',
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
