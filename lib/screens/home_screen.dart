import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/chat/chat_game.dart';
import '../games/memory_match/memory_match_game.dart';
import '../games/perfect_puzzles/perfect_puzzles_game.dart';
import '../games/rivals/rivals_game.dart';
import '../games/sand_drawing/sand_drawing_game.dart';
import '../games/space_adventure/space_adventure_game.dart';
import '../games/tic_tac_toe/tic_tac_toe_game.dart';
import '../games/world_walk/world_walk_game.dart';

/// Colours and fonts of the games shelf.
class Shelf {
  static const bg = Color(0xFF1D1B3A);
  static const ink = Color(0xFF1D1B3A);
  static const paper = Color(0xFFFFFAF0);
  static const sun = Color(0xFFFFD23F);
  static const hot = Color(0xFFFF4F6D);
  static const mint = Color(0xFF3DDC97);
  static const muted = Color(0xFFB9B4E0);
  static const display = 'LilitaOne';
  static const body = 'Nunito';

  /// A thick black outline around big title text.
  static const outline = [
    Shadow(color: Colors.black, offset: Offset(0, 5)),
    Shadow(color: Colors.black, offset: Offset(3, 0)),
    Shadow(color: Colors.black, offset: Offset(-3, 0)),
    Shadow(color: Colors.black, offset: Offset(0, -3)),
  ];

  static const background = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(-0.6, -1),
      radius: 1.1,
      colors: [Color(0xFF3B3480), bg],
      stops: [0, 0.45],
    ),
  );
}

/// A game that shows up on the home screen.
class GameEntry {
  const GameEntry({
    required this.title,
    required this.builder,
    this.tagline = '',
    this.badge,
    this.isNew = false,
    this.picture,
    this.background = const Color(0xFF2A2654),
    this.icon = Icons.videogame_asset,
  });

  final String title;

  /// One short line under the title.
  final String tagline;

  /// The little label in the corner, like "Puzzle".
  final String? badge;

  /// Shows a green "New!" label instead of the badge.
  final bool isNew;

  /// The picture on the game's square, in assets/icons/.
  final String? picture;

  /// Fills the square around the picture.
  final Color background;

  /// Shown when a game has no picture yet.
  final IconData icon;
  final WidgetBuilder builder;
}

/// The games everyone sees. Add new games here.
final List<GameEntry> games = [
  GameEntry(
    title: 'Islas Rivals',
    tagline: 'Win a 1v1 duel in the arena.',
    badge: 'Shooter',
    isNew: true,
    picture: 'assets/icons/rivals.png',
    background: const Color(0xFF6E8BA8),
    builder: (_) => const RivalsGame(),
  ),
  GameEntry(
    title: 'Perfect Puzzles',
    tagline: 'Put the picture back together.',
    badge: 'Puzzle',
    picture: 'assets/icons/puzzles.png',
    background: const Color(0xFF5B2A86),
    builder: (_) => const PerfectPuzzlesGame(),
  ),
  GameEntry(
    title: 'Space Adventure',
    tagline: 'Fly your rocket through the stars.',
    badge: 'Space',
    picture: 'assets/icons/rocket.png',
    background: const Color(0xFF0B1033),
    builder: (_) => const SpaceAdventureGame(),
  ),
  GameEntry(
    title: 'Sand Drawing',
    tagline: 'Draw in the sand with your finger.',
    badge: 'Creative',
    picture: 'assets/icons/sand.png',
    background: const Color(0xFFC9A46A),
    builder: (_) => const SandDrawingGame(),
  ),
  GameEntry(
    title: 'Tic-Tac-Toe',
    tagline: 'Get three in a row to win.',
    badge: 'Classic',
    picture: 'assets/icons/tictactoe.png',
    background: const Color(0xFF1F6FB2),
    builder: (_) => const TicTacToeGame(),
  ),
  GameEntry(
    title: 'Memory Match',
    tagline: 'Flip the cards and find the pairs.',
    badge: 'Memory',
    picture: 'assets/icons/memory.png',
    background: const Color(0xFFB84A5A),
    builder: (_) => const MemoryMatchGame(),
  ),
];

/// Archived games: hidden from everyone except the creator, who can still
/// open them from the Archived Games tab. Move a game between these two
/// lists to archive it or put it back out.
final List<GameEntry> archivedGames = [
  GameEntry(
    title: 'Islas Chat',
    tagline: 'Chat with friends.',
    badge: 'Archived',
    picture: 'assets/icons/chat.png',
    background: const Color(0xFF0E7C66),
    builder: (_) => const ChatGame(),
  ),
  GameEntry(
    title: 'Walk to Australia',
    tagline: 'Walk all the way from the UK.',
    badge: 'Archived',
    picture: 'assets/icons/walk.png',
    background: const Color(0xFFFF8A4C),
    builder: (_) => const WorldWalkGame(),
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

  // Tapping the title 5 times quickly also opens the secret, because a
  // press-and-hold is easy to miss on a phone.
  int _titleTaps = 0;
  DateTime _lastTitleTap = DateTime(2000);

  @override
  void initState() {
    super.initState();
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

  void _secret() => _creator ? _openArchive() : _askForCode();

  void _onTitleTap() {
    final now = DateTime.now();
    _titleTaps = now.difference(_lastTitleTap).inMilliseconds < 800
        ? _titleTaps + 1
        : 1;
    _lastTitleTap = now;
    if (_titleTaps >= 5) {
      _titleTaps = 0;
      _secret();
    }
  }

  void _openArchive() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArchivedGamesScreen(onLock: () => _setCreator(false)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ShelfPage(
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTitleTap,
        onLongPress: _secret,
        child: const ShelfTitle(first: 'Islas ', second: 'Games'),
      ),
      subtitle: 'Pick a square to play.',
      topRight: _creator
          ? _PillButton(
              icon: Icons.inventory_2_outlined,
              label: 'Archived games',
              onTap: _openArchive,
            )
          : null,
      games: games,
    );
  }
}

/// Only the creator gets here. Play archived games to work on them.
class ArchivedGamesScreen extends StatelessWidget {
  const ArchivedGamesScreen({super.key, required this.onLock});

  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    return ShelfPage(
      topLeft: _PillButton(
        icon: Icons.arrow_back,
        label: 'Back',
        onTap: () => Navigator.of(context).pop(),
      ),
      topRight: _PillButton(
        icon: Icons.lock_outline,
        label: 'Hide',
        tooltip: 'Hide the archive on this device',
        onTap: () {
          onLock();
          Navigator.of(context).pop();
        },
      ),
      title: const ShelfTitle(first: 'Archived ', second: 'Games'),
      subtitle: "🔒 Only you can see these. They're hidden from the home screen "
          'but not gone, so you can play them, make them better and put them back out.',
      games: archivedGames,
    );
  }
}

/// The big tilted yellow and pink title.
class ShelfTitle extends StatelessWidget {
  const ShelfTitle({super.key, required this.first, required this.second});

  final String first;
  final String second;

  @override
  Widget build(BuildContext context) {
    final size = (MediaQuery.sizeOf(context).width * 0.08).clamp(38.0, 72.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Transform.rotate(
        angle: -0.035,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: first),
            TextSpan(text: second, style: const TextStyle(color: Shelf.hot)),
          ]),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Shelf.display,
            fontSize: size,
            height: 1,
            color: Shelf.sun,
            shadows: Shelf.outline,
          ),
        ),
      ),
    );
  }
}

/// A page with a title and a shelf of game squares.
class ShelfPage extends StatelessWidget {
  const ShelfPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.games,
    this.topLeft,
    this.topRight,
  });

  final Widget title;
  final String subtitle;
  final List<GameEntry> games;
  final Widget? topLeft;
  final Widget? topRight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Shelf.bg,
      body: DecoratedBox(
        decoration: Shelf.background,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 40,
                            child: Row(children: [
                              if (topLeft != null) topLeft!,
                              const Spacer(),
                              if (topRight != null) topRight!,
                            ]),
                          ),
                          title,
                          const SizedBox(height: 12),
                          Text(subtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontFamily: Shelf.body,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Shelf.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      child: GameGrid(games: games),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.tooltip});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const StadiumBorder(
          side: BorderSide(color: Color(0x80FFFFFF), width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontFamily: Shelf.body,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// One big square per game, like a games shelf.
class GameGrid extends StatelessWidget {
  const GameGrid({super.key, required this.games});

  final List<GameEntry> games;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 20.0;
      final across = ((box.maxWidth + gap) / (300 + gap)).floor().clamp(1, 4);
      final size = (box.maxWidth - gap * (across - 1)) / across;
      return Wrap(
        spacing: gap,
        runSpacing: gap + 8,
        children: [
          for (final game in games)
            SizedBox(width: size, height: size, child: GameSquare(game: game)),
        ],
      );
    });
  }
}

class GameSquare extends StatefulWidget {
  const GameSquare({super.key, required this.game});

  final GameEntry game;

  @override
  State<GameSquare> createState() => _GameSquareState();
}

class _GameSquareState extends State<GameSquare> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final lift = _down ? -4.0 : (_hover ? 4.0 : 0.0);
    final badge = game.isNew ? 'New!' : game.badge;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: game.builder)),
        child: Semantics(
          button: true,
          label: 'Play ${game.title}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            transform: Matrix4.translationValues(0, -lift, 0)
              ..rotateZ(_hover && !_down ? -0.01 : 0),
            decoration: BoxDecoration(
              color: game.background,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.black, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black, offset: Offset(0, 8 + lift)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (game.picture != null)
                    Image.asset(game.picture!, fit: BoxFit.cover)
                  else
                    Icon(game.icon, size: 96, color: Shelf.paper),
                  if (badge != null)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        decoration: BoxDecoration(
                          color: game.isNew ? Shelf.mint : Shelf.paper,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: Text(badge,
                            style: const TextStyle(
                                fontFamily: Shelf.display,
                                fontSize: 14,
                                color: Shelf.ink)),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      padding: const EdgeInsets.fromLTRB(18, 14, 84, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(game.title.toUpperCase(),
                              style: const TextStyle(
                                  fontFamily: Shelf.display,
                                  fontSize: 28,
                                  height: 1.05,
                                  color: Shelf.paper)),
                          if (game.tagline.isNotEmpty)
                            Text(game.tagline,
                                style: const TextStyle(
                                    fontFamily: Shelf.body,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFFDDD8FF))),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Shelf.sun,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black, offset: Offset(0, 4))
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.play_arrow_rounded,
                            size: 34, color: Shelf.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
