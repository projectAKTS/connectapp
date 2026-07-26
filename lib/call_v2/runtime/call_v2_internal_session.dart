import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'call_v2_runtime_state.dart';

class CallV2InternalParticipantHandle {
  const CallV2InternalParticipantHandle._({
    required this.value,
    required this.safeLabel,
  });

  factory CallV2InternalParticipantHandle.fromIdentifier(String value) {
    final normalized = _requireIdentifier(value);
    return CallV2InternalParticipantHandle._(
      value: normalized,
      safeLabel: _safeOpaqueLabel(normalized),
    );
  }

  final String value;
  final String safeLabel;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'label': safeLabel,
      'present': value.isNotEmpty,
    };
  }

  @override
  String toString() => 'CallV2InternalHandle(${toSafeDebugMap()})';
}

class CallV2InternalSession {
  const CallV2InternalSession._({
    required this.callIdentifier,
    required this.localHandle,
    required this.remoteHandle,
    required this.mode,
    required this.direction,
    required this.phase,
    required this.accessReady,
    required this.rtcReady,
  });

  factory CallV2InternalSession.outgoing({
    required String callIdentifier,
    required String localIdentifier,
    required String remoteIdentifier,
    required CallV2RuntimeCallMode mode,
  }) {
    final local = CallV2InternalParticipantHandle.fromIdentifier(
      localIdentifier,
    );
    final remote = CallV2InternalParticipantHandle.fromIdentifier(
      remoteIdentifier,
    );
    if (local.value == remote.value) {
      throw const CallV2InternalSessionError();
    }
    return CallV2InternalSession._(
      callIdentifier: _requireIdentifier(callIdentifier),
      localHandle: local,
      remoteHandle: remote,
      mode: mode,
      direction: CallV2RuntimeDirection.outgoing,
      phase: CallV2RuntimePhase.idle,
      accessReady: false,
      rtcReady: false,
    );
  }

  factory CallV2InternalSession.incoming({
    required String callIdentifier,
    required String localIdentifier,
    required String remoteIdentifier,
    required CallV2RuntimeCallMode mode,
  }) {
    final local = CallV2InternalParticipantHandle.fromIdentifier(
      localIdentifier,
    );
    final remote = CallV2InternalParticipantHandle.fromIdentifier(
      remoteIdentifier,
    );
    if (local.value == remote.value) {
      throw const CallV2InternalSessionError();
    }
    return CallV2InternalSession._(
      callIdentifier: _requireIdentifier(callIdentifier),
      localHandle: local,
      remoteHandle: remote,
      mode: mode,
      direction: CallV2RuntimeDirection.incoming,
      phase: CallV2RuntimePhase.idle,
      accessReady: false,
      rtcReady: false,
    );
  }

  final String callIdentifier;
  final CallV2InternalParticipantHandle localHandle;
  final CallV2InternalParticipantHandle remoteHandle;
  final CallV2RuntimeCallMode mode;
  final CallV2RuntimeDirection direction;
  final CallV2RuntimePhase phase;
  final bool accessReady;
  final bool rtcReady;

  CallV2InternalSession copyWith({
    CallV2RuntimePhase? phase,
    bool? accessReady,
    bool? rtcReady,
  }) {
    return CallV2InternalSession._(
      callIdentifier: callIdentifier,
      localHandle: localHandle,
      remoteHandle: remoteHandle,
      mode: mode,
      direction: direction,
      phase: phase ?? this.phase,
      accessReady: accessReady ?? this.accessReady,
      rtcReady: rtcReady ?? this.rtcReady,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'local': localHandle.toSafeDebugMap(),
      'remote': remoteHandle.toSafeDebugMap(),
      'mode': mode.name,
      'direction': direction.name,
      'phase': phase.name,
      'accessReady': accessReady,
      'setupReady': rtcReady,
    };
  }

  @override
  String toString() => 'CallV2InternalSession(${toSafeDebugMap()})';
}

class CallV2InternalSessionError implements Exception {
  const CallV2InternalSessionError();
}

String _requireIdentifier(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      value.length > 128 ||
      value.contains('/')) {
    throw const CallV2InternalSessionError();
  }
  return value;
}

String _safeOpaqueLabel(String value) {
  final digest = sha256.convert(utf8.encode(value)).toString();
  return 'h${digest.substring(0, 12)}';
}
