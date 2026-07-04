import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/ui/call_v2_controlled_failure_view_model.dart';
import 'package:connect_app/call_v2/ui/call_v2_production_user_action.dart';
import 'package:connect_app/call_v2/ui/shells/call_v2_controlled_failure_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders generic controlled text without raw error enum names',
      (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ControlledFailureScreen(viewModel: _model()),
      ),
    );

    expect(find.text('Call unavailable'), findsOneWidget);
    expect(find.text('rejected'), findsNothing);
    expect(find.text('CallV2ClientErrorCode.rejected'), findsNothing);
  });

  testWidgets('unauthorized maps to generic permission required text',
      (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ControlledFailureScreen(
          viewModel: _model(errorCode: CallV2ClientErrorCode.unauthorized),
        ),
      ),
    );

    expect(find.text('Permission required'), findsOneWidget);
    expect(find.text('unauthorized'), findsNothing);
  });

  testWidgets('retry and dismiss appear only when enabled', (tester) async {
    await tester.pumpWidget(
      _host(
        CallV2ControlledFailureScreen(
          viewModel: _model(retryEnabled: false, dismissEnabled: true),
        ),
      ),
    );

    expect(find.text('Retry'), findsNothing);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('controls emit typed actions when callback is supplied',
      (tester) async {
    final actions = <CallV2ProductionUserAction>[];
    await tester.pumpWidget(
      _host(
        CallV2ControlledFailureScreen(
          viewModel: _model(retryEnabled: true, dismissEnabled: true),
          onAction: actions.add,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.retryControlledFailure',
    )));
    await tester.tap(find.byKey(const ValueKey<String>(
      'call-v2.action.dismissControlledFailure',
    )));

    expect(actions, <CallV2ProductionUserAction>[
      CallV2ProductionUserAction.retryControlledFailure,
      CallV2ProductionUserAction.dismissControlledFailure,
    ]);
  });
}

Widget _host(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

CallV2ControlledFailureViewModel _model({
  CallV2ClientErrorCode errorCode = CallV2ClientErrorCode.rejected,
  bool retryEnabled = true,
  bool dismissEnabled = false,
}) {
  return CallV2ControlledFailureViewModel(
    errorCode: errorCode,
    retryEnabled: retryEnabled,
    dismissEnabled: dismissEnabled,
    allowedActions: <CallV2ProductionUserAction>{
      if (retryEnabled) CallV2ProductionUserAction.retryControlledFailure,
      if (dismissEnabled) CallV2ProductionUserAction.dismissControlledFailure,
    },
  );
}
