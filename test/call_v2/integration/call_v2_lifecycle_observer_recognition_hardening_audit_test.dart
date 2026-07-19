import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_lifecycle_observer_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_navigator_owner_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2LifecycleObserverRecognitionHardeningAudit;

  test('lifecycle observer recognition hardening audit artifact passes', () {
    expect(
      audit,
      isA<CallV2LifecycleObserverRecognitionHardeningAudit>(),
    );
    expect(
      audit.decision,
      CallV2LifecycleObserverRecognitionHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsMetadataOnly, isTrue);
    expect(audit.recordsLifecycleObserverRecognitionPass, isTrue);
    expect(audit.recordsNavigatorRecognitionHardeningPass, isTrue);
    expect(audit.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(audit.recordsLifecycleObserverHardeningPass, isTrue);
    expect(audit.recordsLifecycleObserverClosed, isTrue);
    expect(audit.recordsNoLifecycleRegistration, isTrue);
    expect(audit.recordsNoAppLifecycleListener, isTrue);
    expect(audit.recordsNoWidgetsBindingObserver, isTrue);
    expect(audit.recordsNoLifecycleCallbacksSubscriptions, isTrue);
    expect(audit.recordsNoAsyncHandles, isTrue);
    expect(audit.recordsNoNavigatorWiring, isTrue);
    expect(audit.recordsNoNavigatorKey, isTrue);
    expect(audit.recordsNoGlobalKey, isTrue);
    expect(audit.recordsNoBuildContextStored, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
    expect(audit.recordsProductionCompositionUnconstructed, isTrue);
    expect(audit.recordsStartupBridgeUncalled, isTrue);
    expect(audit.recordsNoBackendFirebaseAccess, isTrue);
    expect(audit.recordsNoRtcPermissionMediaDeviceAccess, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
    expect(audit.recordsNoDependencyPlatformConfigChanges, isTrue);
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.recordsRollbackOneCommit, isTrue);
    expect(audit.recordsV1Protected, isTrue);
  });

  test('rollout recognition and upstream audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2LifecycleObserverRecognition.decision,
      CallV2LifecycleObserverRecognitionDecision.pass,
    );
    expect(
      callV2NavigatorOwnerRecognitionHardeningAudit.decision,
      CallV2NavigatorOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2FinalStagedPreRuntimeIntegrationAudit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
    expect(
      callV2LifecycleObserverHardeningAudit.decision,
      CallV2LifecycleObserverHardeningAuditDecision.pass,
    );
  });

  test('hardening audit source has no forbidden imports or executable hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_lifecycle_observer_recognition_hardening_audit.dart',
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
      'CallV2LifecycleObserverBoundary(',
      'callV2LifecycleObserverBoundary',
      'resolveCallV2Route(',
      'DisabledCallV2RouteRegistry(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'hardening audit source creates no lifecycle navigator backend or RTC hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_lifecycle_observer_recognition_hardening_audit.dart',
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
      'real app runtime lifecycle platform and config files do not reference hardening audit',
      () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
      'lib/call_v2/integration/call_v2_lifecycle_observer_hardening_audit.dart',
      'lib/call_v2/integration/call_v2_lifecycle_observer_recognition.dart',
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
      ..._dartFilesUnder('lib/call_v2/runtime'),
      ..._dartFilesUnder('lib/call_v2/rtc'),
      ..._dartFilesUnder('lib/call_v2/permissions'),
    ]) {
      final source = _readIfExists(path);
      expect(
        source,
        isNot(
          contains(
            'call_v2_lifecycle_observer_recognition_hardening_audit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains('CallV2LifecycleObserverRecognitionHardeningAudit'),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains('callV2LifecycleObserverRecognitionHardeningAudit'),
        ),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 30);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(audit.toSafeDebugMap()['observerRegistered'], isFalse);
    expect(audit.toSafeDebugMap()['appLifecycleHookCreated'], isFalse);
    expect(audit.toSafeDebugMap()['bindingObserverAttached'], isFalse);
    expect(audit.toSafeDebugMap()['callbacksSubscribed'], isFalse);
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
