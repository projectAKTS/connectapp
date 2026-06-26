import 'call_lifecycle.dart';
import 'participant_media_state.dart';

enum CallParticipantRole {
  caller,
  callee;

  CallParticipantRole get peer {
    switch (this) {
      case CallParticipantRole.caller:
        return CallParticipantRole.callee;
      case CallParticipantRole.callee:
        return CallParticipantRole.caller;
    }
  }
}

class CallSnapshot {
  const CallSnapshot({
    required this.callId,
    required this.version,
    required this.lifecycle,
    required this.callerUid,
    required this.calleeUid,
    this.callerMediaState = ParticipantMediaState.notJoined,
    this.calleeMediaState = ParticipantMediaState.notJoined,
    this.createdAt,
    this.acceptedAt,
    this.activeAt,
    this.endedAt,
    this.terminalReason,
    this.failureCode,
  });

  final String callId;
  final int version;
  final CallLifecycle lifecycle;
  final String callerUid;
  final String calleeUid;
  final ParticipantMediaState callerMediaState;
  final ParticipantMediaState calleeMediaState;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? activeAt;
  final DateTime? endedAt;
  final String? terminalReason;
  final String? failureCode;

  ParticipantMediaState mediaStateFor(CallParticipantRole role) {
    switch (role) {
      case CallParticipantRole.caller:
        return callerMediaState;
      case CallParticipantRole.callee:
        return calleeMediaState;
    }
  }

  ParticipantMediaState peerMediaStateFor(CallParticipantRole role) {
    return mediaStateFor(role.peer);
  }
}
