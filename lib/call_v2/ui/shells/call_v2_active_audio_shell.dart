import 'package:flutter/material.dart';

import '../call_v2_active_audio_view_model.dart';
import '../call_v2_production_user_action.dart';
import 'call_v2_shell_controls.dart';
import 'call_v2_shell_labels.dart';

class CallV2ActiveAudioScreen extends StatelessWidget {
  const CallV2ActiveAudioScreen({
    super.key,
    required this.viewModel,
    this.onAction,
  });

  final CallV2ActiveAudioViewModel viewModel;
  final CallV2ScreenActionChanged? onAction;

  @override
  Widget build(context) {
    return CallV2ScreenScaffold(
      children: <Widget>[
        Text(
          viewModel.reconnecting
              ? callV2ScreenShellText(CallV2ScreenShellLabel.reconnecting)
              : callV2ScreenShellText(CallV2ScreenShellLabel.audioCall),
          key: const ValueKey<String>('call-v2.audio.title'),
        ),
        Text(
          'Phase: ${viewModel.connectionPhase.name}',
          key: const ValueKey<String>('call-v2.audio.phase'),
        ),
        Text(
          'Elapsed: ${viewModel.elapsedSeconds}',
          key: const ValueKey<String>('call-v2.audio.elapsed'),
        ),
        Text(
          'Muted: ${viewModel.muted}',
          key: const ValueKey<String>('call-v2.audio.muted'),
        ),
        Text(
          'Speaker: ${viewModel.speakerEnabled}',
          key: const ValueKey<String>('call-v2.audio.speaker'),
        ),
        CallV2ScreenActionButton(
          action: CallV2ProductionUserAction.toggleMute,
          label: CallV2ScreenShellLabel.mute,
          allowedActions: viewModel.allowedActions,
          onAction: onAction,
        ),
        CallV2ScreenActionButton(
          action: CallV2ProductionUserAction.toggleSpeaker,
          label: CallV2ScreenShellLabel.speaker,
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
