import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_harness.dart';
import 'package:connect_app/call_v2/call_v2_media_session_controller.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor performs no RTC operations', () {
    final rtc = _FakeRtcAdapter();
    _controller(rtc: rtc);

    expect(rtc.operations, isEmpty);
    expect(rtc.eventSubscriptionCount, 0);
  });

  test('disabled gate performs no adapter calls or media reports', () async {
    final rtc = _FakeRtcAdapter();
    final api = _FakeApi();
    final harness = _harness(api: api, enabled: false);
    final controller = _controller(rtc: rtc, harness: harness, enabled: false);

    await controller.start(
      config: _config(),
      preparingIdempotencyKey: 'prep',
      joiningIdempotencyKey: 'join',
    );

    expect(rtc.operations, isEmpty);
    expect(api.mediaRequests, isEmpty);
  });

  test('invalid config is rejected before adapter invocation', () async {
    final rtc = _FakeRtcAdapter();
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);

    await expectLater(
      controller.start(
        config: _config(channelName: ' bad'),
        preparingIdempotencyKey: 'prep',
        joiningIdempotencyKey: 'join',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
    );

    expect(rtc.operations, isEmpty);
  });

  test('call ID mismatch with authoritative snapshot is rejected', () async {
    final rtc = _FakeRtcAdapter();
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);

    await expectLater(
      controller.start(
        config: _config(callId: 'other_call'),
        preparingIdempotencyKey: 'prep',
        joiningIdempotencyKey: 'join',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(rtc.operations, isEmpty);
  });

  test('ringing snapshot cannot start RTC', () async {
    await _expectStartRejectedFor(CallLifecycle.ringing);
  });

  test('accepted snapshot can start', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);
    expect(started.rtc.joinCount, 1);
  });

  test('active snapshot can start', () async {
    final started = await _startWithSnapshot(CallLifecycle.active);
    expect(started.rtc.joinCount, 1);
  });

  test('terminal snapshot cannot start', () async {
    await _expectStartRejectedFor(CallLifecycle.completed);
  });

  test('start reports preparing before initialize', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    expect(started.log.indexOf('report:preparing'),
        lessThan(started.log.indexOf('initialize')));
  });

  test('initialize and joining report occur before join', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    expect(started.log.indexOf('initialize'),
        lessThan(started.log.indexOf('report:joining')));
    expect(started.log.indexOf('report:joining'),
        lessThan(started.log.indexOf('join')));
  });

  test('local status does not become joined before RTC joined event', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    expect(started.controller.state.status, CallV2MediaSessionStatus.joining);
  });

  test('exact duplicate start shares one future', () async {
    final log = <String>[];
    final rtc = _FakeRtcAdapter(log: log)..heldInitialize = Completer<void>();
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);

    final first = controller.start(
      config: _config(),
      preparingIdempotencyKey: 'prep',
      joiningIdempotencyKey: 'join',
    );
    final second = controller.start(
      config: _config(),
      preparingIdempotencyKey: 'prep',
      joiningIdempotencyKey: 'join',
    );
    rtc.heldInitialize!.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(rtc.initializeCount, 1);
    expect(rtc.joinCount, 1);
  });

  test('conflicting start is rejected while startup is active', () async {
    final rtc = _FakeRtcAdapter()..heldInitialize = Completer<void>();
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);

    final first = controller.start(
      config: _config(),
      preparingIdempotencyKey: 'prep',
      joiningIdempotencyKey: 'join',
    );
    await expectLater(
      controller.start(
        config: _config(channelName: 'other_channel'),
        preparingIdempotencyKey: 'prep',
        joiningIdempotencyKey: 'join',
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    rtc.heldInitialize!.complete();
    await first;

    expect(rtc.initializeCount, 1);
  });

  test('failed initialize cleans up and reports media_failed', () async {
    final api = _FakeApi();
    final rtc = _FakeRtcAdapter()..failInitialize = true;
    final harness = _readyHarness(api: api);
    final controller = _controller(rtc: rtc, harness: harness);

    await expectLater(
      _start(controller),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(controller.state.status, CallV2MediaSessionStatus.failed);
    expect(api.mediaStates, contains('media_failed'));
    expect(rtc.disposeCount, 1);
  });

  test('failed initialize still disposes when media_failed report fails',
      () async {
    final api = _FakeApi()..failMediaStates.add('media_failed');
    final rtc = _FakeRtcAdapter()..failInitialize = true;
    final harness = _readyHarness(api: api);
    final controller = _controller(rtc: rtc, harness: harness);

    await expectLater(
      _start(controller),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(controller.state.status, CallV2MediaSessionStatus.failed);
    expect(controller.state.errorCode, CallV2ClientErrorCode.unavailable);
    expect(api.mediaStates, contains('media_failed'));
    expect(rtc.disposeCount, 1);
  });

  test('failed join cleans up and reports media_failed', () async {
    final api = _FakeApi();
    final rtc = _FakeRtcAdapter()..failJoin = true;
    final harness = _readyHarness(api: api);
    final controller = _controller(rtc: rtc, harness: harness);

    await expectLater(
      _start(controller),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(controller.state.status, CallV2MediaSessionStatus.failed);
    expect(api.mediaStates, contains('media_failed'));
    expect(rtc.disposeCount, 1);
  });

  test('failed join still leaves and disposes when media_failed report fails',
      () async {
    final api = _FakeApi()..failMediaStates.add('media_failed');
    final rtc = _FakeRtcAdapter()..failJoin = true;
    final harness = _readyHarness(api: api);
    final controller = _controller(rtc: rtc, harness: harness);

    await expectLater(
      _start(controller),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(controller.state.status, CallV2MediaSessionStatus.failed);
    expect(rtc.leaveCount, 1);
    expect(rtc.disposeCount, 1);
    rtc.failJoin = false;
    await _start(controller);
    expect(controller.state.status, CallV2MediaSessionStatus.joining);
  });

  test('joined event updates local state and reports joined', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    started.rtc.emit(const CallV2RtcJoined());
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.joined);
    expect(started.api.mediaStates, contains('joined'));
  });

  test('reconnecting and reconnected events report deterministic states',
      () async {
    final started = await _joinedSession();

    started.rtc.emit(const CallV2RtcReconnecting());
    await _pump();
    started.rtc.emit(const CallV2RtcReconnected());
    await _pump();

    expect(
        started.api.mediaStates,
        containsAll(<String>[
          'reconnecting',
          'joined',
        ]));
    expect(started.controller.state.status, CallV2MediaSessionStatus.joined);
  });

  test('disconnected event reports disconnected without ending the call',
      () async {
    final started = await _joinedSession();

    started.rtc.emit(const CallV2RtcDisconnected());
    await _pump();

    expect(
        started.controller.state.status, CallV2MediaSessionStatus.disconnected);
    expect(started.api.mediaStates, contains('disconnected'));
    expect(started.api.endRequests, isEmpty);
  });

  test('remote join and leave only update remote presence', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);
    final beforeReports = started.api.mediaRequests.length;

    started.rtc.emit(const CallV2RtcRemoteParticipantJoined());
    await _pump();
    expect(started.controller.state.remoteParticipantPresent, isTrue);
    started.rtc.emit(const CallV2RtcRemoteParticipantLeft());
    await _pump();

    expect(started.controller.state.remoteParticipantPresent, isFalse);
    expect(started.api.mediaRequests.length, beforeReports);
  });

  test('fatal error reports media_failed and cleans up once', () async {
    final started = await _joinedSession();

    started.rtc.emit(
      const CallV2RtcFatalError(CallV2RtcErrorCategory.deviceUnavailable),
    );
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.failed);
    expect(started.controller.state.errorCode, CallV2ClientErrorCode.rejected);
    expect(started.api.mediaStates, contains('media_failed'));
    expect(started.rtc.disposeCount, 1);
  });

  test('fatal error cleanup survives failed media_failed report', () async {
    final started = await _joinedSession();
    started.api.failMediaStates.add('media_failed');

    started.rtc.emit(
      const CallV2RtcFatalError(CallV2RtcErrorCategory.deviceUnavailable),
    );
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.failed);
    expect(started.controller.state.errorCode, CallV2ClientErrorCode.rejected);
    expect(started.controller.state.errorCode.toString(),
        isNot(contains('raw media report secret')));
    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
  });

  test('raw provider error details are not exposed', () async {
    final started = await _joinedSession();

    started.rtc.emit(
      const CallV2RtcFatalError(CallV2RtcErrorCategory.unknown),
    );
    await _pump();

    expect(started.controller.state.errorCode.toString(),
        isNot(contains('raw secret')));
  });

  test('RTC joined event and media callable result do not change lifecycle',
      () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    started.rtc.emit(const CallV2RtcJoined());
    await _pump();

    expect(started.harness.snapshot!.lifecycle, CallLifecycle.accepted);
    expect(started.api.mediaResultsLifecycle, 'active');
  });

  test('active authoritative snapshot does not restart adapter', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    await started.controller.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.active, version: 8),
    );

    expect(started.rtc.initializeCount, 1);
    expect(started.rtc.joinCount, 1);
    expect(started.harness.snapshot!.lifecycle, CallLifecycle.active);
  });

  test('terminal snapshot leaves and disposes', () async {
    final started = await _joinedSession();

    await started.controller.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
    );

    expect(started.controller.state.status, CallV2MediaSessionStatus.left);
    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
    expect(started.api.mediaStates, contains('left'));
  });

  test('different-call snapshot cannot migrate session', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    await started.controller.handleAuthoritativeSnapshot(
      _snapshot(callId: 'other_call', lifecycle: CallLifecycle.active),
    );

    expect(started.harness.snapshot!.callId, 'call_a');
    expect(started.rtc.initializeCount, 1);
  });

  test('navigation remains snapshot-driven', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    started.rtc.emit(const CallV2RtcJoined());
    await _pump();

    expect(started.harness.openNavigationIntentFor(started.harness.snapshot!),
        isNotNull);
    expect(started.harness.openNavigationIntentFor(started.harness.snapshot!),
        isNull);
  });

  test('leave calls adapter once and reports left', () async {
    final started = await _joinedSession();

    await started.controller.leave(idempotencyKey: 'leave_key');

    expect(started.rtc.leaveCount, 1);
    expect(started.api.mediaStates, contains('left'));
  });

  test('leave report failure still leaves, disposes, and ends left', () async {
    final started = await _joinedSession();
    started.api.failMediaStates.add('left');

    await expectLater(
      started.controller.leave(idempotencyKey: 'leave_key'),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
    expect(started.rtc.cancelCount, 1);
    expect(started.controller.state.status, CallV2MediaSessionStatus.left);
    expect(
        started.controller.state.errorCode, CallV2ClientErrorCode.unavailable);
    expect(started.api.mediaStates, contains('left'));

    await started.controller.start(
      config: _config(channelName: 'fresh_channel'),
      preparingIdempotencyKey: 'fresh_prep',
      joiningIdempotencyKey: 'fresh_join',
    );
    expect(started.controller.state.status, CallV2MediaSessionStatus.joining);
  });

  test('duplicate leave shares one future and dispose occurs once', () async {
    final started = await _joinedSession();
    started.rtc.heldLeave = Completer<void>();

    final first = started.controller.leave(idempotencyKey: 'leave_key');
    final second = started.controller.leave(idempotencyKey: 'leave_key');
    started.rtc.heldLeave!.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
  });

  test('repeated cleanup is safe and late joined event is ignored', () async {
    final started = await _joinedSession();

    await started.controller.leave(idempotencyKey: 'leave_key');
    await started.controller.leave(idempotencyKey: 'leave_key');
    started.rtc.emit(const CallV2RtcJoined());
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.left);
    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
  });

  test('microphone toggle updates after adapter success', () async {
    final started = await _joinedSession();

    await started.controller.setMicrophoneEnabled(false);

    expect(started.controller.state.microphoneEnabled, isFalse);
    expect(started.rtc.microphoneCalls, <bool>[false]);
  });

  test('failed microphone toggle preserves previous state', () async {
    final started = await _joinedSession();
    started.rtc.failMicrophone = true;

    await expectLater(
      started.controller.setMicrophoneEnabled(false),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(started.controller.state.microphoneEnabled, isTrue);
  });

  test('camera toggle updates after adapter success', () async {
    final started = await _joinedSession();

    await started.controller.setCameraEnabled(true);

    expect(started.controller.state.cameraEnabled, isTrue);
    expect(started.rtc.cameraCalls, <bool>[true]);
  });

  test('audio-only session rejects camera enable', () async {
    final started = await _startWithSnapshot(
      CallLifecycle.accepted,
      config: _config(isVideo: false),
    );

    await expectLater(
      started.controller.setCameraEnabled(true),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(started.rtc.cameraCalls, isEmpty);
  });

  test('duplicate same-value toggles are no-ops', () async {
    final started = await _joinedSession();

    await started.controller.setMicrophoneEnabled(true);
    await started.controller.setCameraEnabled(false);

    expect(started.rtc.microphoneCalls, isEmpty);
    expect(started.rtc.cameraCalls, isEmpty);
  });

  test('stop during initialize cannot later join', () async {
    final rtc = _FakeRtcAdapter()..heldInitialize = Completer<void>();
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);

    final start = _start(controller);
    final leave = controller.leave(idempotencyKey: 'leave_key');
    rtc.heldInitialize!.complete();
    await expectLater(
      start,
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await leave;
    rtc.emit(const CallV2RtcJoined());
    await _pump();

    expect(controller.state.status, CallV2MediaSessionStatus.left);
    expect(rtc.joinCount, 0);
  });

  test('stop during join leaves attempted RTC session', () async {
    final rtc = _FakeRtcAdapter()..heldJoin = Completer<void>();
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);

    final start = _start(controller);
    await _pump();
    final leave = controller.leave(idempotencyKey: 'leave_key');
    rtc.heldJoin!.complete();
    await expectLater(
      start,
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await leave;

    expect(controller.state.status, CallV2MediaSessionStatus.left);
    expect(rtc.joinCount, 1);
    expect(rtc.leaveCount, 1);
    expect(rtc.disposeCount, 1);
  });

  test('terminal snapshot racing with joined event finishes left', () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    final terminal = started.controller.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
    );
    started.rtc.emit(const CallV2RtcJoined());
    await terminal;
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.left);
  });

  test('terminal snapshot leave report failure still cleans up once', () async {
    final started = await _joinedSession();
    started.api.failMediaStates.add('left');

    final terminal = started.controller.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
    );
    started.rtc.emit(const CallV2RtcJoined());
    await expectLater(
      terminal,
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.left);
    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
  });

  test('fatal error racing with leave cleans up once', () async {
    final started = await _joinedSession();

    final leave = started.controller.leave(idempotencyKey: 'leave_key');
    started.rtc.emit(
      const CallV2RtcFatalError(CallV2RtcErrorCategory.unavailable),
    );
    await leave;
    await _pump();

    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
  });

  test('fatal then leave with failed reports does not leak or stick', () async {
    final started = await _joinedSession();
    started.api.failMediaStates.addAll(<String>['media_failed', 'left']);

    started.rtc.emit(
      const CallV2RtcFatalError(CallV2RtcErrorCategory.permissionDenied),
    );
    await _pump();
    await started.controller.leave(idempotencyKey: 'leave_key');

    expect(started.rtc.leaveCount, 1);
    expect(started.rtc.disposeCount, 1);
    expect(started.controller.state.status, CallV2MediaSessionStatus.left);

    await started.controller.start(
      config: _config(channelName: 'fresh_after_fatal'),
      preparingIdempotencyKey: 'fresh_prep',
      joiningIdempotencyKey: 'fresh_join',
    );
    expect(started.controller.state.status, CallV2MediaSessionStatus.joining);
  });

  test('old generation events cannot mutate new session', () async {
    final rtc = _FakeRtcAdapter();
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);
    await _start(controller);
    await controller.leave(idempotencyKey: 'leave_key');
    await controller.start(
      config: _config(channelName: 'channel_again'),
      preparingIdempotencyKey: 'prep_again',
      joiningIdempotencyKey: 'join_again',
    );
    rtc.emitToSubscription(0, const CallV2RtcJoined());
    await _pump();

    expect(controller.state.status, CallV2MediaSessionStatus.joining);
  });

  test('old generation cleanup does not overwrite fresh failed state',
      () async {
    final started = await _joinedSession();
    started.api.failMediaStates.add('left');

    await expectLater(
      started.controller.leave(idempotencyKey: 'leave_key'),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await started.controller.start(
      config: _config(channelName: 'fresh_generation'),
      preparingIdempotencyKey: 'fresh_prep',
      joiningIdempotencyKey: 'fresh_join',
    );
    started.rtc.emitToSubscription(0, const CallV2RtcDisconnected());
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.joining);
  });

  test('failed first session permits fresh start', () async {
    final rtc = _FakeRtcAdapter()..failInitialize = true;
    final harness = _readyHarness();
    final controller = _controller(rtc: rtc, harness: harness);

    await expectLater(
      _start(controller),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    rtc.failInitialize = false;
    await _start(controller);

    expect(controller.state.status, CallV2MediaSessionStatus.joining);
    expect(rtc.initializeCount, 2);
  });

  test('joined report failure is contained and later events continue',
      () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);
    started.api.failMediaStates.add('joined');

    started.rtc.emit(const CallV2RtcJoined());
    await _pump();
    expect(started.controller.state.status, CallV2MediaSessionStatus.joined);
    expect(
        started.controller.state.errorCode, CallV2ClientErrorCode.unavailable);
    started.api.failMediaStates.remove('joined');
    started.rtc.emit(const CallV2RtcReconnecting());
    await _pump();

    expect(
        started.controller.state.status, CallV2MediaSessionStatus.reconnecting);
    expect(started.controller.state.errorCode, isNull);
    expect(started.harness.snapshot!.lifecycle, CallLifecycle.accepted);
    expect(started.rtc.leaveCount, 0);
    expect(started.rtc.disposeCount, 0);
  });

  test('reconnecting and disconnected report failures do not stop RTC events',
      () async {
    final started = await _joinedSession();
    started.api.failMediaStates
        .addAll(<String>['reconnecting', 'disconnected']);

    started.rtc.emit(const CallV2RtcReconnecting());
    await _pump();
    started.rtc.emit(const CallV2RtcDisconnected());
    await _pump();
    started.api.failMediaStates.clear();
    started.rtc.emit(const CallV2RtcReconnected());
    await _pump();

    expect(started.controller.state.status, CallV2MediaSessionStatus.joined);
    expect(started.api.endRequests, isEmpty);
    expect(started.rtc.leaveCount, 0);
    expect(started.rtc.disposeCount, 0);
  });

  test(
      'duplicate event callbacks do not duplicate identical transition reports',
      () async {
    final started = await _startWithSnapshot(CallLifecycle.accepted);

    started.rtc.emit(const CallV2RtcJoined());
    started.rtc.emit(const CallV2RtcJoined());
    await _pump();

    expect(
      started.api.mediaStates.where((state) => state == 'joined').length,
      1,
    );
  });

  test('existing Phase 3 surfaces remain Firebase-free in this controller', () {
    final controllerSource =
        File('lib/call_v2/call_v2_media_session_controller.dart')
            .readAsStringSync();
    final adapterSource =
        File('lib/call_v2/rtc/call_v2_rtc_adapter.dart').readAsStringSync();

    for (final source in <String>[controllerSource, adapterSource]) {
      expect(source.contains('FirebaseFirestore'), isFalse);
      expect(source.contains('FirebaseAuth'), isFalse);
      expect(source.contains('FirebaseAppCheck'), isFalse);
      expect(source.contains('Agora'), isFalse);
      expect(source.contains('agora_rtc_engine'), isFalse);
    }
    expect(Firebase.apps, isEmpty);
  });
}

Future<void> _expectStartRejectedFor(CallLifecycle lifecycle) async {
  final rtc = _FakeRtcAdapter();
  final harness = _readyHarness(snapshot: _snapshot(lifecycle: lifecycle));
  final controller = _controller(rtc: rtc, harness: harness);

  await expectLater(
    _start(controller),
    throwsA(_clientError(CallV2ClientErrorCode.rejected)),
  );
  expect(rtc.operations, isEmpty);
}

Future<_StartedSession> _startWithSnapshot(
  CallLifecycle lifecycle, {
  CallV2RtcSessionConfig? config,
}) async {
  final log = <String>[];
  final api = _FakeApi(log: log);
  final rtc = _FakeRtcAdapter(log: log);
  final harness = _readyHarness(
    api: api,
    snapshot: _snapshot(
      callId: config?.callId ?? 'call_a',
      lifecycle: lifecycle,
    ),
  );
  final controller = _controller(rtc: rtc, harness: harness);
  await _start(controller, config: config);
  return _StartedSession(
    controller: controller,
    rtc: rtc,
    api: api,
    harness: harness,
    log: log,
  );
}

Future<_StartedSession> _joinedSession() async {
  final started = await _startWithSnapshot(CallLifecycle.accepted);
  started.rtc.emit(const CallV2RtcJoined());
  await _pump();
  return started;
}

Future<void> _start(
  CallV2MediaSessionController controller, {
  CallV2RtcSessionConfig? config,
}) {
  return controller.start(
    config: config ?? _config(),
    preparingIdempotencyKey: 'prep',
    joiningIdempotencyKey: 'join',
  );
}

CallV2MediaSessionController _controller({
  required _FakeRtcAdapter rtc,
  CallV2Harness? harness,
  bool enabled = true,
}) {
  return CallV2MediaSessionController(
    featureGate: CallV2FeatureGate(enabled: enabled),
    rtcAdapter: rtc,
    harness: harness ?? _readyHarness(enabled: enabled),
  );
}

CallV2Harness _readyHarness({
  _FakeApi? api,
  CallSnapshot? snapshot,
  bool enabled = true,
}) {
  final harness = _harness(api: api, enabled: enabled);
  final initial = snapshot ?? _snapshot();
  if (enabled) {
    harness.injectPublicSnapshot(initial);
  }
  return harness;
}

CallV2Harness _harness({
  _FakeApi? api,
  bool enabled = true,
}) {
  return CallV2Harness(
    featureGate: CallV2FeatureGate(enabled: enabled),
    api: CallV2Api(api ?? _FakeApi()),
    localParticipantRole: () => CallParticipantRole.caller,
  );
}

CallSnapshot _snapshot({
  String callId = 'call_a',
  CallLifecycle lifecycle = CallLifecycle.accepted,
  int version = 7,
}) {
  return CallSnapshot(
    callId: callId,
    version: version,
    lifecycle: lifecycle,
    callerUid: 'caller',
    calleeUid: 'callee',
    callerMediaState: ParticipantMediaState.notJoined,
    calleeMediaState: ParticipantMediaState.notJoined,
  );
}

CallV2RtcSessionConfig _config({
  String callId = 'call_a',
  String channelName = 'channel_a',
  int rtcUid = 123,
  bool isVideo = true,
  String? token = 'opaque_token',
}) {
  return CallV2RtcSessionConfig(
    callId: callId,
    channelName: channelName,
    rtcUid: rtcUid,
    isVideo: isVideo,
    token: token,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _StartedSession {
  const _StartedSession({
    required this.controller,
    required this.rtc,
    required this.api,
    required this.harness,
    required this.log,
  });

  final CallV2MediaSessionController controller;
  final _FakeRtcAdapter rtc;
  final _FakeApi api;
  final CallV2Harness harness;
  final List<String> log;
}

class _FakeRtcAdapter implements CallV2RtcAdapter {
  _FakeRtcAdapter({List<String>? log}) : _log = log ?? <String>[];

  final List<String> _log;
  final operations = <String>[];
  final microphoneCalls = <bool>[];
  final cameraCalls = <bool>[];
  final _subscriptions = <_FakeRtcSubscription>[];
  CallV2RtcSessionConfig? lastConfig;
  Completer<void>? heldInitialize;
  Completer<void>? heldJoin;
  Completer<void>? heldLeave;
  bool failInitialize = false;
  bool failJoin = false;
  bool failLeave = false;
  bool failMicrophone = false;
  bool failCamera = false;
  int initializeCount = 0;
  int joinCount = 0;
  int leaveCount = 0;
  int disposeCount = 0;
  int eventSubscriptionCount = 0;
  int cancelCount = 0;

  @override
  Future<void> initialize(CallV2RtcSessionConfig config) async {
    initializeCount += 1;
    lastConfig = config;
    _record('initialize');
    if (failInitialize) throw StateError('raw initialize secret');
    await heldInitialize?.future;
  }

  @override
  Future<void> joinChannel() async {
    joinCount += 1;
    _record('join');
    if (failJoin) throw StateError('raw join secret');
    await heldJoin?.future;
  }

  @override
  Future<void> leaveChannel() async {
    leaveCount += 1;
    _record('leave');
    if (failLeave) throw StateError('raw leave secret');
    await heldLeave?.future;
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _record('microphone:$enabled');
    if (failMicrophone) throw StateError('raw microphone secret');
    microphoneCalls.add(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _record('camera:$enabled');
    if (failCamera) throw StateError('raw camera secret');
    cameraCalls.add(enabled);
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    _record('dispose');
  }

  @override
  Stream<CallV2RtcEvent> get events => _FakeRtcEventStream(this);

  void emit(CallV2RtcEvent event) {
    for (final subscription in _subscriptions) {
      if (subscription.active) subscription.handleEvent(event);
    }
  }

  void emitToSubscription(int index, CallV2RtcEvent event) {
    _subscriptions[index].handleEvent(event);
  }

  void _record(String operation) {
    operations.add(operation);
    _log.add(operation);
  }
}

class _FakeRtcEventStream extends Stream<CallV2RtcEvent> {
  _FakeRtcEventStream(this._adapter);

  final _FakeRtcAdapter _adapter;

  @override
  StreamSubscription<CallV2RtcEvent> listen(
    void Function(CallV2RtcEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _adapter.eventSubscriptionCount += 1;
    final subscription = _FakeRtcSubscription(
      handleEvent: onData ?? (_) {},
      onCancel: () => _adapter.cancelCount += 1,
    );
    _adapter._subscriptions.add(subscription);
    return subscription;
  }
}

class _FakeRtcSubscription implements StreamSubscription<CallV2RtcEvent> {
  _FakeRtcSubscription({
    required this.handleEvent,
    required this.onCancel,
  });

  final void Function(CallV2RtcEvent event) handleEvent;
  final void Function() onCancel;
  bool active = true;

  @override
  Future<void> cancel() async {
    if (active) onCancel();
    active = false;
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);

  @override
  bool get isPaused => false;

  @override
  void onData(void Function(CallV2RtcEvent data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}
}

class _FakeApi implements CallableCallV2Api {
  _FakeApi({List<String>? log}) : _log = log ?? <String>[];

  final List<String> _log;
  final mediaRequests = <Map<String, Object?>>[];
  final endRequests = <Map<String, Object?>>[];
  final failMediaStates = <String>{};
  String mediaResultsLifecycle = 'active';
  int _mediaVersion = 0;

  List<String> get mediaStates {
    return mediaRequests
        .map((request) => request['mediaState'])
        .whereType<String>()
        .toList(growable: false);
  }

  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) async {
    mediaRequests.add(Map<String, Object?>.from(request));
    _log.add('report:${request['mediaState']}');
    final mediaState = request['mediaState'];
    if (mediaState is String && failMediaStates.contains(mediaState)) {
      throw StateError('raw media report secret');
    }
    _mediaVersion += 1;
    return <String, Object?>{
      'callId': request['callId'],
      'participantUid': 'caller',
      'mediaState': request['mediaState'],
      'mediaVersion': _mediaVersion,
      'mediaChanged': true,
      'lifecycleState': mediaResultsLifecycle,
      'callVersion': 10,
      'promotedToActive': mediaResultsLifecycle == 'active',
      'idempotentReplay': false,
    };
  }

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) async {
    endRequests.add(Map<String, Object?>.from(request));
    throw StateError('unused');
  }

  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) =>
      throw StateError('unused');
  @override
  Future<Object?> startCallV2(Map<String, Object?> request) =>
      throw StateError('unused');
}
