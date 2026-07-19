import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_owner_recognition_consolidation_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_recognition_hardening_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2FinalOwnerRecognitionConsolidationAudit;

  test('final owner-recognition consolidation audit artifact passes', () {
    expect(
      audit,
      isA<CallV2FinalOwnerRecognitionConsolidationAudit>(),
    );
    expect(
      audit.decision,
      CallV2FinalOwnerRecognitionConsolidationAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsMetadataOnly, isTrue);
    expect(audit.recordsRuntimeStartupRecognitionHardeningPass, isTrue);
    expect(audit.recordsBackendFirebaseRecognitionHardeningPass, isTrue);
    expect(audit.recordsRtcPermissionRecognitionHardeningPass, isTrue);
    expect(audit.recordsNavigatorRecognitionHardeningPass, isTrue);
    expect(audit.recordsLifecycleObserverRecognitionHardeningPass, isTrue);
    expect(audit.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(audit.recordsOwnersClosedInert, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
    expect(audit.recordsStartupBridgeUncalled, isTrue);
    expect(audit.recordsNoBackendFirebaseAccess, isTrue);
    expect(audit.recordsNoFirestoreListeners, isTrue);
    expect(audit.recordsNoFirestoreReads, isTrue);
    expect(audit.recordsNoFirestoreWrites, isTrue);
    expect(audit.recordsNoAuthFunctionsAppCheck, isTrue);
    expect(audit.recordsNoRtcInitialized, isTrue);
    expect(audit.recordsNoRtcEngineCreated, isTrue);
    expect(audit.recordsNoRtcChannelJoined, isTrue);
    expect(audit.recordsNoRtcTokenChannelConsumed, isTrue);
    expect(audit.recordsNoPermissionsRequested, isTrue);
    expect(audit.recordsNoMediaDeviceAccess, isTrue);
    expect(audit.recordsNoNavigatorWiring, isTrue);
    expect(audit.recordsNoNavigatorKey, isTrue);
    expect(audit.recordsNoGlobalKey, isTrue);
    expect(audit.recordsNoBuildContextStored, isTrue);
    expect(audit.recordsNoMaterialAppRouteWiring, isTrue);
    expect(audit.recordsNoNavigatorCalls, isTrue);
    expect(audit.recordsNoLifecycleRegistration, isTrue);
    expect(audit.recordsNoAppLifecycleListener, isTrue);
    expect(audit.recordsNoWidgetsBindingObserver, isTrue);
    expect(audit.recordsNoLifecycleCallbacksSubscriptions, isTrue);
    expect(audit.recordsNoAsyncHandles, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
    expect(audit.recordsNoDependencyPlatformConfigChanges, isTrue);
    expect(audit.recordsNoRulesFunctionsConfigChanges, isTrue);
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.recordsRollbackOneCommit, isTrue);
    expect(audit.recordsV1Protected, isTrue);
  });

  test('rollout and all owner recognition hardening audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.decision,
      CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.decision,
      CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2RtcPermissionOwnerRecognitionHardeningAudit.decision,
      CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2NavigatorOwnerRecognitionHardeningAudit.decision,
      CallV2NavigatorOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2LifecycleObserverRecognitionHardeningAudit.decision,
      CallV2LifecycleObserverRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2FinalStagedPreRuntimeIntegrationAudit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
  });

  test('consolidation audit source has no forbidden imports or hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_final_owner_recognition_consolidation_audit.dart',
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
      'camera',
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
      '.collection(',
      '.doc(',
      '.snapshots(',
      '.get(',
      '.set(',
      '.update(',
      '.delete(',
      '.httpsCallable(',
      'addSnapshotListener',
      'onSnapshot',
      'runTransaction',
      'writeBatch',
      'signIn',
      'signOut',
      'createAgoraRtcEngine',
      'RtcEngine(',
      'joinChannel',
      'requestPermissions',
      'Permission.',
      'availableCameras',
      'CameraController',
      'Navigator.',
      'Navigator(',
      'GlobalKey(',
      'BuildContext context',
      'BuildContext? context',
      'MaterialApp(',
      'CupertinoPageRoute',
      'RouteSettings(',
      'Timer(',
      'StreamController',
      'StreamSubscription',
      '.listen(',
      'AppLifecycleListener(',
      'WidgetsBinding.instance',
      '.addObserver(',
      '.removeObserver(',
      'didChangeAppLifecycleState',
      'ProductionCallV2StartupBridge',
      'startCallV2Production',
      'startRuntime',
      'runtime.start',
      'constructRuntime',
      'decideWhileDisabled',
      'resolveCallV2Route(',
      'DisabledCallV2RouteRegistry(',
      'CallV2Runtime(',
      'CallV2ProductionComposition(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'consolidation audit source creates no runtime backend RTC navigator or lifecycle calls',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_final_owner_recognition_consolidation_audit.dart',
    );

    for (final forbidden in <String>[
      'Firebase.initializeApp',
      'FirebaseFirestore.instance',
      'FirebaseAuth.instance',
      'FirebaseFunctions.instance',
      'FirebaseAppCheck.instance',
      'BackendService(',
      'FirebaseService(',
      'RtcService(',
      'PermissionService(',
      'MediaService(',
      'DeviceService(',
      'NavigatorService(',
      'NavigationService(',
      'LifecycleService(',
      'WidgetsBindingObserver with',
      'implements WidgetsBindingObserver',
      'CallV2Runtime(',
      'CallV2ProductionComposition(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'real app owner runtime platform and config files do not reference consolidation audit',
      () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'pubspec.yaml',
      'pubspec.lock',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
      'macos/Runner/Info.plist',
      'linux/CMakeLists.txt',
      'web/index.html',
      'windows/CMakeLists.txt',
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
      ..._dartFilesUnder('lib/call_v2/startup'),
      ..._dartFilesUnder('lib/call_v2/runtime'),
      ..._dartFilesUnder('lib/call_v2/firebase'),
      ..._dartFilesUnder('lib/call_v2/rtc'),
      ..._dartFilesUnder('lib/call_v2/permissions'),
      'lib/call_v2/integration/call_v2_runtime_startup_owner.dart',
      'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
      'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
      'lib/call_v2/integration/call_v2_navigator_owner.dart',
      'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
    ]) {
      final source = _readIfExists(path);
      expect(
        source,
        isNot(
          contains(
            'call_v2_final_owner_recognition_consolidation_audit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2FinalOwnerRecognitionConsolidationAudit')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2FinalOwnerRecognitionConsolidationAudit')),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 43);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(audit.toSafeDebugMap()['runtimeConstructed'], isFalse);
    expect(audit.toSafeDebugMap()['runtimeStarted'], isFalse);
    expect(audit.toSafeDebugMap()['backendAccess'], isFalse);
    expect(audit.toSafeDebugMap()['rtcInitialized'], isFalse);
    expect(audit.toSafeDebugMap()['permissionsRequested'], isFalse);
    expect(audit.toSafeDebugMap()['navWired'], isFalse);
    expect(audit.toSafeDebugMap()['observerRegistered'], isFalse);
    expect(audit.toSafeDebugMap()['asyncHandlesOpened'], isFalse);

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
      'navigatorKey',
      'contextId',
      'resumed',
      'inactive',
      'paused',
      'hidden',
      'detached',
      'collection',
      'document',
      'routeStack',
      'payload',
      'raw',
      'stack',
    ]) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

String _readIfExists(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : '';
}

List<String> _dartFilesUnder(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    return <String>[];
  }
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path)
      .toList(growable: false);
}
