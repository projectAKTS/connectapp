import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_final_owner_recognition_consolidation_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_final_staged_pre_runtime_integration_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_real_wiring_boundary.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundary = callV2FirstRealWiringBoundary;

  test('first real wiring boundary artifact passes while disabled', () {
    expect(boundary, isA<CallV2FirstRealWiringBoundary>());
    expect(boundary.decision, CallV2FirstRealWiringBoundaryDecision.pass);
    expect(boundary.passes, isTrue);
    expect(boundary.recordsHumanApproval, isTrue);
    expect(boundary.recordsDeveloperOnly, isTrue);
    expect(boundary.recordsRolloutFalse, isTrue);
    expect(boundary.recordsProductionExposureBlocked, isTrue);
    expect(boundary.recordsPublicRouteReachabilityBlocked, isTrue);
    expect(boundary.recordsFinalOwnerRecognitionConsolidationPass, isTrue);
    expect(boundary.recordsFinalStagedPreRuntimeAuditPass, isTrue);
    expect(boundary.recordsMetadataToWiringBoundaryOnly, isTrue);
    expect(boundary.recordsRuntimeConstructionBlocked, isTrue);
    expect(boundary.recordsRuntimeStartBlocked, isTrue);
    expect(boundary.recordsStartupBridgeCallBlocked, isTrue);
    expect(boundary.recordsBackendWritesBlocked, isTrue);
    expect(boundary.recordsBackendReadsBlocked, isTrue);
    expect(boundary.recordsFirestoreListenersBlocked, isTrue);
    expect(boundary.recordsAuthFunctionsAppCheckBlocked, isTrue);
    expect(boundary.recordsRtcInitializationBlocked, isTrue);
    expect(boundary.recordsRtcEngineCreationBlocked, isTrue);
    expect(boundary.recordsRtcChannelJoinBlocked, isTrue);
    expect(boundary.recordsRtcTokenChannelConsumptionBlocked, isTrue);
    expect(boundary.recordsPermissionRequestsBlocked, isTrue);
    expect(boundary.recordsCapturePromptBlocked, isTrue);
    expect(boundary.recordsMediaDeviceAccessBlocked, isTrue);
    expect(boundary.recordsNavigatorWiringBlocked, isTrue);
    expect(boundary.recordsNavigatorKeyCreationBlocked, isTrue);
    expect(boundary.recordsGlobalKeyCreationBlocked, isTrue);
    expect(boundary.recordsBuildContextStorageBlocked, isTrue);
    expect(boundary.recordsMaterialAppRouteWiringBlocked, isTrue);
    expect(boundary.recordsNavigatorCallsBlocked, isTrue);
    expect(boundary.recordsLifecycleRegistrationBlocked, isTrue);
    expect(boundary.recordsAppLifecycleListenerBlocked, isTrue);
    expect(boundary.recordsWidgetsBindingObserverBlocked, isTrue);
    expect(boundary.recordsAsyncHandlesBlocked, isTrue);
    expect(boundary.recordsRouteResolverNullWhileFalse, isTrue);
    expect(boundary.recordsDisabledRegistryNull, isTrue);
    expect(boundary.recordsDeploymentBlocked, isTrue);
    expect(boundary.recordsConfigPlatformChangesBlocked, isTrue);
    expect(boundary.recordsRollbackOneCommit, isTrue);
    expect(boundary.recordsV1Protected, isTrue);
  });

  test('rollout and accepted prerequisite audits remain closed', () {
    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(
      callV2FinalOwnerRecognitionConsolidationAudit.decision,
      CallV2FinalOwnerRecognitionConsolidationAuditDecision.pass,
    );
    expect(
      callV2FinalStagedPreRuntimeIntegrationAudit.decision,
      CallV2FinalStagedPreRuntimeIntegrationAuditDecision.pass,
    );
  });

  test('source has no forbidden imports or executable hooks', () {
    final source = _read(
      'lib/call_v2/integration/call_v2_first_real_wiring_boundary.dart',
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
      'resolveCallV2Route(',
      'DisabledCallV2RouteRegistry(',
      'CallV2Runtime(',
      'CallV2ProductionComposition(',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
      'source creates no backend RTC permission navigator lifecycle runtime calls',
      () {
    final source = _read(
      'lib/call_v2/integration/call_v2_first_real_wiring_boundary.dart',
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

  test('real app implementation and config files do not reference boundary',
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
      ..._dartFilesUnder('lib/call_v2/production'),
      'lib/call_v2/integration/call_v2_runtime_startup_owner.dart',
      'lib/call_v2/integration/call_v2_backend_firebase_owner.dart',
      'lib/call_v2/integration/call_v2_rtc_permission_owner.dart',
      'lib/call_v2/integration/call_v2_navigator_owner.dart',
      'lib/call_v2/integration/call_v2_lifecycle_observer.dart',
    ]) {
      final source = _readIfExists(path);
      expect(
        source,
        isNot(contains('call_v2_first_real_wiring_boundary')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('CallV2FirstRealWiringBoundary')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('callV2FirstRealWiringBoundary')),
        reason: path,
      );
    }
  });

  test('safe debug output contains no sensitive identifiers', () {
    final debugText = '${boundary.toSafeDebugMap()} $boundary';

    expect(boundary.toSafeDebugMap()['statusCount'], 38);
    expect(boundary.toSafeDebugMap()['rollbackCount'], 9);

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
  if (!file.existsSync()) {
    return '';
  }
  return file.readAsStringSync();
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
