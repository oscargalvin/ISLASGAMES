import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battle_model.dart';
import 'battle_painter.dart';

const _nameKey = 'battle_username';

/// Islas Battle: drop onto an island, grab guns and be the last one standing.
class BattleGameScreen extends StatefulWidget {
  const BattleGameScreen({super.key});

  @override
  State<BattleGameScreen> createState() => _BattleGameScreenState();
}

class _BattleGameScreenState extends State<BattleGameScreen> {
  final _name = TextEditingController();
  Mode _mode = Mode.battleRoyale;
  Difficulty _difficulty = Difficulty.normal;
  String? _error;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final n = p.getString(_nameKey);
      if (n != null && mounted) setState(() => _name.text = n);
    }).catchError((_) {});
  }

  bool _checkName() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Type your username first!');
      return false;
    }
    setState(() => _error = null);
    SharedPreferences.getInstance()
        .then((p) => p.setString(_nameKey, _name.text.trim()))
        .catchError((_) => false);
    return true;
  }

  void _play() {
    if (!_checkName()) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BattleMatch(
        game: BattleGame(
            playerName: _name.text.trim(),
            mode: _mode,
            difficulty: _difficulty),
      ),
    ));
  }

  void _online() {
    if (!_checkName()) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Online battles coming soon'),
        content: const Text(
            'Playing against real people needs the Islas game server, and that isn\'t switched on yet. '
            'For now you can battle the bots!'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget chip<T>(T value, T group, String label, ValueChanged<T> on) =>
        ChoiceChip(
          label: Text(label),
          selected: value == group,
          onSelected: (_) => setState(() => on(value)),
        );
    return Scaffold(
      backgroundColor: const Color(0xFF1B2A1E),
      appBar: AppBar(
        title: const Text('Islas Battle'),
        backgroundColor: const Color(0xFF223826),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ISLAS BATTLE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      maxLength: 16,
                      autofillHints: const <String>[],
                      decoration: InputDecoration(
                        labelText: 'Your username',
                        border: const OutlineInputBorder(),
                        errorText: _error,
                      ),
                    ),
                    const Text('Game',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Wrap(spacing: 6, children: [
                      chip(Mode.battleRoyale, _mode, 'Battle (8 players)',
                          (v) => _mode = v),
                      chip(Mode.oneVsOne, _mode, '1v1', (v) => _mode = v),
                      chip(Mode.twoVsTwo, _mode, '2v2', (v) => _mode = v),
                    ]),
                    const SizedBox(height: 8),
                    const Text('Bots',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Wrap(spacing: 6, children: [
                      chip(Difficulty.easy, _difficulty, 'Easy',
                          (v) => _difficulty = v),
                      chip(Difficulty.normal, _difficulty, 'Normal',
                          (v) => _difficulty = v),
                      chip(Difficulty.hard, _difficulty, 'Hard',
                          (v) => _difficulty = v),
                    ]),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _play,
                      icon: const Icon(Icons.smart_toy),
                      label: const Text('PLAY VS BOTS'),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: const Color(0xFF2E7D32)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _online,
                      icon: const Icon(Icons.public),
                      label: const Text('PLAY ONLINE'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Computer: WASD to move, mouse to aim, click to shoot, 1-5 change gun, R reload, '
                      'E swap gun, hold Space for jetpack.\n'
                      'Phone: left thumb moves, right thumb aims and shoots.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One match against the bots.
class BattleMatch extends StatefulWidget {
  const BattleMatch({super.key, required this.game});

  final BattleGame game;

  @override
  State<BattleMatch> createState() => _BattleMatchState();
}

class _BattleMatchState extends State<BattleMatch>
    with SingleTickerProviderStateMixin {
  late BattleGame game = widget.game;
  final controls = Controls();
  late final Ticker _ticker;
  late Ground _ground = Ground.build(game);
  Duration _last = Duration.zero;
  final _keys = <LogicalKeyboardKey>{};
  bool _touch = false;
  bool _mouseDown = false;
  Offset? _mouse;
  Size _size = Size.zero;
  final _sticks = <int, (bool left, Offset origin, Offset now)>{};
  String? _toast;
  double _toastTime = 0;
  bool _ended = false;
  final _players = List.generate(6, (_) => AudioPlayer());
  int _nextPlayer = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    _ticker.dispose();
    HardwareKeyboard.instance.removeHandler(_onKey);
    for (final p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  void _sound(String name, [double volume = 1]) {
    if (volume < 0.05) return;
    final p = _players[_nextPlayer++ % _players.length];
    p
        .stop()
        .then((_) =>
            p.play(AssetSource('audio/battle/$name.wav'), volume: volume))
        .catchError((_) {});
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent) {
      _keys.add(e.logicalKey);
      final k = e.logicalKey;
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      if (digits.contains(k)) controls.swapTo = digits.indexOf(k);
      if (k == LogicalKeyboardKey.keyR) controls.reload = true;
      if (k == LogicalKeyboardKey.keyE) controls.pickup = true;
      if (k == LogicalKeyboardKey.keyQ) controls.nextWeapon = true;
    } else if (e is KeyUpEvent) {
      _keys.remove(e.logicalKey);
    }
    return true;
  }

  double get _zoom {
    if (_size.isEmpty) return 1;
    var z = (_size.shortestSide / 620).clamp(0.5, 1.1);
    if (game.watching.gun?.type == WeaponType.sniper) z *= 0.7;
    return z;
  }

  Offset get _camera {
    final me = game.watching;
    var c = me.pos;
    if (me.gun?.type == WeaponType.sniper)
      c += Offset.fromDirection(me.aim, _size.shortestSide * 0.35 / _zoom);
    return c;
  }

  Offset _toScreen(Offset world) =>
      (world - _camera) * _zoom + _size.center(Offset.zero);

  void _tick(Duration now) {
    final dt =
        _last == Duration.zero ? 0.016 : (now - _last).inMicroseconds / 1e6;
    _last = now;

    // Keyboard movement.
    var m = Offset.zero;
    if (_keys.contains(LogicalKeyboardKey.keyW) ||
        _keys.contains(LogicalKeyboardKey.arrowUp)) m += const Offset(0, -1);
    if (_keys.contains(LogicalKeyboardKey.keyS) ||
        _keys.contains(LogicalKeyboardKey.arrowDown)) m += const Offset(0, 1);
    if (_keys.contains(LogicalKeyboardKey.keyA) ||
        _keys.contains(LogicalKeyboardKey.arrowLeft)) m += const Offset(-1, 0);
    if (_keys.contains(LogicalKeyboardKey.keyD) ||
        _keys.contains(LogicalKeyboardKey.arrowRight)) m += const Offset(1, 0);
    var fire = _mouseDown;
    var jet = _keys.contains(LogicalKeyboardKey.space);
    // Thumb sticks.
    for (final (left, origin, at) in _sticks.values) {
      final d = at - origin;
      if (left) {
        m = d / 55;
      } else if (d.distance > 12) {
        controls.aim = d.direction;
        fire = d.distance > 30;
      }
    }
    if (_mouse != null && !_touch)
      controls.aim = (_mouse! - _toScreen(game.player.pos)).direction;
    controls.move = m;
    controls.fire = fire;
    controls.jet = jet || _jetHeld;

    game.update(dt, controls);
    _playEvents();
    _toastTime -= dt;
    if (game.over && !_ended) {
      _ended = true;
      if (game.won) _sound('victory');
    }
    setState(() {});
  }

  bool _jetHeld = false;

  void _playEvents() {
    for (final e in game.events) {
      final vol = (1 - e.distance / 1400).clamp(0.0, 1.0);
      switch (e.kind) {
        case EventKind.shot:
          _sound(e.weapon!.name, vol * 0.8);
        case EventKind.explosion:
          _sound('explosion', vol);
        case EventKind.hit:
          _sound('hit', 0.6);
        case EventKind.playerHit:
          _sound('hurt', 0.7);
        case EventKind.pickup:
          _sound('pickup', 0.6);
          _toast = 'Picked up ${e.text}';
          _toastTime = 1.5;
        case EventKind.kill:
          if (e.text != null && e.text!.startsWith(game.player.name))
            _sound('knock', 0.8);
        case EventKind.reload:
          _sound('reload', 0.6);
        case EventKind.empty:
          _sound('empty', 0.6);
        case EventKind.jet:
          break;
      }
    }
    game.events.clear();
  }

  void _restart() {
    setState(() {
      game = BattleGame(
          playerName: game.playerName,
          mode: game.mode,
          difficulty: game.difficulty);
      _ground = Ground.build(game);
      _ended = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(builder: (context, box) {
        _size = box.biggest;
        final me = game.player;
        return Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                cursor: SystemMouseCursors.precise,
                onHover: (e) => _mouse = e.localPosition,
                child: Listener(
                  onPointerDown: (e) {
                    if (e.kind == PointerDeviceKind.touch) {
                      _touch = true;
                      _sticks[e.pointer] = (
                        e.localPosition.dx < _size.width / 2,
                        e.localPosition,
                        e.localPosition
                      );
                    } else {
                      _mouse = e.localPosition;
                      _mouseDown = e.buttons & kPrimaryButton != 0;
                    }
                  },
                  onPointerMove: (e) {
                    final s = _sticks[e.pointer];
                    if (s != null) {
                      _sticks[e.pointer] = (s.$1, s.$2, e.localPosition);
                    } else {
                      _mouse = e.localPosition;
                    }
                  },
                  onPointerUp: (e) {
                    _sticks.remove(e.pointer);
                    _mouseDown = false;
                  },
                  onPointerCancel: (e) {
                    _sticks.remove(e.pointer);
                    _mouseDown = false;
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: BattlePainter(
                        game: game,
                        ground: _ground,
                        camera: _camera,
                        zoom: _zoom,
                        time: game.time),
                  ),
                ),
              ),
            ),
            if (me.hurtFlash > 0 ||
                (me.pos - game.stormCenter).distance > game.stormRadius)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      Colors.transparent,
                      (me.hurtFlash > 0 ? Colors.red : Colors.purple)
                          .withValues(alpha: 0.45),
                    ], stops: const [
                      0.6,
                      1
                    ]),
                  ),
                ),
              ),
            for (final (left, origin, at) in _sticks.values)
              ..._stick(origin, at, left),
            _topBar(),
            _bottomBar(),
            if (_touch && me.hasJetpack && me.alive) _jetButton(),
            if (game.nearPickup != null && me.alive) _swapPrompt(),
            if (_toast != null && _toastTime > 0)
              Positioned(
                top: 90,
                left: 0,
                right: 0,
                child: IgnorePointer(child: Center(child: _label(_toast!, 16))),
              ),
            if (game.over) _endScreen(),
          ],
        );
      }),
    );
  }

  List<Widget> _stick(Offset origin, Offset at, bool left) {
    final d = at - origin;
    final knob = d.distance > 55 ? origin + d / d.distance * 55 : at;
    return [
      Positioned(
        left: origin.dx - 55,
        top: origin.dy - 55,
        child: IgnorePointer(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
              color: Colors.white10,
            ),
          ),
        ),
      ),
      Positioned(
        left: knob.dx - 24,
        top: knob.dy - 24,
        child: IgnorePointer(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (left ? Colors.white : Colors.redAccent)
                    .withValues(alpha: 0.5)),
          ),
        ),
      ),
    ];
  }

  Widget _label(String text, double size) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: size,
                fontWeight: FontWeight.w700)),
      );

  Widget _topBar() {
    final storm = game.stormMoving
        ? 'Storm closing in!'
        : game.stormPhase >= 5
            ? 'Final circle'
            : 'Storm moves in ${game.stormTimer.ceil()}s';
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton.filledTonal(
              tooltip: 'Leave game',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('👥 ${game.aliveCount} left   🎯 ${game.player.kills}',
                      14),
                  const SizedBox(height: 4),
                  _label('🌀 $storm', 12),
                  const SizedBox(height: 4),
                  for (final k in game.feed.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(k.text,
                          style: TextStyle(
                              color: k.byPlayer
                                  ? Colors.amberAccent
                                  : Colors.white,
                              fontSize: 11,
                              shadows: const [Shadow(blurRadius: 3)])),
                    ),
                ],
              ),
            ),
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(painter: MiniMapPainter(game)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final me = game.player;
    final g = me.gun;
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (g != null)
                _label(
                    me.reloading > 0
                        ? 'Reloading...'
                        : '${g.spec.name}  ${g.mag} / ${me.ammo[g.spec.ammo]}',
                    14),
              const SizedBox(height: 4),
              SizedBox(
                width: 220,
                child: Column(children: [
                  _bar(me.shield / 100, const Color(0xFF42A5F5)),
                  const SizedBox(height: 3),
                  _bar(me.health / 100, const Color(0xFF66BB6A)),
                  if (me.hasJetpack) ...[
                    const SizedBox(height: 3),
                    _bar(me.fuel / 100, Colors.orange),
                  ],
                ]),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 5; i++) _slot(i),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => controls.reload = true,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double v, Color c) => Container(
        height: 9,
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(4)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v.clamp(0, 1),
          child: Container(
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(4))),
        ),
      );

  Widget _slot(int i) {
    final g = game.player.slots[i];
    final selected = game.player.current == i;
    return GestureDetector(
      onTap: () => controls.swapTo = i,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: g == null
              ? Colors.black38
              : rarityColor(g.spec.rarity).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 3 : 1),
        ),
        child: g == null
            ? null
            : CustomPaint(
                painter: _GunIcon(g.type),
              ),
      ),
    );
  }

  Widget _jetButton() => Positioned(
        right: 20,
        bottom: 150,
        child: Listener(
          onPointerDown: (_) => _jetHeld = true,
          onPointerUp: (_) => _jetHeld = false,
          onPointerCancel: (_) => _jetHeld = false,
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Colors.orange, shape: BoxShape.circle),
            child: const Icon(Icons.rocket_launch, color: Colors.white),
          ),
        ),
      );

  Widget _swapPrompt() => Positioned(
        bottom: 150,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap: () => controls.pickup = true,
            child: _label(
                '${_touch ? 'Tap' : 'Press E'}: pick up ${game.nearPickup!.label}',
                15),
          ),
        ),
      );

  Widget _endScreen() {
    final won = game.won;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(won ? '#1 VICTORY!' : 'Knocked out!',
                  style: TextStyle(
                      color: won ? Colors.amberAccent : Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      shadows: const [Shadow(blurRadius: 8)])),
              if (!won)
                Text('You came #${game.player.placed}',
                    style: const TextStyle(color: Colors.white, fontSize: 22)),
              Text('Knock-outs: ${game.player.kills}',
                  style: const TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 20),
              Row(mainAxisSize: MainAxisSize.min, children: [
                FilledButton(
                    onPressed: _restart, child: const Text('Play again')),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Menu'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _GunIcon extends CustomPainter {
  _GunIcon(this.type);
  final WeaponType type;

  @override
  void paint(Canvas canvas, Size size) {
    final len = weapons[type]!.length + 12;
    final s = (size.width - 8) / len;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.rotate(-0.4);
    canvas.translate(-len / 2 + 8, 0);
    drawGun(canvas, type);
  }

  @override
  bool shouldRepaint(_GunIcon oldDelegate) => oldDelegate.type != type;
}
