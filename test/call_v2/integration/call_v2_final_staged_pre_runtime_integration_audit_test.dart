import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_app_router_bridge_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_app_router_bridge_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_pre_wiring_consolidation_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_main_startup_bridge_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_main_startup_bridge_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_activation_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2FinalStagedPreRuntimeIntegrationAudit;

  test('final staged pre-runtime integration audit artifact passes', () {
    expect(audit, isA<CallV2FinalStagedPreRuntimeIntegrationAudit>());
    expect(
      audit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsStagedPreRuntimeOnly, isTrue);
    expect(audit.recordsRouteRegistryActivationPass, isTrue);
    expect(audit.recordsRouteActivationHardeningPass, isTrue);
    expect(audit.recordsRouteRegistryHardeningPass, isTrue);
    expect(audit.recordsAppRouterBridgeRecognitionPass, isTrue);
    expect(audit.recordsAppRouterBridgeHardeningPass, isTrue);
    expect(audit.recordsMainStartupBridgeRecognitionPass, isTrue);
    expect(audit.recordsMainStartupBridgeHardeningPass, isTrue);
    expect(audit.recordsFinalPreWiringConsolidationPass, isTrue);
    expect(audit.recordsCanonicalRoutesKnown, isTrue);
    expect(audit.recordsLegacyReadyExcluded, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
    expect(audit.recordsNoRouteObjectCreatedWhileFalse, isTrue);
    expect(audit.recordsNoRouteSinkUsedWhileFalse, isTrue);
    expect(audit.recordsNoScreenCreatedWhileFalse, isTrue);
    expect(audit.recordsMainDartUnchanged, isTrue);
    expect(audit.recordsAppRouterUnchanged, isTrue);
    expect(audit.recordsStartupBridgeUnchanged, isTrue);
    expect(audit.recordsNoMainStartupCall, isTrue);
    expect(audit.recordsNoStartupBridgeCall, isTrue);
    expect(audit.recordsProductionIntegrationDisabled, isTrue);
    expect(audit.recordsDisabledOwnerInert, isTrue);
    expect(audit.recordsProductionCompositionUnconstructed, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
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

  test('staged recognition and hardening chain remains closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2RouteRegistryActivation.decision,
      CallV2RouteRegistryActivationDecision.pass,
    );
    expect(
      callV2RouteRegistryActivationHardeningAudit.decision,
      CallV2RouteRegistryActivationHardeningAuditDecision.pass,
    );
    expect(
      callV2RouteRegistryHardeningAudit.decision,
      CallV2RouteRegistryHardeningAuditDecision.pass,
    );
    expect(
      callV2AppRouterBridgeRecognition.decision,
      CallV2AppRouterBridgeRecognitionDecision.pass,
    );
    expect(
      callV2AppRouterBridgeHardeningAudit.decision,
      CallV2AppRouterBridgeHardeningAuditDecision.pass,
    );
    expect(
      callV2MainStartupBridgeRecognition.decision,
      CallV2MainStartupBridgeRecognitionDecision.pass,
    );
    expect(
      callV2MainStartupBridgeHardeningAudit.decision,
      CallV2MainStartupBridgeHardeningAuditDecision.pass,
    );
    expect(
      callV2FinalPreWiringConsolidationAudit.decision,
      CallV2FinalPreWiringConsolidationAuditDecision.pass,
    );
  });

  test('canonical route resolver remains null while rollout is false', () {
    final disabledRegistry = const DisabledCallV2RouteRegistry();

    for (final routeName in callV2DeveloperCanonicalRouteNames) {
      final settings = RouteSettings(name: routeName);
      expect(resolveCallV2Route(settings), isNull, reason: routeName);
      expect(disabledRegistry.resolve(settings), isNull, reason: routeName);
    }

    expect(resolveCallV2Route(const RouteSettings(name: '/call-v2/ready')),
        isNull);
    expect(resolveCallV2Route(const RouteSettings(name: '/unknown')), isNull);
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 42);
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

  test('audit source has no forbidden imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_final_staged_pre_runtime_integration_audit.dart',
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
      'ProductionCallV2StartupBridge',
      'startCallV2Production',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app files do not reference final staged pre-runtime audit', () {
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
        isNot(
          contains('call_v2_final_staged_pre_runtime_integration_audit'),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2FinalStagedPreRuntimeIntegrationAudit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2FinalStagedPreRuntimeIntegrationAudit')),
        reason: path,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
