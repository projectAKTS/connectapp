import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_firestore_subscription_coordinator.dart';
import 'package:connect_app/call_v2/call_v2_harness.dart';
import 'package:connect_app/call_v2/call_v2_media_orchestrator.dart';
import 'package:connect_app/call_v2/call_v2_media_session_controller.dart';
import 'package:connect_app/call_v2/call_v2_runtime.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video call snapshot-to-media happy path uses real V2 components',
      () async {
    final harness = _CallV2IntegrationHarness();

    expect(harness.api.mediaReports, isEmpty);
    expect(harness.rtcProvider.requests, isEmpty);
    expect(harness.rtcAdapter.initializeCount, 0);

    await harness.start();
    await harness.emit(CallLifecycle.ringing, version: 1);

    expect(harness.runtime.state.status, CallV2RuntimeStatus.running);
    expect(harness.harness.snapshot!.lifecycle, CallLifecycle.ringing);
    expect(harness.rtcProvider.requests, isEmpty);
    expect(harness.rtcAdapter.initializeCount, 0);
    expect(harness.rtcAdapter.joinCount, 0);

    await harness.bridge(isVideo: true);
    expect(harness.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.awaitingEligibility);
    expect(harness.rtcProvider.requests, isEmpty);

    await harness.emit(CallLifecycle.accepted, version: 2);
    final accepted = harness.bridge(isVideo: true);
    await _pump();
    expect(harness.rtcProvider.requests, hasLength(1));
    expect(harness.rtcProvider.requests.single.isVideo, isTrue);
    expect(harness.rtcAdapter.initializeCount, 0);

    harness.rtcProvider.completeNext(harness.rtcConfig(isVideo: true));
    await accepted;
    harness.rtcAdapter.emit(const CallV2RtcJoined());
    await _pump();

    expect(harness.api.mediaStates, <String>[
      'preparing',
      'joining',
      'joined',
    ]);
    expect(harness.api.mediaIdempotencyKeys, <String>[
      'call_a_preparing',
      'call_a_joining',
      'call_a_joined',
    ]);
    expect(harness.rtcAdapter.initializeCount, 1);
    expect(harness.rtcAdapter.joinCount, 1);
    expect(harness.rtcAdapter.lastConfig!.isVideo, isTrue);
    expect(harness.rtcAdapter.lastConfig!.token, _redactedToken);
    expect(
        harness.mediaController.state.status, CallV2MediaSessionStatus.joined);
    expect(harness.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.active);
    expect(harness.harness.snapshot!.lifecycle, CallLifecycle.accepted);

    await harness.emit(CallLifecycle.active, version: 3);
    await harness.bridge(isVideo: true);
    await harness.bridge(isVideo: true);
    await _pump();
    expect(harness.rtcProvider.requests, hasLength(1));
    expect(harness.rtcAdapter.initializeCount, 1);
    expect(harness.rtcAdapter.joinCount, 1);
    expect(harness.harness.snapshot!.lifecycle, CallLifecycle.active);

    await harness.emit(CallLifecycle.completed, version: 4);
    await harness.bridge(isVideo: true);
    await _pump();
    expect(harness.rtcAdapter.leaveCount, 1);
    expect(harness.rtcAdapter.disposeCount, 1);
    expect(harness.mediaController.state.status, CallV2MediaSessionStatus.left);
    expect(harness.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.stopped);
    expect(harness.api.mediaStates.last, 'left');

    await harness.runtime.stop();
    expect(harness.coordinator.status, CallV2SubscriptionStatus.stopped);
    expect(harness.runtime.state.status, CallV2RuntimeStatus.stopped);
  });

  test('audio call reaches adapter with audio session config', () async {
    final harness = _CallV2IntegrationHarness();

    await harness.start();
    await harness.emit(CallLifecycle.accepted, version: 1);
    final accepted = harness.bridge(isVideo: false);
    await _pump();
    harness.rtcProvider.completeNext(harness.rtcConfig(isVideo: false));
    await accepted;

    expect(harness.rtcProvider.requests.single.isVideo, isFalse);
    expect(harness.rtcAdapter.lastConfig!.isVideo, isFalse);
    expect(harness.rtcAdapter.initializeCount, 1);
    expect(harness.rtcAdapter.joinCount, 1);
    expect(harness.harness.snapshot!.lifecycle, CallLifecycle.accepted);
  });

  test('terminal during config resolution cannot start stale media', () async {
    final harness = _CallV2IntegrationHarness();

    await harness.start();
    await harness.emit(CallLifecycle.accepted, version: 1);
    final accepted = harness.bridge(isVideo: true);
    await _pump();
    expect(harness.rtcProvider.requests, hasLength(1));

    await harness.emit(CallLifecycle.completed, version: 2);
    await harness.bridge(isVideo: true);
    harness.rtcProvider.completeNext(harness.rtcConfig(isVideo: true));

    await expectLater(
      accepted,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    expect(harness.rtcAdapter.initializeCount, 0);
    expect(harness.rtcAdapter.joinCount, 0);
    expect(harness.mediaController.state.status, CallV2MediaSessionStatus.left);
    expect(harness.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.stopped);
    expect(harness.runtime.state.toString(), isNot(contains(_redactedToken)));
  });

  test('terminal during join leaves and stale completion cannot reactivate',
      () async {
    final harness = _CallV2IntegrationHarness()
      ..rtcAdapter.holdJoin = Completer<void>();

    await harness.start();
    await harness.emit(CallLifecycle.accepted, version: 1);
    final accepted = harness.bridge(isVideo: true);
    await _pump();
    harness.rtcProvider.completeNext(harness.rtcConfig(isVideo: true));
    await _pump();
    expect(harness.rtcAdapter.joinCount, 1);

    await harness.emit(CallLifecycle.completed, version: 2);
    await harness.bridge(isVideo: true);
    expect(harness.rtcAdapter.leaveCount, 1);
    expect(harness.mediaController.state.status, CallV2MediaSessionStatus.left);

    harness.rtcAdapter.holdJoin!.complete();
    await expectLater(
      accepted,
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    harness.rtcAdapter.emit(const CallV2RtcJoined());
    await _pump();

    expect(harness.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.stopped);
    expect(harness.mediaController.state.status, CallV2MediaSessionStatus.left);
  });

  test('duplicate snapshot storm shares resolving, joining, and active work',
      () async {
    final harness = _CallV2IntegrationHarness()
      ..rtcAdapter.holdJoin = Completer<void>();

    await harness.start();
    await harness.emit(CallLifecycle.accepted, version: 1);
    final first = harness.bridge(isVideo: true);
    final second = harness.bridge(isVideo: true);
    final third = harness.bridge(isVideo: true);
    await _pump();
    expect(harness.rtcProvider.requests, hasLength(1));
    expect(harness.orchestrationKeys, <String>[
      'call_a_resolveConfig',
      'call_a_preparing',
      'call_a_joining',
    ]);

    harness.rtcProvider.completeNext(harness.rtcConfig(isVideo: true));
    await _pump();
    expect(harness.rtcAdapter.initializeCount, 1);
    expect(harness.rtcAdapter.joinCount, 1);

    final duplicateWhileJoining = harness.bridge(isVideo: true);
    expect(harness.rtcAdapter.joinCount, 1);
    harness.rtcAdapter.holdJoin!.complete();
    await Future.wait(<Future<void>>[
      first,
      second,
      third,
      duplicateWhileJoining,
    ]);
    await harness.bridge(isVideo: true);
    await harness.emit(CallLifecycle.active, version: 2);
    await harness.bridge(isVideo: true);

    expect(harness.rtcProvider.requests, hasLength(1));
    expect(harness.rtcAdapter.initializeCount, 1);
    expect(harness.rtcAdapter.joinCount, 1);
    expect(harness.api.mediaStates, <String>['preparing', 'joining']);
  });

  test('different-call explicit snapshots are rejected before forwarding',
      () async {
    final harness = _CallV2IntegrationHarness();

    await harness.start();
    await harness.emit(CallLifecycle.accepted, version: 1);
    final accepted = harness.bridge(isVideo: true);
    await _pump();
    harness.rtcProvider.completeNext(harness.rtcConfig(isVideo: true));
    await accepted;

    await expectLater(
      harness.runtime.handleAuthoritativeSnapshot(
        _snapshot(callId: 'call_b', lifecycle: CallLifecycle.active),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await expectLater(
      harness.runtime.handleAuthoritativeSnapshot(
        _snapshot(callId: 'call_b', lifecycle: CallLifecycle.completed),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(harness.harness.snapshot!.callId, 'call_a');
    expect(harness.rtcAdapter.leaveCount, 0);
    await harness.emit(CallLifecycle.completed, version: 2);
    await harness.bridge(isVideo: true);
    expect(harness.rtcAdapter.leaveCount, 1);
  });

  test('provider and adapter failures are controlled and retryable', () async {
    final providerFailure = _CallV2IntegrationHarness()
      ..rtcProvider.nextError =
          const CallV2ClientError(CallV2ClientErrorCode.unavailable);

    await providerFailure.start();
    await providerFailure.emit(CallLifecycle.accepted, version: 1);
    await expectLater(
      providerFailure.bridge(isVideo: true),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    expect(providerFailure.rtcAdapter.initializeCount, 0);
    expect(providerFailure.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.failed);
    expect(providerFailure.orchestrator.state.errorCode,
        CallV2ClientErrorCode.unavailable);

    await providerFailure.emit(CallLifecycle.accepted, version: 2);
    final retry = providerFailure.bridge(isVideo: true);
    await _pump();
    providerFailure.rtcProvider
        .completeNext(providerFailure.rtcConfig(isVideo: true));
    await retry;
    expect(providerFailure.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.active);

    final adapterFailure = _CallV2IntegrationHarness()
      ..rtcAdapter.initializeError = StateError('provider secret');
    await adapterFailure.start();
    await adapterFailure.emit(CallLifecycle.accepted, version: 1);
    final failed = adapterFailure.bridge(isVideo: true);
    await _pump();
    adapterFailure.rtcProvider
        .completeNext(adapterFailure.rtcConfig(isVideo: true));
    await expectLater(
      failed,
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    expect(adapterFailure.rtcAdapter.disposeCount, 1);
    expect(adapterFailure.mediaController.state.status,
        CallV2MediaSessionStatus.failed);
    expect(adapterFailure.mediaController.state.errorCode,
        CallV2ClientErrorCode.unavailable);
    expect(adapterFailure.mediaController.state.toString(),
        isNot(contains('provider secret')));

    adapterFailure.rtcAdapter.initializeError = null;
    await adapterFailure.emit(CallLifecycle.accepted, version: 2);
    final adapterRetry = adapterFailure.bridge(isVideo: true);
    await _pump();
    adapterFailure.rtcProvider
        .completeNext(adapterFailure.rtcConfig(isVideo: true));
    await adapterRetry;
    expect(adapterFailure.rtcAdapter.initializeCount, 2);
    expect(adapterFailure.orchestrator.state.status,
        CallV2MediaOrchestrationStatus.active);
  });

  test('stop during runtime start and cleanup failure remain bounded',
      () async {
    late _CallV2IntegrationHarness stoppingHarness;
    stoppingHarness = _CallV2IntegrationHarness(
      callStreamOverride: _SynchronousDocumentStream(onBeforeListenReturn: () {
        unawaited(stoppingHarness.runtime.stop());
      }),
    );

    await expectLater(
      stoppingHarness.start(),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    await _pump();
    expect(stoppingHarness.runtime.state.status, CallV2RuntimeStatus.stopped);

    final fresh = _CallV2IntegrationHarness(callId: 'call_b');
    await fresh.start();
    expect(fresh.runtime.state.status, CallV2RuntimeStatus.running);

    final cleanup = _CallV2IntegrationHarness()
      ..api.failMediaStates.add('left');
    await cleanup.start();
    await cleanup.emit(CallLifecycle.accepted, version: 1);
    final accepted = cleanup.bridge(isVideo: true);
    await _pump();
    cleanup.rtcProvider.completeNext(cleanup.rtcConfig(isVideo: true));
    await accepted;

    await expectLater(
      cleanup.runtime.stop(),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    expect(cleanup.rtcAdapter.leaveCount, 1);
    expect(cleanup.rtcAdapter.disposeCount, 1);
    expect(cleanup.coordinator.status, CallV2SubscriptionStatus.stopped);
    expect(cleanup.runtime.state.status, CallV2RuntimeStatus.stopped);
    expect(cleanup.runtime.state.errorCode, CallV2ClientErrorCode.unavailable);
  });

  test('runtime integration source remains isolated from production wiring',
      () {
    final sources = <String>[
      'lib/call_v2/call_v2_runtime.dart',
      'test/call_v2/call_v2_runtime_integration_test.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    for (final forbidden in <String>[
      'Firebase' '.initializeApp',
      'FirebaseFirestore' '.instance',
      'FirebaseAuth' '.instance',
      'FirebaseFunctions' '.instance',
      'Naviga' 'tor',
      'main' '.dart',
      'Ago' 'ra',
      'Twi' 'lio',
      'get' 'It',
      'Provider' 'Scope',
      'service' ' locator',
      'background service' ' registration',
    ]) {
      expect(sources.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}

class _CallV2IntegrationHarness {
  _CallV2IntegrationHarness({
    this.callId = 'call_a',
    _TrackedDocumentSource? callStreamOverride,
  })  : api = _FakeCallableApi(),
        streams = _TrackedStreams(),
        rtcProvider = _FakeRtcConfigProvider(),
        rtcAdapter = _FakeRtcAdapter() {
    if (callStreamOverride != null) {
      streams.callStreamFor(callId, callStreamOverride);
    }
    runtime = createCallV2Runtime(
      featureGate: const CallV2FeatureGate(enabled: true),
      api: api,
      callDocumentStream: streams.callFactory,
      participantDocumentStream: streams.participantFactory,
      rtcConfigProvider: rtcProvider,
      rtcAdapter: rtcAdapter,
      localParticipantUid: () => callerUid,
      localParticipantRole: () => CallParticipantRole.caller,
      mediaReportKeyFactory: (callId, mediaState) =>
          '${callId}_${mediaState.name}',
      orchestrationKeyFactory: (callId, purpose) {
        final key = '${callId}_${purpose.name}';
        orchestrationKeys.add(key);
        return key;
      },
    );
  }

  final String callId;
  final String callerUid = 'caller';
  final String calleeUid = 'callee';
  final _FakeCallableApi api;
  final _TrackedStreams streams;
  final _FakeRtcConfigProvider rtcProvider;
  final _FakeRtcAdapter rtcAdapter;
  final orchestrationKeys = <String>[];
  late final CallV2Runtime runtime;

  CallV2Harness get harness => runtime.harness;

  CallV2FirestoreSubscriptionCoordinator get coordinator {
    return runtime.subscriptionCoordinator
        as CallV2FirestoreSubscriptionCoordinator;
  }

  CallV2MediaOrchestrator get orchestrator => runtime.mediaOrchestrator;

  CallV2MediaSessionController get mediaController {
    return runtime.mediaController as CallV2MediaSessionController;
  }

  Future<void> start() {
    return runtime.start(
      callId: callId,
      callerUid: callerUid,
      calleeUid: calleeUid,
      localUid: callerUid,
    );
  }

  Future<void> emit(
    CallLifecycle lifecycle, {
    required int version,
    String? callId,
    String callerMediaState = 'not_joined',
    String calleeMediaState = 'not_joined',
  }) async {
    final docs = await _documents(
      callId: callId ?? this.callId,
      callData: _callData(
        lifecycleState: lifecycle.name,
        version: version,
        callerUid: callerUid,
        calleeUid: calleeUid,
        participantUids: <String>[callerUid, calleeUid],
      ),
      callerData: _participantData(
        uid: callerUid,
        role: 'caller',
        mediaState: callerMediaState,
        mediaVersion: version,
      ),
      calleeData: _participantData(
        uid: calleeUid,
        role: 'callee',
        mediaState: calleeMediaState,
        mediaVersion: version,
      ),
    );
    streams.call(docs.call.id).add(docs.call);
    streams.participant(docs.call.id, callerUid).add(docs.caller);
    streams.participant(docs.call.id, calleeUid).add(docs.callee);
    await _pump();
  }

  Future<void> bridge({required bool isVideo}) {
    final snapshot = harness.snapshot;
    if (snapshot == null) {
      throw StateError('missing authoritative snapshot');
    }
    return runtime.handleAuthoritativeSnapshot(snapshot, isVideo: isVideo);
  }

  Map<String, Object?> rtcConfig({required bool isVideo}) {
    final issuedAt =
        DateTime.now().toUtc().subtract(const Duration(seconds: 5));
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 10));
    return <String, Object?>{
      'callId': callId,
      'localParticipantUid': callerUid,
      'channelName': '${callId}_channel',
      'rtcUid': 12345,
      'token': _redactedToken,
      'isVideo': isVideo,
      'issuedAt': issuedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'idempotentReplay': false,
    };
  }
}

class _FakeCallableApi implements CallableCallV2Api {
  final mediaReports = <Map<String, Object?>>[];
  final lifecycleCommands = <String>[];
  final failMediaStates = <String>{};

  List<String> get mediaStates {
    return mediaReports
        .map((request) => request['mediaState']! as String)
        .toList();
  }

  List<String> get mediaIdempotencyKeys {
    return mediaReports
        .map((request) => request['idempotencyKey']! as String)
        .toList();
  }

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) async {
    lifecycleCommands.add('accept');
    return _lifecycleResult(
        request['callId']! as String, CallLifecycle.accepted);
  }

  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) async {
    lifecycleCommands.add('cancel');
    return _lifecycleResult(
        request['callId']! as String, CallLifecycle.cancelled);
  }

  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) async {
    lifecycleCommands.add('decline');
    return _lifecycleResult(
        request['callId']! as String, CallLifecycle.declined);
  }

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) async {
    lifecycleCommands.add('end');
    return _lifecycleResult(
        request['callId']! as String, CallLifecycle.completed);
  }

  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) async {
    throw StateError('lease renewal is not part of this integration path');
  }

  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) async {
    final copied = Map<String, Object?>.from(request);
    mediaReports.add(copied);
    final mediaState = copied['mediaState']! as String;
    if (failMediaStates.contains(mediaState)) {
      throw StateError('controlled fake media report failure');
    }
    return <String, Object?>{
      'callId': copied['callId'],
      'participantUid': 'caller',
      'mediaState': mediaState,
      'mediaVersion': mediaReports.length,
      'mediaChanged': true,
      'lifecycleState': 'accepted',
      'callVersion': 2,
      'promotedToActive': false,
      'activeAt': null,
      'reconnectDeadlineAt': null,
      'idempotentReplay': false,
    };
  }

  @override
  Future<Object?> startCallV2(Map<String, Object?> request) async {
    throw StateError('start callable is not part of this integration path');
  }
}

class _FakeRtcConfigProvider implements CallV2RtcConfigProvider {
  final requests = <CallV2RtcConfigRequest>[];
  final _pending = <Completer<Object?>>[];
  Object? nextError;

  @override
  Future<Object?> resolveRtcConfig(CallV2RtcConfigRequest request) {
    requests.add(request);
    final error = nextError;
    nextError = null;
    if (error != null) {
      if (error is CallV2ClientError) {
        return Future<Object?>.error(error);
      }
      return Future<Object?>.error(StateError('raw provider detail'));
    }
    final completer = Completer<Object?>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext(Object? value) {
    _pending.removeAt(0).complete(value);
  }
}

class _FakeRtcAdapter implements CallV2RtcAdapter {
  final _events = StreamController<CallV2RtcEvent>.broadcast();
  int initializeCount = 0;
  int joinCount = 0;
  int leaveCount = 0;
  int disposeCount = 0;
  CallV2RtcSessionConfig? lastConfig;
  Completer<void>? holdJoin;
  Object? initializeError;

  @override
  Stream<CallV2RtcEvent> get events => _events.stream;

  @override
  Future<void> initialize(CallV2RtcSessionConfig config) async {
    initializeCount += 1;
    lastConfig = config;
    final error = initializeError;
    if (error != null) throw error;
  }

  @override
  Future<void> joinChannel() async {
    joinCount += 1;
    await holdJoin?.future;
  }

  @override
  Future<void> leaveChannel() async {
    leaveCount += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  void emit(CallV2RtcEvent event) {
    _events.add(event);
  }
}

class _TrackedStreams {
  final _callStreams = <String, _TrackedDocumentSource>{};
  final _participantStreams = <_ParticipantRequest, _TrackedDocumentSource>{};

  Stream<DocumentSnapshot<Map<String, dynamic>>> callFactory(String callId) {
    return (_callStreams[callId] ??= _TrackedDocumentStream()).stream;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> participantFactory(
    String callId,
    String participantUid,
  ) {
    return (_participantStreams[_ParticipantRequest(callId, participantUid)] ??=
            _TrackedDocumentStream())
        .stream;
  }

  void callStreamFor(String callId, _TrackedDocumentSource source) {
    _callStreams[callId] = source;
  }

  _TrackedDocumentSource call(String callId) => _callStreams[callId]!;

  _TrackedDocumentSource participant(String callId, String participantUid) {
    return _participantStreams[_ParticipantRequest(callId, participantUid)]!;
  }
}

abstract class _TrackedDocumentSource {
  Stream<DocumentSnapshot<Map<String, dynamic>>> get stream;
  void add(DocumentSnapshot<Map<String, dynamic>> document);
}

class _TrackedDocumentStream implements _TrackedDocumentSource {
  final _controller =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>();

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> get stream {
    return _controller.stream;
  }

  @override
  void add(DocumentSnapshot<Map<String, dynamic>> document) {
    _controller.add(document);
  }
}

class _SynchronousDocumentStream
    extends Stream<DocumentSnapshot<Map<String, dynamic>>>
    implements _TrackedDocumentSource {
  _SynchronousDocumentStream({this.onBeforeListenReturn});

  final void Function()? onBeforeListenReturn;
  final _subscriptions = <_SynchronousDocumentSubscription>[];

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> get stream => this;

  @override
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> listen(
    void Function(DocumentSnapshot<Map<String, dynamic>> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _SynchronousDocumentSubscription();
    subscription.handleData = onData;
    _subscriptions.add(subscription);
    onBeforeListenReturn?.call();
    return subscription;
  }

  @override
  void add(DocumentSnapshot<Map<String, dynamic>> document) {
    for (final subscription in _subscriptions) {
      if (subscription.isActive) subscription.handleData?.call(document);
    }
  }
}

class _SynchronousDocumentSubscription
    implements StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> {
  bool isActive = true;
  void Function(DocumentSnapshot<Map<String, dynamic>> event)? handleData;

  @override
  Future<void> cancel() async {
    isActive = false;
  }

  @override
  void onData(
      void Function(DocumentSnapshot<Map<String, dynamic>> data)? handleData) {
    this.handleData = handleData;
  }

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);

  @override
  bool get isPaused => false;
}

class _ParticipantRequest {
  const _ParticipantRequest(this.callId, this.participantUid);

  final String callId;
  final String participantUid;

  @override
  bool operator ==(Object other) {
    return other is _ParticipantRequest &&
        other.callId == callId &&
        other.participantUid == participantUid;
  }

  @override
  int get hashCode => Object.hash(callId, participantUid);
}

Future<_Documents> _documents({
  required String callId,
  required Map<String, Object?> callData,
  required Map<String, Object?> callerData,
  required Map<String, Object?> calleeData,
}) async {
  final firestore = FakeFirebaseFirestore();
  await firestore.doc('calls/$callId').set(callData);
  await firestore.doc('calls/$callId/participants/caller').set(callerData);
  await firestore.doc('calls/$callId/participants/callee').set(calleeData);
  return _Documents(
    call: await firestore.doc('calls/$callId').get(),
    caller: await firestore.doc('calls/$callId/participants/caller').get(),
    callee: await firestore.doc('calls/$callId/participants/callee').get(),
  );
}

Map<String, Object?> _callData({
  required String lifecycleState,
  required int version,
  required String callerUid,
  required String calleeUid,
  required List<String> participantUids,
}) {
  return <String, Object?>{
    'schemaVersion': 2,
    'callSystem': 'v2',
    'lifecycleState': lifecycleState,
    'version': version,
    'callerUid': callerUid,
    'calleeUid': calleeUid,
    'participantUids': participantUids,
    'createdAt': Timestamp.fromDate(_now),
    'acceptedAt': lifecycleState == 'ringing' ? null : Timestamp.fromDate(_now),
    'activeAt': lifecycleState == 'active' ? Timestamp.fromDate(_now) : null,
    'endedAt': _terminalLifecycleNames.contains(lifecycleState)
        ? Timestamp.fromDate(_now)
        : null,
    'endReason': lifecycleState == 'completed' ? 'ended' : null,
    'failureCode': null,
  };
}

Map<String, Object?> _participantData({
  required String uid,
  required String role,
  required String mediaState,
  required int mediaVersion,
}) {
  return <String, Object?>{
    'uid': uid,
    'role': role,
    'mediaState': mediaState,
    'mediaVersion': mediaVersion,
    'lastMediaStateAt': Timestamp.fromDate(_now),
  };
}

CallSnapshot _snapshot({
  required String callId,
  required CallLifecycle lifecycle,
}) {
  return CallSnapshot(
    callId: callId,
    version: 99,
    lifecycle: lifecycle,
    callerUid: 'caller',
    calleeUid: 'callee',
  );
}

Map<String, Object?> _lifecycleResult(String callId, CallLifecycle lifecycle) {
  return <String, Object?>{
    'callId': callId,
    'lifecycleState': lifecycle.name,
    'version': 1,
    'terminal': lifecycle.isTerminal,
    'acceptedAt': null,
    'acceptedJoinDeadlineAt': null,
    'endedAt': null,
    'endReason': null,
    'failureCode': null,
    'idempotentReplay': false,
  };
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having((error) => error.code, 'code', code);
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _Documents {
  const _Documents({
    required this.call,
    required this.caller,
    required this.callee,
  });

  final DocumentSnapshot<Map<String, dynamic>> call;
  final DocumentSnapshot<Map<String, dynamic>> caller;
  final DocumentSnapshot<Map<String, dynamic>> callee;
}

const _redactedToken = 'test_token_redacted';
final _now = DateTime.utc(2026, 6, 25, 12);
const _terminalLifecycleNames = <String>{
  'completed',
  'declined',
  'cancelled',
  'missed',
  'failed',
};
