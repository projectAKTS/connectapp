enum CallV2RuntimePhase {
  idle,
  preparing,
  permissionPreflight,
  requestingPermission,
  connecting,
  ringing,
  ready,
  active,
  ending,
  ended,
  failed,
}

enum CallV2RuntimeCallMode {
  audio,
  video,
}

enum CallV2RuntimeDirection {
  outgoing,
  incoming,
}

enum CallV2RuntimeErrorCategory {
  none,
  permissionDenied,
  rtcUnavailable,
  backendUnavailable,
  invalidState,
  unknown,
}

class CallV2RuntimeState {
  const CallV2RuntimeState({
    required this.phase,
    this.mode,
    this.direction,
    this.errorCategory = CallV2RuntimeErrorCategory.none,
  });

  static const idle = CallV2RuntimeState(phase: CallV2RuntimePhase.idle);

  final CallV2RuntimePhase phase;
  final CallV2RuntimeCallMode? mode;
  final CallV2RuntimeDirection? direction;
  final CallV2RuntimeErrorCategory errorCategory;

  bool get isTerminal {
    return phase == CallV2RuntimePhase.ended ||
        phase == CallV2RuntimePhase.failed;
  }

  CallV2RuntimeState copyWith({
    CallV2RuntimePhase? phase,
    CallV2RuntimeCallMode? mode,
    CallV2RuntimeDirection? direction,
    CallV2RuntimeErrorCategory? errorCategory,
    bool clearCallShape = false,
    bool clearError = false,
  }) {
    return CallV2RuntimeState(
      phase: phase ?? this.phase,
      mode: clearCallShape ? null : mode ?? this.mode,
      direction: clearCallShape ? null : direction ?? this.direction,
      errorCategory: clearError
          ? CallV2RuntimeErrorCategory.none
          : errorCategory ?? this.errorCategory,
    );
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'phase': phase.name,
      'mode': mode?.name,
      'direction': direction?.name,
      'errorCategory': errorCategory.name,
      'terminal': isTerminal,
    };
  }

  @override
  String toString() {
    return 'CallV2RuntimeState('
        'phase: ${phase.name}, '
        'mode: ${mode?.name}, '
        'direction: ${direction?.name}, '
        'errorCategory: ${errorCategory.name}'
        ')';
  }
}
