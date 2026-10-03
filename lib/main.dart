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
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const DouglasStartupScreen(),
    );
  }
}

class DouglasStartupScreen extends StatefulWidget {
  const DouglasStartupScreen({super.key});

  @override
  State<DouglasStartupScreen> createState() => _DouglasStartupScreenState();
}

class _DouglasStartupScreenState extends State<DouglasStartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const ChatScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 170,
            height: 60,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final position = 170 - (_controller.value * 210);

                return Stack(
                  children: [
                    Positioned(
                      left: position,
                      top: 10,
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        size: 34,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
