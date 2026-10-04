import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';

void main() {
  runApp(const IslaGptApp());
}

class IslaGptApp extends StatelessWidget {
  const IslaGptApp({super.key, this.chatScreen});

  /// Lets tests swap in a chat screen with a fake backend.
  final Widget? chatScreen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Isla GPT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: chatScreen ?? const ChatScreen(),
    );
  }
}
