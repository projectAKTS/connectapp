import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_status.dart';
import 'package:connect_app/call_v2/integration/call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_production_integration_owner.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2DeveloperSkeletonCompositionAudit;

  test('audit artifact exists and is developer-only hard-disabled pass', () {
    expect(audit.components, hasLength(6));
    expect(audit.invariants, hasLength(15));
    expect(audit.rollback, hasLength(6));
    expect(audit.isDeveloperOnly, isTrue);
    expect(audit.isHardDisabled, isTrue);
    expect(audit.isRolloutEnabled, isFalse);
    expect(audit.isReachable, isFalse);
    expect(audit.decision, CallV2DeveloperSkeletonCompositionDecision.pass);
    expect(audit.passesSharedInvariants, isTrue);
  });

  test('audit lists all six Phase 7 skeleton components', () {
    expect(
      audit.components,
      <CallV2DeveloperSkeletonComponent>[
        CallV2DeveloperSkeletonComponent.routeRegistration,
        CallV2DeveloperSkeletonComponent.lifecycleObserver,
        CallV2DeveloperSkeletonComponent.navigatorOwner,
        CallV2DeveloperSkeletonComponent.runtimeStartupOwner,
        CallV2DeveloperSkeletonComponent.backendFirebaseOwner,
        CallV2DeveloperSkeletonComponent.rtcPermissionOwner,
      ],
    );
    expect(audit.allComponentsPresent, isTrue);
    expect(audit.includesRouteRegistration, isTrue);
    expect(audit.includesLifecycleObserver, isTrue);
    expect(audit.includesNavigatorOwner, isTrue);
    expect(audit.includesRuntimeStartupOwner, isTrue);
    expect(audit.includesBackendFirebaseOwner, isTrue);
    expect(audit.includesRtcPermissionOwner, isTrue);
  });

  test('all skeletons remain hard-disabled unreachable and rollout false', () {
    expect(callV2DeveloperRouteRegistrationSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperLifecycleObserverSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperNavigatorOwnerSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperRuntimeStartupOwnerSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperBackendOwnerSkeleton.isHardDisabled, isTrue);
    expect(callV2DeveloperRtcPermissionOwnerSkeleton.isHardDisabled, isTrue);

    expect(callV2DeveloperRouteRegistrationSkeleton.isReachable, isFalse);
    expect(callV2DeveloperLifecycleObserverSkeleton.isReachable, isFalse);
    expect(callV2DeveloperNavigatorOwnerSkeleton.isReachable, isFalse);
    expect(callV2DeveloperRuntimeStartupOwnerSkeleton.isReachable, isFalse);
    expect(callV2DeveloperBackendOwnerSkeleton.isReachable, isFalse);
    expect(callV2DeveloperRtcPermissionOwnerSkeleton.isReachable, isFalse);

    expect(callV2DeveloperRouteRegistrationSkeleton.isRolloutEnabled, isFalse);
    expect(callV2DeveloperLifecycleObserverSkeleton.isRolloutEnabled, isFalse);
    expect(callV2DeveloperNavigatorOwnerSkeleton.isRolloutEnabled, isFalse);
    expect(
        callV2DeveloperRuntimeStartupOwnerSkeleton.isRolloutEnabled, isFalse);
    expect(callV2DeveloperBackendOwnerSkeleton.isRolloutEnabled, isFalse);
    expect(callV2DeveloperRtcPermissionOwnerSkeleton.isRolloutEnabled, isFalse);
  });

  test('composition audit blocks runtime composition backend and RTC access',
      () {
    expect(audit.startsRuntime, isFalse);
    expect(audit.constructsProductionComposition, isFalse);
    expect(audit.accessesBackendFirebase, isFalse);
    expect(audit.opensFirestoreListeners, isFalse);
    expect(audit.callsAuthFunctions, isFalse);
    expect(audit.accessesRtcPermissions, isFalse);
    expect(audit.initializesRtc, isFalse);
    expect(audit.requestsPermissions, isFalse);
    expect(audit.enumeratesDevices, isFalse);
    expect(audit.capturesMedia, isFalse);
  });

  test('composition audit blocks navigator lifecycle route and async handles',
      () {
    expect(audit.wiresNavigator, isFalse);
    expect(audit.registersLifecycleObserver, isFalse);
    expect(audit.mutatesRouteRegistry, isFalse);
    expect(audit.opensAsyncHandles, isFalse);
    expect(audit.changesPubspecPlatformConfig, isFalse);
    expect(audit.changesRulesFunctionsConfig, isFalse);
    expect(audit.protectsV1, isTrue);
    expect(audit.rollbackPreserved, isTrue);
  });

  test('safe debug output exposes only counts and booleans', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['componentCount'], 6);
    expect(audit.toSafeDebugMap()['invariantCount'], 15);
    expect(audit.toSafeDebugMap()['rollbackCount'], 6);
    expect(audit.toSafeDebugMap()['decision'], 'pass');
    expect(audit.toSafeDebugMap()['hardDisabled'], isTrue);

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

  test('rollout and route registries remain disabled', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      resolveCallV2Route(const RouteSettings(name: '/call-v2/connecting')),
      isNull,
    );
    expect(
      const DisabledCallV2RouteRegistry().resolve(
        const RouteSettings(name: '/call-v2/connecting'),
      ),
      isNull,
    );
  });

  test('disabled owner remains inert and does not construct composition',
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
        owner.status.lifecycle, CallV2ProductionIntegrationLifecycle.disabled);
    expect(owner.status.compositionConstructed, isFalse);
    expect(owner.status.runtimeStarted, isFalse);
    expect(owner.status.routesRegistered, isFalse);
    expect(owner.status.screensAvailable, isFalse);
    expect(compositionConstructed, isFalse);
  });

  test('real app boundary files do not reference the composition audit', () {
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
        isNot(contains('call_v2_developer_skeleton_composition_audit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2DeveloperSkeletonCompositionAudit')),
        reason: path,
      );
    }
  });

  test('audit source avoids real app startup platform and service hooks', () {
    final source = File(
      'lib/call_v2/integration/'
      'call_v2_developer_skeleton_composition_audit.dart',
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
      'CallV2ProductionComposition',
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
