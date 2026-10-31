import 'package:connect_app/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, String name) =>
      tester.pumpWidget(MaterialApp(home: InitialsAvatar(url: '', name: name)));

  testWidgets('first and last initials, uppercased', (tester) async {
    await pump(tester, 'yakup  akturk 2026');
    expect(find.text('YA'), findsOneWidget);
    await pump(tester, 'şule');
    expect(find.text('Ş'), findsOneWidget);
  });

  testWidgets('no name falls back to the person icon', (tester) async {
    await pump(tester, '  ');
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
