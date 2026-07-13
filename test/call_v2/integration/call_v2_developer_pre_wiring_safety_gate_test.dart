import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_owner_skeleton.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_owner_skeleton.dart';
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
  final gate = callV2DeveloperPreWiringSafetyGate;

  test('gate artifact records default hard-disabled pre-wiring status', () {
    expect(gate.statuses, hasLength(19));
    expect(gate.isDeveloperOnly, isTrue);
    expect(gate.isHardDisabled, isTrue);
    expect(gate.isRolloutEnabled, isFalse);
    expect(gate.isReachable, isFalse);
    expect(gate.isCompositionAuditPassing, isTrue);
    expect(gate.isDisabledOwnerInert, isTrue);
    expect(gate.isBackupProtected, isTrue);
    expect(gate.requiresHumanApproval, isTrue);
    expect(gate.requiresExactScope, isTrue);
    expect(gate.requiresAllowedFiles, isTrue);
    expect(gate.requiresRollback, isTrue);
    expect(gate.requiresKillSwitch, isTrue);
    expect(gate.requiresDeveloperAllowlist, isTrue);
    expect(gate.requiresV1Smoke, isTrue);
    expect(gate.requiresPrivacyReview, isTrue);
    expect(gate.requiresFullValidation, isTrue);
    expect(gate.blocksDeployment, isTrue);
    expect(gate.blocksProductionServiceContact, isTrue);
    expect(gate.blocksPublicExposure, isTrue);
  });

  test('default gate has no selected scope and blocks Phase 7J', () {
    expect(gate.selectedScope, CallV2DeveloperPreWiringScope.noneSelected);
    expect(
      gate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(gate.hasSelectedScope, isFalse);
    expect(gate.hasExactlyOneSelectedScope, isFalse);
  });

  test('selected scope without approval or allowed files still blocks', () {
    final selected = gate.evaluateFutureScope(
      selectedScope: CallV2DeveloperPreWiringScope.routeRegistrationOnly,
      explicitFutureApproval: false,
      allowedFilesListed: true,
      oneCommitRollbackConfirmed: true,
    );

    expect(selected.hasExactlyOneSelectedScope, isTrue);
    expect(
      selected.decision,
      CallV2DeveloperPreWiringGateDecision.blockedMissingApproval,
    );

    final missingFiles = gate.evaluateFutureScope(
      selectedScope: CallV2DeveloperPreWiringScope.lifecycleObserverOnly,
      explicitFutureApproval: true,
      allowedFilesListed: false,
      oneCommitRollbackConfirmed: true,
    );
    expect(
      missingFiles.decision,
      CallV2DeveloperPreWiringGateDecision.blockedMissingApproval,
    );
  });

  test('audit failure blocks even with explicit future approval', () {
    final failingGate = CallV2DeveloperPreWiringSafetyGate(
      compositionAudit: CallV2DeveloperSkeletonCompositionAudit(
        components: const <CallV2DeveloperSkeletonComponent>[],
        invariants: const <CallV2DeveloperSkeletonCompositionInvariant>[],
        rollback: const <CallV2DeveloperSkeletonCompositionRollback>[],
      ),
      statuses: gate.statuses,
      selectedScope: CallV2DeveloperPreWiringScope.navigatorOwnerOnly,
      explicitFutureApproval: true,
      allowedFilesListed: true,
      oneCommitRollbackConfirmed: true,
      blockedActions: gate.blockedActions,
      validationRequirements: gate.validationRequirements,
      rollbackRequirements: gate.rollbackRequirements,
    );

    expect(
      failingGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedAuditFailed,
    );
  });

  test('explicit future approval allows only developer-only next phase', () {
    for (final scope in CallV2DeveloperPreWiringScope.values.where(
      (scope) => scope != CallV2DeveloperPreWiringScope.noneSelected,
    )) {
      final approved = gate.evaluateFutureScope(
        selectedScope: scope,
        explicitFutureApproval: true,
        allowedFilesListed: true,
        oneCommitRollbackConfirmed: true,
      );

      expect(
        approved.decision,
        CallV2DeveloperPreWiringGateDecision
            .allowedForExplicitFutureDeveloperOnlyPhase,
        reason: scope.name,
      );
      expect(approved.canWireRoutes, isFalse);
      expect(approved.canStartRuntime, isFalse);
      expect(approved.canRegisterLifecycleObserver, isFalse);
      expect(approved.canWireNavigator, isFalse);
      expect(approved.canAccessBackendFirebase, isFalse);
      expect(approved.canInitializeRtc, isFalse);
      expect(approved.canRequestPermissions, isFalse);
      expect(approved.canModifyPubspecPlatform, isFalse);
      expect(approved.canModifyRulesFunctionsConfig, isFalse);
    }
  });

  test('blocked actions and validation requirements are complete', () {
    expect(
      gate.blockedActions,
      <CallV2DeveloperPreWiringBlockedAction>[
        CallV2DeveloperPreWiringBlockedAction.enableRollout,
        CallV2DeveloperPreWiringBlockedAction.exposePublicUsers,
        CallV2DeveloperPreWiringBlockedAction.deploy,
        CallV2DeveloperPreWiringBlockedAction.contactProductionServices,
        CallV2DeveloperPreWiringBlockedAction.registerRoutes,
        CallV2DeveloperPreWiringBlockedAction.startRuntime,
        CallV2DeveloperPreWiringBlockedAction.registerLifecycleObserver,
        CallV2DeveloperPreWiringBlockedAction.wireNavigator,
        CallV2DeveloperPreWiringBlockedAction.accessBackendFirebase,
        CallV2DeveloperPreWiringBlockedAction.initializeRtc,
        CallV2DeveloperPreWiringBlockedAction.requestPermissions,
        CallV2DeveloperPreWiringBlockedAction.modifyPubspecPlatform,
        CallV2DeveloperPreWiringBlockedAction.modifyRulesFunctionsConfig,
      ],
    );
    expect(gate.hasRequiredValidation, isTrue);
    expect(
      gate.validationRequirements,
      containsAll(CallV2DeveloperPreWiringValidationRequirement.values),
    );
  });

  test('rollback requirements preserve one commit and V1 protection', () {
    expect(gate.hasRequiredRollback, isTrue);
    expect(gate.protectsV1, isTrue);
    expect(
      gate.rollbackRequirements,
      containsAll(<CallV2DeveloperPreWiringRollbackRequirement>[
        CallV2DeveloperPreWiringRollbackRequirement.oneCommitRevert,
        CallV2DeveloperPreWiringRollbackRequirement.keepRolloutFalse,
        CallV2DeveloperPreWiringRollbackRequirement.keepRouteRegistryNull,
        CallV2DeveloperPreWiringRollbackRequirement.keepDisabledOwnerInert,
        CallV2DeveloperPreWiringRollbackRequirement.noDeploymentRequired,
        CallV2DeveloperPreWiringRollbackRequirement.v1Unaffected,
      ]),
    );
  });

  test('safe debug output exposes only counts booleans and enum names', () {
    final debugText = '${gate.toSafeDebugMap()} $gate';

    expect(gate.toSafeDebugMap()['statusCount'], 19);
    expect(gate.toSafeDebugMap()['blockedActionCount'], 13);
    expect(gate.toSafeDebugMap()['validationRequirementCount'], 12);
    expect(gate.toSafeDebugMap()['rollbackRequirementCount'], 8);
    expect(gate.toSafeDebugMap()['decision'], 'blockedNoScopeSelected');

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

  test('rollout registry disabled owner and composition audit stay closed',
      () async {
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
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
    );

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
    expect(compositionConstructed, isFalse);
  });

  test('all six skeletons remain hard-disabled and unreachable', () {
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
  });

  test('real app boundary files do not reference the pre-wiring gate', () {
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
        isNot(contains('call_v2_developer_pre_wiring_safety_gate')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2DeveloperPreWiringSafetyGate')),
        reason: path,
      );
    }
  });

  test('gate source avoids real app startup platform and service hooks', () {
    final source = File(
      'lib/call_v2/integration/'
      'call_v2_developer_pre_wiring_safety_gate.dart',
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
