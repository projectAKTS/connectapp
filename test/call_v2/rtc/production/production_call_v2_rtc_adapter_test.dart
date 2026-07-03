import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/production/call_v2_rtc_engine_transport.dart';
import 'package:connect_app/call_v2/rtc/production/production_call_v2_rtc_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects', () {
      final transport = _FakeTransport();

      final adapter = _adapter(transport: transport);

      expect(adapter.state, ProductionCallV2RtcAdapterState.uninitialized);
      expect(transport.operations, isEmpty);
      expect(transport.eventListenCount, 0);
    });

    test('source has no singleton, Firebase, startup, UI, SDK, or writes', () {
      final sources = _productionSources();

      for (final forbidden in <String>[
        'Firebase.initializeApp',
        'FirebaseFirestore.instance',
        'FirebaseAuth.instance',
        'FirebaseFunctions.instance',
        'FirebaseAppCheck.instance',
        'AgoraRtcEngine',
        'agora_rtc_engine',
        'createAgoraRtcEngine',
        'CallV2Runtime(',
        'CallV2Harness(',
        'Navigator',
        'MaterialPageRoute',
        'BuildContext',
        'runApp',
        'serviceLocator',
        'getIt',
        '.set(',
        '.update(',
        '.delete(',
        'Platform.environment',
        'String.fromEnvironment',
        'dotenv',
        'print(',
        'debugPrint',
        'developer.log',
      ]) {
        expect(sources.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('default RTC adapter capability remains false', () {
      expect(callV2NoProductionCapabilities.rtcAdapterAvailable, isFalse);
    });
  });

  group('feature gate', () {
    test('disabled operations reject without transport calls', () async {
      final transport = _FakeTransport();
      final adapter = _adapter(enabled: false, transport: transport);

      await expectLater(
        adapter.initialize(_config()),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        adapter.joinChannel(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        adapter.setMicrophoneEnabled(false),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await expectLater(
        adapter.setCameraEnabled(true),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(transport.operations, isEmpty);
    });

    test('cleanup remains allowed after gate disablement', () async {
      var enabled = true;
      final transport = _FakeTransport();
      final adapter = _adapter(
        transport: transport,
        isFeatureEnabled: () => enabled,
      );

      await adapter.initialize(_config());
      await adapter.joinChannel();
      transport.emit(const CallV2RtcEngineJoined());
      enabled = false;

      await adapter.leaveChannel();
      await adapter.dispose();

      expect(
          transport.operations,
          containsAllInOrder(<String>[
            'initialize',
            'join',
            'leave',
            'dispose',
          ]));
      expect(adapter.state, ProductionCallV2RtcAdapterState.disposed);
    });
  });

  group('initialization', () {
    test('valid config initializes once and forwards audio config exactly',
        () async {
      final transport = _FakeTransport();
      final adapter = _adapter(transport: transport);
      final config = _config(isVideo: false);

      await adapter.initialize(config);
      await adapter.initialize(config);

      expect(transport.initializeCount, 1);
      expect(transport.lastSession, _sessionFor(config));
      expect(adapter.state, ProductionCallV2RtcAdapterState.initialized);
    });

    test('video config and token are forwarded only to transport', () async {
      final transport = _FakeTransport();
      final adapter = _adapter(transport: transport);
      final config = _config(isVideo: true, token: _secretToken);

      await adapter.initialize(config);

      expect(transport.lastSession, _sessionFor(config));
      expect(transport.lastSession!.token, _secretToken);
      expect(adapter.hasRetainedCredentials, isTrue);
      expect(adapter.toString(), isNot(contains(_secretToken)));
      expect(adapter.state.toString(), isNot(contains(_secretToken)));
    });

    test('duplicate pending initialize shares one transport call', () async {
      final transport = _FakeTransport()..holdInitialize = Completer<void>();
      final adapter = _adapter(transport: transport);

      final first = adapter.initialize(_config());
      final second = adapter.initialize(_config());
      await _pump();
      transport.holdInitialize!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(transport.initializeCount, 1);
    });

    test('conflicting initialize is rejected', () async {
      final transport = _FakeTransport()..holdInitialize = Completer<void>();
      final adapter = _adapter(transport: transport);
      final first = adapter.initialize(_config());

      await expectLater(
        adapter.initialize(_config(channelName: 'other_channel')),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      transport.holdInitialize!.complete();
      await first;

      expect(transport.initializeCount, 1);
    });

    test('initialize failure is controlled and clears retained credentials',
        () async {
      final transport = _FakeTransport()..failInitialize = true;
      final adapter = _adapter(transport: transport);

      await expectLater(
        adapter.initialize(_config(token: _secretToken)),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(adapter.state, ProductionCallV2RtcAdapterState.uninitialized);
      expect(adapter.hasRetainedCredentials, isFalse);
      expect(adapter.toString(), isNot(contains(_secretToken)));
    });
  });

  group('join', () {
    test('join before initialize is rejected', () async {
      final adapter = _adapter();

      await expectLater(
        adapter.joinChannel(),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });

    test('join after initialize calls transport once', () async {
      final transport = _FakeTransport();
      final adapter = _adapter(transport: transport);

      await adapter.initialize(_config());
      await adapter.joinChannel();

      expect(transport.joinCount, 1);
      expect(adapter.state, ProductionCallV2RtcAdapterState.joining);
    });

    test('duplicate join while pending shares one transport call', () async {
      final transport = _FakeTransport()..holdJoin = Completer<void>();
      final adapter = _adapter(transport: transport);

      await adapter.initialize(_config());
      final first = adapter.joinChannel();
      final second = adapter.joinChannel();
      await _pump();
      transport.holdJoin!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(transport.joinCount, 1);
    });

    test('joined callback emits accepted joined event', () async {
      final started = await _joinedAdapter();
      final events = <CallV2RtcEvent>[];
      final sub = started.adapter.events.listen(events.add);

      started.transport.emit(const CallV2RtcEngineJoined());
      await _pump();
      await sub.cancel();

      expect(
          events,
          isA<List<CallV2RtcEvent>>().having(
            (items) => items.whereType<CallV2RtcJoined>().length,
            'joined count',
            1,
          ));
      expect(started.adapter.state, ProductionCallV2RtcAdapterState.joined);
    });

    test('join failure is controlled and has no automatic retry', () async {
      final transport = _FakeTransport()..failJoin = true;
      final adapter = _adapter(transport: transport);

      await adapter.initialize(_config());
      await expectLater(
        adapter.joinChannel(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(transport.joinCount, 1);
      expect(adapter.state, ProductionCallV2RtcAdapterState.initialized);
    });

    test('stale join completion after leave cannot reactivate', () async {
      final transport = _FakeTransport()..holdJoin = Completer<void>();
      final adapter = _adapter(transport: transport);

      await adapter.initialize(_config());
      final join = adapter.joinChannel();
      await _pump();
      await adapter.leaveChannel();
      transport.holdJoin!.complete();
      await expectLater(
        join,
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(adapter.state, ProductionCallV2RtcAdapterState.uninitialized);
      expect(adapter.hasRetainedCredentials, isFalse);
    });

    test('stale join completion after dispose cannot reactivate', () async {
      final transport = _FakeTransport()..holdJoin = Completer<void>();
      final adapter = _adapter(transport: transport);

      await adapter.initialize(_config());
      final join = adapter.joinChannel();
      await _pump();
      await adapter.dispose();
      transport.holdJoin!.complete();
      await expectLater(
        join,
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(adapter.state, ProductionCallV2RtcAdapterState.disposed);
    });
  });

  group('media controls', () {
    test('microphone and camera toggles are forwarded', () async {
      final started = await _joinedAdapter();

      await started.adapter.setMicrophoneEnabled(false);
      await started.adapter.setCameraEnabled(true);

      expect(started.transport.microphoneCalls, <bool>[false]);
      expect(started.transport.cameraCalls, <bool>[true]);
    });

    test('audio mode rejects camera enable and allows camera disable',
        () async {
      final started = await _joinedAdapter(config: _config(isVideo: false));

      await expectLater(
        started.adapter.setCameraEnabled(true),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await started.adapter.setCameraEnabled(false);

      expect(started.transport.cameraCalls, <bool>[false]);
    });

    test('controls before initialize and after dispose are rejected', () async {
      final adapter = _adapter();

      await expectLater(
        adapter.setMicrophoneEnabled(false),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
      await adapter.dispose();
      await expectLater(
        adapter.setCameraEnabled(false),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });
  });

  group('events', () {
    test('event ordering and remote presence events are preserved', () async {
      final started = await _joinedAdapter();
      final events = <String>[];
      final sub = started.adapter.events.listen(
        (event) => events.add(event.runtimeType.toString()),
      );

      started.transport.emit(const CallV2RtcEngineJoined());
      started.transport.emit(const CallV2RtcEngineRemoteParticipantJoined());
      started.transport.emit(const CallV2RtcEngineRemoteParticipantLeft());
      started.transport.emit(const CallV2RtcEngineReconnecting());
      started.transport.emit(const CallV2RtcEngineDisconnected());
      started.transport.emit(const CallV2RtcEngineReconnected());
      await _pump();
      await sub.cancel();

      expect(events, <String>[
        'CallV2RtcJoined',
        'CallV2RtcRemoteParticipantJoined',
        'CallV2RtcRemoteParticipantLeft',
        'CallV2RtcReconnecting',
        'CallV2RtcDisconnected',
        'CallV2RtcReconnected',
      ]);
    });

    test('unknown transport error is sanitized', () async {
      final started = await _joinedAdapter();
      final events = <CallV2RtcEvent>[];
      final sub = started.adapter.events.listen(events.add);

      started.transport.emit(
        const CallV2RtcEngineFailure(CallV2RtcErrorCategory.unknown),
      );
      await _pump();
      await sub.cancel();

      final fatal = events.whereType<CallV2RtcFatalError>().single;
      expect(fatal.category, CallV2RtcErrorCategory.unknown);
      expect(fatal.toString(), isNot(contains(_secretToken)));
      expect(fatal.toString(), isNot(contains('raw sdk')));
    });

    test('events after dispose are ignored and stream closes', () async {
      final started = await _joinedAdapter();
      var done = false;
      final events = <CallV2RtcEvent>[];
      started.adapter.events.listen(events.add, onDone: () => done = true);

      await started.adapter.dispose();
      started.transport.emit(const CallV2RtcEngineJoined());
      await _pump();

      expect(events, isEmpty);
      expect(done, isTrue);
    });

    test('adapter emits no lifecycle mutation event', () async {
      final started = await _joinedAdapter();
      final events = <CallV2RtcEvent>[];
      final sub = started.adapter.events.listen(events.add);

      started.transport.emit(const CallV2RtcEngineJoined());
      started.transport.emit(const CallV2RtcEngineDisconnected());
      await _pump();
      await sub.cancel();

      expect(
        events.map((event) => event.runtimeType.toString()),
        isNot(contains('CallLifecycle')),
      );
    });

    test('joined callback during leaving is ignored', () async {
      final started = await _joinedAdapterInJoinedState();
      final events = <CallV2RtcEvent>[];
      final sub = started.adapter.events.listen(events.add);
      started.transport.holdLeave = Completer<void>();

      final leave = started.adapter.leaveChannel();
      await _pump();
      started.transport.emit(const CallV2RtcEngineJoined());
      await _pump();

      expect(started.adapter.state, ProductionCallV2RtcAdapterState.leaving);
      expect(events.whereType<CallV2RtcJoined>(), isEmpty);
      started.transport.holdLeave!.complete();
      await leave;
      await sub.cancel();
    });

    test('cleanup state suppresses reconnect remote failure and disconnect',
        () async {
      final started = await _joinedAdapterInJoinedState();
      final events = <CallV2RtcEvent>[];
      final sub = started.adapter.events.listen(events.add);
      started.transport.holdLeave = Completer<void>();

      final leave = started.adapter.leaveChannel();
      await _pump();
      started.transport.emit(const CallV2RtcEngineReconnected());
      started.transport.emit(const CallV2RtcEngineRemoteParticipantJoined());
      started.transport.emit(const CallV2RtcEngineRemoteParticipantLeft());
      started.transport.emit(
        const CallV2RtcEngineFailure(CallV2RtcErrorCategory.unknown),
      );
      started.transport.emit(const CallV2RtcEngineDisconnected());
      await _pump();

      expect(started.adapter.state, ProductionCallV2RtcAdapterState.leaving);
      expect(events, isEmpty);
      started.transport.holdLeave!.complete();
      await leave;
      await sub.cancel();
    });

    test('joined callback while initialized is ignored', () async {
      final transport = _FakeTransport();
      final adapter = _adapter(transport: transport);
      final events = <CallV2RtcEvent>[];
      final sub = adapter.events.listen(events.add);

      await adapter.initialize(_config());
      transport.emit(const CallV2RtcEngineJoined());
      await _pump();
      await sub.cancel();

      expect(adapter.state, ProductionCallV2RtcAdapterState.initialized);
      expect(events.whereType<CallV2RtcJoined>(), isEmpty);
    });

    test('joined callback while joining transitions once', () async {
      final started = await _joinedAdapter();
      final events = <CallV2RtcEvent>[];
      final sub = started.adapter.events.listen(events.add);

      started.transport.emit(const CallV2RtcEngineJoined());
      started.transport.emit(const CallV2RtcEngineJoined());
      await _pump();
      await sub.cancel();

      expect(started.adapter.state, ProductionCallV2RtcAdapterState.joined);
      expect(events.whereType<CallV2RtcJoined>().length, 1);
    });

    test('reconnected callback while initialized does not transition to joined',
        () async {
      final transport = _FakeTransport();
      final adapter = _adapter(transport: transport);
      final events = <CallV2RtcEvent>[];
      final sub = adapter.events.listen(events.add);

      await adapter.initialize(_config());
      transport.emit(const CallV2RtcEngineReconnected());
      await _pump();
      await sub.cancel();

      expect(adapter.state, ProductionCallV2RtcAdapterState.initialized);
      expect(events.whereType<CallV2RtcReconnected>(), isEmpty);
    });

    test('remote events while initialized are ignored', () async {
      final transport = _FakeTransport();
      final adapter = _adapter(transport: transport);
      final events = <CallV2RtcEvent>[];
      final sub = adapter.events.listen(events.add);

      await adapter.initialize(_config());
      transport.emit(const CallV2RtcEngineRemoteParticipantJoined());
      transport.emit(const CallV2RtcEngineRemoteParticipantLeft());
      await _pump();
      await sub.cancel();

      expect(events.whereType<CallV2RtcRemoteParticipantJoined>(), isEmpty);
      expect(events.whereType<CallV2RtcRemoteParticipantLeft>(), isEmpty);
    });

    test('remote events while joined are emitted in order', () async {
      final started = await _joinedAdapterInJoinedState();
      final events = <String>[];
      final sub = started.adapter.events.listen(
        (event) => events.add(event.runtimeType.toString()),
      );

      started.transport.emit(const CallV2RtcEngineRemoteParticipantJoined());
      started.transport.emit(const CallV2RtcEngineRemoteParticipantLeft());
      await _pump();
      await sub.cancel();

      expect(events, <String>[
        'CallV2RtcRemoteParticipantJoined',
        'CallV2RtcRemoteParticipantLeft',
      ]);
    });

    test('events after leave completes are ignored', () async {
      final started = await _joinedAdapterInJoinedState();
      final events = <CallV2RtcEvent>[];
      final sub = started.adapter.events.listen(events.add);

      await started.adapter.leaveChannel();
      started.transport.emit(const CallV2RtcEngineJoined());
      started.transport.emit(const CallV2RtcEngineReconnected());
      started.transport.emit(const CallV2RtcEngineRemoteParticipantJoined());
      await _pump();
      await sub.cancel();

      expect(events, isEmpty);
      expect(
          started.adapter.state, ProductionCallV2RtcAdapterState.uninitialized);
    });

    test('late joined callback after held join and leave emits no joined',
        () async {
      final transport = _FakeTransport()
        ..holdJoin = Completer<void>()
        ..holdLeave = Completer<void>();
      final adapter = _adapter(transport: transport);
      final events = <CallV2RtcEvent>[];
      final sub = adapter.events.listen(events.add);

      await adapter.initialize(_config());
      final join = adapter.joinChannel();
      await _pump();
      final leave = adapter.leaveChannel();
      await _pump();
      transport.emit(const CallV2RtcEngineJoined());
      await _pump();
      transport.holdLeave!.complete();
      await leave;
      transport.holdJoin!.complete();
      await expectLater(
        join,
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );
      await sub.cancel();

      expect(events.whereType<CallV2RtcJoined>(), isEmpty);
      expect(adapter.state, ProductionCallV2RtcAdapterState.uninitialized);
    });

    test('late joined callback after held join and dispose emits no joined',
        () async {
      final transport = _FakeTransport()
        ..holdJoin = Completer<void>()
        ..holdLeave = Completer<void>();
      final adapter = _adapter(transport: transport);
      final events = <CallV2RtcEvent>[];
      adapter.events.listen(events.add);

      await adapter.initialize(_config());
      final join = adapter.joinChannel();
      await _pump();
      final dispose = adapter.dispose();
      await _pump();
      transport.emit(const CallV2RtcEngineJoined());
      await _pump();
      transport.holdLeave!.complete();
      await dispose;
      transport.holdJoin!.complete();
      await expectLater(
        join,
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(events.whereType<CallV2RtcJoined>(), isEmpty);
      expect(adapter.state, ProductionCallV2RtcAdapterState.disposed);
    });

    test('stale filtering preserves valid joined-session events', () async {
      final started = await _joinedAdapterInJoinedState();
      final events = <String>[];
      final sub = started.adapter.events.listen(
        (event) => events.add(event.runtimeType.toString()),
      );

      started.transport.emit(const CallV2RtcEngineReconnecting());
      started.transport.emit(const CallV2RtcEngineReconnected());
      started.transport.emit(const CallV2RtcEngineDisconnected());
      started.transport.emit(
        const CallV2RtcEngineFailure(CallV2RtcErrorCategory.unknown),
      );
      await _pump();
      await sub.cancel();

      expect(events, <String>[
        'CallV2RtcReconnecting',
        'CallV2RtcReconnected',
        'CallV2RtcDisconnected',
        'CallV2RtcFatalError',
      ]);
    });
  });

  group('cleanup', () {
    test('leave is idempotent and clears credentials', () async {
      final started =
          await _joinedAdapter(config: _config(token: _secretToken));

      await started.adapter.leaveChannel();
      await started.adapter.leaveChannel();

      expect(started.transport.leaveCount, 1);
      expect(
          started.adapter.state, ProductionCallV2RtcAdapterState.uninitialized);
      expect(started.adapter.hasRetainedCredentials, isFalse);
    });

    test('dispose is idempotent and attempts leave before release', () async {
      final started = await _joinedAdapter();

      await started.adapter.dispose();
      await started.adapter.dispose();

      expect(
          started.transport.operations,
          containsAllInOrder(<String>[
            'leave',
            'dispose',
          ]));
      expect(started.transport.disposeCount, 1);
      expect(started.adapter.state, ProductionCallV2RtcAdapterState.disposed);
    });

    test('callback subscription removed during cleanup', () async {
      final started = await _joinedAdapter();

      await started.adapter.leaveChannel();

      expect(started.transport.cancelCount, 1);
    });

    test('engine release attempted despite leave failure', () async {
      final started = await _joinedAdapter();
      started.transport.failLeave = true;

      await expectLater(
        started.adapter.dispose(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(started.transport.leaveCount, 1);
      expect(started.transport.disposeCount, 1);
      expect(started.adapter.hasRetainedCredentials, isFalse);
      expect(started.adapter.state, ProductionCallV2RtcAdapterState.disposed);
    });

    test('cleanup failure is controlled and leaves no active resources',
        () async {
      final started = await _joinedAdapter();
      started.transport.failDispose = true;

      await expectLater(
        started.adapter.dispose(),
        throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
      );

      expect(started.adapter.state, ProductionCallV2RtcAdapterState.disposed);
      expect(started.adapter.hasRetainedCredentials, isFalse);
      expect(started.adapter.toString(), isNot(contains(_secretToken)));
    });
  });
}

ProductionCallV2RtcAdapter _adapter({
  bool enabled = true,
  _FakeTransport? transport,
  bool Function()? isFeatureEnabled,
}) {
  return ProductionCallV2RtcAdapter(
    featureGate: CallV2FeatureGate(enabled: enabled),
    transport: transport ?? _FakeTransport(),
    isFeatureEnabled: isFeatureEnabled,
  );
}

CallV2RtcSessionConfig _config({
  String callId = 'call_a',
  String channelName = 'channel_a',
  int rtcUid = 123,
  bool isVideo = true,
  String? token = 'credential_token',
}) {
  return CallV2RtcSessionConfig(
    callId: callId,
    channelName: channelName,
    rtcUid: rtcUid,
    isVideo: isVideo,
    token: token,
  );
}

CallV2RtcEngineSession _sessionFor(CallV2RtcSessionConfig config) {
  return CallV2RtcEngineSession(
    channelName: config.channelName,
    rtcUid: config.rtcUid,
    isVideo: config.isVideo,
    token: config.token,
  );
}

Future<_StartedAdapter> _joinedAdapter({
  CallV2RtcSessionConfig? config,
}) async {
  final transport = _FakeTransport();
  final adapter = _adapter(transport: transport);
  await adapter.initialize(config ?? _config());
  await adapter.joinChannel();
  return _StartedAdapter(adapter: adapter, transport: transport);
}

Future<_StartedAdapter> _joinedAdapterInJoinedState({
  CallV2RtcSessionConfig? config,
}) async {
  final started = await _joinedAdapter(config: config);
  started.transport.emit(const CallV2RtcEngineJoined());
  await _pump();
  expect(started.adapter.state, ProductionCallV2RtcAdapterState.joined);
  return started;
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

String _productionSources() {
  return <String>[
    'lib/call_v2/rtc/production/call_v2_rtc_engine_transport.dart',
    'lib/call_v2/rtc/production/production_call_v2_rtc_adapter.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

const _secretToken = 'secret_credential_token';

class _StartedAdapter {
  const _StartedAdapter({
    required this.adapter,
    required this.transport,
  });

  final ProductionCallV2RtcAdapter adapter;
  final _FakeTransport transport;
}

class _FakeTransport implements CallV2RtcEngineTransport {
  final operations = <String>[];
  final microphoneCalls = <bool>[];
  final cameraCalls = <bool>[];
  late final _events = StreamController<CallV2RtcEngineEvent>.broadcast(
    sync: true,
    onListen: () => eventListenCount += 1,
    onCancel: () => cancelCount += 1,
  );

  Completer<void>? holdInitialize;
  Completer<void>? holdJoin;
  Completer<void>? holdLeave;
  bool failInitialize = false;
  bool failJoin = false;
  bool failLeave = false;
  bool failDispose = false;
  CallV2RtcEngineSession? lastSession;
  int initializeCount = 0;
  int joinCount = 0;
  int leaveCount = 0;
  int disposeCount = 0;
  int eventListenCount = 0;
  int cancelCount = 0;

  @override
  Future<void> initialize(CallV2RtcEngineSession session) async {
    operations.add('initialize');
    initializeCount += 1;
    lastSession = session;
    await holdInitialize?.future;
    if (failInitialize) throw StateError('raw sdk initialize secret');
  }

  @override
  Future<void> joinChannel() async {
    operations.add('join');
    joinCount += 1;
    await holdJoin?.future;
    if (failJoin) throw StateError('raw sdk join secret');
  }

  @override
  Future<void> leaveChannel() async {
    operations.add('leave');
    leaveCount += 1;
    await holdLeave?.future;
    if (failLeave) throw StateError('raw sdk leave secret');
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    operations.add('microphone:$enabled');
    microphoneCalls.add(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    operations.add('camera:$enabled');
    cameraCalls.add(enabled);
  }

  @override
  Future<void> dispose() async {
    operations.add('dispose');
    disposeCount += 1;
    if (failDispose) throw StateError('raw sdk dispose secret');
  }

  @override
  Stream<CallV2RtcEngineEvent> get events => _events.stream;

  void emit(CallV2RtcEngineEvent event) {
    _events.add(event);
  }
}
