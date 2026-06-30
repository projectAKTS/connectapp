import 'call_v2_api.dart';
import 'call_v2_feature_gate.dart';
import 'domain/call_lifecycle.dart';
import 'domain/call_local_phase.dart';
import 'domain/call_snapshot.dart';

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
  bool _commandInFlight = false;
  String? _inFlightCommandKey;
  bool _cleanupCompleted = false;
  final List<_QueuedCommand> _commandQueue = <_QueuedCommand>[];

  CallSnapshot? get snapshot => _snapshot;

  CallLocalPhase get localPhase =>
      _snapshot == null ? CallLocalPhase.idle : _localPhaseFor(_snapshot!);

  void injectSnapshot(CallSnapshot snapshot) {
    if (!_featureGate.enabled) return;
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
    if (snapshot.lifecycle.isTerminal) {
      _cleanupCompleted = false;
    }
  }

  Future<void> startCall(StartCallV2Request request) async {
    await _runCommand(
      'start:${request.calleeUid}',
      () => _api.startCallV2(request),
    );
  }

  Future<void> acceptCall(CallV2LifecycleCommandRequest request) async {
    await _runCommand(
      'accept:${request.callId}',
      () => _api.acceptCallV2(request),
    );
  }

  Future<void> declineCall(CallV2LifecycleCommandRequest request) async {
    await _runCommand(
      'decline:${request.callId}',
      () => _api.declineCallV2(request),
    );
  }

  Future<void> cancelCall(CallV2LifecycleCommandRequest request) async {
    await _runCommand(
      'cancel:${request.callId}',
      () => _api.cancelCallV2(request),
    );
  }

  Future<void> endCall(CallV2LifecycleCommandRequest request) async {
    await _runCommand(
      'end:${request.callId}',
      () => _api.endCallV2(request),
    );
  }

  Future<void> reportMedia(CallV2MediaReportRequest request) async {
    await _runCommand(
      'media:${request.callId}',
      () => _api.reportParticipantMediaV2(request),
    );
  }

  Future<void> renewLease(CallV2LeaseRenewalRequest request) async {
    await _runCommand(
      'lease:${request.callId}',
      () => _api.renewActiveCallLeaseV2(request),
    );
  }

  Future<void> cleanupIfTerminal() async {
    final snapshot = _snapshot;
    if (snapshot == null ||
        !snapshot.lifecycle.isTerminal ||
        _cleanupCompleted) {
      return;
    }
    _cleanupCompleted = true;
    _snapshot = null;
    _commandQueue.clear();
    _inFlightCommandKey = null;
    _commandInFlight = false;
  }

  Future<void> _runCommand(String key, Future<void> Function() action) async {
    if (!_featureGate.enabled) return;
    if (_inFlightCommandKey == key ||
        _commandQueue.any((item) => item.key == key)) {
      return;
    }
    _commandQueue.add(_QueuedCommand(key, action));
    if (_commandInFlight) {
      return;
    }
    _commandInFlight = true;
    try {
      while (_commandQueue.isNotEmpty) {
        final next = _commandQueue.removeAt(0);
        _inFlightCommandKey = next.key;
        await next.action();
      }
    } finally {
      _commandInFlight = false;
      _inFlightCommandKey = null;
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
  const _QueuedCommand(this.key, this.action);

  final String key;
  final Future<void> Function() action;
}
