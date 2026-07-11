import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('call state bridge sources are isolated and unregistered', () {
    final sources = _bridgeSources();

    expect(sources.join('\n'), contains('CallV2ProductionCallStateBridge'));
    expect(sources.join('\n'), contains('CallV2ProductionRuntimeUiBridge'));
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    for (final source in sources) {
      for (final forbidden in <String>[
        'Firebase',
        'FirebaseFirestore',
        'FirebaseAuth',
        'FirebaseFunctions',
        'httpsCallable',
        'Firestore',
        'snapshots',
        'collection(',
        'doc(',
        'set(',
        'update(',
        'get(',
        'Agora',
        'RtcEngine',
        'WebRTC',
        'permission_handler',
        'Permission.',
        'PermissionStatus',
        'NavigatorState',
        'navigatorKey',
        'GlobalKey',
        'BuildContext',
        'Timer',
        'StreamController',
        'StreamSubscription',
        'MethodChannel',
        'EventChannel',
        'main.dart',
        'app_router',
        'route_registry',
        'startup',
        'registerRoute',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('event model contains no raw backend service or media objects', () {
    final eventSource = File(
      'lib/call_v2/integration/call_v2_production_call_state_bridge_event.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'Object ',
      'dynamic ',
      'Firebase',
      'Firestore',
      'Auth',
      'Functions',
      'Navigator',
      'BuildContext',
      'StackTrace',
      'Exception',
      'DocumentSnapshot',
      'QuerySnapshot',
      'DocumentReference',
      'RtcEngine',
      'Permission.',
      'PermissionStatus',
      'token',
      'channel',
      'uid',
      'callId',
      'credentialPayload',
    ]) {
      expect(eventSource, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('bridge stores no navigator context timer stream or service state', () {
    final bridgeSource = File(
      'lib/call_v2/integration/call_v2_production_call_state_bridge.dart',
    ).readAsStringSync();
    final statusSource = File(
      'lib/call_v2/integration/call_v2_production_call_state_bridge_status.dart',
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
        'Firestore',
        'RtcEngine',
        'Permission.',
        'PermissionStatus',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('real app and accepted production boundaries remain disconnected', () {
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
        isNot(contains('CallV2ProductionCallStateBridge')),
        reason: entry.key,
      );
    }
  });

  test('debug output policy excludes routes identifiers and raw failures', () {
    for (final source in _bridgeSources()) {
      for (final forbidden in <String>[
        '/call-v2',
        'routeName',
        'uid',
        'callId',
        'token',
        'channel',
        'credential=',
        'StackTrace',
        'Exception',
        'message',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('V1 platform backend dependency and config scopes remain untouched', () {
    for (final source in _bridgeSources()) {
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
      'lib/call_v2/integration/call_v2_production_call_state_bridge.dart',
    ).readAsStringSync(),
    File(
      'lib/call_v2/integration/call_v2_production_call_state_bridge_event.dart',
    ).readAsStringSync(),
    File(
      'lib/call_v2/integration/call_v2_production_call_state_bridge_result.dart',
    ).readAsStringSync(),
    File(
      'lib/call_v2/integration/call_v2_production_call_state_bridge_status.dart',
    ).readAsStringSync(),
  ];
}
