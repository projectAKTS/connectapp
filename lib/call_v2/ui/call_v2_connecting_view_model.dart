import 'call_v2_production_user_action.dart';
import 'call_v2_ui_session_reference.dart';

final class CallV2ConnectingViewModel {
  CallV2ConnectingViewModel({
    required this.mediaMode,
    required this.connectionPhase,
    required this.cancelEnabled,
    required Set<CallV2ProductionUserAction> allowedActions,
  }) : allowedActions = Set<CallV2ProductionUserAction>.unmodifiable(
          allowedActions,
        );

  final CallV2ProductionMediaMode mediaMode;
  final CallV2ProductionConnectionPhase connectionPhase;
  final bool cancelEnabled;
  final Set<CallV2ProductionUserAction> allowedActions;

  bool get connecting {
    return connectionPhase == CallV2ProductionConnectionPhase.connecting ||
        connectionPhase == CallV2ProductionConnectionPhase.joining;
  }

  bool get reconnecting {
    return connectionPhase == CallV2ProductionConnectionPhase.reconnecting;
  }

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'viewModel': 'connecting',
      'mediaMode': mediaMode.name,
      'connectionPhase': connectionPhase.name,
      'cancelEnabled': cancelEnabled,
      'connecting': connecting,
      'reconnecting': reconnecting,
      'allowedActions': allowedActions.map((action) => action.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ConnectingViewModel(${toSafeDebugMap()})';
  }
}
