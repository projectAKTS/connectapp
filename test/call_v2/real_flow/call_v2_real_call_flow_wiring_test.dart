import 'dart:io';

import 'package:connect_app/call_v2/firebase/call_v2_dev_callable_target.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/real_flow/call_v2_real_call_flow_gate.dart';
import 'package:connect_app/screens/call/agora_call_screen.dart';
import 'package:connect_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validDevAppId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('default public real call flow remains legacy V1', () {
    const gate = CallV2RealCallFlowGate();
    final decision = gate.selectForUserStartedCall(isVideo: false);

    expect(decision.connectionSystem, CallV2RealCallConnectionSystem.legacyV1);
    expect(decision.callV2Selected, isFalse);
    expect(decision.fallbackUsed, isFalse);
  });

  test('developer gate selects Call V2 dev without manual app id define', () {
    const gate = CallV2RealCallFlowGate(
      config: CallV2RealCallFlowConfig(
        enabled: true,
        devCallableEnabled: true,
      ),
    );
    final decision = gate.selectForUserStartedCall(isVideo: true);

    expect(decision.connectionSystem, CallV2RealCallConnectionSystem.callV2Dev);
    expect(decision.callV2Selected, isTrue);
    expect(decision.devCallableSelected, isTrue);
    expect(decision.fallbackUsed, isFalse);
  });

  test('developer gate preserves V1 fallback when dev callable is disabled',
      () {
    const gate = CallV2RealCallFlowGate(
      config: CallV2RealCallFlowConfig(
        enabled: true,
        devCallableEnabled: false,
      ),
    );
    final decision = gate.selectForUserStartedCall(isVideo: false);

    expect(decision.connectionSystem, CallV2RealCallConnectionSystem.legacyV1);
    expect(decision.callV2Selected, isFalse);
    expect(decision.fallbackUsed, isTrue);
    expect(decision.blockerCode, 'dev_callable_disabled');
  });

  test('caller and receiver select Call V2 from invite marker', () {
    final callerSystem =
        callConnectionSystemFromInviteValue(callV2DevInviteSystemValue);
    final receiverSystem =
        callConnectionSystemFromInviteValue(callV2DevInviteSystemValue);

    expect(callerSystem, CallV2RealCallConnectionSystem.callV2Dev);
    expect(receiverSystem, CallV2RealCallConnectionSystem.callV2Dev);
    expect(callConnectionSystemFromInviteValue(null),
        CallV2RealCallConnectionSystem.legacyV1);
  });

  testWidgets('real call button selects Call V2 under developer gate',
      (tester) async {
    final starts = <CallV2RealCallFlowDecision>[];
    final service = CallService(
      currentUidProvider: () => 'local-participant',
      callV2Gate: const CallV2RealCallFlowGate(
        config: CallV2RealCallFlowConfig(
          enabled: true,
          devCallableEnabled: true,
        ),
      ),
      startSession: (
        context, {
        required toUid,
        required toName,
        required isVideo,
        required callV2Decision,
      }) async {
        starts.add(callV2Decision);
        return true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              key: const ValueKey<String>('real-call-button'),
              onPressed: () {
                service.startCall(
                  context,
                  toUid: 'remote-participant',
                  toName: 'Remote',
                  isVideo: false,
                );
              },
              child: const Text('Audio call'),
            );
          },
        ),
      ),
    );

    expect(starts, isEmpty);
    await tester.tap(find.byKey(const ValueKey<String>('real-call-button')));
    await tester.pump();

    expect(starts, hasLength(1));
    expect(starts.single.connectionSystem,
        CallV2RealCallConnectionSystem.callV2Dev);
  });

  testWidgets('public real call button remains on V1 fallback', (tester) async {
    final starts = <CallV2RealCallFlowDecision>[];
    final service = CallService(
      currentUidProvider: () => 'local-participant',
      startSession: (
        context, {
        required toUid,
        required toName,
        required isVideo,
        required callV2Decision,
      }) async {
        starts.add(callV2Decision);
        return true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                service.startCall(
                  context,
                  toUid: 'remote-participant',
                  toName: 'Remote',
                  isVideo: true,
                );
              },
              child: const Text('Video call'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Video call'));
    await tester.pump();

    expect(starts, hasLength(1));
    expect(starts.single.connectionSystem,
        CallV2RealCallConnectionSystem.legacyV1);
    expect(starts.single.fallbackUsed, isFalse);
  });

  test('Call V2 dev token helper calls deployed dev callable on demand only',
      () async {
    final client = _FakeCallableClient();
    final target = _FakeDevCallableTarget(client);

    expect(client.calls, isEmpty);

    final auth = await fetchCallV2DevAgoraToken(
      callIdentifier: 'real-call',
      participantIdentifier: 'local-participant',
      isVideo: false,
      devCallableTarget: target,
    );

    expect(client.calls, hasLength(1));
    expect(client.calls.single.name, 'callV2RtcToken');
    expect(client.calls.single.data.keys.toSet(),
        <String>{'callId', 'participantUid', 'isVideo'});
    expect(auth.appId, validDevAppId);
    expect(auth.channelName, 'safe-route');
    expect(auth.uid, 42);
    expect(auth.token, isNotEmpty);
  });

  test('real flow safe debug output avoids unsafe identifiers', () {
    const gate = CallV2RealCallFlowGate(
      config: CallV2RealCallFlowConfig(
        enabled: true,
        devCallableEnabled: true,
      ),
    );
    final debug = gate.toSafeDebugMap().toString().toLowerCase();

    for (final forbidden in <String>[
      'token',
      'channel',
      'uid',
      'user',
      'participant',
      'device',
      'secret',
      'payload',
      'raw',
      'CALL_V2_DEV_AGORA_APP_ID'.toLowerCase(),
      validDevAppId,
    ]) {
      expect(debug, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('real call status separates callable attempted from reached', () {
    final source =
        File('lib/screens/call/agora_call_screen.dart').readAsStringSync();

    expect(source, contains('callableAttempted='));
    expect(source, contains('callableReached='));
    final attemptedIndex = source.indexOf('_callV2CallableAttempted = true');
    final runtimeFetchIndex =
        source.indexOf('fetchCallV2DevAgoraToken(', attemptedIndex);
    expect(attemptedIndex, isNonNegative);
    expect(runtimeFetchIndex, isNonNegative);
    expect(attemptedIndex, lessThan(runtimeFetchIndex));
    expect(source, contains("_callV2CallableReached = true"));
    expect(source, contains("'callable_\${error.code.name}'"));
    expect(source, contains("'callable_unavailable'"));
  });
}

class _FakeDevCallableTarget implements CallV2DevCallableTarget {
  const _FakeDevCallableTarget(this.client);

  final _FakeCallableClient client;

  @override
  Future<FirebaseCallV2CallableTransport> createTransport() async {
    return FirebaseCallV2CallableTransport(client: client);
  }

  @override
  Map<String, Object?> toSafeDebugMap() {
    return const <String, Object?>{
      'devTargetReady': true,
      'callableReachable': true,
      'selectedRegion': 'us-central1',
    };
  }
}

class _FakeCallableClient implements FirebaseCallV2CallableClient {
  final calls = <_CallableInvocation>[];

  @override
  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls.add(_CallableInvocation(name, Map<String, Object?>.of(data)));
    return <String, Object?>{
      'status': 'ok',
      'result': <String, Object?>{
        'channelAlias': 'safe-route',
        'rtcUid': 42,
        'token': 'test-access',
        'appId': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'expiresInSeconds': 3600,
      },
    };
  }
}

class _CallableInvocation {
  const _CallableInvocation(this.name, this.data);

  final String name;
  final Map<String, Object?> data;
}
