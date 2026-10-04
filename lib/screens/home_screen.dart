import 'package:flutter/material.dart';

import '../games/memory_match/memory_match_game.dart';
import '../games/perfect_puzzles/perfect_puzzles_game.dart';
import '../games/sand_drawing/sand_drawing_game.dart';
import '../games/space_adventure/space_adventure_game.dart';
import '../games/tic_tac_toe/tic_tac_toe_game.dart';

/// A game that shows up on the home screen.
class GameEntry {
  const GameEntry({
    required this.title,
    required this.icon,
    required this.builder,
  });

  final String title;
  final IconData icon;
  final WidgetBuilder builder;
}

/// Add new games to this list. Tap Counter is archived: its code is still
/// here, it just isn't on the home screen.
final List<GameEntry> games = [
  GameEntry(
    title: 'Perfect Puzzles',
    icon: Icons.extension,
    builder: (_) => const PerfectPuzzlesGame(),
  ),
  GameEntry(
    title: 'Space Adventure',
    icon: Icons.rocket_launch,
    builder: (_) => const SpaceAdventureGame(),
  ),
  GameEntry(
    title: 'Sand Drawing',
    icon: Icons.gesture,
    builder: (_) => const SandDrawingGame(),
  ),
  GameEntry(
    title: 'Tic-Tac-Toe',
    icon: Icons.grid_3x3,
    builder: (_) => const TicTacToeGame(),
  ),
  GameEntry(
    title: 'Memory Match',
    icon: Icons.style,
    builder: (_) => const MemoryMatchGame(),
  ),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Islas Games')),
      body: GridView.extent(
        maxCrossAxisExtent: 220,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          for (final game in games)
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: game.builder)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(game.icon, size: 48),
                    const SizedBox(height: 8),
                    Text(game.title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tiny starter game so there's something to play straight away.
class TapCounterGame extends StatefulWidget {
  const TapCounterGame({super.key});

  @override
  State<TapCounterGame> createState() => _TapCounterGameState();
}

class _TapCounterGameState extends State<TapCounterGame> {
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tap Counter')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score', style: Theme.of(context).textTheme.titleLarge),
            Text('$_score', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _score++),
              icon: const Icon(Icons.touch_app),
              label: const Text('Tap!'),
            ),
            TextButton(
              onPressed: () => setState(() => _score = 0),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }
}
