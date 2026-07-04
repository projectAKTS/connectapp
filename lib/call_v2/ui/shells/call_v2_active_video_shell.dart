import 'package:flutter/material.dart';

import '../call_v2_active_video_view_model.dart';
import '../call_v2_production_user_action.dart';
import 'call_v2_shell_controls.dart';
import 'call_v2_shell_labels.dart';

class CallV2ActiveVideoScreen extends StatelessWidget {
  const CallV2ActiveVideoScreen({
    super.key,
    required this.viewModel,
    this.onAction,
  });

  final CallV2ActiveVideoViewModel viewModel;
  final CallV2ScreenActionChanged? onAction;

  @override
  Widget build(context) {
    return CallV2ScreenScaffold(
      children: <Widget>[
        Text(
          viewModel.reconnecting
              ? callV2ScreenShellText(CallV2ScreenShellLabel.reconnecting)
              : callV2ScreenShellText(CallV2ScreenShellLabel.videoCall),
          key: const ValueKey<String>('call-v2.video.title'),
        ),
        Text(
          'Phase: ${viewModel.connectionPhase.name}',
          key: const ValueKey<String>('call-v2.video.phase'),
        ),
        Text(
          'Microphone muted: ${viewModel.microphoneMuted}',
          key: const ValueKey<String>('call-v2.video.microphone'),
        ),
        Text(
          'Camera enabled: ${viewModel.localCameraEnabled}',
          key: const ValueKey<String>('call-v2.video.camera'),
        ),
        Text(
          'Remote video: ${viewModel.remoteVideoAvailable}',
          key: const ValueKey<String>('call-v2.video.remoteVideo'),
        ),
        Text(
          'Rendering: ${viewModel.renderingState.name}',
          key: const ValueKey<String>('call-v2.video.rendering'),
        ),
        CallV2ScreenActionButton(
          action: CallV2ProductionUserAction.toggleMute,
          label: CallV2ScreenShellLabel.mute,
          allowedActions: viewModel.allowedActions,
          onAction: onAction,
        ),
        CallV2ScreenActionButton(
          action: CallV2ProductionUserAction.toggleCamera,
          label: CallV2ScreenShellLabel.camera,
          allowedActions: viewModel.allowedActions,
          onAction: onAction,
        ),
        if (viewModel.cameraSwitchEnabled)
          CallV2ScreenActionButton(
            action: CallV2ProductionUserAction.switchCamera,
            label: CallV2ScreenShellLabel.switchCamera,
            allowedActions: viewModel.allowedActions,
            onAction: onAction,
          ),
        if (viewModel.leaveEnabled)
          CallV2ScreenActionButton(
            action: CallV2ProductionUserAction.leave,
            label: CallV2ScreenShellLabel.leave,
            allowedActions: viewModel.allowedActions,
            onAction: onAction,
          ),
      ],
    );
  }
}
