import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_media_orchestrator.dart';
import 'package:connect_app/call_v2/call_v2_runtime.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration.dart';
import 'package:connect_app/call_v2/call_v2_runtime_configuration_validator.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validator construction has no side effects', () {
    const CallV2RuntimeConfigurationValidator();

    expect(
      File('lib/call_v2/call_v2_runtime_configuration_validator.dart')
          .readAsStringSync(),
      isNot(contains('instance')),
    );
  });

  test('disabled local config with provider none is valid', () {
    final validation = _validate(const CallV2RuntimeConfiguration(
      enabled: false,
      environment: CallV2Environment.local,
      rtcProvider: CallV2RtcProviderKind.none,
      rtcAppIdReference: '',
      callCollectionName: 'calls',
      participantSubcollectionName: 'participants',
      rtcTokenMaxLifetime: Duration(minutes: 15),
      minimumTokenRemainingValidity: Duration(seconds: 60),
    ));

    expect(validation.isValid, isTrue);
    expect(validation.issues, isEmpty);
  });

  test('enabled config with provider none is invalid', () {
    expect(
      _codes(_validate(_validConfig(rtcProvider: CallV2RtcProviderKind.none))),
      contains(CallV2RuntimeConfigurationIssueCode.missingRtcProvider),
    );
  });

  test('production config with fake provider is invalid', () {
    expect(
      _codes(_validate(_validConfig(
        environment: CallV2Environment.production,
        rtcProvider: CallV2RtcProviderKind.fake,
      ))),
      contains(
        CallV2RuntimeConfigurationIssueCode.fakeProviderForbiddenInProduction,
      ),
    );
  });

  test('production config with real provider and valid reference is valid', () {
    final validation = _validate(_validConfig(
      environment: CallV2Environment.production,
      rtcProvider: CallV2RtcProviderKind.agora,
      rtcAppIdReference: 'CALL_V2_AGORA_APP_ID',
    ));

    expect(validation.isValid, isTrue);
  });

  test('missing RTC app reference invalid for real provider', () {
    expect(
      _codes(_validate(_validConfig(rtcAppIdReference: ''))),
      contains(
        CallV2RuntimeConfigurationIssueCode.missingRtcAppIdReference,
      ),
    );
  });

  test('RTC app reference whitespace invalid', () {
    expect(
      _codes(_validate(_validConfig(rtcAppIdReference: ' APP_ID'))),
      contains(
        CallV2RuntimeConfigurationIssueCode.missingRtcAppIdReference,
      ),
    );
  });

  test('collection name empty invalid', () {
    expect(
      _codes(_validate(_validConfig(callCollectionName: ''))),
      contains(CallV2RuntimeConfigurationIssueCode.invalidCollectionName),
    );
  });

  test('collection name whitespace invalid', () {
    expect(
      _codes(_validate(_validConfig(callCollectionName: ' calls'))),
      contains(CallV2RuntimeConfigurationIssueCode.invalidCollectionName),
    );
  });

  test('collection name containing slash invalid', () {
    expect(
      _codes(_validate(_validConfig(callCollectionName: 'calls/v2'))),
      contains(CallV2RuntimeConfigurationIssueCode.invalidCollectionName),
    );
  });

  test('participant collection invalid separately', () {
    final codes = _codes(_validate(_validConfig(
      participantSubcollectionName: 'participants/v2',
    )));

    expect(
      codes,
      contains(
        CallV2RuntimeConfigurationIssueCode.invalidParticipantCollectionName,
      ),
    );
    expect(
      codes,
      isNot(
          contains(CallV2RuntimeConfigurationIssueCode.invalidCollectionName)),
    );
  });

  test('token lifetime zero invalid', () {
    expect(
      _codes(_validate(_validConfig(rtcTokenMaxLifetime: Duration.zero))),
      contains(CallV2RuntimeConfigurationIssueCode.invalidTokenLifetime),
    );
  });

  test('token lifetime negative invalid', () {
    expect(
      _codes(_validate(_validConfig(
        rtcTokenMaxLifetime: const Duration(seconds: -1),
      ))),
      contains(CallV2RuntimeConfigurationIssueCode.invalidTokenLifetime),
    );
  });

  test('token lifetime above accepted maximum invalid', () {
    expect(
      _codes(_validate(_validConfig(
        rtcTokenMaxLifetime:
            callV2AcceptedRtcTokenMaxLifetime + const Duration(seconds: 1),
      ))),
      contains(CallV2RuntimeConfigurationIssueCode.invalidTokenLifetime),
    );
  });

  test('minimum remaining validity zero invalid', () {
    expect(
      _codes(_validate(_validConfig(
        minimumTokenRemainingValidity: Duration.zero,
      ))),
      contains(
        CallV2RuntimeConfigurationIssueCode.invalidMinimumRemainingValidity,
      ),
    );
  });

  test('minimum remaining validity negative invalid', () {
    expect(
      _codes(_validate(_validConfig(
        minimumTokenRemainingValidity: const Duration(seconds: -1),
      ))),
      contains(
        CallV2RuntimeConfigurationIssueCode.invalidMinimumRemainingValidity,
      ),
    );
  });

  test('minimum validity equal to lifetime invalid', () {
    expect(
      _codes(_validate(_validConfig(
        rtcTokenMaxLifetime: const Duration(minutes: 5),
        minimumTokenRemainingValidity: const Duration(minutes: 5),
      ))),
      contains(
        CallV2RuntimeConfigurationIssueCode.minimumValidityExceedsLifetime,
      ),
    );
  });

  test('minimum validity greater than lifetime invalid', () {
    expect(
      _codes(_validate(_validConfig(
        rtcTokenMaxLifetime: const Duration(minutes: 5),
        minimumTokenRemainingValidity: const Duration(minutes: 6),
      ))),
      contains(
        CallV2RuntimeConfigurationIssueCode.minimumValidityExceedsLifetime,
      ),
    );
  });

  test('multiple issues are accumulated deterministically', () {
    final validation = _validate(_validConfig(
      environment: CallV2Environment.production,
      rtcProvider: CallV2RtcProviderKind.fake,
      rtcAppIdReference: '',
      callCollectionName: 'calls/v2',
      participantSubcollectionName: '',
      rtcTokenMaxLifetime: Duration.zero,
      minimumTokenRemainingValidity: Duration.zero,
    ));

    expect(validation.issues.length, greaterThan(4));
  });

  test('issue ordering is stable', () {
    final validation = _validate(_validConfig(
      rtcProvider: CallV2RtcProviderKind.none,
      callCollectionName: '',
      participantSubcollectionName: '',
      rtcTokenMaxLifetime: Duration.zero,
      minimumTokenRemainingValidity: Duration.zero,
    ));

    expect(_codes(validation), <CallV2RuntimeConfigurationIssueCode>[
      CallV2RuntimeConfigurationIssueCode.missingRtcProvider,
      CallV2RuntimeConfigurationIssueCode.invalidCollectionName,
      CallV2RuntimeConfigurationIssueCode.invalidParticipantCollectionName,
      CallV2RuntimeConfigurationIssueCode.invalidTokenLifetime,
      CallV2RuntimeConfigurationIssueCode.invalidMinimumRemainingValidity,
      CallV2RuntimeConfigurationIssueCode.minimumValidityExceedsLifetime,
    ]);
  });

  test('validation does not throw for malformed values', () {
    expect(
      () => _validate(_validConfig(
        rtcAppIdReference: ' bad/reference ',
        callCollectionName: ' / ',
        participantSubcollectionName: ' ',
        rtcTokenMaxLifetime: const Duration(days: -1),
        minimumTokenRemainingValidity: const Duration(days: 2),
      )),
      returnsNormally,
    );
  });

  test('safe debug map contains only allowed fields', () {
    final debug = _validConfig().toSafeDebugMap();

    expect(debug.keys, <String>{
      'enabled',
      'environment',
      'rtcProvider',
      'rtcAppIdReference',
      'callCollectionName',
      'participantSubcollectionName',
      'rtcMaxLifetimeSeconds',
      'minimumRemainingValiditySeconds',
    });
  });

  test('safe debug map contains no token or secret field names', () {
    final text = _validConfig().toSafeDebugMap().toString().toLowerCase();

    for (final forbidden in _secretLikeTerms) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('toString contains no secret-like content', () {
    final text = _validConfig().toString().toLowerCase();

    for (final forbidden in _secretLikeTerms) {
      expect(text, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('existing runtime factory remains side-effect free', () {
    final deps = _RuntimeFactoryDeps();

    createCallV2Runtime(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: deps.api,
      callDocumentStream: deps.callDocumentStream,
      participantDocumentStream: deps.participantDocumentStream,
      rtcConfigProvider: deps.rtcConfigProvider,
      rtcAdapter: deps.rtcAdapter,
      localParticipantUid: deps.localParticipantUid,
      localParticipantRole: deps.localParticipantRole,
      mediaReportKeyFactory: deps.mediaReportKey,
      orchestrationKeyFactory: deps.orchestrationKey,
    );

    expect(deps.callStreamRequests, 0);
    expect(deps.participantStreamRequests, 0);
    expect(deps.rtcConfigProvider.requests, 0);
    expect(deps.rtcAdapter.initializeCount, 0);
    expect(deps.localUidReads, 0);
    expect(deps.localRoleReads, 0);
  });

  test('validated factory rejects invalid config before construction', () {
    final deps = _RuntimeFactoryDeps();

    expect(
      () => createValidatedCallV2Runtime(
        configuration: _validConfig(callCollectionName: ''),
        api: deps.api,
        callDocumentStream: deps.callDocumentStream,
        participantDocumentStream: deps.participantDocumentStream,
        rtcConfigProvider: deps.rtcConfigProvider,
        rtcAdapter: deps.rtcAdapter,
        localParticipantUid: deps.localParticipantUid,
        localParticipantRole: deps.localParticipantRole,
        mediaReportKeyFactory: deps.mediaReportKey,
        orchestrationKeyFactory: deps.orchestrationKey,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
    );
    expect(deps.callStreamRequests, 0);
    expect(deps.rtcConfigProvider.requests, 0);
  });

  test('validated factory accepts valid config', () {
    final deps = _RuntimeFactoryDeps();
    final runtime = createValidatedCallV2Runtime(
      configuration: _validConfig(),
      api: deps.api,
      callDocumentStream: deps.callDocumentStream,
      participantDocumentStream: deps.participantDocumentStream,
      rtcConfigProvider: deps.rtcConfigProvider,
      rtcAdapter: deps.rtcAdapter,
      localParticipantUid: deps.localParticipantUid,
      localParticipantRole: deps.localParticipantRole,
      mediaReportKeyFactory: deps.mediaReportKey,
      orchestrationKeyFactory: deps.orchestrationKey,
    );

    expect(runtime, isA<CallV2Runtime>());
    expect(runtime.state.status, CallV2RuntimeStatus.idle);
  });

  test('validated factory creates no network or stream activity', () {
    final deps = _RuntimeFactoryDeps();

    createValidatedCallV2Runtime(
      configuration: _validConfig(),
      api: deps.api,
      callDocumentStream: deps.callDocumentStream,
      participantDocumentStream: deps.participantDocumentStream,
      rtcConfigProvider: deps.rtcConfigProvider,
      rtcAdapter: deps.rtcAdapter,
      localParticipantUid: deps.localParticipantUid,
      localParticipantRole: deps.localParticipantRole,
      mediaReportKeyFactory: deps.mediaReportKey,
      orchestrationKeyFactory: deps.orchestrationKey,
    );

    expect(deps.api.invocations, isEmpty);
    expect(deps.callStreamRequests, 0);
    expect(deps.participantStreamRequests, 0);
    expect(deps.rtcConfigProvider.requests, 0);
    expect(deps.rtcAdapter.initializeCount, 0);
    expect(deps.mediaKeyCalls, 0);
    expect(deps.orchestrationKeyCalls, 0);
  });

  test('no Firebase singleton access', () {
    _expectSourcesDoNotContain(<String>[
      'Firebase.initializeApp',
      'FirebaseFirestore.instance',
      'FirebaseAuth.instance',
      'FirebaseFunctions.instance',
      'FirebaseAppCheck.instance',
    ]);
  });

  test('no RTC SDK import', () {
    _expectSourcesDoNotContain(<String>[
      'agora_rtc_engine',
      'AgoraRtcEngine',
      'Twilio',
    ]);
  });

  test('no environment-variable access', () {
    _expectSourcesDoNotContain(<String>[
      'Platform.environment',
      'String.fromEnvironment',
      'dotenv',
    ]);
  });

  test('no startup or route wiring', () {
    _expectSourcesDoNotContain(<String>[
      'main.dart',
      'Navigator',
      'ProviderScope',
      'getIt',
      'service locator',
    ]);
  });
}

CallV2RuntimeConfigurationValidation _validate(
  CallV2RuntimeConfiguration configuration,
) {
  return const CallV2RuntimeConfigurationValidator().validate(configuration);
}

List<CallV2RuntimeConfigurationIssueCode> _codes(
  CallV2RuntimeConfigurationValidation validation,
) {
  return validation.issues.map((issue) => issue.code).toList();
}

CallV2RuntimeConfiguration _validConfig({
  bool enabled = true,
  CallV2Environment environment = CallV2Environment.development,
  CallV2RtcProviderKind rtcProvider = CallV2RtcProviderKind.agora,
  String rtcAppIdReference = 'CALL_V2_RTC_APP_ID',
  String callCollectionName = 'calls',
  String participantSubcollectionName = 'participants',
  Duration rtcTokenMaxLifetime = const Duration(minutes: 15),
  Duration minimumTokenRemainingValidity = const Duration(seconds: 60),
}) {
  return CallV2RuntimeConfiguration(
    enabled: enabled,
    environment: environment,
    rtcProvider: rtcProvider,
    rtcAppIdReference: rtcAppIdReference,
    callCollectionName: callCollectionName,
    participantSubcollectionName: participantSubcollectionName,
    rtcTokenMaxLifetime: rtcTokenMaxLifetime,
    minimumTokenRemainingValidity: minimumTokenRemainingValidity,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

void _expectSourcesDoNotContain(List<String> forbiddenTerms) {
  final source = <String>[
    'lib/call_v2/call_v2_runtime_configuration.dart',
    'lib/call_v2/call_v2_runtime_configuration_validator.dart',
    'lib/call_v2/call_v2_runtime.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');

  for (final forbidden in forbiddenTerms) {
    expect(source, isNot(contains(forbidden)), reason: forbidden);
  }
}

class _RuntimeFactoryDeps {
  final api = _FakeCallableApi();
  final rtcConfigProvider = _FakeRtcConfigProvider();
  final rtcAdapter = _FakeRtcAdapter();
  var callStreamRequests = 0;
  var participantStreamRequests = 0;
  var localUidReads = 0;
  var localRoleReads = 0;
  var mediaKeyCalls = 0;
  var orchestrationKeyCalls = 0;

  Stream<DocumentSnapshot<Map<String, dynamic>>> callDocumentStream(String _) {
    callStreamRequests += 1;
    return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> participantDocumentStream(
    String _,
    String __,
  ) {
    participantStreamRequests += 1;
    return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
  }

  String localParticipantUid() {
    localUidReads += 1;
    return 'caller';
  }

  CallParticipantRole localParticipantRole() {
    localRoleReads += 1;
    return CallParticipantRole.caller;
  }

  String mediaReportKey(String _, ParticipantMediaState __) {
    mediaKeyCalls += 1;
    return 'media_key';
  }

  String orchestrationKey(
    String _,
    CallV2MediaOrchestrationKeyPurpose __,
  ) {
    orchestrationKeyCalls += 1;
    return 'orchestration_key';
  }
}

class _FakeCallableApi implements CallableCallV2Api {
  final invocations = <String>[];

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) async {
    invocations.add('accept');
    return null;
  }

  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) async {
    invocations.add('cancel');
    return null;
  }

  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) async {
    invocations.add('decline');
    return null;
  }

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) async {
    invocations.add('end');
    return null;
  }

  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) async {
    invocations.add('renew');
    return null;
  }

  @override
  Future<Object?> reportParticipantMediaV2(
    Map<String, Object?> request,
  ) async {
    invocations.add('media');
    return null;
  }

  @override
  Future<Object?> startCallV2(Map<String, Object?> request) async {
    invocations.add('start');
    return null;
  }
}

class _FakeRtcConfigProvider implements CallV2RtcConfigProvider {
  var requests = 0;

  @override
  Future<Object?> resolveRtcConfig(CallV2RtcConfigRequest request) async {
    requests += 1;
    return null;
  }
}

class _FakeRtcAdapter implements CallV2RtcAdapter {
  var initializeCount = 0;

  @override
  Stream<CallV2RtcEvent> get events => const Stream<CallV2RtcEvent>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize(CallV2RtcSessionConfig config) async {
    initializeCount += 1;
  }

  @override
  Future<void> joinChannel() async {}

  @override
  Future<void> leaveChannel() async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}
}

const _secretLikeTerms = <String>[
  'rawtoken',
  'access_token',
  'authtoken',
  'secret',
  'privatekey',
  'private key',
  'serviceaccount',
  'service account',
  'apikey',
  'api key',
  'clientsecret',
];
