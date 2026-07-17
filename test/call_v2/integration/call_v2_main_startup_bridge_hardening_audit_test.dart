import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_app_router_bridge_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_pre_wiring_consolidation_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_main_startup_bridge_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_main_startup_bridge_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2MainStartupBridgeHardeningAudit;

  test('main startup bridge hardening audit artifact remains closed', () {
    expect(audit, isA<CallV2MainStartupBridgeHardeningAudit>());
    expect(
      audit.decision,
      CallV2MainStartupBridgeHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsMetadataOnly, isTrue);
    expect(audit.recordsMainStartupBridgeRecognitionPass, isTrue);
    expect(audit.recordsMainDartUnchanged, isTrue);
    expect(audit.recordsNoMainDartBridgeImport, isTrue);
    expect(audit.recordsNoMainStartupCall, isTrue);
    expect(audit.recordsNoStartupBridgeCall, isTrue);
    expect(audit.recordsStartupBridgeUnchanged, isTrue);
    expect(audit.recordsProductionIntegrationDisabled, isTrue);
    expect(audit.recordsDisabledOwnerInert, isTrue);
    expect(audit.recordsProductionCompositionUnconstructed, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
    expect(audit.recordsAppRouterBridgeHardeningPass, isTrue);
    expect(audit.recordsFinalPreWiringConsolidationPass, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
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

  test('accepted recognition and prior audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2MainStartupBridgeRecognition.decision,
      CallV2MainStartupBridgeRecognitionDecision.pass,
    );
    expect(
      callV2AppRouterBridgeHardeningAudit.decision,
      CallV2AppRouterBridgeHardeningAuditDecision.pass,
    );
    expect(
      callV2FinalPreWiringConsolidationAudit.decision,
      CallV2FinalPreWiringConsolidationAuditDecision.pass,
    );
  });

  test('main.dart source does not reference startup bridge artifacts', () {
    final source = _read('lib/main.dart');

    for (final forbidden in <String>[
      'call_v2_main_startup_bridge_recognition',
      'call_v2_main_startup_bridge_hardening_audit',
      'CallV2MainStartupBridgeRecognition',
      'CallV2MainStartupBridgeHardeningAudit',
      'callV2MainStartupBridgeRecognition',
      'callV2MainStartupBridgeHardeningAudit',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('startup bridge source does not reference new artifacts', () {
    final source = _read(
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
    );

    for (final forbidden in <String>[
      'call_v2_main_startup_bridge_recognition',
      'call_v2_main_startup_bridge_hardening_audit',
      'CallV2MainStartupBridgeRecognition',
      'CallV2MainStartupBridgeHardeningAudit',
      'callV2MainStartupBridgeRecognition',
      'callV2MainStartupBridgeHardeningAudit',
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
      'call_v2_main_startup_bridge_hardening_audit',
      'CallV2AppRouterBridgeRecognition',
      'CallV2AppRouterBridgeHardeningAudit',
      'CallV2MainStartupBridgeRecognition',
      'CallV2MainStartupBridgeHardeningAudit',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('hardening audit source has no forbidden imports or executable hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_main_startup_bridge_hardening_audit.dart',
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
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 31);
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

  test('real app platform backend and config files do not reference audit', () {
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
        isNot(contains('call_v2_main_startup_bridge_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2MainStartupBridgeHardeningAudit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2MainStartupBridgeHardeningAudit')),
        reason: path,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
