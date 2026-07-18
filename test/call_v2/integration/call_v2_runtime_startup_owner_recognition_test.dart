import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recognition = callV2RuntimeStartupOwnerRecognition;

  test('runtime startup owner recognition artifact passes', () {
    expect(recognition, isA<CallV2RuntimeStartupOwnerRecognition>());
    expect(
      recognition.decision,
      CallV2RuntimeStartupOwnerRecognitionDecision.pass,
    );
    expect(recognition.passes, isTrue);
    expect(recognition.recordsHumanApprovedPhase7AJ, isTrue);
    expect(recognition.recordsDeveloperOnly, isTrue);
    expect(recognition.recordsRolloutFalse, isTrue);
    expect(recognition.recordsMetadataOnly, isTrue);
    expect(recognition.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(recognition.recordsRuntimeStartupOwnerHardeningPass, isTrue);
    expect(recognition.recordsRuntimeStartupOwnerClosed, isTrue);
    expect(recognition.recordsRuntimeUnconstructed, isTrue);
    expect(recognition.recordsRuntimeNotStarted, isTrue);
    expect(recognition.recordsNoRuntimeStartupCall, isTrue);
    expect(recognition.recordsProductionCompositionUnconstructed, isTrue);
    expect(recognition.recordsStartupBridgeUncalled, isTrue);
    expect(recognition.recordsMainDartUnchanged, isTrue);
    expect(recognition.recordsAppRouterUnchanged, isTrue);
    expect(recognition.recordsRoutesUnreachable, isTrue);
    expect(recognition.recordsRouteResolverNullWhileFalse, isTrue);
    expect(recognition.recordsDisabledRegistryNull, isTrue);
    expect(recognition.recordsNoBackendFirebaseAccess, isTrue);
    expect(recognition.recordsNoRtcPermissionMediaDeviceAccess, isTrue);
    expect(recognition.recordsNoNavigatorWiring, isTrue);
    expect(recognition.recordsNoLifecycleRegistration, isTrue);
    expect(recognition.recordsNoAsyncHandles, isTrue);
    expect(recognition.recordsNoDependencyPlatformConfigChanges, isTrue);
    expect(recognition.recordsNoDeployment, isTrue);
    expect(recognition.recordsRollbackOneCommit, isTrue);
    expect(recognition.recordsV1Protected, isTrue);
  });

  test('rollout final staged audit and startup owner hardening remain closed',
      () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2FinalStagedPreRuntimeIntegrationAudit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
    expect(
      callV2RuntimeStartupOwnerHardeningAudit.decision,
      CallV2RuntimeStartupOwnerHardeningAuditDecision.pass,
    );
    expect(
      callV2RuntimeStartupOwnerHardeningAudit.recordsHardDisabled,
      isTrue,
    );
    expect(
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRuntimeConstruction,
      isTrue,
    );
    expect(
      callV2RuntimeStartupOwnerHardeningAudit.recordsNoRuntimeStart,
      isTrue,
    );
  });

  test('recognition source has no forbidden imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_runtime_startup_owner_recognition.dart',
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
      'FirebaseFirestore',
      'FirebaseFunctions',
      'FirebaseAuth',
      'FirebaseAppCheck',
      '.collection(',
      '.doc(',
      '.get(',
      '.set(',
      '.update(',
      '.delete(',
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
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real app and runtime files do not reference recognition artifact', () {
    for (final path in <String>[
      'lib/main.dart',
      'lib/navigation/app_router.dart',
      'lib/call_v2/startup/production_call_v2_startup_bridge.dart',
      'lib/call_v2/production/call_v2_production_composition.dart',
      'pubspec.yaml',
      'pubspec.lock',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
      'linux/CMakeLists.txt',
      'web/index.html',
      'windows/CMakeLists.txt',
      'firebase.json',
      'firestore.rules',
      'connect_functions/index.js',
      ..._dartFilesUnder('lib/call_v2/runtime'),
    ]) {
      final source = _read(path);
      expect(
        source,
        isNot(contains('call_v2_runtime_startup_owner_recognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2RuntimeStartupOwnerRecognition')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2RuntimeStartupOwnerRecognition')),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${recognition.toSafeDebugMap()} $recognition';

    expect(recognition.toSafeDebugMap()['statusCount'], 26);
    expect(recognition.toSafeDebugMap()['approvalRecorded'], isTrue);

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
      'stack',
      'raw',
    ]) {
      expect(debugText, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

String _read(String path) => File(path).readAsStringSync();

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
