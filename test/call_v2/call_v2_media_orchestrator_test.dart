import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_media_orchestrator.dart';
import 'package:connect_app/call_v2/call_v2_media_session_controller.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:connect_app/call_v2/rtc/call_v2_resolved_rtc_config.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('constructor has no side effects', () {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();

    _orchestrator(resolver: resolver, media: media);

    expect(resolver.resolveCount, 0);
    expect(resolver.invalidateCount, 0);
    expect(media.startCount, 0);
    expect(media.leaveCount, 0);
    expect(media.snapshots, isEmpty);
  });

  test('disabled gate does not resolve config, start media, or leave',
      () async {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(
      enabled: false,
      resolver: resolver,
      media: media,
    );

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.stop();

    expect(resolver.resolveCount, 0);
    expect(media.startCount, 0);
    expect(media.leaveCount, 0);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
    expect(orchestrator.state.errorCode, CallV2ClientErrorCode.rejected);
  });

  test('ringing does not resolve and awaits eligibility', () async {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.ringing),
      isVideo: true,
    );

    expect(resolver.resolveCount, 0);
    expect(media.startCount, 0);
    expect(orchestrator.state.status,
        CallV2MediaOrchestrationStatus.awaitingEligibility);
  });

  test('accepted resolves and starts through converted session config',
      () async {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();
    final keys = <String>[];
    final orchestrator = _orchestrator(
      resolver: resolver,
      media: media,
      keyFactory: (callId, purpose) {
        final key = '${callId}_${purpose.name}';
        keys.add(key);
        return key;
      },
    );

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );

    expect(resolver.resolveCount, 1);
    expect(resolver.isVideoRequests, <bool>[true]);
    expect(media.startCount, 1);
    expect(media.lastConfig, _sessionConfig());
    expect(media.preparingKeys, <String>['call_a_preparing']);
    expect(media.joiningKeys, <String>['call_a_joining']);
    expect(keys, <String>[
      'call_a_resolveConfig',
      'call_a_preparing',
      'call_a_joining',
    ]);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
  });

  test('active resolves and starts if not started', () async {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.active),
      isVideo: false,
    );

    expect(resolver.isVideoRequests, <bool>[false]);
    expect(media.startCount, 1);
    expect(orchestrator.state.isVideo, isFalse);
  });

  test('active after accepted does not restart', () async {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.active, version: 8),
      isVideo: true,
    );

    expect(resolver.resolveCount, 1);
    expect(media.startCount, 1);
  });

  test('terminal without active media does not resolve', () async {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed),
      isVideo: true,
    );

    expect(resolver.resolveCount, 0);
    expect(media.startCount, 0);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('terminal after active leaves exactly once', () async {
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
      isVideo: true,
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 9),
      isVideo: true,
    );

    expect(media.leaveCount, 1);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('duplicates while resolving share one future and one key set', () async {
    final resolver = _FakeResolver()..heldResolve = Completer<void>();
    final media = _FakeMediaController();
    final keyCalls = <CallV2MediaOrchestrationKeyPurpose>[];
    final orchestrator = _orchestrator(
      resolver: resolver,
      media: media,
      keyFactory: (callId, purpose) {
        keyCalls.add(purpose);
        return '${callId}_${purpose.name}';
      },
    );

    final first = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    final second = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted, version: 8),
      isVideo: true,
    );
    resolver.heldResolve!.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(resolver.resolveCount, 1);
    expect(media.startCount, 1);
    expect(keyCalls, <CallV2MediaOrchestrationKeyPurpose>[
      CallV2MediaOrchestrationKeyPurpose.resolveConfig,
      CallV2MediaOrchestrationKeyPurpose.preparing,
      CallV2MediaOrchestrationKeyPurpose.joining,
    ]);
  });

  test('duplicates while media start is in flight share one future', () async {
    final media = _FakeMediaController()..heldStart = Completer<void>();
    final orchestrator = _orchestrator(media: media);

    final first = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.active),
      isVideo: true,
    );
    await _pump();
    final second = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.active, version: 8),
      isVideo: true,
    );
    media.heldStart!.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(media.startCount, 1);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
  });

  test('duplicate snapshots after active are no-ops', () async {
    final resolver = _FakeResolver();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted, version: 8),
      isVideo: true,
    );

    expect(resolver.resolveCount, 1);
    expect(media.startCount, 1);
  });

  test('same call with different video mode is rejected', () async {
    final orchestrator = _orchestrator();

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );

    await expectLater(
      orchestrator.handleAuthoritativeSnapshot(
        _snapshot(lifecycle: CallLifecycle.active, version: 8),
        isVideo: false,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
  });

  test('different call while active is rejected and does not stop current call',
      () async {
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );

    await expectLater(
      orchestrator.handleAuthoritativeSnapshot(
        _snapshot(callId: 'call_b', lifecycle: CallLifecycle.active),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(media.leaveCount, 0);
    expect(orchestrator.state.callId, 'call_a');
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
  });

  test('different terminal call snapshot does not stop active current call',
      () async {
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(callId: 'call_b', lifecycle: CallLifecycle.completed),
      isVideo: true,
    );

    expect(media.leaveCount, 0);
    expect(orchestrator.state.callId, 'call_a');
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
  });

  test('fresh different call works after terminal cleanup', () async {
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
      isVideo: true,
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(callId: 'call_b', lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );

    expect(media.startCount, 2);
    expect(orchestrator.state.callId, 'call_b');
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
  });

  test('terminal during config resolution prevents media start', () async {
    final resolver = _FakeResolver()..heldResolve = Completer<void>();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    final start = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await _pump();
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
      isVideo: true,
    );
    resolver.heldResolve!.complete();

    await expectLater(
      start,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    expect(media.startCount, 0);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('terminal during media start finishes stopped', () async {
    final media = _FakeMediaController()..heldStart = Completer<void>();
    final orchestrator = _orchestrator(media: media);

    final start = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await _pump();
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
      isVideo: true,
    );
    media.heldStart!.complete();

    await expectLater(
      start,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    expect(media.leaveCount, 1);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('resolver controlled error is preserved and does not start media',
      () async {
    final resolver = _FakeResolver()
      ..nextResolveError =
          const CallV2ClientError(CallV2ClientErrorCode.unauthorized);
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    await expectLater(
      orchestrator.handleAuthoritativeSnapshot(
        _snapshot(lifecycle: CallLifecycle.accepted),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unauthorized)),
    );

    expect(media.startCount, 0);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.failed);
    expect(orchestrator.state.errorCode, CallV2ClientErrorCode.unauthorized);
  });

  test('unknown resolver error becomes unavailable and retry succeeds',
      () async {
    final resolver = _FakeResolver()..nextResolveError = StateError('secret');
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    await expectLater(
      orchestrator.handleAuthoritativeSnapshot(
        _snapshot(lifecycle: CallLifecycle.accepted),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted, version: 8),
      isVideo: true,
    );

    expect(media.startCount, 1);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
  });

  test('media controlled error is preserved and retry succeeds', () async {
    final media = _FakeMediaController()
      ..nextStartError =
          const CallV2ClientError(CallV2ClientErrorCode.unauthorized);
    final orchestrator = _orchestrator(media: media);

    await expectLater(
      orchestrator.handleAuthoritativeSnapshot(
        _snapshot(lifecycle: CallLifecycle.accepted),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unauthorized)),
    );
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted, version: 8),
      isVideo: true,
    );

    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
    expect(media.startCount, 2);
  });

  test('unknown media start error becomes unavailable', () async {
    final media = _FakeMediaController()..nextStartError = StateError('secret');
    final orchestrator = _orchestrator(media: media);

    await expectLater(
      orchestrator.handleAuthoritativeSnapshot(
        _snapshot(lifecycle: CallLifecycle.accepted),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.failed);
    expect(orchestrator.state.errorCode, CallV2ClientErrorCode.unavailable);
  });

  test('stop during config resolution invalidates completion', () async {
    final resolver = _FakeResolver()..heldResolve = Completer<void>();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    final start = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await _pump();
    await orchestrator.stop();
    resolver.heldResolve!.complete();

    await expectLater(
      start,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    expect(media.startCount, 0);
    expect(resolver.invalidateCount, greaterThanOrEqualTo(1));
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('stop during media start cannot later become active', () async {
    final media = _FakeMediaController()..heldStart = Completer<void>();
    final orchestrator = _orchestrator(media: media);

    final start = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await _pump();
    await orchestrator.stop();
    media.heldStart!.complete();

    await expectLater(
      start,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('duplicate stop is safe and stop after active leaves once', () async {
    final media = _FakeMediaController()..heldLeave = Completer<void>();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    final first = orchestrator.stop();
    final second = orchestrator.stop();
    media.heldLeave!.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(media.leaveCount, 1);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('leave report failure still ends orchestrator stopped', () async {
    final media = _FakeMediaController()
      ..nextLeaveError =
          const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );

    await expectLater(
      orchestrator.stop(),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );

    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
    expect(orchestrator.state.errorCode, CallV2ClientErrorCode.unavailable);
  });

  test('fresh start works after stop', () async {
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.stop();
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(callId: 'call_b', lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );

    expect(media.startCount, 2);
    expect(orchestrator.state.callId, 'call_b');
  });

  test('old same-call resolution completion cannot clear newer retry',
      () async {
    final resolver = _FakeResolver()..heldResolve = Completer<void>();
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(resolver: resolver, media: media);

    final oldStart = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await _pump();
    await orchestrator.stop();
    resolver.heldResolve!.complete();
    await expectLater(
      oldStart,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    resolver.heldResolve = null;
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted, version: 8),
      isVideo: true,
    );

    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
    expect(media.startCount, 1);
  });

  test('old media-start completion cannot clear newer retry', () async {
    final media = _FakeMediaController()..heldStart = Completer<void>();
    final orchestrator = _orchestrator(media: media);

    final oldStart = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await _pump();
    await orchestrator.stop();
    media.heldStart!.complete();
    await expectLater(
      oldStart,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    media.heldStart = null;
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted, version: 8),
      isVideo: true,
    );

    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.active);
    expect(media.startCount, 2);
  });

  test('old stop completion cannot overwrite new call state', () async {
    final media = _FakeMediaController()..heldLeave = Completer<void>();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    final oldStop = orchestrator.stop();
    await _pump();
    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(callId: 'call_b', lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    media.heldLeave!.complete();
    await oldStop;
    media.heldLeave = null;
    await orchestrator.stop();

    expect(media.leaveCount, 2);
    expect(orchestrator.state.status, CallV2MediaOrchestrationStatus.stopped);
  });

  test('state and stale operation errors contain no token or channel details',
      () async {
    final resolver = _FakeResolver()..heldResolve = Completer<void>();
    final orchestrator = _orchestrator(resolver: resolver);

    final start = orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await _pump();
    await orchestrator.stop();
    resolver.heldResolve!.complete();

    Object? error;
    try {
      await start;
    } catch (caught) {
      error = caught;
    }
    expect(error.toString(), isNot(contains('opaque_token')));
    expect(error.toString(), isNot(contains('channel_a')));
    expect(orchestrator.state.toString(), isNot(contains('opaque_token')));
    expect(orchestrator.state.toString(), isNot(contains('channel_a')));
  });

  test('RTC config result and media start do not mutate snapshot lifecycle',
      () async {
    final snapshot = _snapshot(lifecycle: CallLifecycle.accepted);
    final orchestrator = _orchestrator();

    await orchestrator.handleAuthoritativeSnapshot(snapshot, isVideo: true);

    expect(snapshot.lifecycle, CallLifecycle.accepted);
  });

  test('navigation remains snapshot-driven and endCall is not invoked',
      () async {
    final media = _FakeMediaController();
    final orchestrator = _orchestrator(media: media);

    await orchestrator.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.accepted),
      isVideo: true,
    );
    await orchestrator.stop();

    expect(media.startCount, 1);
    expect(media.leaveCount, 1);
  });

  test('orchestrator imports stay isolated from Firebase, SDK, and adapter',
      () async {
    final source = await File('lib/call_v2/call_v2_media_orchestrator.dart')
        .readAsString();

    expect(source, isNot(contains('firebase')));
    expect(source, isNot(contains('Firebase')));
    expect(source, isNot(contains('agora')));
    expect(source, isNot(contains('Agora')));
    expect(source, isNot(contains('CallV2RtcAdapter')));
  });

  test('invalid local idempotency key generation is rejected', () async {
    final orchestrator = _orchestrator(
      keyFactory: (_, __) => ' bad',
    );

    await expectLater(
      orchestrator.handleAuthoritativeSnapshot(
        _snapshot(lifecycle: CallLifecycle.accepted),
        isVideo: true,
      ),
      throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
    );
  });
}

CallV2MediaOrchestrator _orchestrator({
  bool enabled = true,
  _FakeResolver? resolver,
  _FakeMediaController? media,
  String Function(String, CallV2MediaOrchestrationKeyPurpose)? keyFactory,
}) {
  return CallV2MediaOrchestrator(
    featureGate: CallV2FeatureGate(enabled: enabled),
    configResolver: resolver ?? _FakeResolver(),
    mediaController: media ?? _FakeMediaController(),
    idempotencyKeyFactory:
        keyFactory ?? (callId, purpose) => '${callId}_${purpose.name}',
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

CallV2ResolvedRtcConfig _resolved({
  String callId = 'call_a',
  bool isVideo = true,
}) {
  return CallV2ResolvedRtcConfig(
    callId: callId,
    localParticipantUid: 'caller',
    channelName: 'channel_a',
    rtcUid: 123,
    token: 'opaque_token',
    isVideo: isVideo,
    issuedAt: DateTime.utc(2026, 1, 1),
    expiresAt: DateTime.utc(2026, 1, 1, 0, 10),
    idempotentReplay: false,
  );
}

CallV2RtcSessionConfig _sessionConfig({
  String callId = 'call_a',
  bool isVideo = true,
}) {
  return CallV2RtcSessionConfig(
    callId: callId,
    channelName: 'channel_a',
    rtcUid: 123,
    token: 'opaque_token',
    isVideo: isVideo,
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

class _FakeResolver implements CallV2RtcConfigResolving {
  int resolveCount = 0;
  int invalidateCount = 0;
  final snapshots = <CallSnapshot>[];
  final isVideoRequests = <bool>[];
  final idempotencyKeys = <String>[];
  Completer<void>? heldResolve;
  Object? nextResolveError;

  @override
  Future<CallV2ResolvedRtcConfig> resolve({
    required bool isVideo,
    required String idempotencyKey,
  }) async {
    resolveCount += 1;
    isVideoRequests.add(isVideo);
    idempotencyKeys.add(idempotencyKey);
    await heldResolve?.future;
    final error = nextResolveError;
    nextResolveError = null;
    if (error != null) throw error;
    return _resolved(isVideo: isVideo);
  }

  @override
  void invalidate() {
    invalidateCount += 1;
  }

  @override
  void handleAuthoritativeSnapshot(CallSnapshot snapshot) {
    snapshots.add(snapshot);
    if (snapshot.lifecycle.isTerminal) invalidate();
  }
}

class _FakeMediaController implements CallV2MediaSessionControlling {
  int startCount = 0;
  int leaveCount = 0;
  final snapshots = <CallSnapshot>[];
  final preparingKeys = <String>[];
  final joiningKeys = <String>[];
  final leavingKeys = <String>[];
  Completer<void>? heldStart;
  Completer<void>? heldLeave;
  Object? nextStartError;
  Object? nextLeaveError;
  CallV2RtcSessionConfig? lastConfig;

  @override
  Future<void> start({
    required CallV2RtcSessionConfig config,
    required String preparingIdempotencyKey,
    required String joiningIdempotencyKey,
  }) async {
    startCount += 1;
    lastConfig = config;
    preparingKeys.add(preparingIdempotencyKey);
    joiningKeys.add(joiningIdempotencyKey);
    await heldStart?.future;
    final error = nextStartError;
    nextStartError = null;
    if (error != null) throw error;
  }

  @override
  Future<void> handleAuthoritativeSnapshot(CallSnapshot snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Future<void> leave({required String idempotencyKey}) async {
    leaveCount += 1;
    leavingKeys.add(idempotencyKey);
    await heldLeave?.future;
    final error = nextLeaveError;
    nextLeaveError = null;
    if (error != null) throw error;
  }
}
