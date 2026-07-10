import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navigator adapter is the only production source with Navigator APIs',
      () {
    final adapter = File(
      'lib/call_v2/integration/call_v2_production_navigator_adapter.dart',
    ).readAsStringSync();

    expect(adapter, contains('CallV2NavigatorProvider'));
    expect(adapter, contains('push'));
    expect(adapter, contains('pushReplacement'));
    expect(adapter, contains('popCallV2Route'));

    for (final forbidden in <String>[
      'GlobalKey',
      'BuildContext',
      'navigatorKey',
      'MaterialApp',
      'Firebase',
      'Firestore',
      'Agora',
      'Rtc',
      'Permission',
      'backend',
      'Timer',
      'Stream',
      'Subscription',
      'register',
      'startsWith',
    ]) {
      expect(adapter, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app and existing integration files remain disconnected', () {
    final sources = <String, String>{
      'main': File('lib/main.dart').readAsStringSync(),
      'router': File('lib/navigation/app_router.dart').readAsStringSync(),
      'disabled owner': File(
        'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
      ).readAsStringSync(),
      'disabled app integration': File(
        'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
      ).readAsStringSync(),
      'composition': File(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ).readAsStringSync(),
      'route registry': File(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ).readAsStringSync(),
    };

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('CallV2ProductionNavigatorAdapter')),
        reason: entry.key,
      );
    }
    expect(
      sources['composition']!,
      contains('uiRouteIntegrationAvailable: false'),
    );
  });

  test('adapter validates exact canonical names only', () {
    final adapter = File(
      'lib/call_v2/integration/call_v2_production_navigator_adapter.dart',
    ).readAsStringSync();

    expect(adapter, contains('CallV2ProductionRouteNames.connecting'));
    expect(adapter, contains('CallV2ProductionRouteNames.activeAudio'));
    expect(adapter, contains('CallV2ProductionRouteNames.activeVideo'));
    expect(adapter, contains('CallV2ProductionRouteNames.controlledFailure'));
    expect(adapter, isNot(contains('/call-v2/ready')));
  });

  test('V1 and platform scopes remain untouched by navigator adapter', () {
    final adapter = File(
      'lib/call_v2/integration/call_v2_production_navigator_adapter.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'call_v1',
      'legacy',
      'connect_functions',
      'firebase.json',
      'firestore.rules',
      'android/',
      'ios/',
      'macos/',
      'windows/',
      'linux/',
      'web/',
    ]) {
      expect(adapter, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}
