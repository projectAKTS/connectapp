import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_real_wiring_boundary.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_real_wiring_boundary_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final touchpoint = callV2FirstActualAppWiringTouchpoint;

  group('Phase 7AW first actual app wiring touchpoint metadata', () {
    test('artifact exists and initializer returns the inert metadata object',
        () {
      final initialized =
          initializeCallV2FirstActualAppWiringTouchpointSafely();

      expect(touchpoint, isA<CallV2FirstActualAppWiringTouchpoint>());
      expect(identical(initialized, touchpoint), isTrue);
      expect(touchpoint.statuses, isNotEmpty);
      expect(touchpoint.rollback, isNotEmpty);
    });

    test('decision passes with approval rollout false and app touchpoint state',
        () {
      expect(touchpoint.decision,
          CallV2FirstActualAppWiringTouchpointDecision.pass);
      expect(touchpoint.passes, isTrue);
      expect(touchpoint.recordsHumanApproval, isTrue);
      expect(touchpoint.recordsDeveloperOnly, isTrue);
      expect(touchpoint.recordsRolloutFalse, isTrue);
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(touchpoint.recordsAppWiringTouchpointPresent, isTrue);
      expect(touchpoint.recordsNoOpWhileRolloutFalse, isTrue);
      expect(touchpoint.recordsProductionExposureBlocked, isTrue);
      expect(touchpoint.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(touchpoint.recordsCallV2ScreenExposureBlocked, isTrue);
    });

    test('accepted Phase 7AU and 7AV prerequisites still pass', () {
      expect(touchpoint.recordsFirstRealWiringBoundaryPass, isTrue);
      expect(
          touchpoint.recordsFirstRealWiringBoundaryHardeningAuditPass, isTrue);
      expect(
        callV2FirstRealWiringBoundary.decision,
        CallV2FirstRealWiringBoundaryDecision.pass,
      );
      expect(
        callV2FirstRealWiringBoundaryHardeningAudit.decision,
        CallV2FirstRealWiringBoundaryHardeningAuditDecision.pass,
      );
    });

    test(
        'runtime backend RTC permission navigator and lifecycle remain blocked',
        () {
      expect(touchpoint.recordsRuntimeConstructionBlocked, isTrue);
      expect(touchpoint.recordsRuntimeStartBlocked, isTrue);
      expect(touchpoint.recordsStartupBridgeCallBlocked, isTrue);
      expect(touchpoint.recordsBackendWritesBlocked, isTrue);
      expect(touchpoint.recordsBackendReadsBlocked, isTrue);
      expect(touchpoint.recordsFirestoreListenersBlocked, isTrue);
      expect(touchpoint.recordsAuthFunctionsAppCheckBlocked, isTrue);
      expect(touchpoint.recordsRtcInitializationBlocked, isTrue);
      expect(touchpoint.recordsRtcEngineCreationBlocked, isTrue);
      expect(touchpoint.recordsRtcChannelJoinBlocked, isTrue);
      expect(touchpoint.recordsRtcTokenChannelConsumptionBlocked, isTrue);
      expect(touchpoint.recordsPermissionRequestsBlocked, isTrue);
      expect(touchpoint.recordsCapturePromptBlocked, isTrue);
      expect(touchpoint.recordsMediaDeviceAccessBlocked, isTrue);
      expect(touchpoint.recordsNavigatorWiringBlocked, isTrue);
      expect(touchpoint.recordsNavigatorKeyCreationBlocked, isTrue);
      expect(touchpoint.recordsGlobalKeyCreationBlocked, isTrue);
      expect(touchpoint.recordsBuildContextStorageBlocked, isTrue);
      expect(touchpoint.recordsMaterialAppRouteWiringBlocked, isTrue);
      expect(touchpoint.recordsNavigatorCallsBlocked, isTrue);
      expect(touchpoint.recordsLifecycleRegistrationBlocked, isTrue);
      expect(touchpoint.recordsAppLifecycleListenerBlocked, isTrue);
      expect(touchpoint.recordsWidgetsBindingObserverBlocked, isTrue);
      expect(touchpoint.recordsAsyncHandlesBlocked, isTrue);
      expect(touchpoint.recordsRouteResolverNotCalledWhileRolloutFalse, isTrue);
    });

    test('deployment config rollback and V1 protection remain closed', () {
      expect(touchpoint.recordsDeploymentBlocked, isTrue);
      expect(touchpoint.recordsConfigPlatformChangesBlocked, isTrue);
      expect(touchpoint.recordsRollbackOneCommit, isTrue);
      expect(touchpoint.recordsV1Protected, isTrue);
    });

    test('safe debug output contains no sensitive identifiers', () {
      final debugText = '${touchpoint.toSafeDebugMap()} $touchpoint';

      expect(touchpoint.toSafeDebugMap()['statusCount'], 39);
      expect(touchpoint.toSafeDebugMap()['rollbackCount'], 9);

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
  });

  group('Phase 7AW source isolation', () {
    test('new source imports only allowed inert dependencies', () {
      final source = _touchpointSource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_first_real_wiring_boundary.dart',
        'call_v2_first_real_wiring_boundary_hardening_audit.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new source has no forbidden imports or executable hooks', () {
      final source = _touchpointSource();

      for (final forbidden in _forbiddenTouchpointSourceStrings) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test(
        'main.dart imports the touchpoint exactly once and calls it before runApp',
        () {
      final main = _read('lib/main.dart');
      const importLine =
          "import 'call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart';";
      const initializer =
          'initializeCallV2FirstActualAppWiringTouchpointSafely';

      expect(_count(main, importLine), 1);
      expect(_count(main, '$initializer();'), 1);
      expect(main.indexOf('$initializer();'),
          lessThan(main.indexOf('runApp(const MyApp());')));
    });

    test('main.dart keeps route resolver behind the rollout flag', () {
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
    });

    test('main.dart touchpoint area adds no runtime or external side effects',
        () {
      final main = _read('lib/main.dart');
      final touchpointArea = _mainTouchpointArea(main);

      for (final forbidden in _forbiddenMainTouchpointAreaStrings) {
        expect(touchpointArea, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('main.dart does not add public Call V2 routes or screen exposure', () {
      final main = _read('lib/main.dart');

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

    test('app router and implementation files do not reference the touchpoint',
        () {
      const forbidden = 'call_v2_first_actual_app_wiring_touchpoint';
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
        expect(source, isNot(contains(forbidden)), reason: path);
        expect(
          source,
          isNot(contains('CallV2FirstActualAppWiringTouchpoint')),
          reason: path,
        );
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
                'call_v2_first_actual_app_wiring_touchpoint.dart',
            'test/call_v2/integration/'
                'call_v2_first_actual_app_wiring_touchpoint_test.dart',
            'test/call_v2/integration/'
                'call_v2_disabled_developer_wiring_touchpoint_test.dart',
          }),
        ),
      );
    });
  });
}

const _forbiddenTouchpointSourceStrings = <String>[
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

const _forbiddenMainTouchpointAreaStrings = <String>[
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

String _touchpointSource() {
  return _read(
    'lib/call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart',
  );
}

String _onGenerateRouteSource(String source) {
  final start = source.indexOf('onGenerateRoute: (settings) {');
  final end = source.indexOf('onUnknownRoute: (settings)');

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));

  return source.substring(start, end);
}

String _mainTouchpointArea(String source) {
  final importIndex = source.indexOf(
    "import 'call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart';",
  );
  final initializerIndex = source.indexOf(
    'initializeCallV2FirstActualAppWiringTouchpointSafely();',
  );
  final runAppIndex = source.indexOf('runApp(const MyApp());');

  expect(importIndex, greaterThanOrEqualTo(0));
  expect(initializerIndex, greaterThan(importIndex));
  expect(runAppIndex, greaterThan(initializerIndex));

  return <String>[
    source.substring(importIndex, source.indexOf('\n', importIndex)),
    source.substring(initializerIndex, runAppIndex),
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
