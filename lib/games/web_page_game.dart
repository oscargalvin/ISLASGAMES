import 'package:flutter/material.dart';

import 'web_page_open_stub.dart'
    if (dart.library.js_interop) 'web_page_open_web.dart';

/// A game that is its own web page in web/, opened full screen so the mouse
/// and keyboard go straight to it.
class WebPageGame extends StatefulWidget {
  const WebPageGame({super.key, required this.path, required this.title});

  /// The page, like 'rivals/index.html'.
  final String path;
  final String title;

  @override
  State<WebPageGame> createState() => _WebPageGameState();
}

class _WebPageGameState extends State<WebPageGame> {
  @override
  void initState() {
    super.initState();
    openWebPage(widget.path);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text('Loading ${widget.title}…',
                style: const TextStyle(color: Colors.white, fontSize: 20))),
      );
}
