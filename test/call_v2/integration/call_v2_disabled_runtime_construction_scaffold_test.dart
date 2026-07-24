import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_scaffold.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scaffold = callV2DisabledRuntimeConstructionScaffold;

  group('Phase 7BG disabled runtime construction scaffold', () {
    test('scaffold artifact exists and decision passes', () {
      expect(
        scaffold,
        isA<CallV2DisabledRuntimeConstructionScaffold>(),
      );
      expect(
        scaffold.decision,
        CallV2DisabledRuntimeConstructionScaffoldDecision.pass,
      );
      expect(scaffold.passes, isTrue);
      expect(scaffold.recordsScaffoldArtifactPresent, isTrue);
    });

    test('scaffold is metadata-only and not wired from main', () {
      expect(scaffold.recordsMetadataOnly, isTrue);
      expect(scaffold.recordsNotCalledFromMain, isTrue);

      final main = _read('lib/main.dart');
      expect(
        main,
        isNot(
          contains('call_v2_disabled_runtime_construction_scaffold.dart'),
        ),
      );
      expect(
        main,
        isNot(contains('callV2DisabledRuntimeConstructionScaffold')),
      );
      expect(
        main,
        isNot(contains('CallV2DisabledRuntimeConstructionScaffold')),
      );
    });

    test('rollout and accepted Phase 7BE/7BF prerequisites remain passing', () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(scaffold.recordsRolloutFalse, isTrue);
      expect(scaffold.recordsPlanBoundaryPass, isTrue);
      expect(scaffold.recordsPlanBoundaryHardeningAuditPass, isTrue);
      expect(
        callV2DisabledRuntimeConstructionPlanBoundary.recordsHumanApproval,
        isTrue,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundary.recordsDeveloperOnly,
        isTrue,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundary.recordsRolloutFalse,
        isTrue,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundary
            .recordsRuntimeConstructionPlanBoundaryPresent,
        isTrue,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit
            .recordsAuditArtifactPresent,
        isTrue,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit
            .recordsPlanBoundaryExists,
        isTrue,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit
            .recordsRolloutFalse,
        isTrue,
      );
    });

    test('no-op route and screen exposure remain blocked while rollout false',
        () {
      expect(scaffold.recordsNoOpWhileRolloutFalse, isTrue);
      expect(scaffold.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(scaffold.recordsCallV2ScreenExposureBlocked, isTrue);
      expect(scaffold.recordsRouteResolverNotCalledWhileRolloutFalse, isTrue);
    });

    test('runtime construction scaffold remains unavailable and unstarted', () {
      expect(scaffold.recordsRuntimeConstructionBlocked, isTrue);
      expect(scaffold.recordsRuntimeDependencyAllocationBlocked, isTrue);
      expect(scaffold.recordsRuntimeDependencyPreparationBlocked, isTrue);
      expect(scaffold.recordsRuntimeCompositionBlocked, isTrue);
      expect(scaffold.recordsRuntimeUnavailable, isTrue);
      expect(scaffold.recordsRuntimeCreationBlocked, isTrue);
      expect(scaffold.recordsRuntimeStartBlocked, isTrue);
      expect(scaffold.recordsProductionStartupBridgeBlocked, isTrue);
      expect(scaffold.recordsStartupBridgeCallBlocked, isTrue);
    });

    test('backend Firestore Auth Functions and App Check remain blocked', () {
      expect(scaffold.recordsBackendWritesBlocked, isTrue);
      expect(scaffold.recordsBackendReadsBlocked, isTrue);
      expect(scaffold.recordsFirestoreListenersBlocked, isTrue);
      expect(scaffold.recordsAuthFunctionsAppCheckBlocked, isTrue);
    });

    test('RTC permissions media navigator lifecycle and async remain blocked',
        () {
      expect(scaffold.recordsRtcInitializationBlocked, isTrue);
      expect(scaffold.recordsRtcEngineCreationBlocked, isTrue);
      expect(scaffold.recordsRtcChannelJoinBlocked, isTrue);
      expect(scaffold.recordsRtcAccessConsumptionBlocked, isTrue);
      expect(scaffold.recordsPermissionRequestsBlocked, isTrue);
      expect(scaffold.recordsCapturePromptBlocked, isTrue);
      expect(scaffold.recordsMediaDeviceAccessBlocked, isTrue);
      expect(scaffold.recordsNavigatorWiringBlocked, isTrue);
      expect(scaffold.recordsNavigatorCallsBlocked, isTrue);
      expect(scaffold.recordsLifecycleRegistrationBlocked, isTrue);
      expect(scaffold.recordsAsyncHandlesBlocked, isTrue);
    });

    test('deployment config rollback and V1 protection remain closed', () {
      expect(scaffold.recordsDeploymentBlocked, isTrue);
      expect(scaffold.recordsConfigPlatformChangesBlocked, isTrue);
      expect(scaffold.recordsRollbackOneCommit, isTrue);
      expect(scaffold.recordsV1Protected, isTrue);
    });

    test('safe debug output contains no sensitive identifiers', () {
      final debugText = '${scaffold.toSafeDebugMap()} $scaffold';

      expect(scaffold.toSafeDebugMap()['statusCount'], 40);
      expect(scaffold.toSafeDebugMap()['rollbackCount'], 15);

      for (final forbidden in _sensitiveDebugStrings) {
        expect(debugText, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 7BG source and app isolation', () {
    test('new source imports only allowed inert dependencies', () {
      final source = _scaffoldSource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_disabled_runtime_construction_plan_boundary.dart',
        'call_v2_disabled_runtime_construction_plan_boundary_hardening_audit.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new source has no forbidden imports hooks or executable calls', () {
      final source = _scaffoldSource();

      for (final forbidden in _forbiddenScaffoldSourceStrings) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('main.dart remains unchanged from previous phase for scaffold', () {
      final main = _read('lib/main.dart');

      expect(
        main,
        isNot(
          contains('call_v2_disabled_runtime_construction_scaffold.dart'),
        ),
      );
      expect(
        main,
        isNot(contains('callV2DisabledRuntimeConstructionScaffold')),
      );
      expect(
        main,
        isNot(contains('CallV2DisabledRuntimeConstructionScaffold')),
      );
      expect(
        main,
        contains('executeCallV2DisabledRuntimeConstructionPlanBoundarySafely'),
      );
    });

    test('app router does not reference scaffold', () {
      final source = _read('lib/navigation/app_router.dart');

      expect(source, isNot(contains(_scaffoldSnake)));
      expect(source, isNot(contains(_scaffoldType)));
      expect(source, isNot(contains(_scaffoldValue)));
    });

    test(
        'startup runtime backend RTC permissions and production ignore scaffold',
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
        expect(source, isNot(contains(_scaffoldSnake)), reason: path);
        expect(source, isNot(contains(_scaffoldType)), reason: path);
        expect(source, isNot(contains(_scaffoldValue)), reason: path);
      }
    });

    test('pubspec platform config rules and functions ignore scaffold', () {
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
        expect(source, isNot(contains(_scaffoldSnake)), reason: path);
        expect(source, isNot(contains(_scaffoldType)), reason: path);
        expect(source, isNot(contains(_scaffoldValue)), reason: path);
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

const _scaffoldSnake = 'call_v2_disabled_runtime_construction_scaffold';
const _scaffoldType = 'CallV2DisabledRuntimeConstructionScaffold';
const _scaffoldValue = 'callV2DisabledRuntimeConstructionScaffold';
const _scaffoldPath =
    'lib/call_v2/integration/call_v2_disabled_runtime_construction_scaffold.dart';

const _allowedChangedFiles = <String>[
  'lib/call_v2/integration/call_v2_disabled_runtime_preflight_boundary.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_preflight_boundary_test.dart',
  'lib/call_v2/integration/call_v2_disabled_runtime_preflight_boundary_hardening_audit.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_preflight_boundary_hardening_audit_test.dart',
  'lib/call_v2/integration/call_v2_disabled_runtime_construction_gate.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_construction_gate_test.dart',
  'lib/call_v2/integration/call_v2_disabled_runtime_construction_gate_hardening_audit.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_construction_gate_hardening_audit_test.dart',
  'lib/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary_test.dart',
  'lib/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary_hardening_audit.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary_hardening_audit_test.dart',
  'lib/call_v2/integration/call_v2_disabled_runtime_construction_scaffold.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_construction_scaffold_test.dart',
];

String _scaffoldSource() {
  return _read(_scaffoldPath);
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

const _forbiddenScaffoldSourceStrings = <String>[
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
