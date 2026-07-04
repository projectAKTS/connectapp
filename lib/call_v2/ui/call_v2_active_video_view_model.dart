import 'call_v2_production_user_action.dart';
import 'call_v2_production_view_state.dart';
import 'call_v2_ui_session_reference.dart';

final class CallV2ActiveVideoViewModel {
  CallV2ActiveVideoViewModel({
    required this.microphoneMuted,
    required this.localCameraEnabled,
    required this.remoteVideoAvailable,
    required this.cameraSwitchEnabled,
    required this.leaveEnabled,
    required this.connectionPhase,
    required this.renderingState,
    required this.reconnecting,
    required Set<CallV2ProductionUserAction> allowedActions,
  }) : allowedActions = Set<CallV2ProductionUserAction>.unmodifiable(
          allowedActions,
        );

  final bool microphoneMuted;
  final bool localCameraEnabled;
  final bool remoteVideoAvailable;
  final bool cameraSwitchEnabled;
  final bool leaveEnabled;
  final CallV2ProductionConnectionPhase connectionPhase;
  final CallV2ProductionVideoRenderingState renderingState;
  final bool reconnecting;
  final Set<CallV2ProductionUserAction> allowedActions;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'viewModel': 'activeVideo',
      'microphoneMuted': microphoneMuted,
      'localCameraEnabled': localCameraEnabled,
      'remoteVideoAvailable': remoteVideoAvailable,
      'cameraSwitchEnabled': cameraSwitchEnabled,
      'leaveEnabled': leaveEnabled,
      'connectionPhase': connectionPhase.name,
      'renderingState': renderingState.name,
      'reconnecting': reconnecting,
      'allowedActions': allowedActions.map((action) => action.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ActiveVideoViewModel(${toSafeDebugMap()})';
  }
}
