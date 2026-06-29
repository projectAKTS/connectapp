import 'call_v2_api.dart';
import 'call_v2_feature_gate.dart';
import 'domain/call_v2_models.dart';

class CallSessionManagerV2 {
  CallSessionManagerV2({
    required CallV2FeatureGate featureGate,
    required CallV2Api api,
  })  : _featureGate = featureGate,
        _api = api;

  final CallV2FeatureGate _featureGate;
  final CallV2Api _api;
  CallV2Snapshot? _snapshot;
  bool _commandInFlight = false;
  bool _cleanupCompleted = false;
  final List<_QueuedCommand> _commandQueue = <_QueuedCommand>[];

  CallV2Snapshot? get snapshot => _snapshot;

  CallV2LocalPhase get localPhase =>
      _snapshot == null ? CallV2LocalPhase.idle : _localPhaseFor(_snapshot!);

  void injectSnapshot(CallV2Snapshot snapshot) {
    if (!_featureGate.enabled) return;
    if (_snapshot != null && _snapshot!.callId != snapshot.callId) return;
    if (_snapshot != null &&
        snapshot.version < _snapshot!.version &&
        !_snapshot!.lifecycle.isTerminal) {
      return;
    }
    _snapshot = snapshot;
    if (snapshot.lifecycle.isTerminal) {
      _cleanupCompleted = false;
    }
  }

  Future<void> startCall(CallV2RequestContext context) async {
    await _runCommand(
        'start:${context.callId}', () => _api.startCallV2(context));
  }

  Future<void> acceptCall(CallV2RequestContext context) async {
    await _runCommand(
        'accept:${context.callId}', () => _api.acceptCallV2(context));
  }

  Future<void> declineCall(CallV2RequestContext context) async {
    await _runCommand(
        'decline:${context.callId}', () => _api.declineCallV2(context));
  }

  Future<void> cancelCall(CallV2RequestContext context) async {
    await _runCommand(
        'cancel:${context.callId}', () => _api.cancelCallV2(context));
  }

  Future<void> endCall(CallV2RequestContext context) async {
    await _runCommand('end:${context.callId}', () => _api.endCallV2(context));
  }

  Future<void> reportMedia(
    CallV2RequestContext context, {
    required CallV2ParticipantMediaState mediaState,
    required int mediaVersion,
  }) async {
    await _runCommand(
      'media:${context.callId}:$mediaVersion',
      () => _api.reportParticipantMediaV2(
        context,
        mediaState: mediaState,
        mediaVersion: mediaVersion,
      ),
    );
  }

  Future<void> renewLease(CallV2RequestContext context) async {
    await _runCommand(
        'lease:${context.callId}', () => _api.renewActiveCallLeaseV2(context));
  }

  Future<void> cleanupIfTerminal() async {
    final snapshot = _snapshot;
    if (snapshot == null ||
        !snapshot.lifecycle.isTerminal ||
        _cleanupCompleted) {
      return;
    }
    _cleanupCompleted = true;
  }

  Future<void> _runCommand(String key, Future<void> Function() action) async {
    if (!_featureGate.enabled) return;
    _commandQueue.add(_QueuedCommand(key, action));
    if (_commandInFlight) {
      return;
    }
    _commandInFlight = true;
    try {
      while (_commandQueue.isNotEmpty) {
        final next = _commandQueue.removeAt(0);
        await next.action();
      }
    } finally {
      _commandInFlight = false;
    }
  }

  CallV2LocalPhase _localPhaseFor(CallV2Snapshot snapshot) {
    switch (snapshot.lifecycle) {
      case CallV2Lifecycle.ringing:
        return CallV2LocalPhase.incomingRinging;
      case CallV2Lifecycle.accepted:
        return CallV2LocalPhase.openingRoute;
      case CallV2Lifecycle.active:
        return CallV2LocalPhase.inCall;
      case CallV2Lifecycle.completed:
      case CallV2Lifecycle.declined:
      case CallV2Lifecycle.cancelled:
      case CallV2Lifecycle.missed:
      case CallV2Lifecycle.failed:
        return CallV2LocalPhase.closing;
    }
  }
}

class _QueuedCommand {
  const _QueuedCommand(this.key, this.action);

  final String key;
  final Future<void> Function() action;
}
