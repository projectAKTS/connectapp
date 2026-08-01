enum CallV2CallLifecycleState {
  idle,
  reserving,
  incomingPrompt,
  outgoingRinging,
  joining,
  connected,
  ending,
  teardown,
}

enum CallV2CallReservationAction {
  reserved,
  duplicate,
  busyDecline,
  pending,
  blocked,
}

class CallV2CallReservation {
  const CallV2CallReservation({
    required this.action,
    required this.generation,
    required this.lifecycleState,
  });

  final CallV2CallReservationAction action;
  final int generation;
  final CallV2CallLifecycleState lifecycleState;

  bool get reserved => action == CallV2CallReservationAction.reserved;
}

class CallV2CallLifecycleArbiter {
  CallV2CallLifecycleState _state = CallV2CallLifecycleState.idle;
  int _generation = 0;
  String? _claimedInviteId;
  String? _pendingInviteId;
  int _duplicateInviteSuppressedCount = 0;
  int _busyInviteDeclinedCount = 0;
  int _staleCandidateDroppedCount = 0;
  int _rapidRedialBlockedCount = 0;

  CallV2CallLifecycleState get state => _state;
  int get generation => _generation;
  bool get incomingPipelineBusy =>
      _state == CallV2CallLifecycleState.incomingPrompt;
  bool get incomingCandidateClaimed => _claimedInviteId != null;
  bool get pendingIncomingPresent => _pendingInviteId != null;
  int get pendingIncomingCount => _pendingInviteId == null ? 0 : 1;
  int get activePromptCount =>
      _state == CallV2CallLifecycleState.incomingPrompt ? 1 : 0;
  int get activeCallRouteCount => _state == CallV2CallLifecycleState.joining ||
          _state == CallV2CallLifecycleState.connected ||
          _state == CallV2CallLifecycleState.outgoingRinging
      ? 1
      : 0;
  bool get outgoingReservationActive =>
      _state == CallV2CallLifecycleState.reserving;
  bool get teardownInProgress =>
      _state == CallV2CallLifecycleState.ending ||
      _state == CallV2CallLifecycleState.teardown;
  int get duplicateInviteSuppressedCount => _duplicateInviteSuppressedCount;
  int get busyInviteDeclinedCount => _busyInviteDeclinedCount;
  int get staleCandidateDroppedCount => _staleCandidateDroppedCount;
  int get rapidRedialBlockedCount => _rapidRedialBlockedCount;

  bool get isIdle => _state == CallV2CallLifecycleState.idle;

  CallV2CallReservation reserveOutgoing() {
    if (_state != CallV2CallLifecycleState.idle) {
      _rapidRedialBlockedCount += 1;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.blocked,
        generation: _generation,
        lifecycleState: _state,
      );
    }
    _generation += 1;
    _claimedInviteId = null;
    _state = CallV2CallLifecycleState.reserving;
    return CallV2CallReservation(
      action: CallV2CallReservationAction.reserved,
      generation: _generation,
      lifecycleState: _state,
    );
  }

  CallV2CallReservation reserveIncoming(String inviteId) {
    final normalized = inviteId.trim();
    if (normalized.isEmpty) {
      _staleCandidateDroppedCount += 1;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.blocked,
        generation: _generation,
        lifecycleState: _state,
      );
    }

    if (_claimedInviteId == normalized) {
      _duplicateInviteSuppressedCount += 1;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.duplicate,
        generation: _generation,
        lifecycleState: _state,
      );
    }

    if (_state == CallV2CallLifecycleState.idle) {
      _generation += 1;
      _claimedInviteId = normalized;
      _pendingInviteId = null;
      _state = CallV2CallLifecycleState.incomingPrompt;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.reserved,
        generation: _generation,
        lifecycleState: _state,
      );
    }

    if (_state == CallV2CallLifecycleState.ending ||
        _state == CallV2CallLifecycleState.teardown ||
        _state == CallV2CallLifecycleState.reserving) {
      _pendingInviteId = normalized;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.pending,
        generation: _generation,
        lifecycleState: _state,
      );
    }

    _busyInviteDeclinedCount += 1;
    return CallV2CallReservation(
      action: CallV2CallReservationAction.busyDecline,
      generation: _generation,
      lifecycleState: _state,
    );
  }

  bool ownsIncoming({
    required int generation,
    required String inviteId,
  }) {
    return _generation == generation &&
        _state == CallV2CallLifecycleState.incomingPrompt &&
        _claimedInviteId == inviteId.trim();
  }

  bool ownsGeneration(int generation) => _generation == generation;

  void outgoingInviteCreated({
    required int generation,
    required String inviteId,
  }) {
    if (_generation != generation ||
        _state != CallV2CallLifecycleState.reserving) {
      _staleCandidateDroppedCount += 1;
      return;
    }
    _claimedInviteId = inviteId.trim();
    _state = CallV2CallLifecycleState.outgoingRinging;
  }

  void releaseOutgoingReservation(int generation) {
    if (_generation != generation ||
        _state != CallV2CallLifecycleState.reserving) {
      return;
    }
    _state = CallV2CallLifecycleState.idle;
    _claimedInviteId = null;
  }

  void incomingAccepted({
    required int generation,
    required String inviteId,
  }) {
    if (!ownsIncoming(generation: generation, inviteId: inviteId)) {
      _staleCandidateDroppedCount += 1;
      return;
    }
    _state = CallV2CallLifecycleState.joining;
  }

  void incomingDeclined({
    required int generation,
    required String inviteId,
  }) {
    if (!ownsIncoming(generation: generation, inviteId: inviteId)) {
      return;
    }
    _state = CallV2CallLifecycleState.idle;
    _claimedInviteId = null;
  }

  void markJoining(int generation) {
    if (_generation == generation) {
      _state = CallV2CallLifecycleState.joining;
    }
  }

  void markConnected(int generation) {
    if (_generation == generation) {
      _state = CallV2CallLifecycleState.connected;
    }
  }

  void beginEnding(int generation) {
    if (_generation == generation) {
      _state = CallV2CallLifecycleState.ending;
    }
  }

  void beginTeardown(int generation) {
    if (_generation == generation) {
      _state = CallV2CallLifecycleState.teardown;
    }
  }

  String? completeTeardown(int generation) {
    if (_generation != generation) return null;
    final pending = _pendingInviteId;
    _claimedInviteId = null;
    _pendingInviteId = null;
    _state = CallV2CallLifecycleState.idle;
    return pending;
  }

  void dropIncoming({
    required int generation,
    required String inviteId,
  }) {
    if (ownsIncoming(generation: generation, inviteId: inviteId)) {
      _state = CallV2CallLifecycleState.idle;
      _claimedInviteId = null;
      _staleCandidateDroppedCount += 1;
    }
  }

  void forceIdleForTest() {
    _state = CallV2CallLifecycleState.idle;
    _generation = 0;
    _claimedInviteId = null;
    _pendingInviteId = null;
    _duplicateInviteSuppressedCount = 0;
    _busyInviteDeclinedCount = 0;
    _staleCandidateDroppedCount = 0;
    _rapidRedialBlockedCount = 0;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'callLifecycleState': _state.name,
      'lifecycleGeneration': _generation,
      'incomingPipelineBusy': incomingPipelineBusy,
      'incomingCandidateClaimed': incomingCandidateClaimed,
      'pendingIncomingPresent': pendingIncomingPresent,
      'pendingIncomingCount': pendingIncomingCount,
      'activePromptCount': activePromptCount,
      'activeCallRouteCount': activeCallRouteCount,
      'outgoingReservationActive': outgoingReservationActive,
      'teardownInProgress': teardownInProgress,
      'duplicateInviteSuppressedCount': duplicateInviteSuppressedCount,
      'busyInviteDeclinedCount': busyInviteDeclinedCount,
      'staleCandidateDroppedCount': staleCandidateDroppedCount,
      'rapidRedialBlockedCount': rapidRedialBlockedCount,
    };
  }
}
