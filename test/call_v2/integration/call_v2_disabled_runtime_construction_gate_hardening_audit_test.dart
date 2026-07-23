import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_disabled_runtime_construction_gate_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2DisabledRuntimeConstructionGateHardeningAudit;
  final gate = callV2DisabledRuntimeConstructionGate;

  group('Phase 7BD disabled runtime construction gate hardening audit', () {
    test('hardening audit artifact exists and passes', () {
      expect(
        audit,
        isA<CallV2DisabledRuntimeConstructionGateHardeningAudit>(),
      );
      expect(
        audit.decision,
        CallV2DisabledRuntimeConstructionGateHardeningAuditDecision.pass,
      );
      expect(audit.passes, isTrue);
      expect(audit.recordsAuditArtifactPresent, isTrue);
    });

    test('Phase 7BC construction gate remains accepted and inert', () {
      expect(audit.recordsGateExists, isTrue);
      expect(audit.recordsGateDecisionPass, isTrue);
      expect(audit.recordsExecutorInert, isTrue);
      expect(gate.decision, CallV2DisabledRuntimeConstructionGateDecision.pass);
      expect(
        identical(executeCallV2DisabledRuntimeConstructionGateSafely(), gate),
        isTrue,
      );
    });

    test('rollout remains false and main.dart call shape is unchanged', () {
      expect(audit.recordsRolloutFalse, isTrue);
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(audit.recordsMainDartImportSingle, isTrue);
      expect(audit.recordsMainDartExecutorSingle, isTrue);
      expect(audit.recordsMainDartExecutionOrder, isTrue);
    });

    test('route resolver and public Call V2 UI remain blocked', () {
      expect(audit.recordsResolverGatedBehindRollout, isTrue);
      expect(audit.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(audit.recordsCallV2ScreenExposureBlocked, isTrue);
      expect(audit.recordsRouteResolverNotCalledWhileRolloutFalse, isTrue);
    });

    test(
        'runtime construction startup bridge and instance creation are blocked',
        () {
      expect(audit.recordsRuntimeConstructionBlocked, isTrue);
      expect(audit.recordsRuntimeStartBlocked, isTrue);
      expect(audit.recordsRuntimeUnavailable, isTrue);
      expect(audit.recordsRuntimeCreationBlocked, isTrue);
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
      expect(audit.recordsRtcTokenChannelConsumptionBlocked, isTrue);
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

      expect(audit.toSafeDebugMap()['statusCount'], 37);
      expect(audit.toSafeDebugMap()['rollbackCount'], 11);

      for (final forbidden in _sensitiveDebugStrings) {
        expect(debugText, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 7BD source and app wiring hardening', () {
    test('new hardening source imports only allowed inert dependencies', () {
      final source = _auditSource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_disabled_runtime_construction_gate.dart',
        'call_v2_disabled_runtime_preflight_boundary.dart',
        'call_v2_disabled_runtime_preflight_boundary_hardening_audit.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new hardening source has no forbidden imports hooks or calls', () {
      final source = _auditSource();

      for (final forbidden in _forbiddenAuditSourceStrings) {
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

    test('implementation and config files do not reference hardening audit',
        () {
      const snake =
          'call_v2_disabled_runtime_construction_gate_hardening_audit';
      const typeName = 'CallV2DisabledRuntimeConstructionGateHardeningAudit';

      for (final path in <String>[
        'lib/main.dart',
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
            'lib/call_v2/integration/'
                'call_v2_disabled_runtime_construction_gate_hardening_audit.dart',
            'test/call_v2/integration/'
                'call_v2_disabled_runtime_construction_gate_hardening_audit_test.dart',
          }),
        ),
      );
    });
  });
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

String _auditSource() {
  return _read(
    'lib/call_v2/integration/'
    'call_v2_disabled_runtime_construction_gate_hardening_audit.dart',
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
