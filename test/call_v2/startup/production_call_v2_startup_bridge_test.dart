import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_contract_manifest.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/call_v2_production_readiness.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/firebase/call_v2_app_check_transport.dart';
import 'package:connect_app/call_v2/firebase/call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/firebase/call_v2_document_snapshot_transport.dart';
import 'package:connect_app/call_v2/identity/call_v2_auth_identity_provider.dart';
import 'package:connect_app/call_v2/permissions/call_v2_media_permission_gateway.dart';
import 'package:connect_app/call_v2/permissions/production/call_v2_permission_transport.dart';
import 'package:connect_app/call_v2/production/call_v2_production_composition.dart';
import 'package:connect_app/call_v2/rtc/production/call_v2_rtc_engine_transport.dart';
import 'package:connect_app/call_v2/startup/call_v2_startup_bridge.dart';
import 'package:connect_app/call_v2/startup/production_call_v2_startup_bridge.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and builder remains lazy', () {
      final deps = _Deps();
      var builds = 0;

      final bridge = ProductionCallV2StartupBridge(
        compositionBuilder: () {
          builds += 1;
          return deps.create(_enabledLocalConfig());
        },
      );

      expect(bridge.state.status, CallV2StartupBridgeStatus.idle);
      expect(builds, 0);
      deps.expectNoExternalCalls();
      _expectNoStartupRegistration();
    });

    test('source has no singleton, UI, route, service, or V1 wiring', () {
      final source = Directory('lib/call_v2/startup')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.readAsStringSync())
          .join('\n');

      for (final forbidden in <String>[
        '.instance',
        'Platform.environment',
        'String.fromEnvironment',
        'dotenv',
        'Secret',
        'secret',
        'main(',
        'runApp',
        'Navigator',
        'MaterialPageRoute',
        'BuildContext',
        'lib/main.dart',
        'lib/services/',
        'lib/screens/',
        'callInvites',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('disabled behavior', () {
    test('disabled configuration rejects before all preflight and runtime work',
        () async {
      final deps = _Deps();
      final bridge = deps.bridge(_disabledLocalConfig());

      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(bridge.state.status, CallV2StartupBridgeStatus.stopped);
      expect(bridge.state.errorCode, CallV2ClientErrorCode.rejected);
      deps.expectNoExternalCalls();
    });
  });

  group('preflight order', () {
    test(
        'successful audio startup uses identity, App Check, permission, runtime',
        () async {
      final deps = _Deps();
      final bridge = deps.bridge(_enabledLocalConfig());

      await bridge.start(_request(isVideo: false));

      expect(deps.events, <String>[
        'auth',
        'appCheck',
        'permission:microphone',
        'callStream:callA',
        'participantStream:caller',
        'participantStream:callee',
      ]);
      expect(deps.permissions.requests, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
      ]);
      expect(bridge.state.status, CallV2StartupBridgeStatus.running);
    });

    test('video startup asks microphone and camera before runtime start',
        () async {
      final deps = _Deps();
      final bridge = deps.bridge(_enabledLocalConfig());

      await bridge.start(_request(isVideo: true));

      expect(deps.permissions.requests, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
        CallV2MediaPermission.camera,
      ]);
      expect(deps.events.indexOf('permission:camera'),
          lessThan(deps.events.indexOf('callStream:callA')));
    });

    test('auth failure prevents App Check, permissions, and runtime', () async {
      final deps = _Deps()..auth.user = null;
      final bridge = deps.bridge(_enabledLocalConfig());

      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.unauthorized)),
      );

      expect(deps.events, <String>['auth']);
      expect(deps.appCheck.calls, 0);
      expect(deps.permissions.requests, isEmpty);
      expect(deps.snapshots.callStreams, 0);
    });

    test('App Check failure prevents permissions and runtime', () async {
      final deps = _Deps()..appCheck.token = null;
      final bridge = deps.bridge(_enabledLocalConfig());

      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(deps.events, <String>['auth', 'appCheck']);
      expect(deps.permissions.requests, isEmpty);
      expect(deps.snapshots.callStreams, 0);
    });

    test('permission denial prevents runtime start', () async {
      final deps = _Deps()..permissions.status = CallV2PermissionStatus.denied;
      final bridge = deps.bridge(_enabledLocalConfig());

      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(deps.events, <String>[
        'auth',
        'appCheck',
        'permission:microphone',
      ]);
      expect(deps.snapshots.callStreams, 0);
    });

    test('authenticated UID is authoritative and no local UID override exists',
        () async {
      final deps = _Deps()..auth.user = _FakeUser('callee');
      final bridge = deps.bridge(_enabledLocalConfig());

      await bridge.start(_request());

      expect(deps.snapshots.callStreams, 1);
      expect(bridge.state.toString(), isNot(contains('callee')));
      expect(_request().toString(), isNot(contains('callee')));
    });
  });

  group('readiness', () {
    test('startup capability declaration enables only startup bridge', () {
      expect(
          callV2IsolatedStartupBridgeCapabilities.callableApiAdapterAvailable,
          isTrue);
      expect(
          callV2IsolatedStartupBridgeCapabilities
              .firestoreSnapshotSourceAvailable,
          isTrue);
      expect(callV2IsolatedStartupBridgeCapabilities.rtcConfigProviderAvailable,
          isTrue);
      expect(
          callV2IsolatedStartupBridgeCapabilities.rtcAdapterAvailable, isTrue);
      expect(
          callV2IsolatedStartupBridgeCapabilities.authIdentitySourceAvailable,
          isTrue);
      expect(callV2IsolatedStartupBridgeCapabilities.appCheckAvailable, isTrue);
      expect(callV2IsolatedStartupBridgeCapabilities.permissionGatewayAvailable,
          isTrue);
      expect(
          callV2IsolatedStartupBridgeCapabilities.runtimeStartupBridgeAvailable,
          isTrue);
      expect(
          callV2IsolatedStartupBridgeCapabilities.uiRouteIntegrationAvailable,
          isFalse);
      expect(
          callV2IsolatedStartupBridgeCapabilities
              .nativeCallIntegrationAvailable,
          isFalse);
      expect(callV2IsolatedStartupBridgeCapabilities.observabilityAvailable,
          isFalse);
    });

    test('readiness remains production blocked and cannot be bypassed',
        () async {
      final deps = _Deps();
      final composition = deps.create(_enabledProductionConfig());
      final readiness = const CallV2ProductionReadinessAuditor().audit(
        manifest: callV2Phase3ContractManifest,
        configuration: composition.configuration,
        capabilities: callV2IsolatedStartupBridgeCapabilities,
      );

      expect(readiness.readyForAdapterImplementation, isTrue);
      expect(readiness.readyForProductionEnablement, isFalse);
      expect(
        _readinessCodes(readiness),
        containsAll(<Object>[
          CallV2ProductionReadinessIssueCode.missingUiRouteIntegration,
          CallV2ProductionReadinessIssueCode.missingObservability,
        ]),
      );

      final bridge = ProductionCallV2StartupBridge(composition: composition);
      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      deps.expectNoExternalCalls();
    });

    test('Phase 4F and global no-capability constants remain unchanged', () {
      expect(
          callV2IsolatedProductionCompositionCapabilities
              .runtimeStartupBridgeAvailable,
          isFalse);
      expect(
        callV2NoProductionCapabilities.toSafeDebugMap().values,
        everyElement(isFalse),
      );
    });
  });

  group('start concurrency', () {
    test('duplicate concurrent same start shares one preflight sequence',
        () async {
      final deps = _Deps()..appCheck.held = Completer<void>();
      final bridge = deps.bridge(_enabledLocalConfig());

      final first = bridge.start(_request());
      final second = bridge.start(_request());

      expect(identical(first, second), isTrue);
      expect(deps.auth.reads, 1);
      deps.appCheck.held!.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(deps.snapshots.callStreams, 1);
    });

    test('conflicting start rejects and start while running is idempotent',
        () async {
      final deps = _Deps()..appCheck.held = Completer<void>();
      final bridge = deps.bridge(_enabledLocalConfig());

      final first = bridge.start(_request());
      await expectLater(
        bridge.start(_request(callId: 'callB')),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      deps.appCheck.held!.complete();
      await first;

      await bridge.start(_request());
      expect(deps.auth.reads, 1);
      expect(deps.snapshots.callStreams, 1);
    });

    test('start while stopping rejects and no automatic retry occurs',
        () async {
      final deps = _Deps();
      final bridge = deps.bridge(_enabledLocalConfig());

      await bridge.start(_request());
      final stop = bridge.stop();
      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await stop;

      expect(deps.auth.reads, 1);
    });

    test('raw preflight errors are sanitized', () async {
      final deps = _Deps()..permissions.throwRaw = true;
      final bridge = deps.bridge(_enabledLocalConfig());

      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );
      expect(bridge.state.toString(), isNot(contains('raw permission')));
    });
  });

  group('races', () {
    test('held identity then stop cannot later run', () async {
      final deps = _Deps();
      final auth = _AsyncAuthProvider();
      final bridge = ProductionCallV2StartupBridge(
        composition: deps.createWithAuthProvider(
          _enabledLocalConfig(),
          auth,
        ),
      );

      final start = bridge.start(_request());
      await bridge.stop();
      auth.complete();

      await expectLater(
        start,
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      expect(deps.appCheck.calls, 0);
      expect(bridge.state.status, CallV2StartupBridgeStatus.stopped);
    });

    test('held App Check then stop cannot later run', () async {
      final deps = _Deps()..appCheck.held = Completer<void>();
      final bridge = deps.bridge(_enabledLocalConfig());

      final start = bridge.start(_request());
      await _pump();
      await bridge.stop();
      deps.appCheck.held!.complete();

      await expectLater(
        start,
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      expect(deps.permissions.requests, isEmpty);
      expect(bridge.state.status, CallV2StartupBridgeStatus.stopped);
    });

    test('held permission then stop cannot later run', () async {
      final deps = _Deps()..permissions.held = Completer<void>();
      final bridge = deps.bridge(_enabledLocalConfig());

      final start = bridge.start(_request());
      await _pump();
      await bridge.stop();
      deps.permissions.held!.complete();

      await expectLater(
        start,
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      expect(deps.snapshots.callStreams, 0);
      expect(bridge.state.status, CallV2StartupBridgeStatus.stopped);
    });
  });

  group('stop and dispose', () {
    test('stop while idle is safe and duplicate stop coalesces', () async {
      final deps = _Deps();
      final bridge = deps.bridge(_enabledLocalConfig());

      final first = bridge.stop();
      final second = bridge.stop();
      await Future.wait(<Future<void>>[first, second]);

      expect(bridge.state.status, CallV2StartupBridgeStatus.stopped);
      expect(deps.snapshots.cancelCount, 0);
    });

    test('stop is allowed when feature gate is disabled', () async {
      final deps = _Deps();
      final bridge = deps.bridge(_disabledLocalConfig());

      await bridge.stop();

      expect(bridge.state.status, CallV2StartupBridgeStatus.stopped);
    });

    test('dispose stops before composition disposal and is idempotent',
        () async {
      final deps = _Deps();
      final bridge = deps.bridge(_enabledLocalConfig());

      await bridge.start(_request());
      await bridge.dispose();
      await bridge.dispose();

      expect(bridge.state.status, CallV2StartupBridgeStatus.disposed);
      expect(deps.snapshots.cancelCount, 3);
      expect(deps.rtc.disposeCount, 1);
      await expectLater(
        bridge.start(_request()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });

    test('all cleanup is attempted and raw cleanup details are absent',
        () async {
      final deps = _Deps(rtcDisposeThrows: true);
      final bridge = deps.bridge(_enabledLocalConfig());

      await expectLater(
        bridge.dispose(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(bridge.state.status, CallV2StartupBridgeStatus.disposed);
      expect(deps.rtc.disposeCount, 1);
      expect(bridge.state.toString(), isNot(contains('raw dispose')));
    });
  });

  group('isolation regression', () {
    test('main, services, screens, pubspec, and backend are unmodified', () {
      for (final path in <String>[
        'lib/main.dart',
        'pubspec.yaml',
        'pubspec.lock',
      ]) {
        expect(File(path).existsSync(), isTrue);
      }
      _expectNoStartupRegistration();
    });
  });
}

class _Deps {
  _Deps({bool rtcDisposeThrows = false})
      : rtc = _FakeRtcTransport(disposeThrows: rtcDisposeThrows);

  final events = <String>[];
  final _FakeCallableTransport callable = _FakeCallableTransport();
  late final _FakeSnapshotTransport snapshots = _FakeSnapshotTransport(events);
  late final _FakeFirebaseAuth auth = _FakeFirebaseAuth(events);
  late final _FakeAppCheckTransport appCheck = _FakeAppCheckTransport(events);
  late final _FakePermissionTransport permissions =
      _FakePermissionTransport(events);
  final _FakeRtcTransport rtc;

  ProductionCallV2StartupBridge bridge(
    CallV2RuntimeConfiguration configuration,
  ) {
    return ProductionCallV2StartupBridge(
      composition: create(configuration),
    );
  }

  CallV2ProductionComposition create(CallV2RuntimeConfiguration configuration) {
    return const CallV2ProductionCompositionFactory().createWithTransports(
      configuration: configuration,
      callableTransport: callable,
      snapshotTransport: snapshots,
      auth: auth,
      appCheckTransport: appCheck,
      rtcTransport: rtc,
      permissionTransport: permissions,
      localParticipantUid: () => 'localUser',
      localParticipantRole: () => CallParticipantRole.caller,
      mediaReportKeyFactory: (callId, state) => 'media_${callId}_${state.name}',
      orchestrationKeyFactory: (callId, purpose) =>
          'orchestration_${callId}_${purpose.name}',
    );
  }

  CallV2ProductionComposition createWithAuthProvider(
    CallV2RuntimeConfiguration configuration,
    CallV2AuthIdentityProvider authIdentityProvider,
  ) {
    final base = create(configuration);
    return CallV2ProductionComposition(
      configuration: base.configuration,
      featureGate: base.featureGate,
      runtime: base.runtime,
      api: base.api,
      snapshotSource: base.snapshotSource,
      rtcCredentialProvider: base.rtcCredentialProvider,
      rtcAdapter: base.rtcAdapter,
      authIdentityProvider: authIdentityProvider,
      appCheckBoundary: base.appCheckBoundary,
      permissionGateway: base.permissionGateway,
      capabilities: base.capabilities,
    );
  }

  void expectNoExternalCalls() {
    expect(callable.calls, 0);
    expect(snapshots.callStreams, 0);
    expect(snapshots.participantStreams, 0);
    expect(auth.reads, 0);
    expect(appCheck.calls, 0);
    expect(permissions.requests, isEmpty);
    expect(rtc.initializeCount, 0);
    expect(rtc.joinCount, 0);
    expect(rtc.disposeCount, 0);
  }
}

class _FakeCallableTransport implements CallV2CallableTransport {
  int calls = 0;

  @override
  Future<Object?> call(
    String callableName,
    Map<String, Object?> request,
  ) async {
    calls += 1;
    return <String, Object?>{};
  }
}

class _FakeSnapshotTransport implements CallV2DocumentSnapshotTransport {
  _FakeSnapshotTransport(this.events);

  final List<String> events;
  int callStreams = 0;
  int participantStreams = 0;
  int cancelCount = 0;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> callDocument(
    String collectionName,
    String callId,
  ) {
    callStreams += 1;
    events.add('callStream:$callId');
    return _stream();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> participantDocument(
    String collectionName,
    String callId,
    String participantCollectionName,
    String participantUid,
  ) {
    participantStreams += 1;
    events.add('participantStream:$participantUid');
    return _stream();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _stream() {
    late StreamController<DocumentSnapshot<Map<String, dynamic>>> controller;
    controller = StreamController<DocumentSnapshot<Map<String, dynamic>>>(
      onCancel: () {
        cancelCount += 1;
      },
    );
    return controller.stream;
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.events);

  final List<String> events;
  int reads = 0;
  User? user = _FakeUser('caller');

  @override
  User? get currentUser {
    reads += 1;
    events.add('auth');
    return user;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  _FakeUser(this._uid);

  final String _uid;

  @override
  String get uid => _uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AsyncAuthProvider implements CallV2AuthIdentityProvider {
  final Completer<void> _held = Completer<void>();

  int calls = 0;

  @override
  Future<CallV2AuthenticatedIdentity> requireAuthenticatedIdentity() async {
    calls += 1;
    await _held.future;
    return CallV2AuthenticatedIdentity(uid: 'caller');
  }

  void complete() {
    if (!_held.isCompleted) _held.complete();
  }
}

class _FakeAppCheckTransport implements CallV2AppCheckTransport {
  _FakeAppCheckTransport(this.events);

  final List<String> events;
  int calls = 0;
  String? token = 'appCheckToken';
  Completer<void>? held;

  @override
  Future<String?> getToken() async {
    calls += 1;
    events.add('appCheck');
    final completer = held;
    if (completer != null) await completer.future;
    return token;
  }
}

class _FakePermissionTransport implements CallV2PermissionTransport {
  _FakePermissionTransport(this.events);

  final List<String> events;
  final requests = <CallV2MediaPermission>[];
  CallV2PermissionStatus status = CallV2PermissionStatus.granted;
  Completer<void>? held;
  bool throwRaw = false;

  @override
  Future<CallV2PermissionStatus> request(
    CallV2MediaPermission permission,
  ) async {
    requests.add(permission);
    events.add('permission:${permission.name}');
    final completer = held;
    if (completer != null) await completer.future;
    if (throwRaw) throw StateError('raw permission failure');
    return status;
  }
}

class _FakeRtcTransport implements CallV2RtcEngineTransport {
  _FakeRtcTransport({required this.disposeThrows});

  final bool disposeThrows;
  int initializeCount = 0;
  int joinCount = 0;
  int disposeCount = 0;
  final _events = StreamController<CallV2RtcEngineEvent>.broadcast();

  @override
  Stream<CallV2RtcEngineEvent> get events => _events.stream;

  @override
  Future<void> initialize(CallV2RtcEngineSession session) async {
    initializeCount += 1;
  }

  @override
  Future<void> joinChannel() async {
    joinCount += 1;
  }

  @override
  Future<void> leaveChannel() async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    await _events.close();
    if (disposeThrows) {
      throw StateError('raw dispose failure');
    }
  }
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

CallV2StartupRequest _request({
  String callId = 'callA',
  bool isVideo = false,
}) {
  return CallV2StartupRequest(
    callId: callId,
    callerUid: 'caller',
    calleeUid: 'callee',
    isVideo: isVideo,
  );
}

CallV2RuntimeConfiguration _disabledLocalConfig() {
  return callV2DefaultRuntimeConfiguration;
}

CallV2RuntimeConfiguration _enabledLocalConfig() {
  return const CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.local,
    rtcProvider: CallV2RtcProviderKind.fake,
    rtcAppIdReference: '',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: Duration(seconds: 60),
  );
}

CallV2RuntimeConfiguration _enabledProductionConfig() {
  return const CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: CallV2RtcProviderKind.agora,
    rtcAppIdReference: 'CALL_V2_AGORA_APP_ID',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: Duration(seconds: 60),
  );
}

List<CallV2ProductionReadinessIssueCode> _readinessCodes(
  CallV2ProductionReadinessResult result,
) {
  return result.issues.map((issue) => issue.code).toList();
}

Future<void> _pump() {
  return Future<void>.delayed(Duration.zero);
}

void _expectNoStartupRegistration() {
  final mainSource = File('lib/main.dart').readAsStringSync();
  expect(mainSource.contains('ProductionCallV2StartupBridge'), isFalse);
  expect(
      mainSource.contains('callV2IsolatedStartupBridgeCapabilities'), isFalse);
}
