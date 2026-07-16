import 'dart:io';

import 'package:connect_app/call_v2/design/call_v2_production_first_wiring_approval_checkpoint.dart';
import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_backend_firebase_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_lifecycle_observer_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_navigator_owner_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_pre_wiring_safety_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_route_registration_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_rtc_permission_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_runtime_startup_approval_scope.dart';
import 'package:connect_app/call_v2/integration/call_v2_developer_skeleton_composition_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_pre_wiring_consolidation_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry.dart';
import 'package:connect_app/call_v2/integration/call_v2_route_registry_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/disabled_call_v2_route_registry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2FinalPreWiringConsolidationAudit;

  test('consolidation audit artifact passes all global closed-state checks',
      () {
    expect(
      audit,
      isA<CallV2FinalPreWiringConsolidationAudit>(),
    );
    expect(audit.decision, CallV2FinalPreWiringConsolidationAuditDecision.pass);
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
    expect(audit.recordsDisabledOwnerInert, isTrue);
    expect(audit.recordsProductionCompositionUnconstructed, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.rollbackPreserved, isTrue);
    expect(audit.protectsV1, isTrue);
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(isCallV2DeveloperRouteRegistrationEnabled, isFalse);
    expect(
      const DisabledCallV2RouteRegistry()
          .resolve(const RouteSettings(name: '/call-v2/audio')),
      isNull,
    );
  });

  test('all developer-only boundaries and hardening audits remain closed', () {
    expect(audit.backendFirebaseOwnerClosed, isTrue);
    expect(audit.backendFirebaseHardeningPasses, isTrue);
    expect(
      callV2BackendFirebaseOwnerHardeningAudit.decision,
      CallV2BackendFirebaseOwnerHardeningAuditDecision.pass,
    );

    expect(audit.rtcPermissionOwnerClosed, isTrue);
    expect(audit.rtcPermissionHardeningPasses, isTrue);
    expect(
      callV2RtcPermissionOwnerHardeningAudit.decision,
      CallV2RtcPermissionOwnerHardeningAuditDecision.pass,
    );

    expect(audit.runtimeStartupOwnerClosed, isTrue);
    expect(audit.runtimeStartupHardeningPasses, isTrue);
    expect(
      callV2RuntimeStartupOwnerHardeningAudit.decision,
      CallV2RuntimeStartupOwnerHardeningAuditDecision.pass,
    );

    expect(audit.navigatorOwnerClosed, isTrue);
    expect(audit.navigatorHardeningPasses, isTrue);
    expect(
      callV2NavigatorOwnerHardeningAudit.decision,
      CallV2NavigatorOwnerHardeningAuditDecision.pass,
    );

    expect(audit.lifecycleObserverClosed, isTrue);
    expect(audit.lifecycleHardeningPasses, isTrue);
    expect(
      callV2LifecycleObserverHardeningAudit.decision,
      CallV2LifecycleObserverHardeningAuditDecision.pass,
    );

    expect(audit.routeRegistryHardeningPasses, isTrue);
    expect(
      callV2RouteRegistryHardeningAudit.decision,
      CallV2RouteRegistryHardeningAuditDecision.pass,
    );
  });

  test('approval scopes gate and skeleton composition remain closed', () {
    expect(audit.backendFirebaseApprovalClosed, isTrue);
    expect(
        callV2DeveloperBackendFirebaseApprovalScope.isStrictlyClosed, isTrue);

    expect(audit.rtcPermissionApprovalClosed, isTrue);
    expect(callV2DeveloperRtcPermissionApprovalScope.isStrictlyClosed, isTrue);

    expect(audit.runtimeStartupApprovalClosed, isTrue);
    expect(callV2DeveloperRuntimeStartupApprovalScope.isDeveloperOnly, isTrue);
    expect(
        callV2DeveloperRuntimeStartupApprovalScope.isRolloutEnabled, isFalse);
    expect(callV2DeveloperRuntimeStartupApprovalScope.startsRuntime, isFalse);

    expect(audit.navigatorApprovalClosed, isTrue);
    expect(callV2DeveloperNavigationOwnerApprovalScope.isDeveloperOnly, isTrue);
    expect(
      callV2DeveloperNavigationOwnerApprovalScope.wiresRealNavigation,
      isFalse,
    );

    expect(audit.lifecycleApprovalClosed, isTrue);
    expect(
      callV2DeveloperLifecycleObserverApprovalScope
          .registersFrameworkLifecycleHook,
      isFalse,
    );
    expect(
      callV2DeveloperLifecycleObserverApprovalScope
          .registersBindingLifecycleHook,
      isFalse,
    );

    expect(audit.routeRegistrationApprovalClosed, isTrue);
    expect(
      callV2DeveloperRouteRegistrationApprovalScope.resolverStillNullWhileFalse,
      isTrue,
    );
    expect(callV2DeveloperRouteRegistrationApprovalScope.createsRouteObject,
        isFalse);

    expect(audit.preWiringSafetyGateBlocked, isTrue);
    expect(
      callV2DeveloperPreWiringSafetyGate.decision,
      CallV2DeveloperPreWiringGateDecision.blockedNoScopeSelected,
    );
    expect(audit.skeletonCompositionPasses, isTrue);
    expect(
      callV2DeveloperSkeletonCompositionAudit.decision,
      CallV2DeveloperSkeletonCompositionDecision.pass,
    );
  });

  test('real app backend RTC navigator lifecycle and async isolation hold', () {
    expect(audit.recordsNoMainDartWiring, isTrue);
    expect(audit.recordsNoAppRouterWiring, isTrue);
    expect(audit.recordsNoStartupBridgeWiring, isTrue);
    expect(audit.recordsNoProductionCompositionWiring, isTrue);
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
  });

  test('first wiring checkpoint remains unchanged and closed', () {
    final checkpoint = callV2ProductionFirstWiringApprovalCheckpoint;

    expect(
      checkpoint.protectedBackupBranch,
      'backup/call-v2-pre-phase6b-2026-07-04',
    );
    expect(
      checkpoint.protectedBackupSha,
      '2a1ea8d6864ab0098d17c52bdf5ec70f66979e4d',
    );
    expect(checkpoint.isPhase6DesignWallAccepted, isTrue);
    expect(checkpoint.isRolloutEnabled, isFalse);
    expect(checkpoint.isCallV2Reachable, isFalse);
    expect(checkpoint.isRouteRegistryEnabled, isFalse);
    expect(checkpoint.isDisabledOwnerActive, isFalse);
    expect(checkpoint.isRuntimeStarted, isFalse);
    expect(checkpoint.hasBackendFirebaseConnection, isFalse);
    expect(checkpoint.hasRtcPermissionConnection, isFalse);
    expect(checkpoint.hasAppRouterConnection, isFalse);
    expect(checkpoint.hasMainStartupConnection, isFalse);
    expect(checkpoint.isDeploymentAuthorized, isFalse);
    expect(checkpoint.isBackupProtected, isTrue);
    expect(checkpoint.isFirstRealWiringApproved, isFalse);
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit'.toLowerCase();

    expect(audit.toSafeDebugMap()['statusCount'], 45);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(debugText, isNot(contains('/call-v2')));
    expect(debugText, isNot(contains('uid')));
    expect(debugText, isNot(contains('userid')));
    expect(debugText, isNot(contains('token')));
    expect(debugText, isNot(contains('credential')));
    expect(debugText, isNot(contains('channel')));
    expect(debugText, isNot(contains('devicelabel')));
    expect(debugText, isNot(contains('deviceid')));
    expect(debugText, isNot(contains('payload')));
    expect(debugText, isNot(contains('raw')));
    expect(debugText, isNot(contains('stack')));
  });

  test('audit source has no forbidden imports hooks or executable access', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_final_pre_wiring_consolidation_audit.dart',
    );

    for (final forbidden in <String>[
      "package:flutter",
      "cloud_firestore",
      "firebase_auth",
      "cloud_functions",
      "firebase_app_check",
      "agora",
      "permission_handler",
      "../startup/",
      "../runtime/",
      "../firebase/",
      "../rtc/",
      "../permissions/",
      "../production/",
      "dart:async",
      "dart:io",
      "Timer(",
      "StreamController",
      "StreamSubscription",
      ".listen(",
      "FirebaseFirestore",
      ".collection(",
      ".doc(",
      ".get(",
      ".set(",
      ".update(",
      ".delete(",
      "FirebaseAuth.",
      "FirebaseAuth(",
      "FirebaseFunctions.",
      "FirebaseFunctions(",
      "FirebaseAppCheck.",
      "FirebaseAppCheck(",
      "createAgoraRtcEngine",
      "joinChannel",
      "requestPermissions",
      "availableCameras",
      "Navigator.",
      "GlobalKey(",
      "BuildContext?",
      "BuildContext)",
      "MaterialApp(",
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app platform backend and config files do not reference audit', () {
    const forbidden = 'call_v2_final_pre_wiring_consolidation_audit';
    const files = <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'pubspec.yaml',
      'pubspec.lock',
      'connect_functions/index.js',
      'firestore.rules',
      'firebase.json',
    ];

    for (final path in files) {
      expect(_read(path), isNot(contains(forbidden)), reason: path);
    }

    for (final directory in <String>[
      'android',
      'ios',
      'macos',
      'windows',
      'linux',
      'web',
      '.github',
      'connect_functions',
    ]) {
      for (final file in _filesUnder(directory)) {
        if (!_isTextFile(file.path)) continue;
        expect(
          file.readAsStringSync(),
          isNot(contains(forbidden)),
          reason: file.path,
        );
      }
    }
  });
}

String _read(String path) {
  return File(path).readAsStringSync();
}

Iterable<File> _filesUnder(String path) {
  final root = Directory(path);
  if (!root.existsSync()) return const Iterable<File>.empty();
  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => !file.path.contains('/Pods/'))
      .where((file) => !file.path.contains('/node_modules/'))
      .where((file) => !file.path.contains('/.dart_tool/'))
      .where((file) => !file.path.contains('/build/'));
}

bool _isTextFile(String path) {
  return path.endsWith('.dart') ||
      path.endsWith('.js') ||
      path.endsWith('.json') ||
      path.endsWith('.yaml') ||
      path.endsWith('.yml') ||
      path.endsWith('.xml') ||
      path.endsWith('.gradle') ||
      path.endsWith('.plist') ||
      path.endsWith('.rules') ||
      path.endsWith('.md') ||
      path.endsWith('.html') ||
      path.endsWith('.css') ||
      path.endsWith('.properties') ||
      path.endsWith('.xcconfig') ||
      path.endsWith('.pbxproj') ||
      path.endsWith('Podfile') ||
      path.endsWith('Podfile.lock') ||
      path.endsWith('pubspec.lock') ||
      path.endsWith('pubspec.yaml');
}
