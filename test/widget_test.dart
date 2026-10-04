import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:douglas_personal_assistant/main.dart';

void main() {
  testWidgets('Douglas AI startup screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const DouglasPersonalAssistantApp());
    await tester.pump();

    expect(find.byType(DouglasStartupScreen), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DouglasStartupScreen), findsOneWidget);
  });
}
