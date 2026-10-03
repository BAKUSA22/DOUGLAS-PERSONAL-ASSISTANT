import 'package:flutter_test/flutter_test.dart';
import 'package:douglas_personal_assistant/main.dart';

void main() {
  testWidgets('Douglas AI dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const DouglasPersonalAssistantApp());
    await tester.pump();

    expect(find.text('DOUGLAS AI'), findsOneWidget);
  });
}
