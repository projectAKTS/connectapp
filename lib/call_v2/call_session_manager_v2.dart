import 'dart:async';

import 'call_v2_api.dart';
import 'call_v2_callable_results.dart';
import 'call_v2_feature_gate.dart';
import 'domain/call_lifecycle.dart';
import 'domain/call_local_phase.dart';
import 'domain/call_snapshot.dart';
import 'pending_started_call_v2.dart';

class CallSessionManagerV2 {
  CallSessionManagerV2({
    required CallV2FeatureGate featureGate,
    required CallV2Api api,
    required CallParticipantRole Function() localParticipantRole,
  })  : _featureGate = featureGate,
        _localParticipantRole = localParticipantRole,
        _api = api;

  final CallV2FeatureGate _featureGate;
  final CallParticipantRole Function() _localParticipantRole;
  final CallV2Api _api;
  CallSnapshot? _snapshot;
  PendingStartedCallV2? _pendingStartedCall;
  _StartRequestIdentity? _inFlightStartRequest;
  bool _commandInFlight = false;
  bool _cleanupCompleted = false;
  final List<_QueuedCommand> _commandQueue = <_QueuedCommand>[];
  final Map<String, Future<Object?>> _activeCommands =
      <String, Future<Object?>>{};

  CallSnapshot? get snapshot => _snapshot;

  PendingStartedCallV2? get pendingStartedCall => _pendingStartedCall;

  CallLocalPhase get localPhase =>
      _snapshot == null ? CallLocalPhase.idle : _localPhaseFor(_snapshot!);

  void injectSnapshot(CallSnapshot snapshot) {
    if (!_featureGate.enabled) return;
    final pendingStartedCall = _pendingStartedCall;
    if (pendingStartedCall != null &&
        pendingStartedCall.callId != snapshot.callId) {
      return;
    }
    if (_snapshot != null && _snapshot!.callId != snapshot.callId) return;
    if (_snapshot != null && _snapshot!.lifecycle.isTerminal) {
      if (!snapshot.lifecycle.isTerminal ||
          snapshot.version <= _snapshot!.version) {
        return;
      }
    }
    if (_snapshot != null &&
        snapshot.version <= _snapshot!.version &&
        !_snapshot!.lifecycle.isTerminal) {
      return;
    }
    _snapshot = snapshot;
    if (pendingStartedCall != null &&
        pendingStartedCall.callId == snapshot.callId) {
      _pendingStartedCall = null;
    }
    if (snapshot.lifecycle.isTerminal) {
      _cleanupCompleted = false;
    }
  }

  Future<StartCallV2Result> startCall(StartCallV2Request request) async {
    if (_snapshot != null && _snapshot!.lifecycle.isNonTerminal) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    final pendingStartedCall = _pendingStartedCall;
    if (pendingStartedCall != null &&
        (pendingStartedCall.calleeUid != request.calleeUid ||
            pendingStartedCall.idempotencyKey != request.idempotencyKey)) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    const key = 'start';
    final existingStartRequest = _inFlightStartRequest;
    final startRequest =
        existingStartRequest ?? _StartRequestIdentity.fromRequest(request);
    final capturedFirstRequest = existingStartRequest == null;
    if (capturedFirstRequest) {
      _inFlightStartRequest = startRequest;
    }
    final StartCallV2Result result;
    try {
      result = await _runCommand(
        key,
        () => _api.startCallV2(request),
      );
    } finally {
      if (capturedFirstRequest &&
          identical(_inFlightStartRequest, startRequest)) {
        _inFlightStartRequest = null;
      }
    }
    final currentPending = _pendingStartedCall;
    if (currentPending != null) {
      if (currentPending.callId != result.callId) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }
      if (currentPending.calleeUid == startRequest.calleeUid &&
          currentPending.idempotencyKey == startRequest.idempotencyKey) {
        _pendingStartedCall = PendingStartedCallV2(
          callId: currentPending.callId,
          calleeUid: currentPending.calleeUid,
          idempotencyKey: currentPending.idempotencyKey,
          version: result.version,
          idempotentReplay: result.idempotentReplay,
          ringingDeadlineAt: result.ringingDeadlineAt,
        );
      }
      return result;
    }
    _pendingStartedCall = PendingStartedCallV2(
      callId: result.callId,
      calleeUid: startRequest.calleeUid,
      idempotencyKey: startRequest.idempotencyKey,
      version: result.version,
      idempotentReplay: result.idempotentReplay,
      ringingDeadlineAt: result.ringingDeadlineAt,
    );
    return result;
  }

  Future<CallV2LifecycleCommandResult> acceptCall(
    CallV2LifecycleCommandRequest request,
  ) {
    return _runCommand(
      'accept:${request.callId}',
      () => _api.acceptCallV2(request),
    );
  }

  Future<CallV2LifecycleCommandResult> declineCall(
    CallV2LifecycleCommandRequest request,
  ) {
    return _runCommand(
      'decline:${request.callId}',
      () => _api.declineCallV2(request),
    );
  }

  Future<CallV2LifecycleCommandResult> cancelCall(
    CallV2LifecycleCommandRequest request,
  ) {
    return _runCommand(
      'cancel:${request.callId}',
      () => _api.cancelCallV2(request),
    );
  }

  Future<CallV2LifecycleCommandResult> endCall(
    CallV2LifecycleCommandRequest request,
  ) {
    return _runCommand(
      'end:${request.callId}',
      () => _api.endCallV2(request),
    );
  }

  Future<CallV2MediaReportResult> reportMedia(
    CallV2MediaReportRequest request,
  ) {
    return _runCommand(
      'media:${request.callId}',
      () => _api.reportParticipantMediaV2(request),
    );
  }

  Future<CallV2LeaseRenewalResult> renewLease(
    CallV2LeaseRenewalRequest request,
  ) {
    return _runCommand(
      'lease:${request.callId}',
      () => _api.renewActiveCallLeaseV2(request),
    );
  }

  Future<void> cleanupIfTerminal() async {
    final snapshot = _snapshot;
    if (_pendingStartedCall != null && snapshot == null) {
      _pendingStartedCall = null;
      _inFlightStartRequest = null;
      _commandQueue.clear();
      _activeCommands.clear();
      _commandInFlight = false;
      return;
    }
    if (snapshot == null ||
        !snapshot.lifecycle.isTerminal ||
        _cleanupCompleted) {
      return;
    }
    _cleanupCompleted = true;
    _snapshot = null;
    _pendingStartedCall = null;
    _inFlightStartRequest = null;
    _commandQueue.clear();
    _activeCommands.clear();
    _commandInFlight = false;
  }

  Future<T> _runCommand<T>(String key, Future<T> Function() action) {
    if (!_featureGate.enabled) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    final existing = _activeCommands[key];
    if (existing != null) {
      return existing.then((value) => value as T);
    }
    final completer = Completer<Object?>();
    _activeCommands[key] = completer.future;
    _commandQueue.add(_QueuedCommand(
      key,
      () async => action(),
      completer,
    ));
    if (_commandInFlight) {
      return completer.future.then((value) => value as T);
    }
    _drainCommandQueue();
    return completer.future.then((value) => value as T);
  }

  Future<void> _drainCommandQueue() async {
    _commandInFlight = true;
    try {
      while (_commandQueue.isNotEmpty) {
        final next = _commandQueue.removeAt(0);
        try {
          final result = await next.action();
          next.completer.complete(result);
        } catch (error, stackTrace) {
          next.completer.completeError(error, stackTrace);
        } finally {
          _activeCommands.remove(next.key);
        }
      }
    } finally {
      _commandInFlight = false;
    }
  }

  CallLocalPhase _localPhaseFor(CallSnapshot snapshot) {
    final localRole = _localParticipantRole();
    switch (snapshot.lifecycle) {
      case CallLifecycle.ringing:
        return localRole == CallParticipantRole.caller
            ? CallLocalPhase.outgoingRinging
            : CallLocalPhase.presentingIncoming;
      case CallLifecycle.accepted:
        return CallLocalPhase.openingCallRoute;
      case CallLifecycle.active:
        return CallLocalPhase.inCall;
      case CallLifecycle.completed:
      case CallLifecycle.declined:
      case CallLifecycle.cancelled:
      case CallLifecycle.missed:
      case CallLifecycle.failed:
        return CallLocalPhase.closing;
    }
  }
}

class _QueuedCommand {
  const _QueuedCommand(this.key, this.action, this.completer);

  final String key;
  final Future<Object?> Function() action;
  final Completer<Object?> completer;
}

class _StartRequestIdentity {
  const _StartRequestIdentity({
    required this.calleeUid,
    required this.idempotencyKey,
  });

  factory _StartRequestIdentity.fromRequest(StartCallV2Request request) {
    return _StartRequestIdentity(
      calleeUid: request.calleeUid,
      idempotencyKey: request.idempotencyKey,
    );
  }

  final String calleeUid;
  final String idempotencyKey;
}
