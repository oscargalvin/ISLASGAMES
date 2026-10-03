import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'planets.dart';
import 'space_model.dart';
import 'launch_painters.dart';
import 'space_painter.dart';
import 'surface_painter.dart';

/// Space Adventure: get your rocket ready, blast off, and explore the
/// solar system - but don't get too hot, too cold, too sick or too hurt!
class SpaceAdventureGame extends StatefulWidget {
  const SpaceAdventureGame({super.key});

  @override
  State<SpaceAdventureGame> createState() => _SpaceAdventureGameState();
}

class _SpaceAdventureGameState extends State<SpaceAdventureGame>
    with SingleTickerProviderStateMixin {
  final game = SpaceGameModel();
  final controls = Controls();
  final Set<String> _touch = {};
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  static final _gameKeys = <LogicalKeyboardKey>[
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.dispose();
    super.dispose();
  }

  bool _held(List<LogicalKeyboardKey> keys, String touchName) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.any(pressed.contains) || _touch.contains(touchName);
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    controls
      ..left = _held([LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA], 'left')
      ..right =
          _held([LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD], 'right')
      ..up = _held([LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW], 'up')
      ..down = _held([LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS], 'down');
    setState(() => game.update(dt, controls));
  }

  bool _onKey(KeyEvent event) {
    final key = event.logicalKey;
    final isEnter = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
    if (isEnter) {
      if (event is KeyDownEvent) setState(game.pressEnter);
      return true;
    }
    if (key == LogicalKeyboardKey.keyA) {
      if (event is KeyDownEvent) setState(game.pressSecretKey);
      return false;
    }
    return _gameKeys.contains(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > 760;
          return Stack(
            children: [
              Positioned.fill(child: _scene(wide)),
              ..._overlays(box, wide),
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: IconButton.filledTonal(
                    tooltip: 'Back to games',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- scenery

  Widget _scene(bool wide) {
    final CustomPainter painter;
    switch (game.phase) {
      case Phase.setup:
      case Phase.countdown:
        painter = LaunchPadPainter(game,
            rocketX: wide ? 0.34 : 0.5,
            groundY: wide ? 0.85 : 0.42,
            roomWidth: wide ? 0.62 : 1.0);
      case Phase.flight:
        painter = FlightPainter(game);
      case Phase.surface:
        painter = SurfacePainter(game);
      default:
        painter = game.scenePhase == Phase.surface
            ? SurfacePainter(game)
            : SpacePainter(game);
    }
    return CustomPaint(painter: painter, child: const SizedBox.expand());
  }

  // ------------------------------------------------------------ overlays

  List<Widget> _overlays(BoxConstraints box, bool wide) {
    switch (game.phase) {
      case Phase.setup:
        return [
          if (wide)
            Positioned(
              right: 24,
              top: 24,
              bottom: 24,
              width: 400,
              child: Center(child: SingleChildScrollView(child: _setupPanel())),
            )
          else
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: box.maxHeight * 0.56),
                child: SingleChildScrollView(child: _setupPanel()),
              ),
            ),
          if (game.messageTime > 0)
            Positioned(
              top: 20,
              left: 16,
              right: wide ? 440 : 70,
              child: Center(child: _bubble(game.message)),
            ),
        ];
      case Phase.countdown:
        return [
          Center(
            child: Text(
              game.countdown > 0 ? '${game.countdown.ceil()}' : 'LIFT OFF! 🚀',
              style: const TextStyle(
                fontSize: 110,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 16, color: Colors.black87)],
              ),
            ),
          ),
        ];
      case Phase.flight:
        return [
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: _panelDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Time until you reach space',
                        style: TextStyle(color: Colors.white70, fontSize: 15)),
                    Text(game.flightClock,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(height: 4),
                    Text(game.flightFact,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 17)),
                    if (game.hasWon)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('🤫 Psst... press A five times really fast!',
                            style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
                child: _bubble('⬅️ ➡️  Use the arrow keys to steer your rocket')),
          ),
          _touchPad(arrowsOnly: true),
        ];
      case Phase.space:
        return [
          _hudPositioned(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 150,
            child: Center(child: _spacePrompt()),
          ),
          _touchPad(),
        ];
      case Phase.surface:
        final info = game.surface;
        final String bubble;
        final bool dim;
        if (game.messageTime > 0) {
          bubble = game.message;
          dim = false;
        } else if (game.nearLandmark && info != null) {
          bubble = '💡 ${info.fact}';
          dim = false;
        } else {
          bubble = 'Press ENTER to get back in your rocket 🚀';
          dim = true;
        }
        return [
          _hudPositioned(),
          Positioned(
            left: 16,
            right: 16,
            bottom: 150,
            child: Center(child: _bubble(bubble, dim: dim)),
          ),
          _touchPad(enterLabel: 'Blast off'),
        ];
      case Phase.gameOver:
        return [
          _endScreen(
            emoji: '💥',
            title: 'Oh no!',
            text: game.deathReason.isEmpty
                ? 'Your astronaut ran out of health.'
                : game.deathReason,
            button: 'Start again from the launch pad 🚀',
            tint: const Color(0xCC4A0000),
          ),
        ];
      case Phase.win:
        return [
          _endScreen(
            emoji: '🏆',
            title: 'You explored the whole solar system!',
            text:
                'You visited every planet all the way out to Pluto. What an amazing astronaut!',
            button: 'Play again 🚀',
            tint: const Color(0xCC1A237E),
          ),
        ];
    }
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      );

  Widget _bubble(String text, {bool dim = false}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: _panelDecoration(),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: dim ? Colors.white70 : Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _setupPanel() {
    final done = game.checklistDone.length;
    final total = SpaceGameModel.jobs.length;
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Get your rocket ready! 🚀',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Tap a job and watch your astronaut do it.'),
            const SizedBox(height: 8),
            for (var i = 0; i < total; i++) _jobTile(i),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              onPressed: game.readyToLaunch ? () => setState(game.launch) : null,
              child: Text(game.readyToLaunch
                  ? '🚀 LAUNCH!'
                  : 'Finish the jobs first ($done/$total)'),
            ),
            if (game.readyToLaunch)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('...or press ENTER', textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }

  Widget _jobTile(int i) {
    final done = game.checklistDone.contains(i);
    final working = game.activeJob == i;
    final busy = game.activeJob != null && !working;
    final locked = i == SpaceGameModel.jobs.length - 1 &&
        game.checklistDone.length < SpaceGameModel.jobs.length - 1;
    final Widget leading;
    if (done) {
      leading = const Icon(Icons.check_circle, color: Colors.green, size: 28);
    } else if (working) {
      leading = SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
            value: game.jobProgress(i), strokeWidth: 4),
      );
    } else if (locked) {
      leading = const Icon(Icons.lock_outline, size: 28, color: Colors.grey);
    } else {
      leading = const Icon(Icons.play_circle_outline, size: 28);
    }
    return ListTile(
      leading: leading,
      title: Text(
        SpaceGameModel.jobs[i].label,
        style: TextStyle(
          fontSize: 17,
          fontWeight: working ? FontWeight.w800 : FontWeight.w500,
          color: done || busy || locked ? Colors.black45 : Colors.black87,
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: working
          ? const Text('Your astronaut is on it...')
          : locked
              ? const Text('Do this one last')
              : null,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: done ? null : () => setState(() => game.tickChecklist(i)),
    );
  }

  Widget _spacePrompt() {
    final p = game.nearPlanet;
    if (p != null) {
      final text = p.landing == LandingType.home
          ? "You're home at Earth! 🌍 Press ENTER to land and get fixed up."
          : game.visited.contains(p.name)
              ? "You've been to ${p.title} already. Press ENTER to land again, or keep flying."
              : 'You found ${p.title}! Press ENTER to land, or keep flying to skip it.';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bubble(text),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => setState(() => game.land(p)),
            icon: const Icon(Icons.flight_land),
            label: Text('Land on ${p.title}'),
          ),
        ],
      );
    }
    if (game.messageTime > 0) return _bubble(game.message);
    return const SizedBox.shrink();
  }

  Widget _hudPositioned() {
    return Positioned(
      top: 12,
      left: 12,
      child: SafeArea(child: _hud()),
    );
  }

  Widget _hud() {
    final hp = game.health.clamp(0.0, 100.0);
    final Color hpColor = hp > 60
        ? Colors.greenAccent
        : hp > 30
            ? Colors.orangeAccent
            : Colors.redAccent;
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    final info = game.surface;
    final onSurface = game.scenePhase == Phase.surface;
    return Container(
      width: 270,
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Text('❤️ Health', style: white),
            const Spacer(),
            Text('${hp.round()}', style: white),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: hp / 100,
              minHeight: 12,
              backgroundColor: Colors.white12,
              color: hpColor,
            ),
          ),
          const SizedBox(height: 10),
          const Row(children: [
            Text('❄️ Cold', style: white),
            Spacer(),
            Text('Hot 🔥', style: white),
          ]),
          const SizedBox(height: 4),
          _TemperatureBar(value: game.temperature),
          const SizedBox(height: 10),
          if (game.status.isNotEmpty)
            Text(
              game.status,
              style: TextStyle(
                color: game.danger ? Colors.orangeAccent : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 8),
          Text('🪐 Places explored: ${game.visited.length}/${game.placesToVisit}',
              style: const TextStyle(color: Colors.white70)),
          if (onSurface && info != null)
            Text(
                '⭐ ${info.itemName}s found: ${game.collected.length}/${SpaceGameModel.itemXs.length}',
                style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _endScreen({
    required String emoji,
    required String title,
    required String text,
    required String button,
    required Color tint,
  }) {
    return Positioned.fill(
      child: Container(
        color: tint,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 80)),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20)),
            ),
            const SizedBox(height: 8),
            Text(
                'You explored ${game.visited.length} of ${game.placesToVisit} places.',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              onPressed: () => setState(game.reset),
              child: Text(button),
            ),
            const SizedBox(height: 8),
            const Text('...or press ENTER',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------- on-screen buttons

  Widget _touchPad({bool arrowsOnly = false, String enterLabel = 'Land'}) {
    Widget arrow(String name, IconData icon) {
      final down = _touch.contains(name);
      return Listener(
        onPointerDown: (_) => setState(() => _touch.add(name)),
        onPointerUp: (_) => setState(() => _touch.remove(name)),
        onPointerCancel: (_) => setState(() => _touch.remove(name)),
        child: Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(down ? 110 : 45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      );
    }

    return Positioned(
      right: 16,
      bottom: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!arrowsOnly && game.phase == Phase.surface)
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              child: FilledButton(
                onPressed: () => setState(game.pressEnter),
                child: Text(enterLabel),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!arrowsOnly) arrow('up', Icons.keyboard_arrow_up),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  arrow('left', Icons.keyboard_arrow_left),
                  if (!arrowsOnly) arrow('down', Icons.keyboard_arrow_down),
                  arrow('right', Icons.keyboard_arrow_right),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemperatureBar extends StatelessWidget {
  const _TemperatureBar({required this.value});

  /// -1 = freezing, 0 = comfy, 1 = boiling.
  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final x = ((value + 1) / 2).clamp(0.0, 1.0) * width;
        return SizedBox(
          height: 14,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    gradient: const LinearGradient(colors: [
                      Color(0xFF2196F3),
                      Color(0xFF4CAF50),
                      Color(0xFFFF5722),
                    ]),
                  ),
                ),
              ),
              Positioned(
                left: (x - 3).clamp(0.0, math.max(0.0, width - 6)),
                top: -4,
                bottom: -4,
                width: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 3)
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
