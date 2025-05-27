import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Connect App header is visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Text('Connect App'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Connect App'), findsOneWidget);
  });
}
