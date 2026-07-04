import 'package:flutter/material.dart';

import '../call_v2_connecting_view_model.dart';
import '../call_v2_production_user_action.dart';
import 'call_v2_shell_controls.dart';
import 'call_v2_shell_labels.dart';

class CallV2ConnectingScreen extends StatelessWidget {
  const CallV2ConnectingScreen({
    super.key,
    required this.viewModel,
    this.onAction,
  });

  final CallV2ConnectingViewModel viewModel;
  final CallV2ScreenActionChanged? onAction;

  @override
  Widget build(context) {
    final title = viewModel.reconnecting
        ? CallV2ScreenShellLabel.reconnecting
        : CallV2ScreenShellLabel.connecting;
    return CallV2ScreenScaffold(
      children: <Widget>[
        Text(
          callV2ScreenShellText(title),
          key: const ValueKey<String>('call-v2.connecting.title'),
        ),
        Text(
          'Mode: ${viewModel.mediaMode.name}',
          key: const ValueKey<String>('call-v2.connecting.mediaMode'),
        ),
        Text(
          'Phase: ${viewModel.connectionPhase.name}',
          key: const ValueKey<String>('call-v2.connecting.phase'),
        ),
        if (viewModel.cancelEnabled)
          CallV2ScreenActionButton(
            action: CallV2ProductionUserAction.cancelConnecting,
            label: CallV2ScreenShellLabel.cancel,
            allowedActions: viewModel.allowedActions,
            onAction: onAction,
          ),
      ],
    );
  }
}
