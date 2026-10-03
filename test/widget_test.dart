import 'package:douglas_personal_assistant/main.dart';
import 'package:douglas_personal_assistant/screens/auth_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DOUGLAS AI authentication screen loads', (tester) async {
    await tester.pumpWidget(const DouglasAiApp(initialScreen: AuthScreen()));

    await tester.pump();

    expect(find.text('DOUGLAS AI'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
