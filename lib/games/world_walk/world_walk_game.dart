import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'walk_model.dart';

const _saveKey = 'world_walk_save';

/// Walk to Australia: get from Liverpool to Sydney on a monthly budget.
class WorldWalkGame extends StatefulWidget {
  const WorldWalkGame({super.key});

  @override
  State<WorldWalkGame> createState() => _WorldWalkGameState();
}

class _WorldWalkGameState extends State<WorldWalkGame> {
  final _rnd = math.Random();
  WalkGame? _game;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    WalkGame game = WalkGame();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_saveKey);
      if (saved != null) {
        game = WalkGame.fromJson(jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {}
    if (mounted) setState(() => _game = game);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saveKey, jsonEncode(_game!.toJson()));
    } catch (_) {}
  }

  void _act(void Function(WalkGame g) action) {
    final g = _game!;
    setState(() => action(g));
    _save();
    final news = g.news;
    if (news != null) {
      g.news = null;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(news, style: const TextStyle(fontSize: 18)),
          actions: [
            FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Yay!')),
          ],
        ),
      );
    }
    if (g.phase == Phase.evening) _chooseBed();
  }

  void _toast(String? text) {
    if (text == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  Future<void> _chooseBed() async {
    final g = _game!;
    final choice = await showModalBottomSheet<Sleep>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🌙 Night time near ${g.here.name}. Where will you sleep?',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('You have £${g.money}.'),
              const SizedBox(height: 12),
              if (g.vehicle.name == 'Campervan')
                _bed(context, Sleep.campervan, '🚐 Your campervan',
                    'Free · lots of energy'),
              _bed(context, Sleep.hotel, '🏨 Hotel',
                  '£${g.hotelPrice} · best sleep, makes you healthier'),
              _bed(context, Sleep.hostel, '🛏️ Hostel',
                  '£${g.hostelPrice} · good sleep'),
              _bed(context, Sleep.camp, '⛺ Camp outside',
                  'Free · chilly, not much energy'),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    _act((g) => g.sleep(choice, _rnd));
  }

  Widget _bed(BuildContext context, Sleep s, String title, String subtitle) {
    final ok = _game!.canSleep(s);
    return Card(
      child: ListTile(
        enabled: ok,
        title: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        subtitle: Text(ok ? subtitle : 'Not enough money'),
        onTap: ok ? () => Navigator.of(context).pop(s) : null,
      ),
    );
  }

  Future<void> _startOver() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start again from Liverpool?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );
    if (sure != true) return;
    setState(() => _game = WalkGame());
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EC),
      appBar: AppBar(
        title: const Text('Walk to Australia'),
        actions: [
          IconButton(
            tooltip: 'Start again',
            icon: const Icon(Icons.restart_alt),
            onPressed: g == null ? null : _startOver,
          ),
        ],
      ),
      body: g == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _whereCard(g),
                      const SizedBox(height: 10),
                      _statsCard(g),
                      const SizedBox(height: 10),
                      if (g.phase == Phase.won || g.phase == Phase.lost)
                        _endCard(g)
                      else
                        _actions(g),
                      const SizedBox(height: 10),
                      _diary(g),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _whereCard(WalkGame g) {
    final next = g.next;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 170, child: CustomPaint(painter: _MapPainter(g))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📍 ${g.here.name}, ${g.here.country} ${g.here.flag}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                if (next != null)
                  Text(g.atPort
                      ? '⛴️ Boat to ${next.name} ${next.flag}: £${g.here.boatToNext}'
                      : 'Next: ${next.name} ${next.flag} · ${g.kmToNext.round()} km'),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: g.progress,
                    minHeight: 18,
                    backgroundColor: Colors.black12,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('🇬🇧 ${(g.progress * 100).toStringAsFixed(1)}% done',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${(totalKm - g.km).round()} km to Sydney 🇦🇺'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsCard(WalkGame g) {
    Widget bar(String label, int value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                  width: 92,
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value / 100,
                    minHeight: 14,
                    backgroundColor: Colors.black12,
                    color: value <= 25 ? Colors.red : color,
                  ),
                ),
              ),
              SizedBox(width: 36, child: Text(' $value')),
            ],
          ),
        );
    final v = g.vehicle;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('📅 Day ${g.day} · Month ${g.month}')),
                Chip(label: Text('💷 £${g.money}')),
                Chip(label: Text('${v.emoji} ${v.name}')),
                ActionChip(
                  label: Text('🤝 ${g.friends.length} friends'),
                  onPressed: () => _showFriends(g),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                'Payday (£$monthlyMoney) in ${g.daysToPayday} day${g.daysToPayday == 1 ? '' : 's'}',
                if (g.daysToNextVehicle > 0)
                  'new vehicle in ${g.daysToNextVehicle} day${g.daysToNextVehicle == 1 ? '' : 's'}',
              ].join(' · '),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            bar('❤️ Health', g.health, Colors.pink),
            bar('🍔 Food', g.food, Colors.orange),
            bar('💧 Water', g.water, Colors.lightBlue),
            bar('⚡ Energy', g.energy, Colors.amber),
          ],
        ),
      ),
    );
  }

  void _showFriends(WalkGame g) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: g.friends.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'No friends yet. Say hello to people on your way! 👋',
                    style: TextStyle(fontSize: 18)),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final f in g.friends)
                    ListTile(
                      leading:
                          Text(f.flag, style: const TextStyle(fontSize: 28)),
                      title: Text(f.name),
                      subtitle: Text('Met in ${f.city}'),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _actions(WalkGame g) {
    final v = g.vehicle;
    final travelLabel = g.atPort
        ? '⛴️ Take the boat (£${g.here.boatToNext})'
        : '${v.emoji} ${v.name == 'Walking' ? 'Walk' : 'Ride'} on today';
    Widget small(String label, VoidCallback? onTap) => Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.white,
            ),
            onPressed: onTap,
            child: Text(label, textAlign: TextAlign.center),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          small('☕ Café meal\n£${g.mealPrice}',
              () => _act((g) => _toast(g.buyMeal()))),
          const SizedBox(width: 8),
          small('💧 Water\n£${g.waterPrice}',
              () => _act((g) => _toast(g.buyWater()))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          small(
              '👋 Say hello',
              g.saidHelloToday
                  ? null
                  : () => _act((g) => _toast(g.sayHello(_rnd)))),
          const SizedBox(width: 8),
          small('😌 Rest today', () => _act((g) => g.rest())),
        ]),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: Colors.deepOrange,
            textStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          onPressed: () => _act((g) => g.travel(_rnd)),
          child: Text(travelLabel),
        ),
      ],
    );
  }

  Widget _endCard(WalkGame g) {
    final won = g.phase == Phase.won;
    return Card(
      color: won ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(won ? '🏆🇦🇺' : '🚑', style: const TextStyle(fontSize: 56)),
            Text(
              won
                  ? 'You made it to Sydney in ${g.day} days!'
                  : 'You got too poorly and had to fly home.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
                won
                    ? 'You made ${g.friends.length} friends along the way. What an adventure!'
                    : 'Tip: keep your food and water up, and sleep somewhere cosy when you can.',
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                setState(() => _game = WalkGame());
                _save();
              },
              child: const Text('Start a new trip from Liverpool'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diary(WalkGame g) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📔 Travel diary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final line in g.log.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}

/// A little map of the route, with the part you've done in orange.
class _MapPainter extends CustomPainter {
  _MapPainter(this.game) : km = game.km;

  final WalkGame game;
  final double km;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7FD3F7), Color(0xFF3FA9E0)],
        ).createShader(full),
    );
    const minLon = -10.0, maxLon = 158.0, minLat = -40.0, maxLat = 58.0;
    const pad = 16.0;
    Offset at(double lat, double lon) => Offset(
          pad + (lon - minLon) / (maxLon - minLon) * (size.width - pad * 2),
          pad + (maxLat - lat) / (maxLat - minLat) * (size.height - pad * 2),
        );
    final pts = [for (final c in route) at(c.lat, c.lon)];

    // Rough land shapes so it looks like a map.
    final land = Paint()..color = const Color(0xFF9BD17B);
    for (final blob in _land) {
      final path = Path()
        ..moveTo(at(blob[0], blob[1]).dx, at(blob[0], blob[1]).dy);
      for (var i = 2; i < blob.length; i += 2) {
        final p = at(blob[i], blob[i + 1]);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), land);
    }

    final whole = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      whole.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        whole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white70);

    // Where you are along the route.
    final i = game.cityIndex;
    var you = pts[i];
    if (i < route.length - 1) {
      final t =
          ((km - cityKm[i]) / (cityKm[i + 1] - cityKm[i])).clamp(0.0, 1.0);
      you = Offset.lerp(pts[i], pts[i + 1], t)!;
    }
    final done = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var j = 1; j <= i; j++) {
      done.lineTo(pts[j].dx, pts[j].dy);
    }
    done.lineTo(you.dx, you.dy);
    canvas.drawPath(
        done,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = Colors.deepOrange);
    for (var j = 0; j < pts.length; j++) {
      canvas.drawCircle(pts[j], 2.5,
          Paint()..color = j <= i ? Colors.deepOrange : Colors.white);
    }
    _label(canvas, '🇬🇧', pts.first + const Offset(-10, -22));
    _label(canvas, '🇦🇺', pts.last + const Offset(-8, 4));
    canvas.drawCircle(you, 15, Paint()..color = Colors.white);
    _label(canvas, game.vehicle.emoji, you - const Offset(10, 11), size: 18);
  }

  void _label(Canvas canvas, String text, Offset at, {double size = 16}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.km != km || old.game.day != game.day;
}

/// Very rough outlines (lat, lon pairs) of Europe/Asia, Africa, Indonesia
/// and Australia.
const _land = <List<double>>[
  [
    58,
    -6,
    58,
    40,
    58,
    100,
    52,
    140,
    40,
    130,
    30,
    122,
    22,
    108,
    10,
    106,
    1,
    104,
    8,
    98,
    16,
    97,
    22,
    90,
    8,
    77,
    22,
    70,
    25,
    57,
    30,
    48,
    13,
    45,
    30,
    33,
    36,
    28,
    36,
    -6,
    44,
    -9,
    50,
    -5
  ],
  [
    36,
    -6,
    37,
    10,
    31,
    32,
    12,
    44,
    0,
    42,
    -10,
    40,
    -25,
    33,
    -35,
    20,
    -15,
    12,
    5,
    8,
    5,
    -8,
    15,
    -17,
    30,
    -10
  ],
  [-6, 105, -8, 115, -9, 125, -7, 120, -3, 110],
  [
    -12,
    131,
    -11,
    142,
    -18,
    146,
    -28,
    153,
    -37,
    150,
    -38,
    140,
    -32,
    128,
    -34,
    116,
    -22,
    114,
    -15,
    125
  ],
];
