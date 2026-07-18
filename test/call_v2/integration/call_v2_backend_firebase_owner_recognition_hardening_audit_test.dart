import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_recognition_hardening_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2BackendFirebaseOwnerRecognitionHardeningAudit;

  test('backend Firebase owner recognition hardening audit artifact passes',
      () {
    expect(
      audit,
      isA<CallV2BackendFirebaseOwnerRecognitionHardeningAudit>(),
    );
    expect(
      audit.decision,
      CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsMetadataOnly, isTrue);
    expect(audit.recordsBackendFirebaseOwnerRecognitionPass, isTrue);
    expect(audit.recordsRuntimeStartupRecognitionHardeningPass, isTrue);
    expect(audit.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(audit.recordsBackendFirebaseOwnerHardeningPass, isTrue);
    expect(audit.recordsBackendFirebaseOwnerClosed, isTrue);
    expect(audit.recordsNoFirebaseAccess, isTrue);
    expect(audit.recordsNoFirestoreListeners, isTrue);
    expect(audit.recordsNoFirestoreReads, isTrue);
    expect(audit.recordsNoFirestoreWrites, isTrue);
    expect(audit.recordsNoAuthCalls, isTrue);
    expect(audit.recordsNoFunctionsCalls, isTrue);
    expect(audit.recordsNoAppCheckCalls, isTrue);
    expect(audit.recordsNoRulesFunctionsConfigChanges, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
    expect(audit.recordsProductionCompositionUnconstructed, isTrue);
    expect(audit.recordsStartupBridgeUncalled, isTrue);
    expect(audit.recordsMainDartUnchanged, isTrue);
    expect(audit.recordsAppRouterUnchanged, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
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
      callV2BackendFirebaseOwnerRecognition.decision,
      CallV2BackendFirebaseOwnerRecognitionDecision.pass,
    );
    expect(
      callV2RuntimeStartupOwnerRecognitionHardeningAudit.decision,
      CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2FinalStagedPreRuntimeIntegrationAudit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
    expect(
      callV2BackendFirebaseOwnerHardeningAudit.decision,
      CallV2BackendFirebaseOwnerHardeningAuditDecision.pass,
    );
  });

  test('hardening audit source has no forbidden imports or executable hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_backend_firebase_owner_recognition_hardening_audit.dart',
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
      'startRuntime',
      'runtime.start',
      'constructRuntime',
      'decideWhileDisabled',
      'CallV2BackendFirebaseOwnerBoundary(',
      'callV2BackendFirebaseOwnerBoundary',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('hardening audit source creates no backend Firebase service instances',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_backend_firebase_owner_recognition_hardening_audit.dart',
    );

    for (final forbidden in <String>[
      'Firebase.initializeApp',
      'FirebaseFirestore.instance',
      'FirebaseAuth.instance',
      'FirebaseFunctions.instance',
      'FirebaseAppCheck.instance',
      'CloudFunctions',
      'AuthProvider',
      'FunctionsProvider',
      'AppCheckProvider',
      'BackendService(',
      'FirebaseService(',
      'FirestoreService(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'real app runtime backend owner platform and config files do not reference hardening audit',
      () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
      'lib/call_v2/integration/call_v2_backend_firebase_owner_hardening_audit.dart',
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
    ]) {
      final source = _readIfExists(path);
      expect(
        source,
        isNot(
          contains(
            'call_v2_backend_firebase_owner_recognition_hardening_audit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains(
            'CallV2BackendFirebaseOwnerRecognitionHardeningAudit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains(
            'callV2BackendFirebaseOwnerRecognitionHardeningAudit',
          ),
        ),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 33);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(audit.toSafeDebugMap()['firebaseAccess'], isFalse);
    expect(audit.toSafeDebugMap()['firestoreListenerOpened'], isFalse);
    expect(audit.toSafeDebugMap()['firestoreRead'], isFalse);
    expect(audit.toSafeDebugMap()['firestoreWrite'], isFalse);

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
      'raw',
      'stack',
      'path',
      'collection/',
      '/collection',
      'documentId',
      'docId',
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
