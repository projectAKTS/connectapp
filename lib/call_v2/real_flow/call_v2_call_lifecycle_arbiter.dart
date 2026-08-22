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
    this.displacedInviteId,
  });

  final CallV2CallReservationAction action;
  final int generation;
  final CallV2CallLifecycleState lifecycleState;
  final String? displacedInviteId;

  bool get reserved => action == CallV2CallReservationAction.reserved;
}

class CallV2PendingClaim {
  const CallV2PendingClaim._({
    required this.claimed,
    required this.generation,
    required this.lifecycleState,
    required this.acceptedIntent,
    this.inviteId,
  });

  const CallV2PendingClaim.none({
    required int generation,
    required CallV2CallLifecycleState lifecycleState,
  }) : this._(
          claimed: false,
          generation: generation,
          lifecycleState: lifecycleState,
          acceptedIntent: false,
        );

  const CallV2PendingClaim.claimed({
    required int generation,
    required String inviteId,
    required bool acceptedIntent,
  }) : this._(
          claimed: true,
          generation: generation,
          lifecycleState: CallV2CallLifecycleState.incomingPrompt,
          inviteId: inviteId,
          acceptedIntent: acceptedIntent,
        );

  final bool claimed;
  final int generation;
  final CallV2CallLifecycleState lifecycleState;
  final String? inviteId;
  final bool acceptedIntent;
}

class CallV2CallLifecycleArbiter {
  CallV2CallLifecycleState _state = CallV2CallLifecycleState.idle;
  int _generation = 0;
  String? _claimedInviteId;
  String? _pendingInviteId;
  String? _pendingAcceptedInviteId;
  int? _pendingAcceptedGeneration;
  bool _pendingAcceptedRecorded = false;
  bool _pendingAcceptedClaimed = false;
  int _duplicateInviteSuppressedCount = 0;
  int _busyInviteDeclinedCount = 0;
  int _staleCandidateDroppedCount = 0;
  int _rapidRedialBlockedCount = 0;
  int _displacedPendingSupersededCount = 0;
  int _preflightLifecycleMutationBlockedCount = 0;
  int _orphanInviteCancelledCount = 0;
  int _lifecycleRegressionSuppressedCount = 0;

  CallV2CallLifecycleState get state => _state;
  int get generation => _generation;
  bool get incomingPipelineBusy =>
      _state == CallV2CallLifecycleState.incomingPrompt;
  bool get incomingCandidateClaimed => _claimedInviteId != null;
  bool get pendingIncomingPresent => _pendingInviteId != null;
  bool get pendingAcceptedIntent => _pendingAcceptedInviteId != null;
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
  int get displacedPendingSupersededCount => _displacedPendingSupersededCount;
  int get preflightLifecycleMutationBlockedCount =>
      _preflightLifecycleMutationBlockedCount;
  int get orphanInviteCancelledCount => _orphanInviteCancelledCount;
  int get lifecycleRegressionSuppressedCount =>
      _lifecycleRegressionSuppressedCount;

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
      _clearPendingAcceptedIntent();
      _state = CallV2CallLifecycleState.incomingPrompt;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.reserved,
        generation: _generation,
        lifecycleState: _state,
      );
    }

    if (_pendingInviteId == normalized &&
        (_state == CallV2CallLifecycleState.ending ||
            _state == CallV2CallLifecycleState.teardown ||
            _state == CallV2CallLifecycleState.reserving)) {
      _duplicateInviteSuppressedCount += 1;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.duplicate,
        generation: _generation,
        lifecycleState: _state,
      );
    }

    if (_state == CallV2CallLifecycleState.ending ||
        _state == CallV2CallLifecycleState.teardown ||
        _state == CallV2CallLifecycleState.reserving) {
      final displaced = _pendingInviteId;
      if (displaced != null && displaced != normalized) {
        _displacedPendingSupersededCount += 1;
        if (_pendingAcceptedInviteId == displaced) {
          _clearPendingAcceptedIntent();
        }
      }
      _pendingInviteId = normalized;
      return CallV2CallReservation(
        action: CallV2CallReservationAction.pending,
        generation: _generation,
        lifecycleState: _state,
        displacedInviteId: displaced == normalized ? null : displaced,
      );
    }

    _busyInviteDeclinedCount += 1;
    return CallV2CallReservation(
      action: CallV2CallReservationAction.busyDecline,
      generation: _generation,
      lifecycleState: _state,
    );
  }

  bool recordPendingAcceptedIntent({
    required int generation,
    required String inviteId,
  }) {
    final normalized = inviteId.trim();
    final pendingLifecycle = _state == CallV2CallLifecycleState.ending ||
        _state == CallV2CallLifecycleState.teardown ||
        _state == CallV2CallLifecycleState.reserving;
    if (normalized.isEmpty ||
        generation != _generation ||
        !pendingLifecycle ||
        _pendingInviteId != normalized) {
      _staleCandidateDroppedCount += 1;
      return false;
    }
    if (_pendingAcceptedInviteId == normalized &&
        _pendingAcceptedGeneration == generation) {
      return true;
    }
    _pendingAcceptedInviteId = normalized;
    _pendingAcceptedGeneration = generation;
    _pendingAcceptedRecorded = true;
    return true;
  }

  bool clearPendingInvite(String inviteId) {
    final normalized = inviteId.trim();
    if (normalized.isEmpty || _pendingInviteId != normalized) return false;
    _pendingInviteId = null;
    if (_pendingAcceptedInviteId == normalized) {
      _clearPendingAcceptedIntent();
    }
    return true;
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
  bool ownsOutgoingReservation(int generation) {
    return _generation == generation &&
        _state == CallV2CallLifecycleState.reserving;
  }

  bool outgoingInviteCreated({
    required int generation,
    required String inviteId,
  }) {
    if (_generation != generation ||
        _state != CallV2CallLifecycleState.reserving) {
      _staleCandidateDroppedCount += 1;
      _orphanInviteCancelledCount += 1;
      return false;
    }
    _claimedInviteId = inviteId.trim();
    _state = CallV2CallLifecycleState.outgoingRinging;
    return true;
  }

  void releaseOutgoingReservation(int generation) {
    if (_generation != generation ||
        _state != CallV2CallLifecycleState.reserving) {
      return;
    }
    _state = CallV2CallLifecycleState.idle;
    _claimedInviteId = null;
  }

  bool incomingAccepted({
    required int generation,
    required String inviteId,
  }) {
    if (!ownsIncoming(generation: generation, inviteId: inviteId)) {
      _staleCandidateDroppedCount += 1;
      return false;
    }
    _state = CallV2CallLifecycleState.joining;
    return true;
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

  bool markJoining(int generation) {
    if (_generation != generation) {
      _staleCandidateDroppedCount += 1;
      return false;
    }
    if (_state == CallV2CallLifecycleState.outgoingRinging ||
        _state == CallV2CallLifecycleState.joining) {
      _state = CallV2CallLifecycleState.joining;
      return true;
    }
    _lifecycleRegressionSuppressedCount += 1;
    return false;
  }

  bool markConnected(int generation) {
    if (_generation != generation) {
      _staleCandidateDroppedCount += 1;
      return false;
    }
    if (_state == CallV2CallLifecycleState.outgoingRinging ||
        _state == CallV2CallLifecycleState.joining ||
        _state == CallV2CallLifecycleState.connected) {
      _state = CallV2CallLifecycleState.connected;
      return true;
    }
    _lifecycleRegressionSuppressedCount += 1;
    return false;
  }

  bool beginEnding(int generation) {
    if (_generation != generation) {
      _staleCandidateDroppedCount += 1;
      return false;
    }
    if (_state == CallV2CallLifecycleState.teardown) {
      _lifecycleRegressionSuppressedCount += 1;
      return false;
    }
    if (_state == CallV2CallLifecycleState.outgoingRinging ||
        _state == CallV2CallLifecycleState.joining ||
        _state == CallV2CallLifecycleState.connected ||
        _state == CallV2CallLifecycleState.incomingPrompt ||
        _state == CallV2CallLifecycleState.ending) {
      _state = CallV2CallLifecycleState.ending;
      return true;
    }
    _lifecycleRegressionSuppressedCount += 1;
    return false;
  }

  bool beginTeardown(int generation) {
    if (_generation != generation) {
      _staleCandidateDroppedCount += 1;
      return false;
    }
    if (_state == CallV2CallLifecycleState.outgoingRinging ||
        _state == CallV2CallLifecycleState.joining ||
        _state == CallV2CallLifecycleState.connected ||
        _state == CallV2CallLifecycleState.incomingPrompt ||
        _state == CallV2CallLifecycleState.ending ||
        _state == CallV2CallLifecycleState.teardown) {
      _state = CallV2CallLifecycleState.teardown;
      return true;
    }
    _lifecycleRegressionSuppressedCount += 1;
    return false;
  }

  CallV2PendingClaim completeTeardownAndClaimPending(int generation) {
    if (_generation != generation) {
      _staleCandidateDroppedCount += 1;
      return CallV2PendingClaim.none(
        generation: _generation,
        lifecycleState: _state,
      );
    }
    final pending = _pendingInviteId;
    final acceptedIntent = pending != null &&
        _pendingAcceptedInviteId == pending &&
        _pendingAcceptedGeneration == generation;
    _claimedInviteId = null;
    _pendingInviteId = null;
    _clearPendingAcceptedIntent();
    if (pending == null) {
      _state = CallV2CallLifecycleState.idle;
      return CallV2PendingClaim.none(
        generation: _generation,
        lifecycleState: _state,
      );
    }
    _generation += 1;
    _claimedInviteId = pending;
    _state = CallV2CallLifecycleState.incomingPrompt;
    _pendingAcceptedClaimed = acceptedIntent;
    return CallV2PendingClaim.claimed(
      generation: _generation,
      inviteId: pending,
      acceptedIntent: acceptedIntent,
    );
  }

  void invalidateForProductionReset({bool publishIdle = true}) {
    _generation += 1;
    _claimedInviteId = null;
    _pendingInviteId = null;
    _clearPendingAcceptedIntent();
    if (publishIdle) {
      _state = CallV2CallLifecycleState.idle;
    } else {
      _preflightLifecycleMutationBlockedCount += 1;
      if (_state != CallV2CallLifecycleState.teardown) {
        _state = CallV2CallLifecycleState.teardown;
      }
    }
  }

  void recordPreflightLifecycleMutationBlocked() {
    _preflightLifecycleMutationBlockedCount += 1;
  }

  void recordOrphanInviteCancelled() {
    _orphanInviteCancelledCount += 1;
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
    _clearPendingAcceptedIntent();
    _pendingAcceptedRecorded = false;
    _pendingAcceptedClaimed = false;
    _duplicateInviteSuppressedCount = 0;
    _busyInviteDeclinedCount = 0;
    _staleCandidateDroppedCount = 0;
    _rapidRedialBlockedCount = 0;
    _displacedPendingSupersededCount = 0;
    _preflightLifecycleMutationBlockedCount = 0;
    _orphanInviteCancelledCount = 0;
    _lifecycleRegressionSuppressedCount = 0;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'callLifecycleState': _state.name,
      'lifecycleGeneration': _generation,
      'incomingPipelineBusy': incomingPipelineBusy,
      'incomingCandidateClaimed': incomingCandidateClaimed,
      'pendingIncomingPresent': pendingIncomingPresent,
      'pendingAcceptedIntent': pendingAcceptedIntent,
      'pendingAcceptedRecorded': _pendingAcceptedRecorded,
      'pendingAcceptedClaimed': _pendingAcceptedClaimed,
      'pendingIncomingCount': pendingIncomingCount,
      'activePromptCount': activePromptCount,
      'activeCallRouteCount': activeCallRouteCount,
      'outgoingReservationActive': outgoingReservationActive,
      'teardownInProgress': teardownInProgress,
      'duplicateInviteSuppressedCount': duplicateInviteSuppressedCount,
      'busyInviteDeclinedCount': busyInviteDeclinedCount,
      'staleCandidateDroppedCount': staleCandidateDroppedCount,
      'rapidRedialBlockedCount': rapidRedialBlockedCount,
      'generationMonotonic': true,
      'reservationStillOwned': _state == CallV2CallLifecycleState.reserving ||
          _state == CallV2CallLifecycleState.incomingPrompt ||
          _state == CallV2CallLifecycleState.outgoingRinging ||
          _state == CallV2CallLifecycleState.joining ||
          _state == CallV2CallLifecycleState.connected,
      'pendingClaimTransferredAtomically':
          _state == CallV2CallLifecycleState.incomingPrompt &&
              _pendingInviteId == null,
      'displacedPendingSupersededCount': displacedPendingSupersededCount,
      'preflightLifecycleMutationBlockedCount':
          preflightLifecycleMutationBlockedCount,
      'orphanInviteCancelledCount': orphanInviteCancelledCount,
      'lifecycleRegressionSuppressedCount': lifecycleRegressionSuppressedCount,
    };
  }

  void _clearPendingAcceptedIntent() {
    _pendingAcceptedInviteId = null;
    _pendingAcceptedGeneration = null;
  }
}
