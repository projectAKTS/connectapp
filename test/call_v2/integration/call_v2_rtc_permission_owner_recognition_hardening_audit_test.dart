import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_backend_firebase_owner_recognition_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_rtc_permission_owner_recognition_hardening_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2RtcPermissionOwnerRecognitionHardeningAudit;

  test('RTC permission owner recognition hardening audit artifact passes', () {
    expect(
      audit,
      isA<CallV2RtcPermissionOwnerRecognitionHardeningAudit>(),
    );
    expect(
      audit.decision,
      CallV2RtcPermissionOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsMetadataOnly, isTrue);
    expect(audit.recordsRtcPermissionOwnerRecognitionPass, isTrue);
    expect(audit.recordsBackendFirebaseRecognitionHardeningPass, isTrue);
    expect(audit.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(audit.recordsRtcPermissionOwnerHardeningPass, isTrue);
    expect(audit.recordsRtcPermissionOwnerClosed, isTrue);
    expect(audit.recordsNoRtcInitialized, isTrue);
    expect(audit.recordsNoRtcEngineCreated, isTrue);
    expect(audit.recordsNoRtcChannelJoined, isTrue);
    expect(audit.recordsNoRtcTokenChannelConsumed, isTrue);
    expect(audit.recordsNoPermissionsRequested, isTrue);
    expect(audit.recordsNoMicrophoneCameraPrompt, isTrue);
    expect(audit.recordsNoDeviceEnumeration, isTrue);
    expect(audit.recordsNoMediaCapture, isTrue);
    expect(audit.recordsNoCameraPreview, isTrue);
    expect(audit.recordsNoAudioVideoPublish, isTrue);
    expect(audit.recordsNoRtcCallbacksListenersSubscriptions, isTrue);
    expect(audit.recordsNoBackendFirebaseAccess, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
    expect(audit.recordsProductionCompositionUnconstructed, isTrue);
    expect(audit.recordsStartupBridgeUncalled, isTrue);
    expect(audit.recordsMainDartUnchanged, isTrue);
    expect(audit.recordsAppRouterUnchanged, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
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
      callV2RtcPermissionOwnerRecognition.decision,
      CallV2RtcPermissionOwnerRecognitionDecision.pass,
    );
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

  test('hardening audit source has no forbidden imports or executable hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_rtc_permission_owner_recognition_hardening_audit.dart',
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

  test('hardening audit source creates no backend RTC or permission services',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_rtc_permission_owner_recognition_hardening_audit.dart',
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
      'real app runtime RTC owner platform and config files do not reference hardening audit',
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
        isNot(
          contains(
            'call_v2_rtc_permission_owner_recognition_hardening_audit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains(
            'CallV2RtcPermissionOwnerRecognitionHardeningAudit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains(
            'callV2RtcPermissionOwnerRecognitionHardeningAudit',
          ),
        ),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 36);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(audit.toSafeDebugMap()['rtcInitialized'], isFalse);
    expect(audit.toSafeDebugMap()['rtcEngineCreated'], isFalse);
    expect(audit.toSafeDebugMap()['rtcJoined'], isFalse);
    expect(audit.toSafeDebugMap()['rtcInputConsumed'], isFalse);
    expect(audit.toSafeDebugMap()['mediaPublished'], isFalse);

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
