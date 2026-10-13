import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_v2_agora_media_runtime.dart';
import 'call_v2_real_call_flow_gate.dart';

@immutable
class CallV2PhysicalMediaKey {
  const CallV2PhysicalMediaKey({
    required this.inviteId,
    required this.acceptedCallkitId,
    required this.lifecycleGeneration,
    required this.channel,
    required this.isVideo,
    required this.isCaller,
    required this.connectionSystem,
  });

  final String inviteId;
  final String acceptedCallkitId;
  final int lifecycleGeneration;
  final String channel;
  final bool isVideo;
  final bool isCaller;
  final CallV2RealCallConnectionSystem connectionSystem;

  bool get hasExactAcceptedCallkitId => acceptedCallkitId.trim().isNotEmpty;

  bool matches(CallV2PhysicalMediaKey other) {
    return inviteId == other.inviteId &&
        acceptedCallkitId.trim().toLowerCase() ==
            other.acceptedCallkitId.trim().toLowerCase() &&
        lifecycleGeneration == other.lifecycleGeneration &&
        channel == other.channel &&
        isVideo == other.isVideo &&
        isCaller == other.isCaller &&
        connectionSystem == other.connectionSystem;
  }
}

enum CallV2PhysicalMediaOwnerPhase {
  waitingAuthority,
  waitingAudioSession,
  checkingPermission,
  starting,
  tokenReady,
  engineReady,
  joining,
  joined,
  terminal,
  failed,
}

@immutable
class CallV2PhysicalMediaOwnerState {
  const CallV2PhysicalMediaOwnerState({
    required this.phase,
    required this.authorityReady,
    required this.audioSessionReady,
    required this.permissionReady,
    required this.joined,
    required this.remoteParticipantPresent,
    required this.muted,
    required this.speakerEnabled,
    required this.mediaActive,
    required this.failureCode,
  });

  final CallV2PhysicalMediaOwnerPhase phase;
  final bool authorityReady;
  final bool audioSessionReady;
  final bool permissionReady;
  final bool joined;
  final bool remoteParticipantPresent;
  final bool muted;
  final bool speakerEnabled;
  final bool mediaActive;
  final String failureCode;

  bool get terminal => phase == CallV2PhysicalMediaOwnerPhase.terminal;
}

typedef CallV2MicrophonePermissionStatus = Future<bool> Function();
typedef CallV2MicrophonePermissionRequest = Future<bool> Function();

class CallV2PhysicalMediaClaim {
  const CallV2PhysicalMediaClaim({
    required this.key,
    required this.authorityReady,
    required this.requiresExactAudioSession,
    required this.allowPermissionRequest,
    required this.runtimeConfig,
    required this.onPermissionUnavailable,
    required this.onEndRequested,
  });

  final CallV2PhysicalMediaKey key;
  final bool authorityReady;
  final bool requiresExactAudioSession;
  final bool allowPermissionRequest;
  final CallV2AgoraMediaRuntimeConfig runtimeConfig;
  final Future<void> Function(String reason) onPermissionUnavailable;
  final Future<void> Function() onEndRequested;
}

class CallV2PhysicalMediaAttachment {
  CallV2PhysicalMediaAttachment._(this._session);

  final _OwnedPhysicalMediaSession _session;
  bool _detached = false;

  CallV2PhysicalMediaKey get key => _session.claim.key;
  ValueListenable<CallV2PhysicalMediaOwnerState> get state => _session.state;

  Future<void> setMuted(bool muted) {
    if (_detached) return Future<void>.value();
    return _session.runtime?.setMuted(muted) ?? Future<void>.value();
  }

  Future<void> setSpeakerEnabled(bool enabled) {
    if (_detached) return Future<void>.value();
    return _session.runtime?.setSpeakerEnabled(enabled) ?? Future<void>.value();
  }

  Future<void> switchCamera() {
    if (_detached) return Future<void>.value();
    return _session.runtime?.switchCamera() ?? Future<void>.value();
  }

  Future<void> requestEnd() {
    if (_detached) return Future<void>.value();
    return _session.claim.onEndRequested();
  }

  void detach() {
    _detached = true;
  }
}

class CallV2PhysicalMediaOwner {
  CallV2PhysicalMediaOwner({
    CallV2PhysicalMediaRuntimeFactory? runtimeFactory,
    CallV2MicrophonePermissionStatus? microphonePermissionStatus,
    CallV2MicrophonePermissionRequest? microphonePermissionRequest,
  })  : _runtimeFactory = runtimeFactory ?? CallV2AgoraMediaRuntime.new,
        _microphonePermissionStatus = microphonePermissionStatus ??
            (() async => (await Permission.microphone.status).isGranted),
        _microphonePermissionRequest = microphonePermissionRequest ??
            (() async => (await Permission.microphone.request()).isGranted);

  static final CallV2PhysicalMediaOwner instance = CallV2PhysicalMediaOwner();

  final CallV2PhysicalMediaRuntimeFactory _runtimeFactory;
  final CallV2MicrophonePermissionStatus _microphonePermissionStatus;
  final CallV2MicrophonePermissionRequest _microphonePermissionRequest;
  final Set<String> _audioSessionReadyExactIds = <String>{};
  _OwnedPhysicalMediaSession? _owned;

  CallV2PhysicalMediaKey? get activeKey => _owned?.claim.key;
  bool get hasOwner => _owned != null;

  CallV2PhysicalMediaAttachment claim(CallV2PhysicalMediaClaim claim) {
    final existing = _owned;
    if (existing != null) {
      if (!existing.claim.key.matches(claim.key)) {
        throw StateError('A different physical media session is active.');
      }
      existing.authorityReady = existing.authorityReady || claim.authorityReady;
      existing.allowPermissionRequest =
          existing.allowPermissionRequest || claim.allowPermissionRequest;
      _applyLatchedAudioReadiness(existing);
      unawaited(_converge(existing));
      return CallV2PhysicalMediaAttachment._(existing);
    }

    if (claim.key.isCaller && claim.requiresExactAudioSession) {
      throw StateError('Outgoing media cannot require incoming CallKit audio.');
    }
    if (claim.requiresExactAudioSession &&
        !claim.key.hasExactAcceptedCallkitId) {
      throw StateError(
          'Accepted CallKit media requires exact native identity.');
    }
    final session = _OwnedPhysicalMediaSession(
      claim: claim,
      authorityReady: claim.authorityReady,
      allowPermissionRequest: claim.allowPermissionRequest,
    );
    _owned = session;
    _applyLatchedAudioReadiness(session);
    _publishReadiness(session);
    unawaited(_converge(session));
    return CallV2PhysicalMediaAttachment._(session);
  }

  CallV2PhysicalMediaAttachment? attach(CallV2PhysicalMediaKey key) {
    final session = _owned;
    if (session == null || !session.claim.key.matches(key)) return null;
    return CallV2PhysicalMediaAttachment._(session);
  }

  bool markAudioSessionReady(String exactCallkitId) {
    final exact = exactCallkitId.trim().toLowerCase();
    if (exact.isEmpty) return false;
    _audioSessionReadyExactIds.add(exact);
    final session = _owned;
    if (session == null ||
        session.claim.key.acceptedCallkitId.trim().toLowerCase() != exact) {
      return false;
    }
    session.audioSessionReady = true;
    _publishReadiness(session);
    unawaited(_converge(session));
    return true;
  }

  void markAudioSessionUnavailable(String exactCallkitId) {
    final exact = exactCallkitId.trim().toLowerCase();
    if (exact.isEmpty) return;
    _audioSessionReadyExactIds.remove(exact);
    final session = _owned;
    if (session != null &&
        session.claim.key.acceptedCallkitId.trim().toLowerCase() == exact &&
        session.runtime == null) {
      session.audioSessionReady = false;
      _publishReadiness(session);
    }
  }

  Future<void> terminate(
    CallV2PhysicalMediaKey key, {
    required String reason,
  }) async {
    final session = _owned;
    if (session == null || !session.claim.key.matches(key)) return;
    session.current = false;
    session.state.value = _stateFor(
      session,
      phase: CallV2PhysicalMediaOwnerPhase.terminal,
    );
    _audioSessionReadyExactIds.remove(
      key.acceptedCallkitId.trim().toLowerCase(),
    );
    final listener = session.runtimeListener;
    if (listener != null) {
      session.runtime?.state.removeListener(listener);
      session.runtimeListener = null;
    }
    final cleanup = session.cleanupFuture ?? session.runtime?.cleanup();
    session.cleanupFuture = cleanup;
    if (cleanup != null) await cleanup;
    if (identical(_owned, session)) _owned = null;
  }

  Future<void> resetForTest() async {
    final session = _owned;
    if (session != null) {
      session.current = false;
      final listener = session.runtimeListener;
      if (listener != null) {
        session.runtime?.state.removeListener(listener);
      }
      await session.runtime?.cleanup();
    }
    _owned = null;
    _audioSessionReadyExactIds.clear();
  }

  void _applyLatchedAudioReadiness(_OwnedPhysicalMediaSession session) {
    if (!session.claim.requiresExactAudioSession) {
      session.audioSessionReady = true;
      return;
    }
    session.audioSessionReady = _audioSessionReadyExactIds.contains(
      session.claim.key.acceptedCallkitId.trim().toLowerCase(),
    );
  }

  Future<void> _converge(_OwnedPhysicalMediaSession session) {
    final active = session.startFuture;
    if (active != null) return active;
    if (!session.current || !identical(_owned, session)) {
      return Future<void>.value();
    }
    if (!session.authorityReady || !session.audioSessionReady) {
      _publishReadiness(session);
      return Future<void>.value();
    }
    final future = _start(session);
    session.startFuture = future;
    return future;
  }

  Future<void> _start(_OwnedPhysicalMediaSession session) async {
    session.state.value = _stateFor(
      session,
      phase: CallV2PhysicalMediaOwnerPhase.checkingPermission,
    );
    var granted = await _microphonePermissionStatus();
    if (!_owns(session)) return;
    if (!granted && session.allowPermissionRequest) {
      granted = await _microphonePermissionRequest();
      if (!_owns(session)) return;
    }
    if (!granted) {
      session.current = false;
      session.state.value = _stateFor(
        session,
        phase: CallV2PhysicalMediaOwnerPhase.failed,
        failureCode: 'background_microphone_permission_unavailable',
      );
      await session.claim.onPermissionUnavailable(
        'background_microphone_permission_unavailable',
      );
      return;
    }
    session.permissionReady = true;
    session.state.value = _stateFor(
      session,
      phase: CallV2PhysicalMediaOwnerPhase.starting,
    );
    final runtime = _runtimeFactory(session.claim.runtimeConfig);
    session.runtime = runtime;
    session.runtimeListener = () => _applyRuntimeState(session);
    runtime.state.addListener(session.runtimeListener!);
    try {
      await runtime.start();
    } finally {
      if (_owns(session)) _applyRuntimeState(session);
    }
  }

  void _applyRuntimeState(_OwnedPhysicalMediaSession session) {
    if (!_owns(session)) return;
    final runtimeState = session.runtime?.state.value;
    if (runtimeState == null) return;
    final phase = switch (runtimeState.phase) {
      CallV2AgoraMediaPhase.preparing => CallV2PhysicalMediaOwnerPhase.starting,
      CallV2AgoraMediaPhase.tokenReady =>
        CallV2PhysicalMediaOwnerPhase.tokenReady,
      CallV2AgoraMediaPhase.engineReady =>
        CallV2PhysicalMediaOwnerPhase.engineReady,
      CallV2AgoraMediaPhase.joining => CallV2PhysicalMediaOwnerPhase.joining,
      CallV2AgoraMediaPhase.joined => CallV2PhysicalMediaOwnerPhase.joined,
      CallV2AgoraMediaPhase.terminal => CallV2PhysicalMediaOwnerPhase.terminal,
      CallV2AgoraMediaPhase.failed => CallV2PhysicalMediaOwnerPhase.failed,
      CallV2AgoraMediaPhase.idle => CallV2PhysicalMediaOwnerPhase.starting,
    };
    session.state.value = CallV2PhysicalMediaOwnerState(
      phase: phase,
      authorityReady: session.authorityReady,
      audioSessionReady: session.audioSessionReady,
      permissionReady: session.permissionReady,
      joined: runtimeState.joined,
      remoteParticipantPresent: runtimeState.remoteParticipantPresent,
      muted: runtimeState.muted,
      speakerEnabled: runtimeState.speakerEnabled,
      mediaActive: runtimeState.mediaActive,
      failureCode: runtimeState.failureCode,
    );
  }

  void _publishReadiness(_OwnedPhysicalMediaSession session) {
    final phase = !session.authorityReady
        ? CallV2PhysicalMediaOwnerPhase.waitingAuthority
        : !session.audioSessionReady
            ? CallV2PhysicalMediaOwnerPhase.waitingAudioSession
            : CallV2PhysicalMediaOwnerPhase.checkingPermission;
    session.state.value = _stateFor(session, phase: phase);
  }

  CallV2PhysicalMediaOwnerState _stateFor(
    _OwnedPhysicalMediaSession session, {
    required CallV2PhysicalMediaOwnerPhase phase,
    String failureCode = 'none',
  }) {
    final runtime = session.runtime?.state.value;
    return CallV2PhysicalMediaOwnerState(
      phase: phase,
      authorityReady: session.authorityReady,
      audioSessionReady: session.audioSessionReady,
      permissionReady: session.permissionReady,
      joined: runtime?.joined ?? false,
      remoteParticipantPresent: runtime?.remoteParticipantPresent ?? false,
      muted: runtime?.muted ?? false,
      speakerEnabled: runtime?.speakerEnabled ?? true,
      mediaActive: runtime?.mediaActive ?? false,
      failureCode: failureCode,
    );
  }

  bool _owns(_OwnedPhysicalMediaSession session) {
    return session.current && identical(_owned, session);
  }
}

class _OwnedPhysicalMediaSession {
  _OwnedPhysicalMediaSession({
    required this.claim,
    required this.authorityReady,
    required this.allowPermissionRequest,
  }) : state = ValueNotifier<CallV2PhysicalMediaOwnerState>(
          CallV2PhysicalMediaOwnerState(
            phase: CallV2PhysicalMediaOwnerPhase.waitingAuthority,
            authorityReady: authorityReady,
            audioSessionReady: false,
            permissionReady: false,
            joined: false,
            remoteParticipantPresent: false,
            muted: false,
            speakerEnabled: true,
            mediaActive: false,
            failureCode: 'none',
          ),
        );

  final CallV2PhysicalMediaClaim claim;
  final ValueNotifier<CallV2PhysicalMediaOwnerState> state;
  bool authorityReady;
  bool audioSessionReady = false;
  bool permissionReady = false;
  bool allowPermissionRequest;
  bool current = true;
  CallV2PhysicalMediaRuntime? runtime;
  VoidCallback? runtimeListener;
  Future<void>? startFuture;
  Future<void>? cleanupFuture;
}
