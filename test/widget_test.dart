import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders a basic widget tree', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Text('Only Focus')))),
    );

    expect(find.text('Only Focus'), findsOneWidget);
  });
}
