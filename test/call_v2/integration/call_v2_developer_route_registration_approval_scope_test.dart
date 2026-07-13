import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scope = callV2DeveloperRouteRegistrationApprovalScope;

  test('approval scope artifact records exact Phase 7J approval', () {
    expect(scope.hasHumanApproval, isTrue);
    expect(scope.isRouteRegistrationOnly, isTrue);
    expect(scope.isDeveloperOnly, isTrue);
    expect(scope.isRolloutEnabled, isFalse);
    expect(scope.resolverStillNullWhileFalse, isTrue);
    expect(scope.startsRuntime, isFalse);
    expect(scope.accessesBackendFirebase, isFalse);
    expect(scope.accessesRtcPermissions, isFalse);
    expect(scope.wiresNavigator, isFalse);
    expect(scope.registersLifecycleObserver, isFalse);
    expect(scope.changesPubspecPlatformConfig, isFalse);
    expect(scope.changesRulesFunctionsConfig, isFalse);
    expect(scope.isDeploymentApproved, isFalse);
    expect(scope.protectsV1, isTrue);
  });

  test('pre-wiring gate default remains blocked but approved scope evaluates',
      () {
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(
      scope.evaluatedGate.selectedScope,
      CallV2DeveloperPreWiringScope.routeRegistrationOnly,
    );
    expect(
      scope.evaluatedGate.decision,
      CallV2DeveloperPreWiringGateDecision
          .allowedForExplicitFutureDeveloperOnlyPhase,
    );
    expect(scope.evaluatedGate.canWireRoutes, isFalse);
    expect(scope.evaluatedGate.canStartRuntime, isFalse);
    expect(scope.evaluatedGate.canAccessBackendFirebase, isFalse);
    expect(scope.evaluatedGate.canInitializeRtc, isFalse);
    expect(scope.evaluatedGate.canRequestPermissions, isFalse);
    expect(scope.evaluatedGate.canModifyPubspecPlatform, isFalse);
    expect(scope.evaluatedGate.canModifyRulesFunctionsConfig, isFalse);
  });

  test('allowed and forbidden future files are scoped to route registration',
      () {
    expect(
      scope.allowedFutureFiles,
      <String>[
        'lib/call_v2/integration/call_v2_route_registry.dart',
        'test/call_v2/integration/call_v2_route_registry_test.dart',
      ],
    );
    expect(scope.allowedFutureFilesAreRouteRegistrationOnly, isTrue);
    expect(scope.forbidsOutOfScopeFutureFiles, isTrue);
    expect(
      scope.forbiddenFutureFiles,
      containsAll(<String>[
        'lib/main.dart',
        'lib/navigation/app_router.dart',
        'lib/call_v2/startup/**',
        'lib/call_v2/runtime/**',
        'lib/call_v2/firebase/**',
        'lib/call_v2/rtc/**',
        'lib/call_v2/permissions/**',
        'pubspec.yaml',
        'pubspec.lock',
        'android/**',
        'ios/**',
        'firestore.rules',
        'firebase.json',
        'connect_functions/**',
      ]),
    );
  });

  test('route resolver remains null for all route names while rollout false',
      () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);

    for (final routeName in <String>[
      '/call-v2/connecting',
      '/call-v2/audio',
      '/call-v2/video',
      '/call-v2/failure',
      '/call-v2/ready',
      '/home',
    ]) {
      expect(
        resolveCallV2Route(RouteSettings(name: routeName)),
        isNull,
        reason: routeName,
      );
      expect(
        const DisabledCallV2RouteRegistry().resolve(
          RouteSettings(name: routeName),
        ),
        isNull,
        reason: routeName,
      );
    }
  });

  test('disabled owner route skeleton and composition audit stay inert',
      () async {
    var compositionConstructed = false;
    final owner = DisabledCallV2ProductionIntegrationOwner(
      rolloutEnabled: () => false,
      compositionFactory: _ThrowingCompositionFactory(
        onConstruct: () => compositionConstructed = true,
      ),
    );

    await owner.initialize();

    expect(
      owner.status.lifecycle,
      CallV2ProductionIntegrationLifecycle.disabled,
    );
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(compositionConstructed, isFalse);
    expect(callV2DeveloperRouteRegistrationSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperRouteRegistrationSkeleton.isReachable, isFalse);
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
    );
  });

  test('approval scope creates no route object screen or sink usage', () {
    expect(scope.createsRouteObject, isFalse);
    expect(scope.createsScreen, isFalse);
    expect(scope.usesRouteSink, isFalse);

    final source = File(
      'lib/call_v2/integration/'
      'call_v2_developer_route_registration_approval_scope.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('CallV2ProductionRouteObjectFactory')));
    expect(source, isNot(contains('CallV2ProductionRouteSink')));
    expect(source, isNot(contains('.createRoute(')));
    expect(source, isNot(contains('.show(')));
  });

  test('safe debug output contains no sensitive data or route strings', () {
    final debugText = '${scope.toSafeDebugMap()} $scope';
    expect(scope.toSafeDebugMap()['evidenceCount'], 14);
    expect(scope.toSafeDebugMap()['allowedFutureFileCount'], 2);
    expect(scope.toSafeDebugMap()['forbiddenFutureFileCount'], 14);
    expect(scope.toSafeDebugMap()['gateDecision'],
        'allowedForExplicitFutureDeveloperOnlyPhase');

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

  test('real app boundary files do not reference approval scope', () {
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
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('call_v2_developer_route_registration_approval_scope')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2DeveloperRouteRegistrationApprovalScope')),
        reason: path,
      );
    }
  });

  test('approval scope source avoids service runtime and platform hooks', () {
    final source = File(
      'lib/call_v2/integration/'
      'call_v2_developer_route_registration_approval_scope.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      "import 'package:",
      'package:flutter/',
      'package:firebase',
      'cloud_firestore',
      'cloud_functions',
      'firebase_auth',
      'agora_rtc_engine',
      'permission_handler',
      'package:camera',
      'package:microphone',
      'dart:async',
      'dart:io',
      'MethodChannel',
      'EventChannel',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      'listen(',
      'AppLifecycleListener',
      'WidgetsBindingObserver',
      'Navigator.',
      'Navigator(',
      'GlobalKey',
      'BuildContext',
      'MaterialApp',
      'ProductionCallV2StartupBridge',
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
      'RtcEngine(',
      'createAgoraRtcEngine',
      'joinChannel',
      'Permission.',
      '.request()',
      'enumerateDevices',
      'startPreview',
      'publishAudio',
      'publishVideo',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('rollback preserves one commit disabled route registry and V1', () {
    expect(scope.rollbackPreserved, isTrue);
    expect(
      scope.rollback,
      <CallV2DeveloperRouteRegistrationApprovalRollback>[
        CallV2DeveloperRouteRegistrationApprovalRollback.oneCommitRevert,
        CallV2DeveloperRouteRegistrationApprovalRollback.keepRolloutFalse,
        CallV2DeveloperRouteRegistrationApprovalRollback.keepRouteRegistryNull,
        CallV2DeveloperRouteRegistrationApprovalRollback.keepDisabledOwnerInert,
        CallV2DeveloperRouteRegistrationApprovalRollback.noDeploymentRequired,
        CallV2DeveloperRouteRegistrationApprovalRollback.noConfigChanges,
        CallV2DeveloperRouteRegistrationApprovalRollback.v1Unaffected,
      ],
    );
  });
}

final class _ThrowingCompositionFactory
    implements CallV2ProductionIntegrationCompositionFactory {
  const _ThrowingCompositionFactory({required this.onConstruct});

  final void Function() onConstruct;

  @override
  Object createProductionComposition() {
    onConstruct();
    throw StateError('must not construct composition');
  }
}
