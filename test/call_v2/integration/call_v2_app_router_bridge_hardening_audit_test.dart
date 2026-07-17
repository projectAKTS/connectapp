import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_app_router_bridge_hardening_audit.dart';
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
  final audit = callV2AppRouterBridgeHardeningAudit;

  test('app-router bridge hardening audit artifact passes', () {
    expect(audit, isA<CallV2AppRouterBridgeHardeningAudit>());
    expect(audit.decision, CallV2AppRouterBridgeHardeningAuditDecision.pass);
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsMetadataOnly, isTrue);
    expect(audit.recordsBridgeRecognitionPass, isTrue);
    expect(audit.recordsAppRouterUnchanged, isTrue);
    expect(audit.recordsNoPublicRouteRegistered, isTrue);
    expect(audit.recordsNoMaterialAppRouteEntry, isTrue);
    expect(audit.recordsNoAppRouterCallV2Import, isTrue);
    expect(audit.recordsNoAppRouterCallV2RouteStrings, isTrue);
    expect(audit.recordsNoAppRouterResolverCall, isTrue);
    expect(audit.recordsNoAppRouterBridgeReference, isTrue);
    expect(audit.recordsResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
    expect(audit.recordsRouteActivationHardeningPass, isTrue);
    expect(audit.recordsRouteRegistryHardeningPass, isTrue);
    expect(audit.recordsFinalPreWiringConsolidationPass, isTrue);
    expect(audit.recordsNoRouteObjectCreatedWhileFalse, isTrue);
    expect(audit.recordsNoRouteSinkUsedWhileFalse, isTrue);
    expect(audit.recordsNoScreenCreatedWhileFalse, isTrue);
    expect(audit.recordsNoRuntimeConstruction, isTrue);
    expect(audit.recordsNoRuntimeStart, isTrue);
    expect(audit.recordsNoBackendFirebaseAccess, isTrue);
    expect(audit.recordsNoFirestoreListeners, isTrue);
    expect(audit.recordsNoFirestoreReads, isTrue);
    expect(audit.recordsNoFirestoreWrites, isTrue);
    expect(audit.recordsNoAuthFunctionsAppCheck, isTrue);
    expect(audit.recordsNoRtcPermissionMediaDeviceAccess, isTrue);
    expect(audit.recordsNoNavigatorWiring, isTrue);
    expect(audit.recordsNoLifecycleRegistration, isTrue);
    expect(audit.recordsNoAsyncHandles, isTrue);
    expect(audit.recordsNoDependencyPlatformConfigChanges, isTrue);
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.recordsRollbackOneCommit, isTrue);
    expect(audit.recordsV1Protected, isTrue);
  });

  test('accepted bridge and prior audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(callV2AppRouterBridgeRecognition.decision,
        CallV2AppRouterBridgeRecognitionDecision.pass);
    expect(callV2RouteRegistryActivationHardeningAudit.decision,
        CallV2RouteRegistryActivationHardeningAuditDecision.pass);
    expect(callV2RouteRegistryHardeningAudit.decision,
        CallV2RouteRegistryHardeningAuditDecision.pass);
    expect(callV2FinalPreWiringConsolidationAudit.decision,
        CallV2FinalPreWiringConsolidationAuditDecision.pass);
  });

  test('resolver and disabled registry stay null for canonical routes', () {
    final disabledRegistry = const DisabledCallV2RouteRegistry();

    for (final routeName in callV2DeveloperCanonicalRouteNames) {
      final settings = RouteSettings(name: routeName);
      expect(resolveCallV2Route(settings), isNull, reason: routeName);
      expect(disabledRegistry.resolve(settings), isNull, reason: routeName);
    }
  });

  test('app router source has no Call V2 wiring or route recognition calls',
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
      'CallV2AppRouterBridgeRecognition',
      'call_v2_app_router_bridge_hardening_audit',
      'CallV2AppRouterBridgeHardeningAudit',
      'CallV2Production',
      'CallV2Connecting',
      'CallV2Audio',
      'CallV2Video',
      'CallV2ControlledFailure',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 34);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);

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

  test('hardening audit source has no forbidden imports or hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_app_router_bridge_hardening_audit.dart',
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

  test('real app platform backend and config files do not reference audit', () {
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
        isNot(contains('call_v2_app_router_bridge_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2AppRouterBridgeHardeningAudit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2AppRouterBridgeHardeningAudit')),
        reason: path,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
