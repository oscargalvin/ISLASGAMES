// The Isla GPT chat app. It's switched off for now (see main.dart) and kept
// here so it can be brought back later.
import 'package:flutter/material.dart';

import 'screens/age_gate.dart';
import 'screens/chat_screen.dart';

class IslaGptApp extends StatelessWidget {
  const IslaGptApp({super.key, this.chatScreen, this.askAge = true});

  /// Lets tests swap in a chat screen with a fake backend.
  final Widget? chatScreen;

  /// Shows the 11+ check before the chat.
  final bool askAge;

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
      home: askAge
          ? AgeGate(child: chatScreen ?? const ChatScreen())
          : chatScreen ?? const ChatScreen(),
    );
  }
}
