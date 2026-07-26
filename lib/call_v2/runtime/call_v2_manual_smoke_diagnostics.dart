import 'call_v2_runtime_state.dart';

class CallV2ManualSmokeDiagnostics {
  const CallV2ManualSmokeDiagnostics({
    required this.permissionReady,
    required this.permissionDone,
    required this.accessReady,
    required this.accessDone,
    required this.setupReady,
    required this.setupDone,
    required this.joinReady,
    required this.joinDone,
    required this.phase,
    required this.failureCategory,
  });

  final bool permissionReady;
  final bool permissionDone;
  final bool accessReady;
  final bool accessDone;
  final bool setupReady;
  final bool setupDone;
  final bool joinReady;
  final bool joinDone;
  final CallV2RuntimePhase phase;
  final CallV2RuntimeErrorCategory failureCategory;

  bool get active => phase == CallV2RuntimePhase.active;

  bool get ended => phase == CallV2RuntimePhase.ended;

  bool get failed => phase == CallV2RuntimePhase.failed;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'permissionReady': permissionReady,
      'permissionDone': permissionDone,
      'accessReady': accessReady,
      'accessDone': accessDone,
      'setupReady': setupReady,
      'setupDone': setupDone,
      'joinReady': joinReady,
      'joinDone': joinDone,
      'active': active,
      'ended': ended,
      'failed': failed,
      'failureCategory': failureCategory.name,
    };
  }

  @override
  String toString() => 'CallV2ManualSmokeDiagnostics(${toSafeDebugMap()})';
}
