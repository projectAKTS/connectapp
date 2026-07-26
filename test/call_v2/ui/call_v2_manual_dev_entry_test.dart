import 'package:connect_app/call_v2/runtime/call_v2_runtime_config.dart';
import 'package:connect_app/call_v2/ui/call_v2_manual_dev_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual developer entry starts in fake mode without side effects',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CallV2ManualDevEntry())),
    );

    expect(find.byKey(const ValueKey<String>('call-v2-manual-dev-entry')),
        findsOneWidget);
    expect(find.text('Fake mode'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Permission preflight'), findsNothing);
  });

  testWidgets('manual developer entry can select internal real-adapter mode',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CallV2ManualDevEntry())),
    );

    await tester.tap(find.byKey(const ValueKey<String>('call-v2-manual-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Internal mode with real adapters').last);
    await tester.pumpAndSettle();

    expect(find.text('Internal mode with real adapters'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
  });

  test('manual entry mode configs keep rollout false and fake default', () {
    expect(const CallV2RuntimeConfig.fake().productionRolloutEnabled, isFalse);
    expect(const CallV2RuntimeConfig.fake().useRealAdapters, isFalse);
  });
}
