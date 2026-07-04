import 'package:connect_app/call_v2/ui/call_v2_connecting_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_connecting_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders sanitized media and phase', (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ConnectingScreen(viewModel: _model()),
      ),
    );

    expect(find.text('Connecting'), findsOneWidget);
    expect(find.text('Mode: audio'), findsOneWidget);
    expect(find.text('Phase: connecting'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('call-v2.connecting.title')),
        findsOneWidget);
    expect(find.bySemanticsLabel('Cancel'), findsWidgets);
  });

  testWidgets('reconnecting state renders correctly', (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ConnectingScreen(
          viewModel: _model(
            connectionPhase: CallV2ProductionConnectionPhase.reconnecting,
          ),
        ),
      ),
    );

    expect(find.text('Reconnecting'), findsOneWidget);
    expect(find.text('Phase: reconnecting'), findsOneWidget);
  });

  testWidgets('cancel appears only when enabled', (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ConnectingScreen(
          viewModel: _model(cancelEnabled: false),
        ),
      ),
    );

    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('optional callback receives typed cancel action only',
      (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    await tester.pumpWidget(
      _host(
        CallV2ConnectingScreen(
          viewModel: _model(),
          onAction: actions.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.cancelConnecting',
    )));

    expect(actions, <CallV2ProductionUserAction>[
      CallV2ProductionUserAction.cancelConnecting,
    ]);
  });

  testWidgets('default null callback disables action', (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    await tester.pumpWidget(
      _host(
        CallV2ConnectingScreen(
          viewModel: _model(),
          onAction: actions.add,
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        CallV2ConnectingScreen(viewModel: _model()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.cancelConnecting',
    )));

    expect(actions, isEmpty);
  });
}

Widget _host(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

CallV2ConnectingViewModel _model({
  bool cancelEnabled = true,
  CallV2ProductionConnectionPhase connectionPhase =
      CallV2ProductionConnectionPhase.connecting,
}) {
  return CallV2ConnectingViewModel(
    mediaMode: CallV2ProductionMediaMode.audio,
    connectionPhase: connectionPhase,
    cancelEnabled: cancelEnabled,
    allowedActions: cancelEnabled
        ? const <CallV2ProductionUserAction>{
            CallV2ProductionUserAction.cancelConnecting,
          }
        : const <CallV2ProductionUserAction>{},
  );
}
