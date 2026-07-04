import 'call_v2_production_user_action.dart';
import 'call_v2_ui_session_reference.dart';

final class CallV2ActiveAudioViewModel {
  CallV2ActiveAudioViewModel({
    required this.muted,
    required this.speakerEnabled,
    required this.leaveEnabled,
    required this.connectionPhase,
    required this.elapsedSeconds,
    required this.reconnecting,
    required Set<CallV2ProductionUserAction> allowedActions,
  }) : allowedActions = Set<CallV2ProductionUserAction>.unmodifiable(
          allowedActions,
        ) {
    if (elapsedSeconds < 0) {
      throw ArgumentError('Invalid Call V2 elapsed seconds.');
    }
  }

  final bool muted;
  final bool speakerEnabled;
  final bool leaveEnabled;
  final CallV2ProductionConnectionPhase connectionPhase;
  final int elapsedSeconds;
  final bool reconnecting;
  final Set<CallV2ProductionUserAction> allowedActions;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'viewModel': 'activeAudio',
      'muted': muted,
      'speakerEnabled': speakerEnabled,
      'leaveEnabled': leaveEnabled,
      'connectionPhase': connectionPhase.name,
      'elapsedSeconds': elapsedSeconds,
      'reconnecting': reconnecting,
      'allowedActions': allowedActions.map((action) => action.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ActiveAudioViewModel(${toSafeDebugMap()})';
  }
}
