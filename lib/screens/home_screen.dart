import 'package:flutter/material.dart';

import '../games/memory_match/memory_match_game.dart';
import '../games/perfect_puzzles/perfect_puzzles_game.dart';
import '../games/sand_drawing/sand_drawing_game.dart';
import '../games/space_adventure/space_adventure_game.dart';
import '../games/tic_tac_toe/tic_tac_toe_game.dart';
import '../games/world_walk/world_walk_game.dart';

/// A game that shows up on the home screen.
class GameEntry {
  const GameEntry({
    required this.title,
    required this.picture,
    required this.builder,
  });

  final String title;

  /// The colourful picture on the game's card, in assets/icons/.
  final String picture;
  final WidgetBuilder builder;
}

/// Add new games to this list. Tap Counter is archived: its code is still
/// here, it just isn't on the home screen.
final List<GameEntry> games = [
  GameEntry(
    title: 'Perfect Puzzles',
    picture: 'assets/icons/puzzles.png',
    builder: (_) => const PerfectPuzzlesGame(),
  ),
  GameEntry(
    title: 'Space Adventure',
    picture: 'assets/icons/rocket.png',
    builder: (_) => const SpaceAdventureGame(),
  ),
  GameEntry(
    title: 'Sand Drawing',
    picture: 'assets/icons/sand.png',
    builder: (_) => const SandDrawingGame(),
  ),
  GameEntry(
    title: 'Tic-Tac-Toe',
    picture: 'assets/icons/tictactoe.png',
    builder: (_) => const TicTacToeGame(),
  ),
  GameEntry(
    title: 'Memory Match',
    picture: 'assets/icons/memory.png',
    builder: (_) => const MemoryMatchGame(),
  ),
  GameEntry(
    title: 'Walk to Australia',
    picture: 'assets/icons/walk.png',
    builder: (_) => const WorldWalkGame(),
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
        childAspectRatio: 0.82,
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
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Expanded(
                        child: Image.asset(game.picture, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      Text(game.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
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
