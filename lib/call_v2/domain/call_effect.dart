enum CallEffectType {
  requestBackendCommand,
  presentIncomingRoute,
  openCallRoute,
  closeCallRoute,
  prepareAgora,
  joinAgora,
  leaveAgora,
  endMatchingNativeCall,
  recordDiagnosticEvent;
}

enum BackendCommandType {
  acceptCall,
  declineCall,
  cancelCall,
  endCall,
  reportMediaPreparing,
  reportMediaJoining,
  reportMediaJoined,
  reportMediaConnection,
  reportCallFailure;
}

class CallEffect {
  const CallEffect({
    required this.type,
    required this.callId,
    this.command,
    this.code,
    this.reason,
  });

  const CallEffect.requestBackendCommand({
    required String callId,
    required BackendCommandType command,
    String? reason,
  }) : this(
          type: CallEffectType.requestBackendCommand,
          callId: callId,
          command: command,
          reason: reason,
        );

  const CallEffect.presentIncomingRoute(String callId)
      : this(type: CallEffectType.presentIncomingRoute, callId: callId);

  const CallEffect.openCallRoute(String callId)
      : this(type: CallEffectType.openCallRoute, callId: callId);

  const CallEffect.closeCallRoute(String callId)
      : this(type: CallEffectType.closeCallRoute, callId: callId);

  const CallEffect.prepareAgora(String callId)
      : this(type: CallEffectType.prepareAgora, callId: callId);

  const CallEffect.joinAgora(String callId)
      : this(type: CallEffectType.joinAgora, callId: callId);

  const CallEffect.leaveAgora(String callId)
      : this(type: CallEffectType.leaveAgora, callId: callId);

  const CallEffect.endMatchingNativeCall(String callId)
      : this(type: CallEffectType.endMatchingNativeCall, callId: callId);

  const CallEffect.recordDiagnosticEvent({
    required String callId,
    required String code,
    String? reason,
  }) : this(
          type: CallEffectType.recordDiagnosticEvent,
          callId: callId,
          code: code,
          reason: reason,
        );

  final CallEffectType type;
  final String callId;
  final BackendCommandType? command;
  final String? code;
  final String? reason;

  @override
  bool operator ==(Object other) {
    return other is CallEffect &&
        other.type == type &&
        other.callId == callId &&
        other.command == command &&
        other.code == code &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(type, callId, command, code, reason);

  @override
  String toString() {
    return 'CallEffect(type: $type, callId: $callId, command: $command, '
        'code: $code, reason: $reason)';
  }
}
