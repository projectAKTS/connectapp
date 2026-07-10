import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bridge files are isolated from real app wiring and services', () {
    final sources = _bridgeSources();

    expect(sources.join('\n'), contains('CallV2ProductionRuntimeUiBridge'));
    expect(sources.join('\n'), contains('CallV2ProductionUiCompositionOwner'));
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    for (final source in sources) {
      for (final forbidden in <String>[
        'NavigatorState',
        'navigatorKey',
        'GlobalKey',
        'BuildContext',
        'Timer',
        'StreamSubscription',
        'Firebase',
        'Firestore',
        'Agora',
        'Rtc',
        'Permission',
        'Backend',
        'backend',
        'main.dart',
        'app_router',
        'route_registry',
        'startup',
        'register',
        'navigatorKey',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('event model contains no raw service or app objects', () {
    final eventSource = File(
      'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_event.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'Object runtime',
      'Object backend',
      'Firebase',
      'Firestore',
      'Navigator',
      'BuildContext',
      'StackTrace',
      'Exception',
      'credentials',
      'token',
      'channel',
      'uid',
      'callId',
      'participant',
    ]) {
      expect(eventSource, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('bridge stores no app navigation or asynchronous subscription state',
      () {
    final bridgeSource = File(
      'lib/call_v2/integration/call_v2_production_runtime_ui_bridge.dart',
    ).readAsStringSync();
    final statusSource = File(
      'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_status.dart',
    ).readAsStringSync();

    for (final source in <String>[bridgeSource, statusSource]) {
      for (final forbidden in <String>[
        'NavigatorState',
        'BuildContext',
        'GlobalKey',
        'Timer',
        'Stream',
        'Subscription',
        'Firebase',
        'Rtc',
        'Permission',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('real app and accepted integration files remain disconnected', () {
    final sources = <String, String>{
      'main': File('lib/main.dart').readAsStringSync(),
      'router': File('lib/navigation/app_router.dart').readAsStringSync(),
      'route registry': File(
        'lib/call_v2/integration/call_v2_route_registry.dart',
      ).readAsStringSync(),
      'disabled owner': File(
        'lib/call_v2/integration/disabled_call_v2_production_integration_owner.dart',
      ).readAsStringSync(),
      'disabled app integration': File(
        'lib/call_v2/integration/disabled_call_v2_app_integration.dart',
      ).readAsStringSync(),
      'composition': File(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ).readAsStringSync(),
    };

    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('CallV2ProductionRuntimeUiBridge')),
        reason: entry.key,
      );
    }
  });

  test('bridge debug output policy excludes routes and sensitive identifiers',
      () {
    final sources = _bridgeSources();

    for (final source in sources) {
      for (final forbidden in <String>[
        '/call-v2',
        'routeName',
        'uid',
        'callId',
        'participant',
        'token',
        'channel',
        'credential',
        'StackTrace',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('V1, platform, backend, and dependency scopes remain untouched', () {
    final changedScope = _bridgeSources();

    for (final source in changedScope) {
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
        'pubspec',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });
}

List<String> _bridgeSources() {
  return <String>[
    File(
      'lib/call_v2/integration/call_v2_production_runtime_ui_bridge.dart',
    ).readAsStringSync(),
    File(
      'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_event.dart',
    ).readAsStringSync(),
    File(
      'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_result.dart',
    ).readAsStringSync(),
    File(
      'lib/call_v2/integration/call_v2_production_runtime_ui_bridge_status.dart',
    ).readAsStringSync(),
  ];
}
