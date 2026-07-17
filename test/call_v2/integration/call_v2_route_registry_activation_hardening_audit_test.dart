import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_final_pre_wiring_consolidation_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_activation_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2RouteRegistryActivationHardeningAudit;

  test('activation hardening audit artifact passes closed-state checks', () {
    expect(audit, isA<CallV2RouteRegistryActivationHardeningAudit>());
    expect(
      audit.decision,
      CallV2RouteRegistryActivationHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsRouteRegistrationDisabled, isTrue);
    expect(audit.recordsResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
    expect(audit.recordsCanonicalRoutesExact, isTrue);
    expect(audit.recordsLegacyReadyExcluded, isTrue);
    expect(audit.recordsHostileArgsIgnoredWhileFalse, isTrue);
    expect(audit.recordsNoRouteObjectCreatedWhileFalse, isTrue);
    expect(audit.recordsNoRouteSinkUsedWhileFalse, isTrue);
    expect(audit.recordsNoScreenCreatedWhileFalse, isTrue);
    expect(audit.recordsNoRuntimeConstruction, isTrue);
    expect(audit.recordsNoRuntimeStart, isTrue);
    expect(audit.recordsNoProductionCompositionConstruction, isTrue);
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
    expect(audit.recordsFinalPreWiringConsolidationPass, isTrue);
    expect(audit.recordsRollbackOneCommit, isTrue);
    expect(audit.recordsV1Protected, isTrue);
  });

  test('route activation and prior audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(isCallV2DeveloperRouteRegistrationEnabled, isFalse);
    expect(callV2RouteRegistryActivation.passes, isTrue);
    expect(callV2RouteRegistryHardeningAudit.decision,
        CallV2RouteRegistryHardeningAuditDecision.pass);
    expect(callV2FinalPreWiringConsolidationAudit.decision,
        CallV2FinalPreWiringConsolidationAuditDecision.pass);
  });

  test('canonical routes are exact and legacy ready remains excluded', () {
    expect(
      callV2DeveloperCanonicalRouteNames,
      <String>{
        '/call-v2/connecting',
        '/call-v2/audio',
        '/call-v2/video',
        '/call-v2/failure',
      },
    );
    expect(audit.recordsCanonicalRoutesExact, isTrue);
    expect(audit.recordsLegacyReadyExcluded, isTrue);
    expect(
      isCallV2DeveloperCanonicalRouteName('/call-v2/ready'),
      isFalse,
    );
  });

  test('resolver and disabled registry stay null while rollout is false', () {
    final disabledRegistry = const DisabledCallV2RouteRegistry();

    for (final routeName in <String>[
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
      '/call-v2/ready',
      '/call-v2/unknown',
      '/',
      '/home',
    ]) {
      final settings = RouteSettings(name: routeName);
      expect(resolveCallV2Route(settings), isNull, reason: routeName);
      expect(disabledRegistry.resolve(settings), isNull, reason: routeName);
    }
  });

  test('route decision remains rollout disabled while rollout is false', () {
    final decision = describeCallV2RouteRegistryDecision(
      const RouteSettings(name: '/call-v2/connecting'),
    );

    expect(
      decision.kind,
      CallV2DeveloperRouteRegistryDecisionKind.rolloutDisabled,
    );
    expect(decision.rolloutEnabled, isFalse);
    expect(decision.routeMayResolve, isFalse);
  });

  test('hostile route arguments are not read while rollout is false', () {
    final hostile = _HostileRouteArguments();
    final settings = RouteSettings(
      name: '/call-v2/connecting',
      arguments: hostile,
    );

    expect(resolveCallV2Route(settings), isNull);
    expect(hostile.readCount, 0);
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit '
        '${callV2RouteRegistryActivation.toSafeDebugMap()} '
        '$callV2RouteRegistryActivation';

    expect(audit.toSafeDebugMap()['statusCount'], 28);
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
      'call_v2_route_registry_activation_hardening_audit.dart',
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

  test('route registry source still has no forbidden service hooks', () {
    final source = _registrySource();

    for (final forbidden in <String>[
      'package:firebase',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'firebase_app_check',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
      'agora_rtc_engine',
      'permission_handler',
      'Permission.',
      'RtcEngine',
      'createAgoraRtcEngine',
      'joinChannel',
      'CallV2Runtime(',
      'Navigator.',
      'Navigator(',
      'BuildContext',
      'GlobalKey',
      'MaterialApp(',
      'dart:async',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      '.listen(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'CallV2ProductionRouteObjectFactory(',
      'CallV2ProductionRouteSink',
      '.createRoute(',
      '.createScreen(',
      '.show(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
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
        isNot(contains('call_v2_route_registry_activation_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RouteRegistryActivationHardeningAudit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2RouteRegistryActivationHardeningAudit')),
        reason: path,
      );
    }
  });
}

String _registrySource() {
  return <String>[
    'lib/call_v2/integration/call_v2_route_registry.dart',
    'lib/call_v2/integration/disabled_call_v2_route_registry.dart',
  ].map(_read).join('\n');
}

String _read(String path) => File(path).readAsStringSync();

final class _HostileRouteArguments {
  int readCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    readCount += 1;
    throw StateError('arguments were read');
  }
}
