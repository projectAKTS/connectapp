import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_shell_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen shell sources do not access services or navigation', () {
    final source = _screenSources();

    for (final forbidden in <String>[
      'Navigator',
      'push(',
      'pop(',
      'removeRoute',
      'Route<',
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
      'static var',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('screens do not store BuildContext or service fields', () {
    final source = _screenSources();

    for (final forbidden in <String>[
      'final BuildContext',
      'BuildContext context;',
      'runtime',
      'composition',
      'backend',
      'transport',
      'engine',
      'token',
      'channel',
      'uid',
      'callId',
      'participantId',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app files remain isolated and rollout remains false', () {
    final main = File('lib/main.dart').readAsStringSync();
    final router = File('lib/navigation/app_router.dart').readAsStringSync();

    expect(main, isNot(contains('CallV2ConnectingScreen')));
    expect(router, isNot(contains('CallV2ConnectingScreen')));
    expect(router, isNot(contains('/call-v2/audio')));
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
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

  test('screen shell result remains typed and inert', () {
    expect(CallV2ScreenShellResult.rendered.name, 'rendered');
    expect(CallV2ScreenShellResult.unavailable.name, 'unavailable');
  });
}

String _screenSources() {
  return Directory('lib/call_v2/ui/shells')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
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
