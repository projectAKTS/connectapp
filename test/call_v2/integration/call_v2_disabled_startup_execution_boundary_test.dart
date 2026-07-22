import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_disabled_startup_execution_boundary.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_actual_app_wiring_touchpoint_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boundary = callV2DisabledStartupExecutionBoundary;

  group('Phase 7AY disabled startup execution boundary', () {
    test('boundary artifact exists and safe executor returns inert metadata',
        () {
      final executed = executeCallV2DisabledStartupBoundarySafely();

      expect(boundary, isA<CallV2DisabledStartupExecutionBoundary>());
      expect(identical(executed, boundary), isTrue);
      expect(boundary.statuses, isNotEmpty);
      expect(boundary.rollback, isNotEmpty);
    });

    test('decision passes with approval developer-only and rollout false', () {
      expect(
        boundary.decision,
        CallV2DisabledStartupExecutionBoundaryDecision.pass,
      );
      expect(boundary.passes, isTrue);
      expect(boundary.recordsHumanApproval, isTrue);
      expect(boundary.recordsDeveloperOnly, isTrue);
      expect(boundary.recordsRolloutFalse, isTrue);
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    });

    test('startup boundary is present and no-op while rollout is false', () {
      expect(boundary.recordsStartupExecutionBoundaryPresent, isTrue);
      expect(boundary.recordsNoOpWhileRolloutFalse, isTrue);
      expect(boundary.recordsRouteResolverNotCalledWhileRolloutFalse, isTrue);
    });

    test('accepted touchpoint and hardening audit remain passing', () {
      expect(boundary.recordsAppTouchpointPass, isTrue);
      expect(boundary.recordsAppTouchpointHardeningAuditPass, isTrue);
      expect(
        callV2FirstActualAppWiringTouchpoint.decision,
        CallV2FirstActualAppWiringTouchpointDecision.pass,
      );
      expect(
        callV2FirstActualAppWiringTouchpointHardeningAudit.decision,
        CallV2FirstActualAppWiringTouchpointHardeningAuditDecision.pass,
      );
    });

    test('production routes screens runtime and startup remain blocked', () {
      expect(boundary.recordsProductionExposureBlocked, isTrue);
      expect(boundary.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(boundary.recordsCallV2ScreenExposureBlocked, isTrue);
      expect(boundary.recordsRuntimeConstructionBlocked, isTrue);
      expect(boundary.recordsRuntimeStartBlocked, isTrue);
      expect(boundary.recordsProductionStartupBridgeBlocked, isTrue);
      expect(boundary.recordsStartupBridgeCallBlocked, isTrue);
    });

    test('backend Firestore Auth Functions and App Check remain blocked', () {
      expect(boundary.recordsBackendWritesBlocked, isTrue);
      expect(boundary.recordsBackendReadsBlocked, isTrue);
      expect(boundary.recordsFirestoreListenersBlocked, isTrue);
      expect(boundary.recordsAuthFunctionsAppCheckBlocked, isTrue);
    });

    test('RTC permissions media navigator lifecycle and async remain blocked',
        () {
      expect(boundary.recordsRtcInitializationBlocked, isTrue);
      expect(boundary.recordsRtcEngineCreationBlocked, isTrue);
      expect(boundary.recordsRtcChannelJoinBlocked, isTrue);
      expect(boundary.recordsRtcTokenChannelConsumptionBlocked, isTrue);
      expect(boundary.recordsPermissionRequestsBlocked, isTrue);
      expect(boundary.recordsCapturePromptBlocked, isTrue);
      expect(boundary.recordsMediaDeviceAccessBlocked, isTrue);
      expect(boundary.recordsNavigatorWiringBlocked, isTrue);
      expect(boundary.recordsNavigatorCallsBlocked, isTrue);
      expect(boundary.recordsLifecycleRegistrationBlocked, isTrue);
      expect(boundary.recordsAsyncHandlesBlocked, isTrue);
    });

    test('deployment config rollback and V1 protection remain closed', () {
      expect(boundary.recordsDeploymentBlocked, isTrue);
      expect(boundary.recordsConfigPlatformChangesBlocked, isTrue);
      expect(boundary.recordsRollbackOneCommit, isTrue);
      expect(boundary.recordsV1Protected, isTrue);
    });

    test('safe debug output contains no sensitive identifiers', () {
      final debugText = '${boundary.toSafeDebugMap()} $boundary';

      expect(boundary.toSafeDebugMap()['statusCount'], 34);
      expect(boundary.toSafeDebugMap()['rollbackCount'], 9);

      for (final forbidden in _sensitiveDebugStrings) {
        expect(debugText, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 7AY source and app wiring isolation', () {
    test('new source imports only allowed inert dependencies', () {
      final source = _boundarySource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_first_actual_app_wiring_touchpoint.dart',
        'call_v2_first_actual_app_wiring_touchpoint_hardening_audit.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new source has no forbidden imports hooks or executable calls', () {
      final source = _boundarySource();

      for (final forbidden in _forbiddenBoundarySourceStrings) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('main.dart imports and executes boundary once in required order', () {
      final main = _read('lib/main.dart');
      const shell = 'initializeCallV2AppIntegrationShellSafely';
      const touchpoint = 'initializeCallV2FirstActualAppWiringTouchpointSafely';
      const boundaryExecutor = 'executeCallV2DisabledStartupBoundarySafely';
      const boundaryImport =
          "import 'call_v2/integration/call_v2_disabled_startup_execution_boundary.dart';";

      expect(_count(main, boundaryImport), 1);
      expect(_count(main, '$boundaryExecutor();'), 1);
      expect(
        main.indexOf('$shell());'),
        lessThan(main.indexOf('$touchpoint();')),
      );
      expect(
        main.indexOf('$touchpoint();'),
        lessThan(main.indexOf('$boundaryExecutor();')),
      );
      expect(
        main.indexOf('$boundaryExecutor();'),
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

    test('implementation and config files do not reference the boundary', () {
      const snake = 'call_v2_disabled_startup_execution_boundary';
      const typeName = 'CallV2DisabledStartupExecutionBoundary';

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
                'call_v2_disabled_startup_execution_boundary.dart',
            'test/call_v2/integration/'
                'call_v2_disabled_startup_execution_boundary_test.dart',
          }),
        ),
      );
    });
  });
}

const _forbiddenBoundarySourceStrings = <String>[
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
];

const _forbiddenMainStartupAreaStrings = <String>[
  'startCallV2Production',
  'startRuntime',
  'runtime.start',
  'constructRuntime',
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

String _boundarySource() {
  return _read(
    'lib/call_v2/integration/call_v2_disabled_startup_execution_boundary.dart',
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
    "import 'call_v2/integration/call_v2_disabled_startup_execution_boundary.dart';",
  );
  final shellIndex = source.indexOf(
    'initializeCallV2AppIntegrationShellSafely());',
  );
  final boundaryIndex = source.indexOf(
    'executeCallV2DisabledStartupBoundarySafely();',
  );
  final runAppIndex = source.indexOf('runApp(const MyApp());');

  expect(importIndex, greaterThanOrEqualTo(0));
  expect(shellIndex, greaterThan(importIndex));
  expect(boundaryIndex, greaterThan(shellIndex));
  expect(runAppIndex, greaterThan(boundaryIndex));

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
