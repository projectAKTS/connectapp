import 'dart:async';
import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_harness.dart';
import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:connect_app/call_v2/rtc/call_v2_resolved_rtc_config.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_provider.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_config_resolver.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
  });

  test('constructor performs no provider calls', () {
    final provider = _FakeRtcConfigProvider();

    _resolver(provider: provider, clock: () => now);

    expect(provider.requests, isEmpty);
  });

  test('disabled gate rejects before provider invocation', () async {
    final provider = _FakeRtcConfigProvider();
    final resolver = _resolver(
      provider: provider,
      enabled: false,
      clock: () => now,
    );

    await expectLater(
      _resolve(resolver),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(provider.requests, isEmpty);
  });

  test('invalid idempotency key rejects before provider invocation', () async {
    final provider = _FakeRtcConfigProvider();
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await expectLater(
      resolver.resolve(isVideo: true, idempotencyKey: ' bad'),
      throwsA(_clientError(CallV2ClientErrorCode.invalidRequest)),
    );

    expect(provider.requests, isEmpty);
  });

  test('missing snapshot rejects before provider invocation', () async {
    final provider = _FakeRtcConfigProvider();
    final resolver = _resolver(provider: provider, clock: () => now);

    await expectLater(
      _resolve(resolver),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(provider.requests, isEmpty);
  });

  for (final lifecycle in <CallLifecycle>[
    CallLifecycle.ringing,
    CallLifecycle.completed,
    CallLifecycle.declined,
    CallLifecycle.cancelled,
    CallLifecycle.missed,
    CallLifecycle.failed,
  ]) {
    test('$lifecycle snapshot cannot resolve credentials', () async {
      final provider = _FakeRtcConfigProvider();
      final resolver = _readyResolver(
        provider: provider,
        snapshot: _snapshot(lifecycle: lifecycle),
        clock: () => now,
      );

      await expectLater(
        _resolve(resolver),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(provider.requests, isEmpty);
    });
  }

  for (final lifecycle in <CallLifecycle>[
    CallLifecycle.accepted,
    CallLifecycle.active,
  ]) {
    test('$lifecycle snapshot can resolve credentials', () async {
      final provider = _FakeRtcConfigProvider(
        responseFactory: (request) => _validResponse(
          now,
          callId: request.callId,
          localParticipantUid: request.localParticipantUid,
          isVideo: request.isVideo,
        ),
      );
      final resolver = _readyResolver(
        provider: provider,
        snapshot: _snapshot(lifecycle: lifecycle),
        clock: () => now,
      );

      final resolved = await _resolve(resolver);

      expect(resolved.callId, 'call_a');
      expect(resolved.localParticipantUid, 'caller');
      expect(provider.requests, hasLength(1));
    });
  }

  test('callee participant can resolve credentials', () async {
    final provider = _FakeRtcConfigProvider(
      responseFactory: (request) => _validResponse(
        now,
        callId: request.callId,
        localParticipantUid: request.localParticipantUid,
        isVideo: request.isVideo,
      ),
    );
    final resolver = _readyResolver(
      provider: provider,
      localUid: () => 'callee',
      clock: () => now,
    );

    final resolved = await _resolve(resolver);

    expect(resolved.localParticipantUid, 'callee');
    expect(provider.requests.single.localParticipantUid, 'callee');
  });

  test('nonparticipant local UID rejects before provider invocation', () async {
    final provider = _FakeRtcConfigProvider();
    final resolver = _readyResolver(
      provider: provider,
      localUid: () => 'intruder',
      clock: () => now,
    );

    await expectLater(
      _resolve(resolver),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );

    expect(provider.requests, isEmpty);
  });

  test('local UID change during in-flight resolution rejects stale result',
      () async {
    var localUid = 'caller';
    final provider = _FakeRtcConfigProvider(gated: true);
    final resolver = _readyResolver(
      provider: provider,
      localUid: () => localUid,
      clock: () => now,
    );

    final future = _resolve(resolver);
    await _pump();
    localUid = 'callee';
    provider.completeGate(0, _validResponse(now));

    await expectLater(
      future,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
  });

  test('provider request contains only the public resolver contract', () async {
    final provider = _FakeRtcConfigProvider(
      responseFactory: (request) => _validResponse(
        now,
        callId: request.callId,
        localParticipantUid: request.localParticipantUid,
        isVideo: request.isVideo,
      ),
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await _resolve(resolver);

    final request = provider.requests.single;
    expect(request.callId, 'call_a');
    expect(request.localParticipantUid, 'caller');
    expect(request.isVideo, isTrue);
    expect(request.idempotencyKey, 'resolve_key');
  });

  test('valid response parses all exposed fields', () async {
    final provider = _FakeRtcConfigProvider(
      nextResponse: _validResponse(
        now,
        channelName: 'channel_custom',
        rtcUid: 987,
        token: 'token_secret',
        idempotentReplay: true,
      ),
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final resolved = await _resolve(resolver);

    expect(resolved.callId, 'call_a');
    expect(resolved.localParticipantUid, 'caller');
    expect(resolved.channelName, 'channel_custom');
    expect(resolved.rtcUid, 987);
    expect(resolved.token, 'token_secret');
    expect(resolved.isVideo, isTrue);
    expect(resolved.idempotentReplay, isTrue);
    expect(resolved.issuedAt, now.subtract(const Duration(seconds: 5)));
    expect(resolved.expiresAt, now.add(const Duration(minutes: 10)));
  });

  for (final entry in <String, Object?>{
    'non-map response': 'not a map',
    'non-string key': {7: 'bad'},
    'unknown field': {..._validResponse(DateTime.utc(2026)), 'extra': true},
    'private actor field': {
      ..._validResponse(DateTime.utc(2026)),
      'actorUid': 'caller',
    },
    'missing required field': () {
      final data = _validResponse(DateTime.utc(2026));
      data.remove('token');
      return data;
    }(),
    'empty call ID': _validResponse(DateTime.utc(2026), callId: ''),
    'trimmed participant UID': _validResponse(
      DateTime.utc(2026),
      localParticipantUid: ' caller',
    ),
    'slash channel name': _validResponse(
      DateTime.utc(2026),
      channelName: 'bad/channel',
    ),
    'zero rtc UID': _validResponse(DateTime.utc(2026), rtcUid: 0),
    'double rtc UID': _validResponse(DateTime.utc(2026), rtcUid: 1.0),
    'overflow rtc UID': _validResponse(
      DateTime.utc(2026),
      rtcUid: 9007199254740992,
    ),
    'empty token': _validResponse(DateTime.utc(2026), token: ''),
    'oversized token': _validResponse(
      DateTime.utc(2026),
      token: ''.padRight(4097, 'x'),
    ),
    'object token': _validResponse(DateTime.utc(2026), token: <String>[]),
    'invalid isVideo': _validResponse(
      DateTime.utc(2026),
      isVideo: 'true',
    ),
    'invalid issuedAt': _validResponse(
      DateTime.utc(2026),
      issuedAt: 'not a timestamp',
    ),
    'invalid expiresAt': _validResponse(
      DateTime.utc(2026),
      expiresAt: Object(),
    ),
    'expired config': _validResponse(
      DateTime.utc(2026),
      expiresAt: DateTime.utc(2025, 12, 31, 23, 59).toIso8601String(),
    ),
    'expires before issuedAt': _validResponse(
      DateTime.utc(2026),
      issuedAt: DateTime.utc(2026, 1, 1, 12, 2).toIso8601String(),
      expiresAt: DateTime.utc(2026, 1, 1, 12, 1).toIso8601String(),
    ),
    'excessive lifetime': _validResponse(
      DateTime.utc(2026),
      issuedAt: DateTime.utc(2026, 1, 1, 12).toIso8601String(),
      expiresAt: DateTime.utc(2026, 1, 1, 12, 15, 1).toIso8601String(),
    ),
    'call mismatch': _validResponse(DateTime.utc(2026), callId: 'other_call'),
    'participant mismatch': _validResponse(
      DateTime.utc(2026),
      localParticipantUid: 'callee',
    ),
    'video mismatch': _validResponse(DateTime.utc(2026), isVideo: false),
  }.entries) {
    test('rejects ${entry.key}', () async {
      final provider = _FakeRtcConfigProvider(nextResponse: entry.value);
      final resolver = _readyResolver(provider: provider, clock: () => now);

      await expectLater(
        _resolve(resolver),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );
    });
  }

  test('issuedAt can be inside the clock skew window', () async {
    final provider = _FakeRtcConfigProvider(
      nextResponse: _validResponse(
        now,
        issuedAt: now.add(const Duration(seconds: 30)).toIso8601String(),
        expiresAt: now.add(const Duration(minutes: 10)).toIso8601String(),
      ),
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final resolved = await _resolve(resolver);

    expect(resolved.issuedAt, now.add(const Duration(seconds: 30)));
  });

  test('issuedAt beyond clock skew is rejected', () async {
    final provider = _FakeRtcConfigProvider(
      nextResponse: _validResponse(
        now,
        issuedAt: now.add(const Duration(seconds: 31)).toIso8601String(),
      ),
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await expectLater(
      _resolve(resolver),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
  });

  test('exact duplicate in-flight request shares one provider call', () async {
    final provider = _FakeRtcConfigProvider(gated: true);
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final first = _resolve(resolver);
    final second = _resolve(resolver);
    await _pump();
    provider.completeGate(0, _validResponse(now));

    final results = await Future.wait(<Future<Object?>>[first, second]);

    expect(provider.requests, hasLength(1));
    expect(identical(results[0], results[1]), isTrue);
  });

  test('different idempotency key while in flight is rejected', () async {
    final provider = _FakeRtcConfigProvider(gated: true);
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final first = _resolve(resolver);
    await expectLater(
      resolver.resolve(isVideo: true, idempotencyKey: 'other_key'),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    provider.completeGate(0, _validResponse(now));
    await first;

    expect(provider.requests, hasLength(1));
  });

  test('different video mode while in flight is rejected', () async {
    final provider = _FakeRtcConfigProvider(gated: true);
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final first = _resolve(resolver);
    await expectLater(
      resolver.resolve(isVideo: false, idempotencyKey: 'audio_key'),
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    provider.completeGate(0, _validResponse(now));
    await first;

    expect(provider.requests, hasLength(1));
  });

  test('provider failure is normalized and permits retry', () async {
    final provider = _FakeRtcConfigProvider(
      queuedErrors: <Object>[StateError('raw provider secret')],
      queuedResponses: <Object?>[_validResponse(now)],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await expectLater(
      _resolve(resolver),
      throwsA(_clientError(CallV2ClientErrorCode.unavailable)),
    );
    final resolved = await _resolve(resolver);

    expect(resolved.callId, 'call_a');
    expect(provider.requests, hasLength(2));
  });

  test('cache is reused across idempotency keys for same call participant mode',
      () async {
    final provider = _FakeRtcConfigProvider(nextResponse: _validResponse(now));
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final first = await _resolve(resolver);
    final second = await resolver.resolve(
      isVideo: true,
      idempotencyKey: 'resolve_key_two',
    );

    expect(identical(first, second), isTrue);
    expect(provider.requests, hasLength(1));
  });

  test('cache is not reused for a different video mode', () async {
    final provider = _FakeRtcConfigProvider(
      queuedResponses: <Object?>[
        _validResponse(now),
        _validResponse(now, isVideo: false),
      ],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await _resolve(resolver);
    final audio = await resolver.resolve(
      isVideo: false,
      idempotencyKey: 'audio_key',
    );

    expect(audio.isVideo, isFalse);
    expect(provider.requests, hasLength(2));
  });

  test('cache is not reused when local participant changes', () async {
    var localUid = 'caller';
    final provider = _FakeRtcConfigProvider(
      responseFactory: (request) => _validResponse(
        now,
        localParticipantUid: request.localParticipantUid,
      ),
    );
    final resolver = _readyResolver(
      provider: provider,
      localUid: () => localUid,
      clock: () => now,
    );

    await _resolve(resolver);
    localUid = 'callee';
    final second = await resolver.resolve(
      isVideo: true,
      idempotencyKey: 'callee_key',
    );

    expect(second.localParticipantUid, 'callee');
    expect(provider.requests, hasLength(2));
  });

  test('cache below minimum remaining validity is refreshed', () async {
    final provider = _FakeRtcConfigProvider(
      queuedResponses: <Object?>[
        _validResponse(
          now,
          expiresAt: now.add(const Duration(seconds: 90)).toIso8601String(),
        ),
        _validResponse(now, channelName: 'fresh_channel'),
      ],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await _resolve(resolver);
    now = now.add(const Duration(seconds: 31));
    final refreshed = await _resolve(resolver);

    expect(refreshed.channelName, 'fresh_channel');
    expect(provider.requests, hasLength(2));
  });

  test('expired cache is refreshed', () async {
    final provider = _FakeRtcConfigProvider(
      queuedResponses: <Object?>[
        _validResponse(
          now,
          expiresAt: now.add(const Duration(seconds: 90)).toIso8601String(),
        ),
        _validResponse(now.add(const Duration(minutes: 2))),
      ],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await _resolve(resolver);
    now = now.add(const Duration(minutes: 2));
    final refreshed = await _resolve(resolver);

    expect(refreshed.expiresAt, now.add(const Duration(minutes: 10)));
    expect(provider.requests, hasLength(2));
  });

  test('manual invalidate clears cache and is idempotent', () async {
    final provider = _FakeRtcConfigProvider(
      queuedResponses: <Object?>[
        _validResponse(now),
        _validResponse(now, channelName: 'after_invalidate'),
      ],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await _resolve(resolver);
    resolver.invalidate();
    resolver.invalidate();
    final refreshed = await _resolve(resolver);

    expect(refreshed.channelName, 'after_invalidate');
    expect(provider.requests, hasLength(2));
  });

  test('terminal authoritative snapshot invalidates cached config', () async {
    final provider = _FakeRtcConfigProvider(
      queuedResponses: <Object?>[
        _validResponse(now),
        _validResponse(now, channelName: 'after_terminal'),
      ],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await _resolve(resolver);
    resolver.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
    );
    final refreshed = await _resolve(resolver);

    expect(refreshed.channelName, 'after_terminal');
    expect(provider.requests, hasLength(2));
  });

  test('different-call authoritative snapshot invalidates cached config',
      () async {
    final provider = _FakeRtcConfigProvider(
      queuedResponses: <Object?>[
        _validResponse(now),
        _validResponse(now, channelName: 'after_other_call'),
      ],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await _resolve(resolver);
    resolver.handleAuthoritativeSnapshot(
      _snapshot(callId: 'other_call', lifecycle: CallLifecycle.active),
    );
    final refreshed = await _resolve(resolver);

    expect(refreshed.channelName, 'after_other_call');
    expect(provider.requests, hasLength(2));
  });

  test('manual invalidate during provider call rejects stale completion',
      () async {
    final provider = _FakeRtcConfigProvider(gated: true);
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final future = _resolve(resolver);
    await _pump();
    resolver.invalidate();
    provider.completeGate(0, _validResponse(now));

    await expectLater(
      future,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
  });

  test('terminal snapshot during provider call rejects stale completion',
      () async {
    final provider = _FakeRtcConfigProvider(gated: true);
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final future = _resolve(resolver);
    await _pump();
    resolver.handleAuthoritativeSnapshot(
      _snapshot(lifecycle: CallLifecycle.completed, version: 8),
    );
    provider.completeGate(0, _validResponse(now));

    await expectLater(
      future,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
  });

  test('late response cannot overwrite newer cache', () async {
    final provider = _FakeRtcConfigProvider(gated: true);
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final oldFuture = _resolve(resolver);
    await _pump();
    resolver.invalidate();
    final newFuture = _resolve(resolver);
    await _pump();
    provider.completeGate(
      1,
      _validResponse(now, channelName: 'new_channel'),
    );
    final newer = await newFuture;
    provider.completeGate(
      0,
      _validResponse(now, channelName: 'old_channel', token: 'old_secret'),
    );

    await expectLater(
      oldFuture,
      throwsA(_clientError(CallV2ClientErrorCode.rejected)),
    );
    final cached = await _resolve(resolver);
    expect(newer.channelName, 'new_channel');
    expect(cached.channelName, 'new_channel');
    expect(provider.requests, hasLength(2));
  });

  test('toSessionConfig maps only adapter fields', () async {
    final provider = _FakeRtcConfigProvider(
      nextResponse: _validResponse(
        now,
        channelName: 'adapter_channel',
        rtcUid: 321,
        token: 'adapter_token',
      ),
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final config = (await _resolve(resolver)).toSessionConfig();

    expect(config.callId, 'call_a');
    expect(config.channelName, 'adapter_channel');
    expect(config.rtcUid, 321);
    expect(config.isVideo, isTrue);
    expect(config.token, 'adapter_token');
  });

  test('resolved config toString redacts token', () async {
    final provider = _FakeRtcConfigProvider(
      nextResponse: _validResponse(now, token: 'super_secret_token'),
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    final resolved = await _resolve(resolver);

    expect(resolved.toString(), contains('<redacted>'));
    expect(resolved.toString(), isNot(contains('super_secret_token')));
  });

  test('raw provider error details are not exposed', () async {
    final provider = _FakeRtcConfigProvider(
      queuedErrors: <Object>[StateError('raw secret token leak')],
    );
    final resolver = _readyResolver(provider: provider, clock: () => now);

    await expectLater(
      _resolve(resolver),
      throwsA(isA<CallV2ClientError>().having(
        (error) => error.toString(),
        'toString',
        isNot(contains('raw secret token leak')),
      )),
    );
  });

  test('resolver source stays client-only and Firebase-free', () {
    final resolverSource =
        File('lib/call_v2/rtc/call_v2_rtc_config_resolver.dart')
            .readAsStringSync();
    final providerSource =
        File('lib/call_v2/rtc/call_v2_rtc_config_provider.dart')
            .readAsStringSync();
    final resolvedSource =
        File('lib/call_v2/rtc/call_v2_resolved_rtc_config.dart')
            .readAsStringSync();
    final combined = '$resolverSource\n$providerSource\n$resolvedSource';

    for (final forbidden in <String>[
      'FirebaseFirestore',
      'FirebaseAuth',
      'FirebaseAppCheck',
      'FirebaseFunctions',
      'Firebase.initializeApp',
      'Agora',
      'agora_rtc_engine',
      'connect_functions',
      'CallV2MediaSessionController(',
      'CallV2RtcAdapter ',
      'joinChannel',
      'initialize(',
    ]) {
      expect(combined.contains(forbidden), isFalse, reason: forbidden);
    }
    expect(Firebase.apps, isEmpty);
  });
}

Future<CallV2ResolvedRtcConfig> _resolve(
  CallV2RtcConfigResolver resolver,
) {
  return resolver.resolve(isVideo: true, idempotencyKey: 'resolve_key');
}

CallV2RtcConfigResolver _readyResolver({
  required _FakeRtcConfigProvider provider,
  CallSnapshot? snapshot,
  String Function()? localUid,
  DateTime Function()? clock,
}) {
  final harness = _harness();
  harness.injectPublicSnapshot(snapshot ?? _snapshot());
  return _resolver(
    provider: provider,
    harness: harness,
    localUid: localUid,
    clock: clock,
  );
}

CallV2RtcConfigResolver _resolver({
  required _FakeRtcConfigProvider provider,
  CallV2Harness? harness,
  String Function()? localUid,
  bool enabled = true,
  DateTime Function()? clock,
}) {
  return CallV2RtcConfigResolver(
    featureGate: CallV2FeatureGate(enabled: enabled),
    provider: provider,
    harness: harness ?? _harness(enabled: enabled),
    localParticipantUid: localUid ?? () => 'caller',
    clock: clock,
  );
}

CallV2Harness _harness({bool enabled = true}) {
  return CallV2Harness(
    featureGate: CallV2FeatureGate(enabled: enabled),
    api: CallV2Api(_ThrowingApi()),
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

Map<String, Object?> _validResponse(
  DateTime now, {
  Object? callId = 'call_a',
  Object? localParticipantUid = 'caller',
  Object? channelName = 'channel_a',
  Object? rtcUid = 123,
  Object? token = 'opaque_token',
  Object? isVideo = true,
  Object? issuedAt,
  Object? expiresAt,
  Object? idempotentReplay = false,
}) {
  return <String, Object?>{
    'callId': callId,
    'localParticipantUid': localParticipantUid,
    'channelName': channelName,
    'rtcUid': rtcUid,
    'token': token,
    'isVideo': isVideo,
    'issuedAt':
        issuedAt ?? now.subtract(const Duration(seconds: 5)).toIso8601String(),
    'expiresAt':
        expiresAt ?? now.add(const Duration(minutes: 10)).toIso8601String(),
    'idempotentReplay': idempotentReplay,
  };
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

class _FakeRtcConfigProvider implements CallV2RtcConfigProvider {
  _FakeRtcConfigProvider({
    this.nextResponse,
    this.responseFactory,
    this.gated = false,
    List<Object?>? queuedResponses,
    List<Object>? queuedErrors,
  })  : queuedResponses = queuedResponses ?? <Object?>[],
        queuedErrors = queuedErrors ?? <Object>[];

  final bool gated;
  final Object? nextResponse;
  final Object? Function(CallV2RtcConfigRequest request)? responseFactory;
  final List<Object?> queuedResponses;
  final List<Object> queuedErrors;
  final requests = <CallV2RtcConfigRequest>[];
  final gates = <Completer<Object?>>[];

  @override
  Future<Object?> resolveRtcConfig(CallV2RtcConfigRequest request) {
    requests.add(request);
    if (gated) {
      final gate = Completer<Object?>();
      gates.add(gate);
      return gate.future;
    }
    if (queuedErrors.isNotEmpty) {
      throw queuedErrors.removeAt(0);
    }
    if (responseFactory != null) {
      return Future<Object?>.value(responseFactory!(request));
    }
    if (queuedResponses.isNotEmpty) {
      return Future<Object?>.value(queuedResponses.removeAt(0));
    }
    return Future<Object?>.value(
      nextResponse ?? _validResponse(DateTime.utc(2026, 1, 1, 12)),
    );
  }

  void completeGate(int index, Object? value) {
    gates[index].complete(value);
  }
}

class _ThrowingApi implements CallableCallV2Api {
  @override
  Future<Object?> acceptCallV2(Map<String, Object?> request) =>
      throw StateError('unexpected API call');

  @override
  Future<Object?> cancelCallV2(Map<String, Object?> request) =>
      throw StateError('unexpected API call');

  @override
  Future<Object?> declineCallV2(Map<String, Object?> request) =>
      throw StateError('unexpected API call');

  @override
  Future<Object?> endCallV2(Map<String, Object?> request) =>
      throw StateError('unexpected API call');

  @override
  Future<Object?> renewActiveCallLeaseV2(Map<String, Object?> request) =>
      throw StateError('unexpected API call');

  @override
  Future<Object?> reportParticipantMediaV2(Map<String, Object?> request) =>
      throw StateError('unexpected API call');

  @override
  Future<Object?> startCallV2(Map<String, Object?> request) =>
      throw StateError('unexpected API call');
}
