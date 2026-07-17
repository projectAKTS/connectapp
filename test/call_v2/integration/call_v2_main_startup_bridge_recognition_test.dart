import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_app_router_bridge_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_main_startup_bridge_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bridge = callV2MainStartupBridgeRecognition;

  test('main startup bridge recognition artifact remains closed', () {
    expect(bridge, isA<CallV2MainStartupBridgeRecognition>());
    expect(bridge.decision, CallV2MainStartupBridgeRecognitionDecision.pass);
    expect(bridge.passes, isTrue);
    expect(bridge.recordsDeveloperOnly, isTrue);
    expect(bridge.recordsRolloutFalse, isTrue);
    expect(bridge.recordsMetadataOnly, isTrue);
    expect(bridge.recordsMainDartUnchanged, isTrue);
    expect(bridge.recordsNoMainStartupCall, isTrue);
    expect(bridge.recordsNoStartupBridgeCall, isTrue);
    expect(bridge.recordsProductionIntegrationDisabled, isTrue);
    expect(bridge.recordsDisabledOwnerInert, isTrue);
    expect(bridge.recordsProductionCompositionUnconstructed, isTrue);
    expect(bridge.recordsRuntimeUnconstructed, isTrue);
    expect(bridge.recordsRuntimeNotStarted, isTrue);
    expect(bridge.recordsAppRouterBridgeHardeningPass, isTrue);
    expect(bridge.recordsRouteResolverNullWhileFalse, isTrue);
    expect(bridge.recordsRoutesUnreachable, isTrue);
    expect(bridge.recordsNoBackendFirebaseAccess, isTrue);
    expect(bridge.recordsNoRtcPermissionMediaDeviceAccess, isTrue);
    expect(bridge.recordsNoNavigatorWiring, isTrue);
    expect(bridge.recordsNoLifecycleRegistration, isTrue);
    expect(bridge.recordsNoAsyncHandles, isTrue);
    expect(bridge.recordsNoDependencyPlatformConfigChanges, isTrue);
    expect(bridge.recordsNoDeployment, isTrue);
    expect(bridge.recordsRollbackOneCommit, isTrue);
    expect(bridge.recordsV1Protected, isTrue);
  });

  test('accepted rollout and app-router hardening remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2AppRouterBridgeHardeningAudit.decision,
      CallV2AppRouterBridgeHardeningAuditDecision.pass,
    );
  });

  test('main.dart source does not reference bridge recognition', () {
    final source = _read('lib/main.dart');

    for (final forbidden in <String>[
      'call_v2_main_startup_bridge_recognition',
      'CallV2MainStartupBridgeRecognition',
      'callV2MainStartupBridgeRecognition',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('startup bridge source does not reference recognition artifact', () {
    final source = _read(
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
    );

    for (final forbidden in <String>[
      'call_v2_main_startup_bridge_recognition',
      'CallV2MainStartupBridgeRecognition',
      'callV2MainStartupBridgeRecognition',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('app router source remains free of Call V2 imports routes and calls',
      () {
    final source = _read('lib/navigation/app_router.dart');

    for (final forbidden in <String>[
      'call_v2',
      'CallV2',
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
      'resolveCallV2Route',
      'call_v2_app_router_bridge_recognition',
      'call_v2_app_router_bridge_hardening_audit',
      'call_v2_main_startup_bridge_recognition',
      'CallV2AppRouterBridgeRecognition',
      'CallV2AppRouterBridgeHardeningAudit',
      'CallV2MainStartupBridgeRecognition',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('recognition source has no forbidden imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_main_startup_bridge_recognition.dart',
    );

    for (final forbidden in <String>[
      "import 'package:flutter",
      "import 'dart:async",
      "import 'dart:io",
      'package:firebase',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'firebase_app_check',
      'agora_rtc_engine',
      'permission_handler',
      '../startup/',
      '../runtime/',
      '../firebase/',
      '../rtc/',
      '../permissions/',
      '../production/',
      '../backend/',
      '../navigation/',
      '../main',
      'navigation/app_router',
      'lib/navigation',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
      '.collection(',
      '.doc(',
      '.get(',
      '.set(',
      '.update(',
      '.delete(',
      'createAgoraRtcEngine',
      'joinChannel',
      'requestPermissions',
      'availableCameras',
      'Navigator.',
      'Navigator(',
      'GlobalKey',
      'BuildContext',
      'MaterialApp(',
      'CupertinoPageRoute',
      'RouteSettings(',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      '.listen(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${bridge.toSafeDebugMap()} $bridge';

    expect(bridge.toSafeDebugMap()['statusCount'], 23);

    for (final forbidden in <String>[
      '/call-v2',
      'args',
      'argument',
      'uid',
      'user',
      'participant',
      'callId',
      'token',
      'credential',
      'channel',
      'deviceLabel',
      'deviceId',
      'payload',
      'stack',
      'raw',
    ]) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app platform backend and config files do not reference bridge',
      () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'pubspec.yaml',
      'pubspec.lock',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
      'linux/CMakeLists.txt',
      'web/index.html',
      'windows/CMakeLists.txt',
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
    ]) {
      final source = _read(path);
      expect(
        source,
        isNot(contains('call_v2_main_startup_bridge_recognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2MainStartupBridgeRecognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2MainStartupBridgeRecognition')),
        reason: path,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
