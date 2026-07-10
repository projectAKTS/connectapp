import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner source has no real app or service integration', () {
    final owner = File(
      'lib/call_v2/integration/call_v2_production_ui_composition_owner.dart',
    ).readAsStringSync();
    final status = File(
      'lib/call_v2/integration/call_v2_production_ui_composition_status.dart',
    ).readAsStringSync();
    final result = File(
      'lib/call_v2/integration/call_v2_production_ui_composition_result.dart',
    ).readAsStringSync();

    expect(owner, contains('CallV2ProductionUiCompositionOwner'));
    expect(owner, contains('CallV2ProductionRouteSink'));
    expect(owner, contains('CallV2ProductionRouteFactory'));
    expect(owner, contains('CallV2ProductionViewModelMapper'));
    expect(owner, contains('CallV2ProductionRouteObjectFactory'));
    expect(status, contains('CallV2ProductionUiCompositionStatus'));
    expect(result, contains('CallV2ProductionUiCompositionResult'));

    for (final source in <String>[owner, status, result]) {
      for (final forbidden in <String>[
        'NavigatorState',
        'navigatorKey',
        'GlobalKey',
        'BuildContext',
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
        'main.dart',
        'app_router',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('real app and existing integration files remain disconnected', () {
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

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    for (final entry in sources.entries) {
      expect(
        entry.value,
        isNot(contains('CallV2ProductionUiCompositionOwner')),
        reason: entry.key,
      );
    }
  });

  test('debug output policy remains identifier and route string free', () {
    final sources = <String>[
      File(
        'lib/call_v2/integration/call_v2_production_ui_composition_status.dart',
      ).readAsStringSync(),
      File(
        'lib/call_v2/integration/call_v2_production_ui_composition_result.dart',
      ).readAsStringSync(),
    ];

    for (final source in sources) {
      for (final forbidden in <String>[
        '/call-v2',
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

  test('V1 platform and backend scopes remain untouched by owner files', () {
    final sources = <String>[
      File(
        'lib/call_v2/integration/call_v2_production_ui_composition_owner.dart',
      ).readAsStringSync(),
      File(
        'lib/call_v2/integration/call_v2_production_ui_composition_status.dart',
      ).readAsStringSync(),
      File(
        'lib/call_v2/integration/call_v2_production_ui_composition_result.dart',
      ).readAsStringSync(),
    ];

    for (final source in sources) {
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
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });
}
