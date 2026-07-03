import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_contract_manifest.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/call_v2_production_readiness.dart';
import 'package:connect_app/call_v2/call_v2_runtime.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/firebase/call_v2_app_check_transport.dart';
import 'package:connect_app/call_v2/firebase/call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/firebase/call_v2_document_snapshot_transport.dart';
import 'package:connect_app/call_v2/permissions/call_v2_media_permission_gateway.dart';
import 'package:connect_app/call_v2/permissions/production/call_v2_permission_transport.dart';
import 'package:connect_app/call_v2/production/call_v2_production_composition.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/production/call_v2_rtc_engine_transport.dart';
import 'package:connect_app/call_v2/rtc/production/production_call_v2_rtc_adapter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction', () {
    test('factory has no side effects and performs no external work', () {
      final deps = _Deps();

      final composition = deps.create(_disabledLocalConfig());

      expect(composition.runtime.state.status, CallV2RuntimeStatus.idle);
      expect(composition.rtcAdapter.state,
          ProductionCallV2RtcAdapterState.uninitialized);
      deps.expectNoExternalCalls();
      _expectNoStartupUiOrRouteWiring();
    });

    test('source has no singleton, environment, secret, startup, or UI wiring',
        () {
      final source = File(
        'lib/call_v2/production/call_v2_production_composition.dart',
      ).readAsStringSync();

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
        'showDialog',
        'BuildContext',
        'register',
        'ServiceLocator',
        'GetIt',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  group('configuration', () {
    test('invalid config is rejected without mutating the object', () {
      final deps = _Deps();
      final config = _disabledLocalConfig(callCollectionName: 'calls/v2');

      expect(
        () => deps.create(config),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
      expect(config.callCollectionName, 'calls/v2');
      deps.expectNoExternalCalls();
    });

    test('disabled local and disabled production configs compose', () {
      final local = _Deps().create(_disabledLocalConfig());
      final production = _Deps().create(_disabledProductionConfig());

      expect(local.featureGate.enabled, isFalse);
      expect(production.featureGate.enabled, isFalse);
    });

    test('enabled production none and fake providers are rejected', () {
      expect(
        () => _Deps().create(_enabledProductionConfig(
          rtcProvider: CallV2RtcProviderKind.none,
        )),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
      expect(
        () => _Deps().create(_enabledProductionConfig(
          rtcProvider: CallV2RtcProviderKind.fake,
        )),
        throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
      );
    });

    test('enabled production real provider is accepted', () {
      final composition = _Deps().create(_enabledProductionConfig());

      expect(composition.featureGate.enabled, isTrue);
    });
  });

  group('shared feature gate', () {
    test('disabled config keeps all gate-aware boundaries disabled', () async {
      final deps = _Deps();
      final composition = deps.create(_disabledLocalConfig());

      await expectLater(
        composition.api.startCallV2(_startRequest()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        composition.authIdentityProvider.requireAuthenticatedIdentity(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        composition.appCheckBoundary.assertAvailable(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        composition.permissionGateway.request(_audioPermissionRequest),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        composition.rtcAdapter.initialize(_rtcConfig()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      deps.expectNoExternalCalls();
    });

    test('enabled config enables all gate-aware boundaries consistently',
        () async {
      final deps = _Deps();
      final composition = deps.create(_enabledProductionConfig());

      expect(composition.featureGate.enabled, isTrue);
      await composition.api.startCallV2(_startRequest());
      await composition.authIdentityProvider.requireAuthenticatedIdentity();
      await composition.appCheckBoundary.assertAvailable();
      await composition.permissionGateway.request(_audioPermissionRequest);
      await composition.rtcAdapter.initialize(_rtcConfig());

      expect(deps.callable.calls, 1);
      expect(deps.auth.reads, 1);
      expect(deps.appCheck.calls, 1);
      expect(deps.permissions.requests, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
      ]);
      expect(deps.rtc.initializeCount, 1);
    });
  });

  group('dependency graph', () {
    test('runtime graph preserves accepted ownership chain', () {
      final composition = _Deps().create(_enabledProductionConfig());

      expect(composition.runtime.harness, same(composition.runtime.harness));
      expect(composition.runtime.subscriptionCoordinator,
          same(composition.runtime.subscriptionCoordinator));
      expect(composition.runtime.mediaOrchestrator,
          same(composition.runtime.mediaOrchestrator));
      expect(composition.runtime.configResolver,
          same(composition.runtime.configResolver));
      expect(composition.runtime.mediaController,
          same(composition.runtime.mediaController));
      expect(composition.rtcAdapter, isA<ProductionCallV2RtcAdapter>());
      expect(composition.runtime, isNot(same(composition.api)));
      expect(composition.runtime, isNot(same(composition.snapshotSource)));
      expect(
          composition.runtime, isNot(same(composition.authIdentityProvider)));
      expect(composition.runtime, isNot(same(composition.appCheckBoundary)));
    });

    test('frozen manifest remains unchanged', () {
      expect(
        callV2Phase3ContractManifest.allowedDependencyEdges,
        callV2AllowedDependencyEdges,
      );
      expect(
        callV2Phase3ContractManifest.forbiddenDependencyEdges,
        callV2ForbiddenDependencyEdges,
      );
      expect(
        callV2Phase3ContractManifest.hasExactAcceptedDependencyGraph,
        isTrue,
      );
    });
  });

  group('capabilities and readiness', () {
    test('composition capabilities report adapters only', () {
      final capabilities = _Deps().create(_disabledLocalConfig()).capabilities;

      expect(capabilities.callableApiAdapterAvailable, isTrue);
      expect(capabilities.firestoreSnapshotSourceAvailable, isTrue);
      expect(capabilities.rtcConfigProviderAvailable, isTrue);
      expect(capabilities.rtcAdapterAvailable, isTrue);
      expect(capabilities.authIdentitySourceAvailable, isTrue);
      expect(capabilities.appCheckAvailable, isTrue);
      expect(capabilities.permissionGatewayAvailable, isTrue);
      expect(capabilities.runtimeStartupBridgeAvailable, isFalse);
      expect(capabilities.uiRouteIntegrationAvailable, isFalse);
      expect(capabilities.nativeCallIntegrationAvailable, isFalse);
      expect(capabilities.observabilityAvailable, isFalse);
      expect(
        callV2NoProductionCapabilities.toSafeDebugMap().values,
        everyElement(isFalse),
      );
    });

    test('disabled and enabled readiness stay production-blocked', () {
      final disabled =
          _Deps().create(_disabledProductionConfig()).auditReadiness();
      final enabled =
          _Deps().create(_enabledProductionConfig()).auditReadiness();

      expect(disabled.readyForAdapterImplementation, isTrue);
      expect(disabled.readyForProductionEnablement, isFalse);
      expect(enabled.readyForAdapterImplementation, isTrue);
      expect(enabled.readyForProductionEnablement, isFalse);
      expect(
          _readinessCodes(enabled),
          containsAll(<Object>[
            CallV2ProductionReadinessIssueCode.missingRuntimeStartupBridge,
            CallV2ProductionReadinessIssueCode.missingUiRouteIntegration,
            CallV2ProductionReadinessIssueCode.missingObservability,
          ]));
    });

    test('readiness uses auditor and does not fake production readiness', () {
      final composition = _Deps().create(_enabledProductionConfig());
      final result = composition.auditReadiness(
        auditor: const CallV2ProductionReadinessAuditor(),
      );

      expect(result.readyForProductionEnablement, isFalse);
      expect(
        result.toString(),
        isNot(contains('override')),
      );
    });
  });

  group('isolation behavior', () {
    test('explicit boundary calls work and construction stays lazy', () async {
      final deps = _Deps();
      final composition = deps.create(_enabledProductionConfig());
      deps.expectNoExternalCalls();

      final identity =
          await composition.authIdentityProvider.requireAuthenticatedIdentity();
      await composition.appCheckBoundary.assertAvailable();
      final permission =
          await composition.permissionGateway.request(_videoPermissionRequest);
      final callable = await composition.api.startCallV2(_startRequest());

      expect(identity.uid, 'localUser');
      expect(permission.allRequiredGranted, isTrue);
      expect(callable, isA<Map<String, Object?>>());
      expect(deps.auth.reads, 1);
      expect(deps.appCheck.calls, 1);
      expect(deps.permissions.requests, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
        CallV2MediaPermission.camera,
      ]);
      expect(deps.callable.calls, 1);
      expect(deps.snapshots.callStreams, 0);
      expect(deps.rtc.initializeCount, 0);
      expect(composition.runtime.state.status, CallV2RuntimeStatus.idle);
    });

    test('snapshot source and RTC adapter remain idle until explicit use',
        () async {
      final deps = _Deps();
      final composition = deps.create(_enabledProductionConfig());

      composition.snapshotSource.callDocumentStream('callA');
      await composition.rtcAdapter.initialize(_rtcConfig());

      expect(deps.snapshots.callStreams, 1);
      expect(deps.rtc.initializeCount, 1);
      expect(composition.runtime.state.status, CallV2RuntimeStatus.idle);
    });
  });

  group('disposal', () {
    test('dispose is idempotent and cleans runtime then RTC adapter', () async {
      final deps = _Deps();
      final composition = deps.create(_enabledProductionConfig());

      await composition.dispose();
      await composition.dispose();

      expect(composition.runtime.state.status, CallV2RuntimeStatus.stopped);
      expect(deps.rtc.disposeCount, 1);
      expect(composition.rtcAdapter.state,
          ProductionCallV2RtcAdapterState.disposed);
    });

    test('cleanup remains allowed with disabled gate', () async {
      final deps = _Deps();
      final composition = deps.create(_disabledLocalConfig());

      await composition.dispose();

      expect(composition.runtime.state.status, CallV2RuntimeStatus.stopped);
      expect(deps.rtc.disposeCount, 1);
    });

    test('all cleanup steps are attempted and raw errors are hidden', () async {
      final deps = _Deps(rtcDisposeThrows: true);
      final composition = deps.create(_enabledProductionConfig());

      await expectLater(
        composition.dispose(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(composition.runtime.state.status, CallV2RuntimeStatus.stopped);
      expect(deps.rtc.disposeCount, 1);
    });
  });
}

class _Deps {
  _Deps({bool rtcDisposeThrows = false})
      : rtc = _FakeRtcTransport(disposeThrows: rtcDisposeThrows);

  final _FakeCallableTransport callable = _FakeCallableTransport();
  final _FakeSnapshotTransport snapshots = _FakeSnapshotTransport();
  final _FakeFirebaseAuth auth = _FakeFirebaseAuth();
  final _FakeAppCheckTransport appCheck = _FakeAppCheckTransport();
  final _FakePermissionTransport permissions = _FakePermissionTransport();
  final _FakeRtcTransport rtc;

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

  void expectNoExternalCalls() {
    expect(callable.calls, 0);
    expect(snapshots.callStreams, 0);
    expect(snapshots.participantStreams, 0);
    expect(auth.reads, 0);
    expect(appCheck.calls, 0);
    expect(permissions.requests, isEmpty);
    expect(rtc.initializeCount, 0);
    expect(rtc.joinCount, 0);
    expect(rtc.leaveCount, 0);
    expect(rtc.disposeCount, 0);
  }
}

class _FakeCallableTransport implements CallV2CallableTransport {
  int calls = 0;

  @override
  Future<Object?> call(
      String callableName, Map<String, Object?> request) async {
    calls += 1;
    return <String, Object?>{
      'callId': 'callA',
      'lifecycleState': 'ringing',
      'version': 1,
      'idempotentReplay': false,
    };
  }
}

class _FakeSnapshotTransport implements CallV2DocumentSnapshotTransport {
  int callStreams = 0;
  int participantStreams = 0;

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> callDocument(
    String collectionName,
    String callId,
  ) {
    callStreams += 1;
    return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> participantDocument(
    String collectionName,
    String callId,
    String participantCollectionName,
    String participantUid,
  ) {
    participantStreams += 1;
    return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
  }
}

class _FakeFirebaseAuth implements FirebaseAuth {
  int reads = 0;
  User? user = _FakeUser('localUser');

  @override
  User? get currentUser {
    reads += 1;
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

class _FakeAppCheckTransport implements CallV2AppCheckTransport {
  int calls = 0;

  @override
  Future<String?> getToken() async {
    calls += 1;
    return 'appCheckToken';
  }
}

class _FakePermissionTransport implements CallV2PermissionTransport {
  final requests = <CallV2MediaPermission>[];

  @override
  Future<CallV2PermissionStatus> request(
    CallV2MediaPermission permission,
  ) async {
    requests.add(permission);
    return CallV2PermissionStatus.granted;
  }
}

class _FakeRtcTransport implements CallV2RtcEngineTransport {
  _FakeRtcTransport({required this.disposeThrows});

  final bool disposeThrows;
  int initializeCount = 0;
  int joinCount = 0;
  int leaveCount = 0;
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
  Future<void> leaveChannel() async {
    leaveCount += 1;
  }

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

CallV2RuntimeConfiguration _disabledLocalConfig({
  String callCollectionName = 'calls',
}) {
  return CallV2RuntimeConfiguration(
    enabled: false,
    environment: CallV2Environment.local,
    rtcProvider: CallV2RtcProviderKind.none,
    rtcAppIdReference: '',
    callCollectionName: callCollectionName,
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: const Duration(seconds: 60),
  );
}

CallV2RuntimeConfiguration _disabledProductionConfig() {
  return const CallV2RuntimeConfiguration(
    enabled: false,
    environment: CallV2Environment.production,
    rtcProvider: CallV2RtcProviderKind.none,
    rtcAppIdReference: '',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: Duration(seconds: 60),
  );
}

CallV2RuntimeConfiguration _enabledProductionConfig({
  CallV2RtcProviderKind rtcProvider = CallV2RtcProviderKind.agora,
}) {
  return CallV2RuntimeConfiguration(
    enabled: true,
    environment: CallV2Environment.production,
    rtcProvider: rtcProvider,
    rtcAppIdReference: 'CALL_V2_AGORA_APP_ID',
    callCollectionName: 'calls',
    participantSubcollectionName: 'participants',
    rtcTokenMaxLifetime: callV2AcceptedRtcTokenMaxLifetime,
    minimumTokenRemainingValidity: const Duration(seconds: 60),
  );
}

Map<String, Object?> _startRequest() {
  return <String, Object?>{
    'calleeUid': 'calleeUser',
    'isVideo': false,
    'idempotencyKey': 'startKey',
  };
}

CallV2RtcSessionConfig _rtcConfig() {
  return const CallV2RtcSessionConfig(
    callId: 'callA',
    channelName: 'channelA',
    rtcUid: 123,
    isVideo: false,
    token: 'rtcToken',
  );
}

List<CallV2ProductionReadinessIssueCode> _readinessCodes(
  CallV2ProductionReadinessResult result,
) {
  return result.issues.map((issue) => issue.code).toList();
}

void _expectNoStartupUiOrRouteWiring() {
  final productionFiles = Directory('lib/call_v2/production')
      .listSync(recursive: true)
      .whereType<File>();
  final source =
      productionFiles.map((file) => file.readAsStringSync()).join('\n');

  for (final forbidden in <String>[
    'lib/main.dart',
    'lib/services/',
    'lib/screens/',
    'Navigator',
    'MaterialPageRoute',
    'runApp',
  ]) {
    expect(source.contains(forbidden), isFalse, reason: forbidden);
  }
}

const _audioPermissionRequest = CallV2MediaPermissionRequest(
  requiresMicrophone: true,
  requiresCamera: false,
);

const _videoPermissionRequest = CallV2MediaPermissionRequest(
  requiresMicrophone: true,
  requiresCamera: true,
);
