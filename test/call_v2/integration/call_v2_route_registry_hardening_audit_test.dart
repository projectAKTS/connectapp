import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2RouteRegistryHardeningAudit;

  test('hardening audit artifact passes with rollout false and unreachable',
      () {
    expect(audit, isA<CallV2RouteRegistryHardeningAudit>());
    expect(audit.decision, CallV2RouteRegistryHardeningAuditDecision.pass);
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsUnreachable, isTrue);
    expect(audit.recordsResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(isCallV2DeveloperRouteRegistrationEnabled, isFalse);
  });

  test('canonical metadata is exact and excludes ready dynamic query fragment',
      () {
    expect(
      callV2DeveloperCanonicalRouteNames,
      <String>{
        '/call-v2/connecting',
        '/call-v2/audio',
        '/call-v2/video',
        '/call-v2/failure',
      },
    );
    expect(audit.canonicalRoutesAreExact, isTrue);
    expect(audit.excludesReadyRoute, isTrue);
    expect(audit.excludesDynamicRoutes, isTrue);
    expect(audit.excludesQueryRoutes, isTrue);
    expect(audit.excludesFragmentRoutes, isTrue);
    expect(
      isCallV2DeveloperCanonicalRouteName('/call-v2/ready'),
      isFalse,
    );
    expect(
      isCallV2DeveloperCanonicalRouteName('/call-v2/connecting/extra'),
      isFalse,
    );
    expect(
      isCallV2DeveloperCanonicalRouteName('/call-v2/audio?mode=debug'),
      isFalse,
    );
    expect(
      isCallV2DeveloperCanonicalRouteName('/call-v2/video#camera'),
      isFalse,
    );
  });

  test('resolver and disabled registry return null for all audited routes', () {
    final disabledRegistry = const DisabledCallV2RouteRegistry();

    for (final routeName in <String>[
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
      '/call-v2/ready',
      '/call-v2/connecting/extra',
      '/call-v2/audio?mode=debug',
      '/call-v2/video#camera',
      '/call-v2/incoming',
      '/',
      '/home',
      '/chat',
    ]) {
      final settings = RouteSettings(name: routeName);
      expect(resolveCallV2Route(settings), isNull, reason: routeName);
      expect(disabledRegistry.resolve(settings), isNull, reason: routeName);
    }
  });

  test('arguments are ignored while rollout is false', () {
    final hostile = _HostileRouteArguments();
    final settings = RouteSettings(
      name: '/call-v2/connecting',
      arguments: hostile,
    );

    expect(resolveCallV2Route(settings), isNull);
    expect(hostile.readCount, 0);
    expect(audit.ignoresArgumentsWhileFalse, isTrue);
    expect(audit.excludesNonCallV2Routes, isTrue);
  });

  test('route decision and audit debug output are safe', () {
    final decision = describeCallV2RouteRegistryDecision(
      const RouteSettings(name: '/call-v2/connecting'),
    );

    expect(
      decision.kind,
      CallV2DeveloperRouteRegistryDecisionKind.rolloutDisabled,
    );
    expect(decision.routeMayResolve, isFalse);

    final debugText =
        '${decision.toSafeDebugMap()} $decision ${audit.toSafeDebugMap()} $audit';
    for (final forbidden in <String>[
      '/call-v2',
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

  test('audit records no route object sink screen or service access', () {
    expect(audit.createsRouteObject, isFalse);
    expect(audit.usesRouteSink, isFalse);
    expect(audit.createsScreen, isFalse);
    expect(audit.startsRuntime, isFalse);
    expect(audit.accessesBackendFirebase, isFalse);
    expect(audit.accessesRtcPermissions, isFalse);
    expect(audit.wiresNavigator, isFalse);
    expect(audit.registersLifecycleObserver, isFalse);
    expect(audit.createsAsyncHandles, isFalse);
    expect(audit.changesPubspecPlatform, isFalse);
    expect(audit.changesRulesFunctionsConfig, isFalse);
    expect(audit.protectsV1, isTrue);
  });

  test('rollback model preserves one commit route-null disabled-owner safety',
      () {
    expect(audit.rollbackPreserved, isTrue);
    expect(
      audit.rollback,
      <CallV2RouteRegistryHardeningRollback>[
        CallV2RouteRegistryHardeningRollback.oneCommitRevert,
        CallV2RouteRegistryHardeningRollback.keepRolloutFalse,
        CallV2RouteRegistryHardeningRollback.keepRouteRegistryNull,
        CallV2RouteRegistryHardeningRollback.keepDisabledOwnerInert,
        CallV2RouteRegistryHardeningRollback.noDeploymentRequired,
        CallV2RouteRegistryHardeningRollback.noConfigChanges,
        CallV2RouteRegistryHardeningRollback.v1Unaffected,
      ],
    );
  });

  test('route registry source remains service navigator and async free', () {
    final source = _read('lib/call_v2/integration/call_v2_route_registry.dart');

    for (final forbidden in _forbiddenSourceTerms) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('hardening audit source has no forbidden imports or hooks', () {
    final source = _read(
      'lib/call_v2/integration/call_v2_route_registry_hardening_audit.dart',
    );

    for (final forbidden in <String>[
      "import 'package:flutter",
      "import 'dart:async",
      "import 'dart:io",
      'package:firebase',
      ..._forbiddenSourceTerms,
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app and config boundaries do not reference hardening audit', () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'pubspec.yaml',
      'pubspec.lock',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
    ]) {
      final source = _read(path);
      expect(
        source,
        isNot(contains('call_v2_route_registry_hardening_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RouteRegistryHardeningAudit')),
        reason: path,
      );
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

const _forbiddenSourceTerms = <String>[
  'cloud_firestore',
  'cloud_functions',
  'firebase_auth',
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
  'CallV2ProductionComposition',
  'ProductionCallV2StartupBridge',
  'CallV2Runtime(',
  'Navigator.',
  'Navigator(',
  'BuildContext',
  'GlobalKey',
  'Timer(',
  'StreamController',
  'StreamSubscription',
  'listen(',
  'AppLifecycleListener',
  'WidgetsBindingObserver',
  'CallV2ProductionRouteObjectFactory(',
  'CallV2ProductionRouteSink',
  '.createRoute(',
  '.createScreen(',
  '.show(',
];

final class _HostileRouteArguments {
  int readCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    readCount += 1;
    throw StateError('arguments were read');
  }
}
