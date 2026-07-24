import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_plan_boundary_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_scaffold.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_scaffold_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2DisabledRuntimeConstructionScaffoldHardeningAudit;

  group('Phase 7BH disabled runtime construction scaffold hardening audit', () {
    test('hardening audit artifact exists and passes', () {
      expect(
        audit,
        isA<CallV2DisabledRuntimeConstructionScaffoldHardeningAudit>(),
      );
      expect(
        audit.decision,
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision.pass,
      );
      expect(audit.passes, isTrue);
      expect(audit.recordsAuditArtifactPresent, isTrue);
    });

    test('scaffold and prerequisite decisions pass without recursion', () {
      expect(
        callV2DisabledRuntimeConstructionScaffold.decision,
        CallV2DisabledRuntimeConstructionScaffoldDecision.pass,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundary.decision,
        CallV2DisabledRuntimeConstructionPlanBoundaryDecision.pass,
      );
      expect(
        callV2DisabledRuntimeConstructionPlanBoundaryHardeningAudit.decision,
        CallV2DisabledRuntimeConstructionPlanBoundaryHardeningAuditDecision
            .pass,
      );
      expect(
        audit.decision,
        CallV2DisabledRuntimeConstructionScaffoldHardeningAuditDecision.pass,
      );
    });

    test('scaffold remains metadata-only and unwired from main', () {
      expect(audit.recordsScaffoldExists, isTrue);
      expect(audit.recordsScaffoldDecisionPass, isTrue);
      expect(audit.recordsMetadataOnly, isTrue);
      expect(audit.recordsScaffoldNotImportedByMain, isTrue);
      expect(audit.recordsScaffoldNotCalledFromMain, isTrue);

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

    test('rollout and construction plan prerequisites remain passing', () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(audit.recordsRolloutFalse, isTrue);
      expect(audit.recordsPlanBoundaryPass, isTrue);
      expect(audit.recordsPlanBoundaryHardeningAuditPass, isTrue);
    });

    test('no-op route and screen exposure remain blocked while rollout false',
        () {
      expect(audit.recordsNoOpWhileRolloutFalse, isTrue);
      expect(audit.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(audit.recordsCallV2ScreenExposureBlocked, isTrue);
      expect(audit.recordsRouteResolverNotCalledWhileRolloutFalse, isTrue);
    });

    test('runtime construction remains unavailable and unstarted', () {
      expect(audit.recordsRuntimeConstructionBlocked, isTrue);
      expect(audit.recordsRuntimeDependencyAllocationBlocked, isTrue);
      expect(audit.recordsRuntimeDependencyPreparationBlocked, isTrue);
      expect(audit.recordsRuntimeCompositionBlocked, isTrue);
      expect(audit.recordsRuntimeUnavailable, isTrue);
      expect(audit.recordsRuntimeCreationBlocked, isTrue);
      expect(audit.recordsRuntimeStartBlocked, isTrue);
      expect(audit.recordsProductionStartupBridgeBlocked, isTrue);
      expect(audit.recordsStartupBridgeCallBlocked, isTrue);
    });

    test('backend Firestore Auth Functions and App Check remain blocked', () {
      expect(audit.recordsBackendWritesBlocked, isTrue);
      expect(audit.recordsBackendReadsBlocked, isTrue);
      expect(audit.recordsFirestoreListenersBlocked, isTrue);
      expect(audit.recordsAuthFunctionsAppCheckBlocked, isTrue);
    });

    test('RTC permissions media navigator lifecycle and async remain blocked',
        () {
      expect(audit.recordsRtcInitializationBlocked, isTrue);
      expect(audit.recordsRtcEngineCreationBlocked, isTrue);
      expect(audit.recordsRtcChannelJoinBlocked, isTrue);
      expect(audit.recordsRtcAccessConsumptionBlocked, isTrue);
      expect(audit.recordsPermissionRequestsBlocked, isTrue);
      expect(audit.recordsCapturePromptBlocked, isTrue);
      expect(audit.recordsMediaDeviceAccessBlocked, isTrue);
      expect(audit.recordsNavigatorWiringBlocked, isTrue);
      expect(audit.recordsNavigatorCallsBlocked, isTrue);
      expect(audit.recordsLifecycleRegistrationBlocked, isTrue);
      expect(audit.recordsAsyncHandlesBlocked, isTrue);
    });

    test('deployment config rollback and V1 protection remain closed', () {
      expect(audit.recordsDeploymentBlocked, isTrue);
      expect(audit.recordsConfigPlatformChangesBlocked, isTrue);
      expect(audit.recordsRollbackOneCommit, isTrue);
      expect(audit.recordsV1Protected, isTrue);
    });

    test('safe debug output contains no sensitive identifiers', () {
      final debugText = '${audit.toSafeDebugMap()} $audit';

      expect(audit.toSafeDebugMap()['statusCount'], 41);
      expect(audit.toSafeDebugMap()['rollbackCount'], 14);

      for (final forbidden in _sensitiveDebugStrings) {
        expect(debugText, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 7BH source and app isolation', () {
    test('new audit source imports only allowed inert dependencies', () {
      final source = _auditSource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_disabled_runtime_construction_plan_boundary.dart',
        'call_v2_disabled_runtime_construction_plan_boundary_hardening_audit.dart',
        'call_v2_disabled_runtime_construction_scaffold.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new audit source has no forbidden imports hooks or executable calls',
        () {
      final source = _auditSource();

      for (final forbidden in _forbiddenAuditSourceStrings) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('main.dart does not reference scaffold hardening audit', () {
      final main = _read('lib/main.dart');

      expect(main, isNot(contains(_auditSnake)));
      expect(main, isNot(contains(_auditType)));
      expect(main, isNot(contains(_auditValue)));
    });

    test('app router does not reference scaffold hardening audit', () {
      final source = _read('lib/navigation/app_router.dart');

      expect(source, isNot(contains(_auditSnake)));
      expect(source, isNot(contains(_auditType)));
      expect(source, isNot(contains(_auditValue)));
    });

    test('startup runtime backend RTC permissions and production ignore audit',
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
        expect(source, isNot(contains(_auditSnake)), reason: path);
        expect(source, isNot(contains(_auditType)), reason: path);
        expect(source, isNot(contains(_auditValue)), reason: path);
      }
    });

    test('pubspec platform config rules and functions ignore audit', () {
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
        expect(source, isNot(contains(_auditSnake)), reason: path);
        expect(source, isNot(contains(_auditType)), reason: path);
        expect(source, isNot(contains(_auditValue)), reason: path);
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

const _auditSnake =
    'call_v2_disabled_runtime_construction_scaffold_hardening_audit';
const _auditType = 'CallV2DisabledRuntimeConstructionScaffoldHardeningAudit';
const _auditValue = 'callV2DisabledRuntimeConstructionScaffoldHardeningAudit';
const _auditPath =
    'lib/call_v2/integration/call_v2_disabled_runtime_construction_scaffold_hardening_audit.dart';

const _allowedChangedFiles = <String>[
  'lib/call_v2/integration/call_v2_disabled_runtime_construction_scaffold_hardening_audit.dart',
  'test/call_v2/integration/call_v2_disabled_runtime_construction_scaffold_hardening_audit_test.dart',
];

String _auditSource() {
  return _read(_auditPath);
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

const _forbiddenAuditSourceStrings = <String>[
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
