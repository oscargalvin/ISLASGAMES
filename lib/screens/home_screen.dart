import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/chat/chat_game.dart';
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
    required this.builder,
    this.picture,
    this.icon = Icons.videogame_asset,
  });

  final String title;

  /// The colourful picture on the game's card, in assets/icons/.
  final String? picture;

  /// Shown when a game has no picture yet.
  final IconData icon;
  final WidgetBuilder builder;
}

/// The games everyone sees. Add new games here.
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
    title: 'Islas Chat',
    picture: 'assets/icons/chat.png',
    builder: (_) => const ChatGame(),
  ),
];

/// Archived games: hidden from everyone except the creator, who can still
/// open them from the Archived Games tab. Move a game between these two
/// lists to archive it or put it back out.
final List<GameEntry> archivedGames = [
  GameEntry(
    title: 'Walk to Australia',
    picture: 'assets/icons/walk.png',
    builder: (_) => const WorldWalkGame(),
  ),
  GameEntry(
    title: 'Tap Counter',
    icon: Icons.touch_app,
    builder: (_) => const TapCounterGame(),
  ),
];

/// The creator code for the Archived Games tab.
const _creatorCode = '2026';
const _creatorKey = 'creator_unlocked';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _creator = false;

  @override
  void initState() {
    super.initState();
    // Opened from an Islas Chat invite link: go straight to the chat.
    final join = Uri.base.queryParameters['join'];
    if (join != null && join.isNotEmpty) {
      SystemNavigator.routeInformationUpdated(
          uri: Uri.parse('/'), replace: true);
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatGame(joinCode: join))));
    }
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _creator = p.getBool(_creatorKey) ?? false);
    }).catchError((_) {});
  }

  Future<void> _setCreator(bool on) async {
    setState(() => _creator = on);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_creatorKey, on);
    } catch (_) {}
  }

  /// Secret: press and hold the "Islas Games" title to tap in the creator code.
  Future<void> _askForCode() async {
    // Number buttons instead of a text box, so password managers like
    // LastPass don't pop up over it.
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _CodePad(),
    );
    final ok = code == null ? null : code == _creatorCode;
    if (!mounted || ok == null) return;
    if (ok) {
      await _setCreator(true);
      if (mounted) _openArchive();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("That's not the code.")));
    }
  }

  void _openArchive() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArchivedGamesScreen(onLock: () => _setCreator(false)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _creator ? _openArchive : _askForCode,
          child: const Text('Islas Games'),
        ),
        actions: [
          if (_creator)
            TextButton.icon(
              onPressed: _openArchive,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Archived games'),
            ),
        ],
      ),
      body: GameGrid(games: games),
    );
  }
}

/// Only the creator gets here. Play archived games to work on them.
class ArchivedGamesScreen extends StatelessWidget {
  const ArchivedGamesScreen({super.key, required this.onLock});

  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived games 🗄️'),
        actions: [
          IconButton(
            tooltip: 'Hide the archive on this device',
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              onLock();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "🔒 Only you can see these. They're hidden from the home screen "
              'but not gone, so you can play them, make them better and put them back out.',
            ),
          ),
          Expanded(child: GameGrid(games: archivedGames)),
        ],
      ),
    );
  }
}

class GameGrid extends StatelessWidget {
  const GameGrid({super.key, required this.games});

  final List<GameEntry> games;

  @override
  Widget build(BuildContext context) {
    return GridView.extent(
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
                      child: game.picture != null
                          ? Image.asset(game.picture!, fit: BoxFit.contain)
                          : Center(child: Icon(game.icon, size: 72)),
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

/// A number pad for the creator code.
class _CodePad extends StatefulWidget {
  const _CodePad();

  @override
  State<_CodePad> createState() => _CodePadState();
}

class _CodePadState extends State<_CodePad> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    Widget key(Widget label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox(
            width: 64,
            height: 56,
            child: FilledButton.tonal(
              onPressed: onTap,
              child: label,
            ),
          ),
        );
    Widget digit(String d) => key(
        Text(d, style: const TextStyle(fontSize: 22)),
        () =>
            setState(() => _code = (_code + d).length > 8 ? _code : _code + d));
    return AlertDialog(
      title: const Text('Creator code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_code.isEmpty ? 'Tap your code' : '●' * _code.length,
              style: const TextStyle(fontSize: 24, letterSpacing: 6)),
          const SizedBox(height: 12),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
                mainAxisSize: MainAxisSize.min,
                children: [for (final d in row) digit(d)]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            key(
                const Icon(Icons.backspace_outlined),
                () => setState(() => _code = _code.isEmpty
                    ? _code
                    : _code.substring(0, _code.length - 1))),
            digit('0'),
            key(const Icon(Icons.check), () => Navigator.pop(context, _code)),
          ]),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
      ],
    );
  }
}
