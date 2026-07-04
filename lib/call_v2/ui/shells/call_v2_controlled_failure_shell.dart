import 'package:flutter/material.dart';

import '../call_v2_controlled_failure_view_model.dart';
import '../call_v2_production_user_action.dart';
import 'call_v2_shell_controls.dart';
import 'call_v2_shell_labels.dart';

class CallV2ControlledFailureScreen extends StatelessWidget {
  const CallV2ControlledFailureScreen({
    super.key,
    required this.viewModel,
    this.onAction,
  });

  final CallV2ControlledFailureViewModel viewModel;
  final CallV2ScreenActionChanged? onAction;

  @override
  Widget build(context) {
    return CallV2ScreenScaffold(
      children: <Widget>[
        Text(
          callV2ScreenShellText(callV2FailureLabelFor(viewModel.errorCode)),
          key: const ValueKey<String>('call-v2.failure.title'),
        ),
        if (viewModel.retryEnabled)
          CallV2ScreenActionButton(
            action: CallV2ProductionUserAction.retryControlledFailure,
            label: CallV2ScreenShellLabel.retry,
            allowedActions: viewModel.allowedActions,
            onAction: onAction,
          ),
        if (viewModel.dismissEnabled)
          CallV2ScreenActionButton(
            action: CallV2ProductionUserAction.dismissControlledFailure,
            label: CallV2ScreenShellLabel.dismiss,
            allowedActions: viewModel.allowedActions,
            onAction: onAction,
          ),
      ],
    );
  }
}
