import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_planner_interface.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_scaffold.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_scaffold_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final planner = callV2DisabledRuntimeConstructionPlannerInterface;

  group('Phase 7BI disabled runtime construction planner interface', () {
    test('planner interface artifact exists and passes', () {
      expect(
        planner,
        isA<CallV2DisabledRuntimeConstructionPlannerInterface>(),
      );
      expect(
        planner.decision,
        CallV2DisabledRuntimeConstructionPlannerInterfaceDecision.pass,
      );
      expect(planner.passes, isTrue);
      expect(planner.recordsPlannerInterfaceArtifactPresent, isTrue);
    });

    test('decision reads return quickly and do not recurse', () {
      final stopwatch = Stopwatch()..start();

      expect(
        planner.decision,
        CallV2DisabledRuntimeConstructionPlannerInterfaceDecision.pass,
      );
      expect(
        callV2DisabledRuntimeConstructionScaffold.decision,
        CallV2DisabledRuntimeConstructionScaffoldDecision.pass,
      );
      expect(
        callV2DisabledRuntimeConstructionScaffoldHardeningAudit.decision,
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision.pass,
      );

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('metadata only and unwired from main', () {
      expect(planner.recordsMetadataOnly, isTrue);
      expect(planner.recordsNotImportedByMain, isTrue);
      expect(planner.recordsNotCalledFromMain, isTrue);

      final main = _read('lib/main.dart');
      expect(main, isNot(contains(_plannerSnake)));
      expect(main, isNot(contains(_plannerType)));
      expect(main, isNot(contains(_plannerValue)));
    });

    test('rollout and scaffold prerequisites remain passing', () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(planner.recordsRolloutFalse, isTrue);
      expect(planner.recordsScaffoldDecisionPass, isTrue);
      expect(planner.recordsScaffoldHardeningAuditDecisionPass, isTrue);
      expect(
        callV2DisabledRuntimeConstructionScaffold.decision,
        CallV2DisabledRuntimeConstructionScaffoldDecision.pass,
      );
      expect(
        callV2DisabledRuntimeConstructionScaffoldHardeningAudit.decision,
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision.pass,
      );
    });

    test('no-op route and screen exposure remain blocked while rollout false',
        () {
      expect(planner.recordsNoOpWhileRolloutFalse, isTrue);
      expect(planner.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(planner.recordsCallV2ScreenExposureBlocked, isTrue);
      expect(planner.recordsRouteResolverNotCalledWhileRolloutFalse, isTrue);
    });

    test('runtime construction planning cannot allocate create or start', () {
      expect(planner.recordsRuntimeConstructionBlocked, isTrue);
      expect(planner.recordsRuntimeDependencyAllocationBlocked, isTrue);
      expect(planner.recordsRuntimeDependencyPreparationBlocked, isTrue);
      expect(planner.recordsRuntimeCompositionBlocked, isTrue);
      expect(planner.recordsRuntimeUnavailable, isTrue);
      expect(planner.recordsRuntimeCreationBlocked, isTrue);
      expect(planner.recordsRuntimeStartBlocked, isTrue);
      expect(planner.recordsProductionStartupBridgeBlocked, isTrue);
      expect(planner.recordsStartupBridgeCallBlocked, isTrue);
    });

    test('backend Firestore Auth Functions and App Check remain blocked', () {
      expect(planner.recordsBackendWritesBlocked, isTrue);
      expect(planner.recordsBackendReadsBlocked, isTrue);
      expect(planner.recordsFirestoreListenersBlocked, isTrue);
      expect(planner.recordsAuthFunctionsAppCheckBlocked, isTrue);
    });

    test('RTC permissions media navigator lifecycle and async remain blocked',
        () {
      expect(planner.recordsRtcInitializationBlocked, isTrue);
      expect(planner.recordsRtcEngineCreationBlocked, isTrue);
      expect(planner.recordsRtcChannelJoinBlocked, isTrue);
      expect(planner.recordsRtcAccessConsumptionBlocked, isTrue);
      expect(planner.recordsPermissionRequestsBlocked, isTrue);
      expect(planner.recordsCapturePromptBlocked, isTrue);
      expect(planner.recordsMediaDeviceAccessBlocked, isTrue);
      expect(planner.recordsNavigatorWiringBlocked, isTrue);
      expect(planner.recordsNavigatorCallsBlocked, isTrue);
      expect(planner.recordsLifecycleRegistrationBlocked, isTrue);
      expect(planner.recordsAsyncHandlesBlocked, isTrue);
    });

    test('deployment config rollback and V1 protection remain closed', () {
      expect(planner.recordsDeploymentBlocked, isTrue);
      expect(planner.recordsConfigPlatformChangesBlocked, isTrue);
      expect(planner.recordsRollbackOneCommit, isTrue);
      expect(planner.recordsV1Protected, isTrue);
    });

    test('safe debug output contains no sensitive identifiers', () {
      final debugMap = planner.toSafeDebugMap();
      final debugText = '$debugMap $planner';

      expect(debugMap['statusCount'], 41);
      expect(debugMap['rollbackCount'], 14);
      expect(debugMap['decision'], 'pass');

      for (final forbidden in _sensitiveDebugStrings) {
        expect(debugText, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 7BI source and app isolation', () {
    test('new source imports only allowed inert dependencies', () {
      final source = _plannerSource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_disabled_runtime_construction_scaffold.dart',
        'call_v2_disabled_runtime_construction_scaffold_hardening_audit.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new source has no forbidden imports hooks or executable calls', () {
      final source = _plannerSource();

      for (final forbidden in _forbiddenPlannerSourceStrings) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('main.dart does not reference planner interface', () {
      final main = _read('lib/main.dart');

      expect(main, isNot(contains(_plannerSnake)));
      expect(main, isNot(contains(_plannerType)));
      expect(main, isNot(contains(_plannerValue)));
    });

    test('app router does not reference planner interface', () {
      final source = _read('lib/navigation/app_router.dart');

      expect(source, isNot(contains(_plannerSnake)));
      expect(source, isNot(contains(_plannerType)));
      expect(source, isNot(contains(_plannerValue)));
    });

    test(
        'startup runtime backend RTC permissions and production ignore planner',
        () {
      for (final path in <String>[
        ..._dartFilesUnder('lib/call_v2/startup'),
        ..._dartFilesUnder('lib/call_v2/runtime'),
        ..._dartFilesUnder('lib/call_v2/firebase'),
        ..._dartFilesUnder('lib/call_v2/rtc'),
        ..._dartFilesUnder('lib/call_v2/permissions'),
        ..._dartFilesUnder('lib/call_v2/production'),
      ]) {
        final source = _readIfExists(path);
        expect(source, isNot(contains(_plannerSnake)), reason: path);
        expect(source, isNot(contains(_plannerType)), reason: path);
        expect(source, isNot(contains(_plannerValue)), reason: path);
      }
    });

    test('pubspec platform config rules and functions ignore planner', () {
      for (final path in <String>[
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
      ]) {
        final source = _readIfExists(path);
        expect(source, isNot(contains(_plannerSnake)), reason: path);
        expect(source, isNot(contains(_plannerType)), reason: path);
        expect(source, isNot(contains(_plannerValue)), reason: path);
      }
    });

    test('only allowed files are changed in the working tree', () {
      final result = Process.runSync('git', <String>[
        'status',
        '--short',
        '--untracked-files=all',
      ]);

      expect(result.exitCode, 0);
      final changed = (result.stdout as String)
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.substring(3))
          .where((path) => path != 'pubspec.lock')
          .toList();

      for (final path in changed) {
        expect(path, isIn(_allowedChangedFiles), reason: path);
      }
    });
  });
}

const _plannerSnake = 'call_v2_disabled_runtime_construction_planner_interface';
const _plannerType = 'CallV2DisabledRuntimeConstructionPlannerInterface';
const _plannerValue = 'callV2DisabledRuntimeConstructionPlannerInterface';
const _plannerPath =
    'lib/call_v2/integration/call_v2_disabled_runtime_construction_planner_interface.dart';

const _allowedChangedFiles = <String>[
  'lib/call_v2/integration/call_v2_disabled_runtime_construction_planner_interface.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_construction_planner_interface_test.dart',
];

String _plannerSource() {
  return _read(_plannerPath);
}

String _read(String path) {
  return File(path).readAsStringSync();
}

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
      .map((file) => file.path)
      .where((path) => path.endsWith('.dart'))
      .toList();
}

const _forbiddenPlannerSourceStrings = <String>[
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
  'createRuntime',
  'runtimeInstance',
  'allocateRuntime',
  'prepareRuntime',
  'composeRuntime',
  'CallV2Runtime(',
  'CallV2ProductionComposition(',
  'resolveCallV2Route(',
  'DisabledCallV2RouteRegistry(',
];

const _sensitiveDebugStrings = <String>[
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
];
