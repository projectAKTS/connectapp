import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/integration/call_v2_rollout_policy.dart';
import 'package:connect_app/call_v2/rtc/agora_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/internal_call_v2_rtc_adapter_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real RTC adapter skeleton remains explicitly disabled', () {
    const gate = AgoraCallV2RtcAdapterGate(
      featureGate: CallV2FeatureGate(enabled: false),
    );

    expect(CallV2RolloutPolicy.productionEnabled, isFalse);
    expect(gate.allowsConstruction, isFalse);
    expect(gate.productionJoinDisabled, isTrue);
  });

  test('real adapter performs no RTC work before explicit calls', () {
    final client = _FakeAgoraClient();
    final adapter = AgoraCallV2RtcAdapter(
      gate: const AgoraCallV2RtcAdapterGate(
        featureGate: CallV2FeatureGate(enabled: true),
        internalGate: InternalCallV2RtcAdapterGate(
          allowAdapterConstruction: true,
          allowInitialization: true,
          allowJoin: true,
        ),
      ),
      client: client,
    );
    addTearDown(adapter.dispose);

    expect(client.initializeCount, 0);
    expect(client.joinCount, 0);
  });

  test('real adapter initializes joins leaves and disposes explicitly',
      () async {
    final client = _FakeAgoraClient();
    final adapter = AgoraCallV2RtcAdapter(
      gate: const AgoraCallV2RtcAdapterGate(
        featureGate: CallV2FeatureGate(enabled: true),
        internalGate: InternalCallV2RtcAdapterGate(
          allowAdapterConstruction: true,
          allowInitialization: true,
          allowJoin: true,
        ),
      ),
      client: client,
    );

    await adapter.initialize(_config);
    await adapter.joinChannel();
    await adapter.leaveChannel();
    await adapter.dispose();
    await adapter.dispose();

    expect(client.initializeCount, 1);
    expect(client.joinCount, 1);
    expect(client.leaveCount, 1);
    expect(client.disposeCount, 1);
  });

  test('real adapter emits safe join lifecycle events', () async {
    final client = _FakeAgoraClient(emitJoined: true);
    final adapter = AgoraCallV2RtcAdapter(
      gate: const AgoraCallV2RtcAdapterGate(
        featureGate: CallV2FeatureGate(enabled: true),
        internalGate: InternalCallV2RtcAdapterGate(
          allowAdapterConstruction: true,
          allowInitialization: true,
          allowJoin: true,
        ),
      ),
      client: client,
    );
    addTearDown(adapter.dispose);
    final events = <CallV2RtcEvent>[];
    final subscription = adapter.events.listen(events.add);
    addTearDown(subscription.cancel);

    await adapter.initialize(_config);
    await adapter.joinChannel();

    expect(events, contains(isA<CallV2RtcJoinStarted>()));
    expect(events, contains(isA<CallV2RtcJoined>()));
    expect(events.toString().toLowerCase(), isNot(contains('token_a')));
    expect(events.toString().toLowerCase(), isNot(contains('channel_a')));
  });

  test('join before initialize rejects without client work', () async {
    final client = _FakeAgoraClient();
    final adapter = AgoraCallV2RtcAdapter(
      gate: const AgoraCallV2RtcAdapterGate(
        featureGate: CallV2FeatureGate(enabled: true),
        internalGate: InternalCallV2RtcAdapterGate(
          allowAdapterConstruction: true,
          allowInitialization: true,
          allowJoin: true,
        ),
      ),
      client: client,
    );
    addTearDown(adapter.dispose);

    await expectLater(adapter.joinChannel(), throwsA(anything));
    expect(client.joinCount, 0);
  });

  test('missing App ID style client rejection is controlled', () async {
    final client = _FakeAgoraClient(rejectInitialize: true);
    final adapter = AgoraCallV2RtcAdapter(
      gate: const AgoraCallV2RtcAdapterGate(
        featureGate: CallV2FeatureGate(enabled: true),
        internalGate: InternalCallV2RtcAdapterGate(
          allowAdapterConstruction: true,
          allowInitialization: true,
          allowJoin: true,
        ),
      ),
      client: client,
    );
    addTearDown(adapter.dispose);

    await expectLater(adapter.initialize(_config), throwsA(anything));
    expect(client.initializeCount, 1);
    expect(client.joinCount, 0);
  });

  test('real adapter gate rejects setup and join when disabled', () async {
    final client = _FakeAgoraClient();
    final adapter = AgoraCallV2RtcAdapter(
      gate: const AgoraCallV2RtcAdapterGate(
        featureGate: CallV2FeatureGate(enabled: false),
      ),
      client: client,
    );
    addTearDown(adapter.dispose);

    await expectLater(adapter.initialize(_config), throwsA(anything));
    expect(client.initializeCount, 0);
  });

  test('source imports Agora but avoids startup routing and backend work', () {
    final source = File('lib/call_v2/rtc/agora_call_v2_rtc_adapter.dart')
        .readAsStringSync();

    expect(source, contains('agora_rtc_engine'));
    for (final forbidden in <String>[
      'Firebase',
      'Navigator',
      'permission_handler',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real adapter safe debug avoids unsafe identifier wording', () {
    final adapter = AgoraCallV2RtcAdapter(
      gate: const AgoraCallV2RtcAdapterGate(
        featureGate: CallV2FeatureGate(enabled: true),
        internalGate: InternalCallV2RtcAdapterGate(
          allowAdapterConstruction: true,
          allowInitialization: true,
          allowJoin: true,
        ),
      ),
      client: _FakeAgoraClient(),
    );
    addTearDown(adapter.dispose);

    final debug = adapter.toSafeDebugMap().toString().toLowerCase();
    for (final forbidden in <String>[
      'token',
      'channel',
      'uid',
      'user',
      'participant',
      'callid',
      'device',
      'credential',
      'secret',
      'raw',
      'payload',
      'stack',
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

const _config = CallV2RtcSessionConfig(
  callId: 'call_a',
  channelName: 'channel_a',
  rtcUid: 1,
  isVideo: true,
  token: 'token_a',
);

class _FakeAgoraClient implements AgoraCallV2RtcEngineClient {
  _FakeAgoraClient({
    this.emitJoined = false,
    this.rejectInitialize = false,
  });

  final bool emitJoined;
  final bool rejectInitialize;
  int initializeCount = 0;
  int joinCount = 0;
  int leaveCount = 0;
  int disposeCount = 0;

  @override
  Future<void> initialize({
    required CallV2RtcSessionConfig config,
    required void Function(CallV2RtcEvent event) emit,
  }) async {
    initializeCount += 1;
    if (rejectInitialize) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    if (emitJoined) {
      emit(const CallV2RtcJoined());
    }
  }

  @override
  Future<void> join() async {
    joinCount += 1;
  }

  @override
  Future<void> leave() async {
    leaveCount += 1;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }
}
