import 'dart:io';

import 'package:connect_app/call_v2/firebase/call_v2_dev_callable_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dev callable target config is explicit and non-production', () {
    const config = helperlyCallV2DevCallableTargetConfig;

    expect(config.isReady, isTrue);
    expect(config.projectId, 'helperly-call-v2-dev');
    expect(config.functionsRegion, 'us-central1');
    expect(config.toFirebaseOptions().projectId, 'helperly-call-v2-dev');
  });

  test('dev callable target safe debug contains only generic diagnostics', () {
    final debug = const FirebaseCallV2DevCallableTarget()
        .toSafeDebugMap()
        .toString()
        .toLowerCase();

    expect(debug, contains('devtargetready'));
    expect(debug, contains('callablereachable'));
    expect(debug, contains('selectedregion'));
    for (final forbidden in _forbiddenDebugFragments) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('default app config remains production project', () {
    final dartConfig =
        File('lib/services/firebase_options.dart').readAsStringSync();
    final iosConfig =
        File('ios/Runner/GoogleService-Info.plist').readAsStringSync();

    expect(dartConfig, contains("projectId: 'connectapp-278b4'"));
    expect(iosConfig, contains('<string>connectapp-278b4</string>'));
    expect(dartConfig, isNot(contains('helperly-call-v2-dev')));
    expect(iosConfig, isNot(contains('helperly-call-v2-dev')));
  });

  test('startup and routing do not initialize the dev callable target', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();

    expect(mainSource, isNot(contains('FirebaseCallV2DevCallableTarget')));
    expect(routerSource, isNot(contains('FirebaseCallV2DevCallableTarget')));
    expect(mainSource, isNot(contains('helperly-call-v2-dev')));
    expect(routerSource, isNot(contains('helperly-call-v2-dev')));
  });
}

const _forbiddenDebugFragments = <String>[
  'token',
  'channel',
  'uid',
  'user',
  'participant',
  'callid',
  'device',
  'credential',
  'secret',
  'raw',
  'payload',
  'stack',
  'project',
  'appid',
  'apikey',
];
