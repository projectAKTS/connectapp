import 'package:connect_app/call_v2/ui/call_v2_active_audio_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_active_audio_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders mute speaker leave and nonnegative duration',
      (tester) async {
    await tester
        .pumpWidget(_host(CallV2ActiveAudioScreen(viewModel: _model())));

    expect(find.text('Audio call'), findsOneWidget);
    expect(find.text('Phase: connected'), findsOneWidget);
    expect(find.text('Elapsed: 61'), findsOneWidget);
    expect(find.text('Muted: true'), findsOneWidget);
    expect(find.text('Speaker: false'), findsOneWidget);
    expect(find.bySemanticsLabel('Mute'), findsWidgets);
    expect(find.bySemanticsLabel('Speaker'), findsWidgets);
    expect(find.bySemanticsLabel('Leave'), findsWidgets);
  });

  testWidgets('reconnecting state renders correctly', (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ActiveAudioScreen(
          viewModel: _model(reconnecting: true),
        ),
      ),
    );

    expect(find.text('Reconnecting'), findsOneWidget);
  });

  testWidgets('controls emit typed actions when callback is supplied',
      (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    await tester.pumpWidget(
      _host(
        CallV2ActiveAudioScreen(
          viewModel: _model(),
          onAction: actions.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.toggleMute',
    )));
    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.toggleSpeaker',
    )));
    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.leave',
    )));

    expect(actions, <CallV2ProductionUserAction>[
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleSpeaker,
      CallV2ProductionUserAction.leave,
    ]);
  });

  testWidgets('disabled controls cannot invoke callbacks', (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    await tester.pumpWidget(
      _host(
        CallV2ActiveAudioScreen(viewModel: _model()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.toggleMute',
    )));

    expect(actions, isEmpty);
  });
}

Widget _host(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

CallV2ActiveAudioViewModel _model({bool reconnecting = false}) {
  return CallV2ActiveAudioViewModel(
    muted: true,
    speakerEnabled: false,
    leaveEnabled: true,
    connectionPhase: reconnecting
        ? CallV2ProductionConnectionPhase.reconnecting
        : CallV2ProductionConnectionPhase.connected,
    elapsedSeconds: 61,
    reconnecting: reconnecting,
    allowedActions: const <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleSpeaker,
      CallV2ProductionUserAction.leave,
    },
  );
}
