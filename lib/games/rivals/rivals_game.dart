import 'package:flutter/material.dart';

import 'rivals_open_stub.dart' if (dart.library.js_interop) 'rivals_open_web.dart';

/// Islas Rivals: a realistic first-person 1v1 arena shooter, in the style of
/// Roblox Rivals. The game itself is a three.js page in web/rivals/, opened
/// full screen so the mouse and keyboard go straight to it.
class RivalsGame extends StatefulWidget {
  const RivalsGame({super.key});

  @override
  State<RivalsGame> createState() => _RivalsGameState();
}

class _RivalsGameState extends State<RivalsGame> {
  @override
  void initState() {
    super.initState();
    openRivals();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text('Loading Islas Rivals…',
                style: TextStyle(color: Colors.white, fontSize: 20))),
      );
}
