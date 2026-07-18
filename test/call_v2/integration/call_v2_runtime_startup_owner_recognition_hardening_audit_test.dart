import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_recognition.dart';
import 'package:connect_app/call_v2/integration/call_v2_runtime_startup_owner_recognition_hardening_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2RuntimeStartupOwnerRecognitionHardeningAudit;

  test('runtime startup owner recognition hardening audit artifact passes', () {
    expect(
      audit,
      isA<CallV2RuntimeStartupOwnerRecognitionHardeningAudit>(),
    );
    expect(
      audit.decision,
      CallV2RuntimeStartupOwnerRecognitionHardeningAuditDecision.pass,
    );
    expect(audit.passes, isTrue);
    expect(audit.recordsHumanApprovedPhase7AJ, isTrue);
    expect(audit.recordsDeveloperOnly, isTrue);
    expect(audit.recordsRolloutFalse, isTrue);
    expect(audit.recordsMetadataOnly, isTrue);
    expect(audit.recordsRuntimeStartupOwnerRecognitionPass, isTrue);
    expect(audit.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(audit.recordsRuntimeStartupOwnerHardeningPass, isTrue);
    expect(audit.recordsRuntimeStartupOwnerClosed, isTrue);
    expect(audit.recordsRuntimeUnconstructed, isTrue);
    expect(audit.recordsRuntimeNotStarted, isTrue);
    expect(audit.recordsNoRuntimeStartupCall, isTrue);
    expect(audit.recordsProductionCompositionUnconstructed, isTrue);
    expect(audit.recordsStartupBridgeUncalled, isTrue);
    expect(audit.recordsMainDartUnchanged, isTrue);
    expect(audit.recordsAppRouterUnchanged, isTrue);
    expect(audit.recordsRoutesUnreachable, isTrue);
    expect(audit.recordsRouteResolverNullWhileFalse, isTrue);
    expect(audit.recordsDisabledRegistryNull, isTrue);
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
    expect(audit.recordsNoDeployment, isTrue);
    expect(audit.recordsRollbackOneCommit, isTrue);
    expect(audit.recordsV1Protected, isTrue);
  });

  test('accepted recognition and prior audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2RuntimeStartupOwnerRecognition.decision,
      CallV2RuntimeStartupOwnerRecognitionDecision.pass,
    );
    expect(
      callV2FinalStagedPreRuntimeIntegrationAudit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
    expect(
      callV2RuntimeStartupOwnerHardeningAudit.decision,
      CallV2RuntimeStartupOwnerHardeningAuditDecision.pass,
    );
  });

  test('hardening audit source has no forbidden imports or executable hooks',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_runtime_startup_owner_recognition_hardening_audit.dart',
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

  test('runtime start and construction calls remain absent from audit source',
      () {
    final source = _read(
      'lib/call_v2/integration/'
      'call_v2_runtime_startup_owner_recognition_hardening_audit.dart',
    );

    for (final forbidden in <String>[
      'startRuntime(',
      '.start(',
      'runtime.start',
      'constructRuntime(',
      'ProductionCallV2Runtime(',
      'CallV2Runtime(',
      'CallV2ProductionComposition(',
      'callV2ProductionComposition(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'real app runtime platform backend and config files do not reference audit',
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
        isNot(
          contains(
            'call_v2_runtime_startup_owner_recognition_hardening_audit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains(
            'CallV2RuntimeStartupOwnerRecognitionHardeningAudit',
          ),
        ),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains(
            'callV2RuntimeStartupOwnerRecognitionHardeningAudit',
          ),
        ),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive data', () {
    final debugText = '${audit.toSafeDebugMap()} $audit';

    expect(audit.toSafeDebugMap()['statusCount'], 31);
    expect(audit.toSafeDebugMap()['rollbackCount'], 7);
    expect(audit.toSafeDebugMap()['approvalRecorded'], isTrue);

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
