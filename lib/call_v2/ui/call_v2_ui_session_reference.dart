enum CallV2ProductionMediaMode {
  audio,
  video,
}

enum CallV2ProductionLocalLifecycleStatus {
  connecting,
  active,
  failed,
  closed,
}

enum CallV2ProductionConnectionPhase {
  idle,
  connecting,
  joining,
  connected,
  reconnecting,
  failed,
  closed,
}

class CallV2UiSessionReference {
  const CallV2UiSessionReference({
    required this.generation,
    required this.mediaMode,
    required this.localLifecycleStatus,
    required this.connectionPhase,
  }) : assert(generation >= 0);

  final int generation;
  final CallV2ProductionMediaMode mediaMode;
  final CallV2ProductionLocalLifecycleStatus localLifecycleStatus;
  final CallV2ProductionConnectionPhase connectionPhase;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'generation': generation,
      'mediaMode': mediaMode.name,
      'localLifecycleStatus': localLifecycleStatus.name,
      'connectionPhase': connectionPhase.name,
    };
  }

  @override
  String toString() {
    return 'CallV2UiSessionReference(${toSafeDebugMap()})';
  }
}
