// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:shelf_scanner_ai/main.dart';

void main() {
  testWidgets('app loads home screen', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Shelf Scanner'), findsOneWidget);
    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(find.text('AI models ready'), findsNothing);
  });
}
