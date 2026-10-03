import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService();
  final loggedInUser = await authService.currentUser();

  runApp(
    DouglasAiApp(
      initialScreen: loggedInUser == null
          ? const AuthScreen()
          : const ChatScreen(),
    ),
  );
}

class DouglasAiApp extends StatelessWidget {
  const DouglasAiApp({required this.initialScreen, super.key});

  final Widget initialScreen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOUGLAS AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: initialScreen,
    );
  }
}
