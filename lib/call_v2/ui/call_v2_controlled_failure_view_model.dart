import '../call_v2_api.dart';
import 'call_v2_production_user_action.dart';

final class CallV2ControlledFailureViewModel {
  CallV2ControlledFailureViewModel({
    required this.errorCode,
    required this.retryEnabled,
    required this.dismissEnabled,
    required Set<CallV2ProductionUserAction> allowedActions,
  }) : allowedActions = Set<CallV2ProductionUserAction>.unmodifiable(
          allowedActions,
        );

  final CallV2ClientErrorCode errorCode;
  final bool retryEnabled;
  final bool dismissEnabled;
  final Set<CallV2ProductionUserAction> allowedActions;

  Map<String, Object?> toSafeDebugMap() {
    return <String, Object?>{
      'viewModel': 'controlledFailure',
      'errorCode': errorCode.name,
      'retryEnabled': retryEnabled,
      'dismissEnabled': dismissEnabled,
      'allowedActions': allowedActions.map((action) => action.name).toList(),
    };
  }

  @override
  String toString() {
    return 'CallV2ControlledFailureViewModel(${toSafeDebugMap()})';
  }
}
