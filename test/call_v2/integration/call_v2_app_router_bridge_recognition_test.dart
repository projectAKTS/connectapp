import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_app_router_bridge_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_pre_wiring_consolidation_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_activation_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bridge = callV2AppRouterBridgeRecognition;

  test('app-router bridge recognition artifact remains closed', () {
    expect(bridge, isA<CallV2AppRouterBridgeRecognition>());
    expect(bridge.decision, CallV2AppRouterBridgeRecognitionDecision.pass);
    expect(bridge.passes, isTrue);
    expect(bridge.recordsDeveloperOnly, isTrue);
    expect(bridge.recordsRolloutFalse, isTrue);
    expect(bridge.recordsMetadataOnly, isTrue);
    expect(bridge.recordsRouteRecognitionKnown, isTrue);
    expect(bridge.recordsAppRouterUnchanged, isTrue);
    expect(bridge.recordsNoPublicRouteRegistered, isTrue);
    expect(bridge.recordsNoMaterialAppRouteEntry, isTrue);
    expect(bridge.recordsResolverNullWhileFalse, isTrue);
    expect(bridge.recordsDisabledRegistryNull, isTrue);
    expect(bridge.recordsNoRouteObjectCreatedWhileFalse, isTrue);
    expect(bridge.recordsNoScreenCreatedWhileFalse, isTrue);
    expect(bridge.recordsNoRouteSinkUsedWhileFalse, isTrue);
    expect(bridge.recordsNoRuntimeConstruction, isTrue);
    expect(bridge.recordsNoRuntimeStart, isTrue);
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

  test('route registry stays unreachable while rollout is false', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(bridge.recordsRolloutFalse, isTrue);
    expect(bridge.recordsRouteRecognitionKnown, isTrue);
    expect(
      callV2RouteRegistryActivationHardeningAudit.decision,
      CallV2RouteRegistryActivationHardeningAuditDecision.pass,
    );
    expect(
      callV2RouteRegistryHardeningAudit.decision,
      CallV2RouteRegistryHardeningAuditDecision.pass,
    );
    expect(
      callV2FinalPreWiringConsolidationAudit.decision,
      CallV2FinalPreWiringConsolidationAuditDecision.pass,
    );

    final disabledRegistry = const DisabledCallV2RouteRegistry();
    for (final routeName in callV2DeveloperCanonicalRouteNames) {
      final settings = RouteSettings(name: routeName);
      expect(resolveCallV2Route(settings), isNull, reason: routeName);
      expect(disabledRegistry.resolve(settings), isNull, reason: routeName);
    }
  });

  test('app-router bridge exposes only safe debug data', () {
    final debugText = '${bridge.toSafeDebugMap()} $bridge';

    expect(bridge.toSafeDebugMap()['statusCount'], 23);
    expect(bridge.toSafeDebugMap()['canonicalRouteCount'], 4);

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

  test('app router source does not import or register Call V2 routes', () {
    final source = _read('lib/navigation/app_router.dart');

    for (final forbidden in <String>[
      'call_v2',
      'CallV2',
      'resolveCallV2Route',
      'call_v2_app_router_bridge_recognition',
      'CallV2AppRouterBridgeRecognition',
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
      'CallV2Production',
      'CallV2Connecting',
      'CallV2Audio',
      'CallV2Video',
      'CallV2ControlledFailure',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('bridge source has no forbidden imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/call_v2_app_router_bridge_recognition.dart',
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

  test('real app platform backend and config files do not reference bridge',
      () {
    for (final path in <String>[
      'lib/main.dart',
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
        isNot(contains('call_v2_app_router_bridge_recognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2AppRouterBridgeRecognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2AppRouterBridgeRecognition')),
        reason: path,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
