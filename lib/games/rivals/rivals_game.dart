import 'package:flutter/material.dart';

import '../web_page_game.dart';

/// Islas Rivals: a realistic first-person 1v1 arena shooter, in the style of
/// Roblox Rivals. The game itself is a three.js page in web/rivals/.
class RivalsGame extends StatelessWidget {
  const RivalsGame({super.key});

  @override
  Widget build(BuildContext context) =>
      const WebPageGame(path: 'rivals/index.html', title: 'Islas Rivals');
}
