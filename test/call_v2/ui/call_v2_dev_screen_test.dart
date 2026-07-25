import 'dart:io';

import 'package:connect_app/call_v2/runtime/fake_call_v2_runtime.dart';
import 'package:connect_app/call_v2/ui/call_v2_dev_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dev screen drives fake call states by explicit user actions',
      (tester) async {
    final runtime = FakeCallV2Runtime();
    addTearDown(runtime.dispose);

    await tester
        .pumpWidget(MaterialApp(home: CallV2DevScreen(runtime: runtime)));
    expect(find.text('Idle'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('start-audio')));
    await tester.pump();
    expect(find.text('Permission preflight'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('request-permission')));
    await tester.pump();
    expect(find.text('Connecting'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('connect-fake-rtc')));
    await tester.pump();
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('activate-call')));
    await tester.pump();
    expect(find.text('Active'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('end-call')));
    await tester.pump();
    expect(find.text('Ended'), findsOneWidget);
  });

  test('dev screen is not referenced by main or router', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final routerSource =
        File('lib/navigation/app_router.dart').readAsStringSync();

    expect(mainSource, isNot(contains('CallV2DevScreen')));
    expect(routerSource, isNot(contains('CallV2DevScreen')));
    expect(routerSource, isNot(contains('/call-v2/dev')));
  });
}
