import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recognition = callV2RtcPermissionOwnerRecognition;

  test('RTC permission owner recognition artifact passes', () {
    expect(recognition, isA<CallV2RtcPermissionOwnerRecognition>());
    expect(
      recognition.decision,
      CallV2RtcPermissionOwnerRecognitionDecision.pass,
    );
    expect(recognition.passes, isTrue);
    expect(recognition.recordsDeveloperOnly, isTrue);
    expect(recognition.recordsRolloutFalse, isTrue);
    expect(recognition.recordsMetadataOnly, isTrue);
    expect(recognition.recordsBackendFirebaseRecognitionHardeningPass, isTrue);
    expect(recognition.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(recognition.recordsRtcPermissionOwnerHardeningPass, isTrue);
    expect(recognition.recordsRtcPermissionOwnerClosed, isTrue);
    expect(recognition.recordsNoRtcInitialized, isTrue);
    expect(recognition.recordsNoRtcEngineCreated, isTrue);
    expect(recognition.recordsNoRtcChannelJoined, isTrue);
    expect(recognition.recordsNoRtcTokenChannelConsumed, isTrue);
    expect(recognition.recordsNoPermissionsRequested, isTrue);
    expect(recognition.recordsNoMicrophoneCameraPrompt, isTrue);
    expect(recognition.recordsNoDeviceEnumeration, isTrue);
    expect(recognition.recordsNoMediaCapture, isTrue);
    expect(recognition.recordsNoCameraPreview, isTrue);
    expect(recognition.recordsNoAudioVideoPublish, isTrue);
    expect(recognition.recordsNoRtcCallbacksListenersSubscriptions, isTrue);
    expect(recognition.recordsNoBackendFirebaseAccess, isTrue);
    expect(recognition.recordsRuntimeUnconstructed, isTrue);
    expect(recognition.recordsRuntimeNotStarted, isTrue);
    expect(recognition.recordsProductionCompositionUnconstructed, isTrue);
    expect(recognition.recordsStartupBridgeUncalled, isTrue);
    expect(recognition.recordsMainDartUnchanged, isTrue);
    expect(recognition.recordsAppRouterUnchanged, isTrue);
    expect(recognition.recordsRoutesUnreachable, isTrue);
    expect(recognition.recordsRouteResolverNullWhileFalse, isTrue);
    expect(recognition.recordsDisabledRegistryNull, isTrue);
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
      callV2BackendFirebaseOwnerRecognitionHardeningAudit.decision,
      CallV2BackendFirebaseOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(
      callV2FinalStagedPreRuntimeIntegrationAudit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
    expect(
      callV2RtcPermissionOwnerHardeningAudit.decision,
      CallV2RtcPermissionOwnerHardeningAuditDecision.pass,
    );
  });

  test('recognition source has no forbidden imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_rtc_permission_owner_recognition.dart',
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
      'leaveChannel',
      'publish',
      'startPreview',
      'stopPreview',
      'requestPermissions',
      'Permission.',
      'availableCameras',
      'CameraController',
      'enumerateDevices',
      'getUserMedia',
      'MediaStream',
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
      'CallV2RtcPermissionOwnerBoundary(',
      'callV2RtcPermissionOwnerBoundary',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('recognition source creates no backend RTC or permission services', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_rtc_permission_owner_recognition.dart',
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
      'RtcService(',
      'PermissionService(',
      'MediaService(',
      'DeviceService(',
      'CameraService(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'real app runtime RTC owner platform and config files do not reference recognition',
      () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
      'lib/call_v2/integration/call_v2_rtc_permission_owner_hardening_audit.dart',
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
        isNot(contains('call_v2_rtc_permission_owner_recognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RtcPermissionOwnerRecognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2RtcPermissionOwnerRecognition')),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${recognition.toSafeDebugMap()} $recognition';

    expect(recognition.toSafeDebugMap()['statusCount'], 35);
    expect(recognition.toSafeDebugMap()['rtcInitialized'], isFalse);
    expect(recognition.toSafeDebugMap()['rtcEngineCreated'], isFalse);
    expect(recognition.toSafeDebugMap()['rtcJoined'], isFalse);
    expect(recognition.toSafeDebugMap()['rtcInputConsumed'], isFalse);
    expect(recognition.toSafeDebugMap()['mediaPublished'], isFalse);

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
      'mediaStreamId',
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
