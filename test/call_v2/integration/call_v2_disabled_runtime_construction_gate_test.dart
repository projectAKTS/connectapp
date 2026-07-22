import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_preflight_boundary.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_preflight_boundary_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final gate = callV2DisabledRuntimeConstructionGate;

  group('Phase 7BC disabled runtime construction gate', () {
    test('gate artifact exists and safe executor returns inert metadata', () {
      final executed = executeCallV2DisabledRuntimeConstructionGateSafely();

      expect(gate, isA<CallV2DisabledRuntimeConstructionGate>());
      expect(identical(executed, gate), isTrue);
      expect(gate.statuses, isNotEmpty);
      expect(gate.rollback, isNotEmpty);
    });

    test('decision passes with approval developer-only and rollout false', () {
      expect(
        gate.decision,
        CallV2DisabledRuntimeConstructionGateDecision.pass,
      );
      expect(gate.passes, isTrue);
      expect(gate.recordsHumanApproval, isTrue);
      expect(gate.recordsDeveloperOnly, isTrue);
      expect(gate.recordsRolloutFalse, isTrue);
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    });

    test('construction gate is present and no-op while rollout is false', () {
      expect(gate.recordsRuntimeConstructionGatePresent, isTrue);
      expect(gate.recordsNoOpWhileRolloutFalse, isTrue);
      expect(gate.recordsRouteResolverNotCalledWhileRolloutFalse, isTrue);
    });

    test('Phase 7BA and Phase 7BB prerequisites remain passing', () {
      expect(gate.recordsRuntimePreflightBoundaryPass, isTrue);
      expect(gate.recordsRuntimePreflightHardeningAuditPass, isTrue);
      expect(
        callV2DisabledRuntimePreflightBoundary.decision,
        CallV2DisabledRuntimePreflightBoundaryDecision.pass,
      );
      expect(
        callV2DisabledRuntimePreflightBoundaryHardeningAudit.decision,
        CallV2DisabledRuntimePreflightBoundaryHardeningAuditDecision.pass,
      );
    });

    test('production routes screens runtime and startup remain blocked', () {
      expect(gate.recordsProductionExposureBlocked, isTrue);
      expect(gate.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(gate.recordsCallV2ScreenExposureBlocked, isTrue);
      expect(gate.recordsRuntimeConstructionBlocked, isTrue);
      expect(gate.recordsRuntimeStartBlocked, isTrue);
      expect(gate.recordsRuntimeInstanceUnavailable, isTrue);
      expect(gate.recordsRuntimeInstanceCreationBlocked, isTrue);
      expect(gate.recordsProductionStartupBridgeBlocked, isTrue);
      expect(gate.recordsStartupBridgeCallBlocked, isTrue);
    });

    test('backend Firestore Auth Functions and App Check remain blocked', () {
      expect(gate.recordsBackendWritesBlocked, isTrue);
      expect(gate.recordsBackendReadsBlocked, isTrue);
      expect(gate.recordsFirestoreListenersBlocked, isTrue);
      expect(gate.recordsAuthFunctionsAppCheckBlocked, isTrue);
    });

    test('RTC permissions media navigator lifecycle and async remain blocked',
        () {
      expect(gate.recordsRtcInitializationBlocked, isTrue);
      expect(gate.recordsRtcEngineCreationBlocked, isTrue);
      expect(gate.recordsRtcChannelJoinBlocked, isTrue);
      expect(gate.recordsRtcTokenChannelConsumptionBlocked, isTrue);
      expect(gate.recordsPermissionRequestsBlocked, isTrue);
      expect(gate.recordsCapturePromptBlocked, isTrue);
      expect(gate.recordsMediaDeviceAccessBlocked, isTrue);
      expect(gate.recordsNavigatorWiringBlocked, isTrue);
      expect(gate.recordsNavigatorCallsBlocked, isTrue);
      expect(gate.recordsLifecycleRegistrationBlocked, isTrue);
      expect(gate.recordsAsyncHandlesBlocked, isTrue);
    });

    test('deployment config rollback and V1 protection remain closed', () {
      expect(gate.recordsDeploymentBlocked, isTrue);
      expect(gate.recordsConfigPlatformChangesBlocked, isTrue);
      expect(gate.recordsRollbackOneCommit, isTrue);
      expect(gate.recordsV1Protected, isTrue);
    });

    test('safe debug output contains no sensitive identifiers', () {
      final debugText = '${gate.toSafeDebugMap()} $gate';

      expect(gate.toSafeDebugMap()['statusCount'], 36);
      expect(gate.toSafeDebugMap()['rollbackCount'], 11);

      for (final forbidden in _sensitiveDebugStrings) {
        expect(debugText, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 7BC source and app wiring isolation', () {
    test('new source imports only allowed inert dependencies', () {
      final source = _gateSource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_disabled_runtime_preflight_boundary.dart',
        'call_v2_disabled_runtime_preflight_boundary_hardening_audit.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new source has no forbidden imports hooks or executable calls', () {
      final source = _gateSource();

      for (final forbidden in _forbiddenGateSourceStrings) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('main.dart imports and executes construction gate once in order', () {
      final main = _read('lib/main.dart');
      const shell = 'initializeCallV2AppIntegrationShellSafely';
      const touchpoint = 'initializeCallV2FirstActualAppWiringTouchpointSafely';
      const startup = 'executeCallV2DisabledStartupBoundarySafely';
      const preflight = 'executeCallV2DisabledRuntimePreflightBoundarySafely';
      const construction = 'executeCallV2DisabledRuntimeConstructionGateSafely';
      const constructionImport =
          "import 'call_v2/integration/call_v2_disabled_runtime_construction_gate.dart';";

      expect(_count(main, constructionImport), 1);
      expect(_count(main, '$construction();'), 1);
      expect(
        main.indexOf('$shell());'),
        lessThan(main.indexOf('$touchpoint();')),
      );
      expect(
        main.indexOf('$touchpoint();'),
        lessThan(main.indexOf('$startup();')),
      );
      expect(
        main.indexOf('$startup();'),
        lessThan(main.indexOf('$preflight();')),
      );
      expect(
        main.indexOf('$preflight();'),
        lessThan(main.indexOf('$construction();')),
      );
      expect(
        main.indexOf('$construction();'),
        lessThan(main.indexOf('runApp(const MyApp());')),
      );
    });

    test('main.dart keeps route resolver behind rollout and exposes no V2 UI',
        () {
      final main = _read('lib/main.dart');
      final onGenerateRoute = _onGenerateRouteSource(main);
      final rolloutCheck =
          onGenerateRoute.indexOf('CallV2RolloutPolicy.productionEnabled');
      final resolverCall = onGenerateRoute.indexOf('resolveCallV2Route');

      expect(rolloutCheck, greaterThanOrEqualTo(0));
      expect(resolverCall, greaterThan(rolloutCheck));
      expect(
        onGenerateRoute,
        contains(
          'final callV2Route = CallV2RolloutPolicy.productionEnabled\n'
          '            ? resolveCallV2Route(settings)\n'
          '            : null;',
        ),
      );

      for (final forbidden in <String>[
        "'/call-v2/connecting'",
        "'/call-v2/audio'",
        "'/call-v2/video'",
        "'/call-v2/failure'",
        "'/call-v2/ready'",
        'CallV2Screen',
        'IncomingCallV2',
        'ActiveCallV2',
      ]) {
        expect(main, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('main.dart touched area has no live startup side effects', () {
      final main = _read('lib/main.dart');
      final startupArea = _mainStartupBoundaryArea(main);

      for (final forbidden in _forbiddenMainStartupAreaStrings) {
        expect(startupArea, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('implementation and config files do not reference the gate', () {
      const snake = 'call_v2_disabled_runtime_construction_gate';
      const typeName = 'CallV2DisabledRuntimeConstructionGate';

      for (final path in <String>[
        'lib/navigation/app_router.dart',
        ..._dartFilesUnder('lib/call_v2/startup'),
        ..._dartFilesUnder('lib/call_v2/runtime'),
        ..._dartFilesUnder('lib/call_v2/firebase'),
        ..._dartFilesUnder('lib/call_v2/rtc'),
        ..._dartFilesUnder('lib/call_v2/permissions'),
        ..._dartFilesUnder('lib/call_v2/production'),
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
        expect(source, isNot(contains(snake)), reason: path);
        expect(source, isNot(contains(typeName)), reason: path);
      }
    });

    test('only allowed files are changed in the working tree', () {
      final result = Process.runSync('git', <String>[
        'diff',
        '--name-only',
        'HEAD',
        '--',
        ':(exclude)pubspec.lock',
      ]);
      expect(result.exitCode, 0);
      final changed = (result.stdout as String)
          .split('\n')
          .where((path) => path.trim().isNotEmpty)
          .toSet();

      expect(
        changed,
        everyElement(
          isIn(<String>{
            'lib/main.dart',
            'lib/call_v2/integration/'
                'call_v2_disabled_runtime_construction_gate.dart',
            'test/call_v2/integration/'
                'call_v2_disabled_runtime_construction_gate_test.dart',
          }),
        ),
      );
    });
  });
}

const _forbiddenGateSourceStrings = <String>[
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
  'resolveCallV2Route(',
  'DisabledCallV2RouteRegistry(',
  'CallV2Runtime(',
  'CallV2ProductionComposition(',
];

const _forbiddenMainStartupAreaStrings = <String>[
  'startCallV2Production',
  'startRuntime',
  'runtime.start',
  'constructRuntime',
  'createRuntime',
  'runtimeInstance',
  'CallV2Runtime(',
  'CallV2ProductionComposition(',
  'Navigator.',
  'GlobalKey(',
  'AppLifecycleListener(',
  'WidgetsBinding.instance.addObserver',
  'createAgoraRtcEngine',
  'joinChannel',
  'requestPermissions',
  'Permission.',
  'FirebaseFirestore.instance',
  'FirebaseAuth.instance',
  'FirebaseFunctions.instance',
  'FirebaseAppCheck.instance',
  '.collection(',
  '.doc(',
  '.snapshots(',
  '.get(',
  '.set(',
  '.update(',
  '.delete(',
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

String _gateSource() {
  return _read(
    'lib/call_v2/integration/'
    'call_v2_disabled_runtime_construction_gate.dart',
  );
}

String _onGenerateRouteSource(String source) {
  final start = source.indexOf('onGenerateRoute: (settings) {');
  final end = source.indexOf('onUnknownRoute: (settings)');

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));

  return source.substring(start, end);
}

String _mainStartupBoundaryArea(String source) {
  final importIndex = source.indexOf(
    "import 'call_v2/integration/call_v2_disabled_runtime_construction_gate.dart';",
  );
  final shellIndex = source.indexOf(
    'initializeCallV2AppIntegrationShellSafely());',
  );
  final constructionIndex = source.indexOf(
    'executeCallV2DisabledRuntimeConstructionGateSafely();',
  );
  final runAppIndex = source.indexOf('runApp(const MyApp());');

  expect(importIndex, greaterThanOrEqualTo(0));
  expect(shellIndex, greaterThan(importIndex));
  expect(constructionIndex, greaterThan(shellIndex));
  expect(runAppIndex, greaterThan(constructionIndex));

  return <String>[
    source.substring(importIndex, source.indexOf('\n', importIndex)),
    source.substring(shellIndex, runAppIndex),
  ].join('\n');
}

int _count(String source, String needle) {
  return RegExp(RegExp.escape(needle)).allMatches(source).length;
}

List<String> _dartFilesUnder(String directory) {
  final root = Directory(directory);
  if (!root.existsSync()) return <String>[];

  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path)
      .toList();
}

String _readIfExists(String path) {
  final file = File(path);
  if (!file.existsSync()) return '';
  return file.readAsStringSync();
}

String _read(String path) => File(path).readAsStringSync();
