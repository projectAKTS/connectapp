import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:connect_app/call_v2/diagnostics/call_v2_physical_diagnostic_ledger.dart';
import 'package:connect_app/call_v2/diagnostics/call_v2_physical_diagnostics_view.dart';

void main() {
  testWidgets('diagnostics overlay is absent while developer gate is disabled',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CallV2PhysicalDiagnosticsOverlay(
        enabled: false,
        child: Text('home'),
      ),
    ));

    expect(find.byKey(const ValueKey<String>('call-v2-diagnostics-open')),
        findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('developer-gated view exposes only compact safe report',
      (tester) async {
    final ledger = CallV2PhysicalDiagnosticLedger();
    ledger.beginAcceptedNativeCall(
      exactNativeKey: 'private-native-key',
      nativeOrdinal: 1,
    );
    ledger.record(CallV2PhysicalDiagnosticStage.flutterAcceptBridgeReceived);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CallV2PhysicalDiagnosticsView(ledger: ledger)),
    ));

    expect(find.text('Call V2 diagnostics'), findsOneWidget);
    final report = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('call-v2-diagnostics-report')),
    );
    expect(report.data, contains('flutterAcceptBridgeReceived'));
    expect(report.data, isNot(contains('private-native-key')));
    expect(find.byKey(const ValueKey<String>('call-v2-diagnostics-copy')),
        findsOneWidget);
  });
}
