import 'package:connect_app/call_v2/ui/call_v2_active_video_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_view_state.dart';
import 'package:connect_app/call_v2/ui/call_v2_ui_session_reference.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_active_video_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders camera microphone and remote placeholders only',
      (tester) async {
    await tester
        .pumpWidget(_host(CallV2ActiveVideoScreen(viewModel: _model())));

    expect(find.text('Video call'), findsOneWidget);
    expect(find.text('Phase: connected'), findsOneWidget);
    expect(find.text('Microphone muted: false'), findsOneWidget);
    expect(find.text('Camera enabled: true'), findsOneWidget);
    expect(find.text('Remote video: false'), findsOneWidget);
    expect(find.text('Rendering: waiting'), findsOneWidget);
    expect(find.bySemanticsLabel('Mute'), findsWidgets);
    expect(find.bySemanticsLabel('Camera'), findsWidgets);
    expect(find.bySemanticsLabel('Switch camera'), findsWidgets);
    expect(find.bySemanticsLabel('Leave'), findsWidgets);
  });

  testWidgets('reconnecting state renders correctly', (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ActiveVideoScreen(viewModel: _model(reconnecting: true)),
      ),
    );

    expect(find.text('Reconnecting'), findsOneWidget);
  });

  testWidgets('camera switch appears only when allowed', (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ActiveVideoScreen(viewModel: _model(cameraSwitchEnabled: false)),
      ),
    );

    expect(find.text('Switch camera'), findsNothing);
  });

  testWidgets('controls emit typed actions when callback is supplied',
      (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    await tester.pumpWidget(
      _host(
        CallV2ActiveVideoScreen(
          viewModel: _model(),
          onAction: actions.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.toggleMute',
    )));
    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.toggleCamera',
    )));
    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.switchCamera',
    )));
    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.leave',
    )));

    expect(actions, <CallV2ProductionUserAction>[
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleCamera,
      CallV2ProductionUserAction.switchCamera,
      CallV2ProductionUserAction.leave,
    ]);
  });
}

Widget _host(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

CallV2ActiveVideoViewModel _model({
  bool reconnecting = false,
  bool cameraSwitchEnabled = true,
}) {
  return CallV2ActiveVideoViewModel(
    microphoneMuted: false,
    localCameraEnabled: true,
    remoteVideoAvailable: false,
    cameraSwitchEnabled: cameraSwitchEnabled,
    leaveEnabled: true,
    connectionPhase: reconnecting
        ? CallV2ProductionConnectionPhase.reconnecting
        : CallV2ProductionConnectionPhase.connected,
    renderingState: CallV2ProductionVideoRenderingState.waiting,
    reconnecting: reconnecting,
    allowedActions: <CallV2ProductionUserAction>{
      CallV2ProductionUserAction.toggleMute,
      CallV2ProductionUserAction.toggleCamera,
      if (cameraSwitchEnabled) CallV2ProductionUserAction.switchCamera,
      CallV2ProductionUserAction.leave,
    },
  );
}
