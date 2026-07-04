import 'package:flutter/material.dart';

import '../call_v2_production_user_action.dart';
import 'call_v2_shell_labels.dart';

typedef CallV2ScreenActionChanged = ValueChanged<CallV2ProductionUserAction>;

class CallV2ScreenActionButton extends StatelessWidget {
  const CallV2ScreenActionButton({
    super.key,
    required this.action,
    required this.label,
    required this.allowedActions,
    required this.onAction,
  });

  final CallV2ProductionUserAction action;
  final CallV2ScreenShellLabel label;
  final Set<CallV2ProductionUserAction> allowedActions;
  final CallV2ScreenActionChanged? onAction;

  @override
  Widget build(context) {
    final text = callV2ScreenShellText(label);
    final enabled = allowedActions.contains(action) && onAction != null;
    return Semantics(
      label: text,
      tooltip: text,
      button: true,
      enabled: enabled,
      child: TextButton(
        key: ValueKey<String>('call-v2.action.${action.name}'),
        onPressed: enabled ? () => onAction?.call(action) : null,
        child: Text(text),
      ),
    );
  }
}

class CallV2ScreenScaffold extends StatelessWidget {
  const CallV2ScreenScaffold({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(context) {
    return Material(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
