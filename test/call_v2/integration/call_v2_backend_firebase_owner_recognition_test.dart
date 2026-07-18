import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_recognition_hardening_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recognition = callV2BackendFirebaseOwnerRecognition;

  test('backend Firebase owner recognition artifact passes', () {
    expect(recognition, isA<CallV2BackendFirebaseOwnerRecognition>());
    expect(
      recognition.decision,
      CallV2BackendFirebaseOwnerRecognitionDecision.pass,
    );
    expect(recognition.passes, isTrue);
    expect(recognition.recordsDeveloperOnly, isTrue);
    expect(recognition.recordsRolloutFalse, isTrue);
    expect(recognition.recordsMetadataOnly, isTrue);
    expect(recognition.recordsRuntimeStartupRecognitionHardeningPass, isTrue);
    expect(recognition.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(recognition.recordsBackendFirebaseOwnerHardeningPass, isTrue);
    expect(recognition.recordsBackendFirebaseOwnerClosed, isTrue);
    expect(recognition.recordsNoFirebaseAccess, isTrue);
    expect(recognition.recordsNoFirestoreListeners, isTrue);
    expect(recognition.recordsNoFirestoreReads, isTrue);
    expect(recognition.recordsNoFirestoreWrites, isTrue);
    expect(recognition.recordsNoAuthCalls, isTrue);
    expect(recognition.recordsNoFunctionsCalls, isTrue);
    expect(recognition.recordsNoAppCheckCalls, isTrue);
    expect(recognition.recordsNoRulesFunctionsConfigChanges, isTrue);
    expect(recognition.recordsRuntimeUnconstructed, isTrue);
    expect(recognition.recordsRuntimeNotStarted, isTrue);
    expect(recognition.recordsProductionCompositionUnconstructed, isTrue);
    expect(recognition.recordsStartupBridgeUncalled, isTrue);
    expect(recognition.recordsMainDartUnchanged, isTrue);
    expect(recognition.recordsAppRouterUnchanged, isTrue);
    expect(recognition.recordsRoutesUnreachable, isTrue);
    expect(recognition.recordsRouteResolverNullWhileFalse, isTrue);
    expect(recognition.recordsDisabledRegistryNull, isTrue);
    expect(recognition.recordsNoRtcPermissionMediaDeviceAccess, isTrue);
    expect(recognition.recordsNoNavigatorWiring, isTrue);
    expect(recognition.recordsNoLifecycleRegistration, isTrue);
    expect(recognition.recordsNoAsyncHandles, isTrue);
    expect(recognition.recordsNoDependencyPlatformConfigChanges, isTrue);
    expect(recognition.recordsNoDeployment, isTrue);
    expect(recognition.recordsRollbackOneCommit, isTrue);
    expect(recognition.recordsV1Protected, isTrue);
  });

  test('rollout and upstream audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
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

  test('recognition source has no forbidden imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_backend_firebase_owner_recognition.dart',
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

  test('recognition source creates no backend Firebase service instances', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_backend_firebase_owner_recognition.dart',
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
      'real app runtime backend owner platform and config files do not reference recognition',
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
        isNot(contains('call_v2_backend_firebase_owner_recognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2BackendFirebaseOwnerRecognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2BackendFirebaseOwnerRecognition')),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${recognition.toSafeDebugMap()} $recognition';

    expect(recognition.toSafeDebugMap()['statusCount'], 32);
    expect(recognition.toSafeDebugMap()['firebaseAccess'], isFalse);
    expect(recognition.toSafeDebugMap()['firestoreListenerOpened'], isFalse);
    expect(recognition.toSafeDebugMap()['firestoreRead'], isFalse);
    expect(recognition.toSafeDebugMap()['firestoreWrite'], isFalse);

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
