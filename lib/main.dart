import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const DouglasPersonalAssistantApp());
}

class DouglasPersonalAssistantApp extends StatelessWidget {
  const DouglasPersonalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOUGLAS AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const ChatScreen(),
    );
  }
}
