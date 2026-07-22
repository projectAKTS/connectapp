import 'dart:io';

import 'package:connect_app/call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_actual_app_wiring_touchpoint_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_real_wiring_boundary.dart';
import 'package:connect_app/call_v2/integration/call_v2_first_real_wiring_boundary_hardening_audit.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final audit = callV2FirstActualAppWiringTouchpointHardeningAudit;
  final touchpoint = callV2FirstActualAppWiringTouchpoint;

  group('Phase 7AX hardening audit', () {
    test('hardening audit artifact exists and passes', () {
      expect(
        audit,
        isA<CallV2FirstActualAppWiringTouchpointHardeningAudit>(),
      );
      expect(
        audit.decision,
        CallV2FirstActualAppWiringTouchpointHardeningAuditDecision.pass,
      );
      expect(audit.passes, isTrue);
    });

    test('Phase 7AW touchpoint remains inert and accepted', () {
      expect(
        touchpoint.decision,
        CallV2FirstActualAppWiringTouchpointDecision.pass,
      );
      expect(audit.recordsTouchpointDecisionPass, isTrue);
      expect(audit.recordsInitializerInert, isTrue);
      expect(
        identical(
          initializeCallV2FirstActualAppWiringTouchpointSafely(),
          touchpoint,
        ),
        isTrue,
      );
    });

    test('rollout and app wiring source remain disabled', () {
      expect(CallV2RolloutPolicy.productionEnabled, isFalse);
      expect(audit.recordsRolloutFalse, isTrue);
      expect(audit.recordsMainDartImportSingle, isTrue);
      expect(audit.recordsMainDartInitializerSingleBeforeRunApp, isTrue);
      expect(audit.recordsResolverGatedBehindRollout, isTrue);

      final main = _read('lib/main.dart');
      const importLine =
          "import 'call_v2/integration/call_v2_first_actual_app_wiring_touchpoint.dart';";
      const initializer =
          'initializeCallV2FirstActualAppWiringTouchpointSafely';

      expect(_count(main, importLine), 1);
      expect(_count(main, '$initializer();'), 1);
      expect(
        main.indexOf('$initializer();'),
        lessThan(main.indexOf('runApp(const MyApp());')),
      );

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

    test('main.dart exposes no public Call V2 routes or screens', () {
      final main = _read('lib/main.dart');

      expect(audit.recordsPublicRouteReachabilityBlocked, isTrue);
      expect(audit.recordsCallV2ScreenExposureBlocked, isTrue);

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

    test('accepted Phase 7AU and 7AV prerequisites remain passing', () {
      expect(audit.recordsFirstRealWiringBoundaryPass, isTrue);
      expect(audit.recordsFirstRealWiringBoundaryHardeningAuditPass, isTrue);
      expect(
        callV2FirstRealWiringBoundary.decision,
        CallV2FirstRealWiringBoundaryDecision.pass,
      );
      expect(
        callV2FirstRealWiringBoundaryHardeningAudit.decision,
        CallV2FirstRealWiringBoundaryHardeningAuditDecision.pass,
      );
    });

    test('runtime startup backend Firestore and auth remain blocked', () {
      expect(audit.recordsRuntimeConstructionBlocked, isTrue);
      expect(audit.recordsRuntimeStartBlocked, isTrue);
      expect(audit.recordsStartupBridgeCallBlocked, isTrue);
      expect(audit.recordsBackendWritesBlocked, isTrue);
      expect(audit.recordsBackendReadsBlocked, isTrue);
      expect(audit.recordsFirestoreListenersBlocked, isTrue);
      expect(audit.recordsAuthFunctionsAppCheckBlocked, isTrue);
    });

    test('RTC permission media navigator lifecycle and async remain blocked',
        () {
      expect(audit.recordsRtcInitializationBlocked, isTrue);
      expect(audit.recordsRtcEngineCreationBlocked, isTrue);
      expect(audit.recordsRtcChannelJoinBlocked, isTrue);
      expect(audit.recordsRtcTokenChannelConsumptionBlocked, isTrue);
      expect(audit.recordsPermissionRequestsBlocked, isTrue);
      expect(audit.recordsCapturePromptBlocked, isTrue);
      expect(audit.recordsMediaDeviceAccessBlocked, isTrue);
      expect(audit.recordsNavigatorWiringBlocked, isTrue);
      expect(audit.recordsNavigatorKeyCreationBlocked, isTrue);
      expect(audit.recordsGlobalKeyCreationBlocked, isTrue);
      expect(audit.recordsBuildContextStorageBlocked, isTrue);
      expect(audit.recordsMaterialAppRouteWiringBlocked, isTrue);
      expect(audit.recordsNavigatorCallsBlocked, isTrue);
      expect(audit.recordsLifecycleRegistrationBlocked, isTrue);
      expect(audit.recordsAppLifecycleListenerBlocked, isTrue);
      expect(audit.recordsWidgetsBindingObserverBlocked, isTrue);
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
      expect(audit.toSafeDebugMap()['rollbackCount'], 9);

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
        'collection',
        'document',
        'payload',
        'raw',
        'stack',
      ]) {
        expect(debugText, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });

  group('Phase 7AX source hardening', () {
    test('new audit source imports only allowed inert dependencies', () {
      final source = _hardeningSource();
      final imports = RegExp("^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((match) => match.group(1))
          .toList();

      expect(imports, <String>[
        'call_v2_first_actual_app_wiring_touchpoint.dart',
        'call_v2_first_real_wiring_boundary.dart',
        'call_v2_first_real_wiring_boundary_hardening_audit.dart',
        'call_v2_rollout_policy.dart',
      ]);
    });

    test('new audit source has no forbidden imports hooks or executable calls',
        () {
      final source = _hardeningSource();

      for (final forbidden in _forbiddenHardeningSourceStrings) {
        expect(source, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('app router and implementation files do not reference hardening audit',
        () {
      const forbidden =
          'call_v2_first_actual_app_wiring_touchpoint_hardening_audit';

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
          isNot(
            contains('CallV2FirstActualAppWiringTouchpointHardeningAudit'),
          ),
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
            'lib/call_v2/integration/'
                'call_v2_first_actual_app_wiring_touchpoint_hardening_audit.dart',
            'test/call_v2/integration/'
                'call_v2_first_actual_app_wiring_touchpoint_hardening_audit_test.dart',
          }),
        ),
      );
    });
  });
}

const _forbiddenHardeningSourceStrings = <String>[
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

String _hardeningSource() {
  return _read(
    'lib/call_v2/integration/'
    'call_v2_first_actual_app_wiring_touchpoint_hardening_audit.dart',
  );
}

String _onGenerateRouteSource(String source) {
  final start = source.indexOf('onGenerateRoute: (settings) {');
  final end = source.indexOf('onUnknownRoute: (settings)');

  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));

  return source.substring(start, end);
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
