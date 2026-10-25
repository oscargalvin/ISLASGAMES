import 'package:flutter/material.dart';

void main() {
  runApp(const OscarAndIslaGamesApp());
}

/// A blank page for now. The Isla GPT chat is in isla_gpt_app.dart,
/// ready to switch back on later.
class OscarAndIslaGamesApp extends StatelessWidget {
  const OscarAndIslaGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oscar and Isla Games',
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
      home: Scaffold(
        appBar: AppBar(title: const Text('Oscar and Isla Games')),
      ),
    );
  }
}
