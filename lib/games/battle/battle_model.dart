import 'dart:math' as math;
import 'dart:ui';

/// Islas Battle: a top-down battle game on an island, against bots.
///
/// Everything here is plain game logic (no drawing), measured in world units
/// where a soldier is about 32 units across.

enum WeaponType { pistol, rifle, shotgun, sniper, rpg }

enum Ammo { light, medium, shells, heavy, rockets }

class WeaponSpec {
  const WeaponSpec({
    required this.name,
    required this.damage,
    required this.fireRate,
    required this.mag,
    required this.reload,
    required this.spread,
    required this.speed,
    required this.range,
    required this.ammo,
    required this.rarity,
    this.pellets = 1,
    this.auto = false,
    this.length = 26,
  });

  final String name;
  final double damage;

  /// Shots per second.
  final double fireRate;
  final int mag;
  final double reload;

  /// Random aim wobble, in radians.
  final double spread;
  final double speed;
  final double range;
  final Ammo ammo;

  /// 0 common (grey) .. 4 legendary (gold).
  final int rarity;
  final int pellets;
  final bool auto;

  /// How long the gun looks.
  final double length;
}

const weapons = <WeaponType, WeaponSpec>{
  WeaponType.pistol: WeaponSpec(
      name: 'Pistol',
      damage: 22,
      fireRate: 4,
      mag: 12,
      reload: 1.1,
      spread: 0.05,
      speed: 1700,
      range: 650,
      ammo: Ammo.light,
      rarity: 0,
      length: 16),
  WeaponType.rifle: WeaponSpec(
      name: 'Assault Rifle',
      damage: 17,
      fireRate: 9,
      mag: 30,
      reload: 1.9,
      spread: 0.06,
      speed: 2100,
      range: 900,
      ammo: Ammo.medium,
      rarity: 2,
      auto: true,
      length: 34),
  WeaponType.shotgun: WeaponSpec(
      name: 'Pump Shotgun',
      damage: 12,
      fireRate: 1.2,
      mag: 6,
      reload: 2.4,
      spread: 0.22,
      speed: 1600,
      range: 330,
      ammo: Ammo.shells,
      rarity: 1,
      pellets: 9,
      length: 30),
  WeaponType.sniper: WeaponSpec(
      name: 'Sniper Rifle',
      damage: 95,
      fireRate: 0.8,
      mag: 5,
      reload: 2.6,
      spread: 0.004,
      speed: 3800,
      range: 2200,
      ammo: Ammo.heavy,
      rarity: 3,
      length: 44),
  WeaponType.rpg: WeaponSpec(
      name: 'Rocket Launcher',
      damage: 105,
      fireRate: 0.6,
      mag: 1,
      reload: 2.4,
      spread: 0.01,
      speed: 750,
      range: 1400,
      ammo: Ammo.rockets,
      rarity: 4,
      length: 40),
};

/// How good a gun is, for bots choosing what to pick up.
int _gunScore(WeaponType t) => switch (t) {
      WeaponType.pistol => 0,
      WeaponType.shotgun => 2,
      WeaponType.rifle => 3,
      WeaponType.sniper => 2,
      WeaponType.rpg => 1,
    };

class Gun {
  Gun(this.type) : mag = weapons[type]!.mag;
  final WeaponType type;
  int mag;
  WeaponSpec get spec => weapons[type]!;
}

enum Mode { battleRoyale, oneVsOne, twoVsTwo }

enum Difficulty { easy, normal, hard }

enum BoxKind { building, container, crate, wall }

/// Something solid and square: a building, shipping container or crate.
class Block {
  Block(this.rect, this.kind, this.color, this.height);
  final Rect rect;
  final BoxKind kind;
  final int color;
  final double height;
}

enum RoundKind { tree, rock, bush }

/// Something round: trees (only the trunk is solid), rocks and bushes.
class Blob {
  Blob(this.center, this.radius, this.kind, this.variant);
  final Offset center;
  final double radius;
  final RoundKind kind;
  final int variant;

  /// The part that stops you and bullets.
  double get solid => switch (kind) {
        RoundKind.tree => radius * 0.22,
        RoundKind.rock => radius * 0.9,
        RoundKind.bush => 0,
      };
}

enum PickupKind { weapon, ammo, medkit, shield, jetpack, speed }

class Pickup {
  Pickup(this.kind, this.pos, {this.weapon, this.ammo, this.amount = 0});
  final PickupKind kind;
  Offset pos;
  final WeaponType? weapon;
  final Ammo? ammo;
  final int amount;
  double age = 0;

  String get label => switch (kind) {
        PickupKind.weapon => weapons[weapon]!.name,
        PickupKind.ammo => 'Ammo',
        PickupKind.medkit => 'Medkit',
        PickupKind.shield => 'Shield potion',
        PickupKind.jetpack => 'Jetpack',
        PickupKind.speed => 'Speed boost',
      };
}

class BotBrain {
  Fighter? target;
  Offset? goal;
  Offset? lastSeen;
  double think = 0;
  double strafe = 1;
  double strafeTimer = 0;
  double sawFor = 0;
  double aimWobble = 0;
  double stuckTimer = 0;
  Offset lastPos = Offset.zero;
}

class Fighter {
  Fighter({
    required this.name,
    required this.team,
    required this.pos,
    this.isPlayer = false,
  });

  final String name;
  final int team;
  final bool isPlayer;
  Offset pos;
  Offset vel = Offset.zero;
  double aim = 0;
  double health = 100;
  double shield = 0;
  bool alive = true;

  final List<Gun?> slots = List.filled(5, null);
  int current = 0;
  final Map<Ammo, int> ammo = {for (final a in Ammo.values) a: 0};
  double cooldown = 0;
  double reloading = 0;

  bool hasJetpack = false;
  double fuel = 0;

  /// 0 on the ground, 1 flying high.
  double altitude = 0;
  double speedBoost = 0;

  double hurtFlash = 0;
  double walk = 0;
  double recoil = 0;
  int kills = 0;
  int placed = 0;
  BotBrain? brain;

  static const radius = 16.0;

  Gun? get gun => slots[current];
  bool get flying => altitude > 0.25;

  void give(Gun g) {
    final same = slots.indexWhere((s) => s?.type == g.type);
    if (same >= 0) {
      ammo[g.spec.ammo] = ammo[g.spec.ammo]! + g.spec.mag;
      return;
    }
    final free = slots.indexWhere((s) => s == null);
    if (free >= 0) {
      slots[free] = g;
      if (slots[current] == null) current = free;
    } else {
      slots[current] = g;
    }
  }
}

class Bullet {
  Bullet(this.pos, this.vel, this.owner, this.type, this.damage, this.range);
  Offset pos;
  final Offset vel;
  final Fighter owner;
  final WeaponType type;
  final double damage;
  double range;
  Offset start = Offset.zero;
}

class Rocket {
  Rocket(this.pos, this.vel, this.owner);
  Offset pos;
  final Offset vel;
  final Fighter owner;
  double life = 2.2;
}

/// Something short-lived to draw: explosions, sparks, smoke and so on.
enum FxKind { explosion, spark, smoke, flash, scorch, splash, dust }

class Fx {
  Fx(this.kind, this.pos, this.life,
      {this.vel = Offset.zero, this.size = 10, this.angle = 0});
  final FxKind kind;
  Offset pos;
  Offset vel;
  final double life;
  final double size;
  final double angle;
  double age = 0;
  double get t => (age / life).clamp(0, 1);
}

/// Things the screen turns into sounds and messages.
enum EventKind {
  shot,
  explosion,
  hit,
  playerHit,
  pickup,
  kill,
  reload,
  empty,
  jet
}

class GameEvent {
  GameEvent(this.kind, {this.weapon, this.distance = 0, this.text});
  final EventKind kind;
  final WeaponType? weapon;
  final double distance;
  final String? text;
}

class KillMessage {
  KillMessage(this.text, this.byPlayer);
  final String text;
  final bool byPlayer;
  double age = 0;
}

/// What the person is pressing right now.
class Controls {
  Offset move = Offset.zero;
  double aim = 0;
  bool fire = false;
  bool jet = false;
  bool reload = false;
  bool pickup = false;
  int? swapTo;
  bool nextWeapon = false;
}

const botNames = [
  'Viper',
  'Ghost',
  'Blaze',
  'Raptor',
  'Echo',
  'Hawk',
  'Shadow',
  'Frost',
  'Titan',
  'Nova',
  'Bolt',
  'Rogue',
  'Fang',
  'Jinx',
  'Onyx',
];

/// The coastline: the island is a wobbly circle.
double coastRadius(double angle, double size) =>
    size +
    size * 0.04 * math.sin(3 * angle + 1) +
    size * 0.027 * math.sin(7 * angle) +
    size * 0.016 * math.sin(13 * angle + 2);

class BattleGame {
  BattleGame({
    required this.playerName,
    this.mode = Mode.battleRoyale,
    this.difficulty = Difficulty.normal,
    int? seed,
  }) : rnd = math.Random(seed) {
    _build();
  }

  final String playerName;
  final Mode mode;
  final Difficulty difficulty;
  final math.Random rnd;

  static const island = 1500.0;

  final blocks = <Block>[];
  final blobs = <Blob>[];
  final roads = <List<Offset>>[];
  final towns = <Offset>[];
  final fighters = <Fighter>[];
  final bullets = <Bullet>[];
  final rockets = <Rocket>[];
  final pickups = <Pickup>[];
  final fx = <Fx>[];
  final scorches = <Fx>[];
  final events = <GameEvent>[];
  final feed = <KillMessage>[];
  late Fighter player;

  // The storm: outside the safe circle hurts.
  Offset stormCenter = Offset.zero;
  double stormRadius = 0;
  double _stormFrom = 0;
  double _stormTo = 0;
  double stormTimer = 0;
  int stormPhase = 0;
  bool stormMoving = false;
  double get stormDamage => 1.0 + stormPhase * 1.5;

  double time = 0;
  bool over = false;
  bool won = false;
  Pickup? nearPickup;

  /// Who the camera follows (a teammate after the player is out).
  Fighter get watching {
    if (player.alive) return player;
    for (final f in fighters) {
      if (f.alive && f.team == player.team) return f;
    }
    return player;
  }

  int get aliveCount => fighters.where((f) => f.alive).length;

  bool onLand(Offset p, [double margin = 0]) {
    final d = p.distance;
    return d < coastRadius(p.direction, island) - margin;
  }

  // ---------------------------------------------------------------- map

  void _build() {
    _makeTowns();
    _makeNature();
    _spawnFighters();
    _scatterLoot();
    final start = mode == Mode.battleRoyale ? island * 1.15 : 820.0;
    stormCenter = mode == Mode.battleRoyale
        ? Offset(rnd.nextDouble() * 400 - 200, rnd.nextDouble() * 400 - 200)
        : Offset.zero;
    stormRadius = _stormFrom = _stormTo = start;
    stormTimer = mode == Mode.battleRoyale ? 45 : 30;
  }

  bool _free(Rect r, [double gap = 30]) {
    final g = r.inflate(gap);
    if (!onLand(g.topLeft, 40) ||
        !onLand(g.topRight, 40) ||
        !onLand(g.bottomLeft, 40) ||
        !onLand(g.bottomRight, 40)) {
      return false;
    }
    for (final b in blocks) {
      if (b.rect.overlaps(g)) return false;
    }
    for (final b in blobs) {
      if (_circleRect(b.center, b.radius * 0.6, g)) return false;
    }
    return true;
  }

  void _makeTowns() {
    // A few towns joined by dirt roads.
    const count = 5;
    for (var i = 0; i < count; i++) {
      final a = i * 2 * math.pi / count + rnd.nextDouble() * 0.6;
      final d = i == 0 ? 0.0 : island * (0.45 + rnd.nextDouble() * 0.2);
      towns.add(Offset(math.cos(a) * d, math.sin(a) * d));
    }
    for (var i = 1; i < towns.length; i++) {
      roads.add(_road(towns[0], towns[i]));
      roads.add(_road(towns[i], towns[i == towns.length - 1 ? 1 : i + 1]));
    }
    const colors = [
      0xFFB23A2E,
      0xFF2E5E8C,
      0xFF3F7A3A,
      0xFFC77B2A,
      0xFF7A7F84,
      0xFF8C3B5E
    ];
    for (final town in towns) {
      // Buildings.
      for (var n = 0; n < 6; n++) {
        for (var tries = 0; tries < 20; tries++) {
          final w = 140.0 + rnd.nextDouble() * 120;
          final h = 120.0 + rnd.nextDouble() * 110;
          final c = town +
              Offset(
                  rnd.nextDouble() * 560 - 280, rnd.nextDouble() * 560 - 280);
          final r = Rect.fromCenter(center: c, width: w, height: h);
          if (_free(r, 70)) {
            blocks.add(Block(
                r,
                BoxKind.building,
                [
                  0xFF9A9590,
                  0xFF8B8378,
                  0xFFA59E93,
                  0xFF7E8288
                ][rnd.nextInt(4)],
                1 + rnd.nextDouble()));
            break;
          }
        }
      }
      // Shipping containers.
      for (var n = 0; n < 5; n++) {
        for (var tries = 0; tries < 20; tries++) {
          final long = rnd.nextBool();
          final c = town +
              Offset(
                  rnd.nextDouble() * 700 - 350, rnd.nextDouble() * 700 - 350);
          final r = Rect.fromCenter(
              center: c, width: long ? 150 : 60, height: long ? 60 : 150);
          if (_free(r, 40)) {
            blocks.add(Block(
                r, BoxKind.container, colors[rnd.nextInt(colors.length)], 0.6));
            break;
          }
        }
      }
      // Crates.
      for (var n = 0; n < 8; n++) {
        for (var tries = 0; tries < 20; tries++) {
          final c = town +
              Offset(
                  rnd.nextDouble() * 800 - 400, rnd.nextDouble() * 800 - 400);
          final r = Rect.fromCenter(center: c, width: 44, height: 44);
          if (_free(r, 24)) {
            blocks.add(Block(r, BoxKind.crate, 0xFF9C7347, 0.35));
            break;
          }
        }
      }
    }
    // Low concrete walls out in the fields to hide behind.
    for (var n = 0; n < 26; n++) {
      for (var tries = 0; tries < 20; tries++) {
        final c = _randomLand(80);
        final long = rnd.nextBool();
        final r = Rect.fromCenter(
            center: c, width: long ? 120 : 26, height: long ? 26 : 120);
        if (_free(r, 50)) {
          blocks.add(Block(r, BoxKind.wall, 0xFFA8A49C, 0.3));
          break;
        }
      }
    }
  }

  List<Offset> _road(Offset a, Offset b) {
    final pts = <Offset>[];
    final bend =
        Offset(rnd.nextDouble() * 300 - 150, rnd.nextDouble() * 300 - 150);
    for (var i = 0; i <= 24; i++) {
      final t = i / 24;
      final mid = Offset.lerp(a, b, 0.5)! + bend;
      final p =
          Offset.lerp(Offset.lerp(a, mid, t)!, Offset.lerp(mid, b, t)!, t)!;
      pts.add(p);
    }
    return pts;
  }

  Offset _randomLand([double margin = 60]) {
    while (true) {
      final a = rnd.nextDouble() * 2 * math.pi;
      final d = math.sqrt(rnd.nextDouble()) * island;
      final p = Offset(math.cos(a) * d, math.sin(a) * d);
      if (onLand(p, margin)) return p;
    }
  }

  bool _nearRoad(Offset p, double gap) {
    for (final road in roads) {
      for (final q in road) {
        if ((q - p).distance < gap) return true;
      }
    }
    return false;
  }

  void _makeNature() {
    // Forests are clumps of trees.
    for (var clump = 0; clump < 22; clump++) {
      final c = _randomLand(150);
      if (towns.any((t) => (t - c).distance < 420)) continue;
      final n = 6 + rnd.nextInt(10);
      for (var i = 0; i < n; i++) {
        final p = c +
            Offset(rnd.nextDouble() * 360 - 180, rnd.nextDouble() * 360 - 180);
        final r = 46.0 + rnd.nextDouble() * 34;
        if (!onLand(p, 90) || _nearRoad(p, 60)) continue;
        if (blocks.any((b) => _circleRect(p, r * 0.5, b.rect))) continue;
        if (blobs.any((b) => (b.center - p).distance < (b.radius + r) * 0.6))
          continue;
        blobs.add(Blob(p, r, RoundKind.tree, rnd.nextInt(4)));
      }
    }
    for (var i = 0; i < 70; i++) {
      final p = _randomLand(80);
      final r = 22.0 + rnd.nextDouble() * 30;
      if (_nearRoad(p, 50) || blocks.any((b) => _circleRect(p, r + 20, b.rect)))
        continue;
      if (blobs.any((b) => (b.center - p).distance < b.radius + r)) continue;
      blobs.add(Blob(p, r, RoundKind.rock, rnd.nextInt(5)));
    }
    for (var i = 0; i < 90; i++) {
      final p = _randomLand(60);
      final r = 18.0 + rnd.nextDouble() * 14;
      if (blocks.any((b) => _circleRect(p, r, b.rect))) continue;
      blobs.add(Blob(p, r, RoundKind.bush, rnd.nextInt(3)));
    }
  }

  Offset _openSpot(Offset near, double spread) {
    for (var tries = 0; tries < 200; tries++) {
      final p = near +
          Offset(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1) * spread;
      if (onLand(p, 60) && !blocked(p, Fighter.radius + 6)) return p;
    }
    return _randomLand();
  }

  void _spawnFighters() {
    final names = [...botNames]..shuffle(rnd);
    var n = 0;
    String botName() => '${names[n++ % names.length]} (bot)';

    switch (mode) {
      case Mode.battleRoyale:
        final spots = <Offset>[];
        for (var i = 0; i < 8; i++) {
          final a = i * 2 * math.pi / 8 + rnd.nextDouble() * 0.4;
          spots.add(
              _openSpot(Offset(math.cos(a), math.sin(a)) * island * 0.55, 160));
        }
        spots.shuffle(rnd);
        player =
            Fighter(name: playerName, team: 0, pos: spots[0], isPlayer: true);
        fighters.add(player);
        for (var i = 1; i < 8; i++) {
          fighters.add(Fighter(name: botName(), team: i, pos: spots[i]));
        }
        for (final f in fighters) {
          f.give(Gun(WeaponType.pistol));
          f.ammo[Ammo.light] = 36;
        }
      case Mode.oneVsOne:
      case Mode.twoVsTwo:
        final a = rnd.nextDouble() * math.pi;
        final home = Offset(math.cos(a), math.sin(a)) * 520;
        final perTeam = mode == Mode.oneVsOne ? 1 : 2;
        player = Fighter(
            name: playerName,
            team: 0,
            pos: _openSpot(home, 80),
            isPlayer: true);
        fighters.add(player);
        for (var i = 1; i < perTeam; i++) {
          fighters.add(
              Fighter(name: botName(), team: 0, pos: _openSpot(home, 120)));
        }
        for (var i = 0; i < perTeam; i++) {
          fighters.add(
              Fighter(name: botName(), team: 1, pos: _openSpot(-home, 120)));
        }
        for (final f in fighters) {
          f.give(Gun(WeaponType.rifle));
          f.give(Gun(WeaponType.shotgun));
          f.ammo[Ammo.medium] = 90;
          f.ammo[Ammo.shells] = 18;
        }
    }
    for (final f in fighters) {
      if (!f.isPlayer) f.brain = BotBrain()..lastPos = f.pos;
      f.aim = (Offset.zero - f.pos).direction;
    }
  }

  void _scatterLoot() {
    final count = mode == Mode.battleRoyale ? 70 : 30;
    final spread = mode == Mode.battleRoyale ? island : 760.0;
    for (var i = 0; i < count; i++) {
      Offset p;
      // Most loot is in towns.
      if (rnd.nextDouble() < 0.6) {
        p = _openSpot(towns[rnd.nextInt(towns.length)], 380);
      } else {
        p = _openSpot(Offset.zero, spread * 0.85);
      }
      if (mode != Mode.battleRoyale && p.distance > 760) continue;
      pickups.add(_randomPickup(p));
    }
  }

  Pickup _randomPickup(Offset p) {
    final r = rnd.nextDouble();
    if (r < 0.40) {
      final w = <WeaponType>[
        WeaponType.rifle,
        WeaponType.rifle,
        WeaponType.shotgun,
        WeaponType.shotgun,
        WeaponType.pistol,
        WeaponType.sniper,
        WeaponType.rpg,
      ][rnd.nextInt(7)];
      return Pickup(PickupKind.weapon, p, weapon: w);
    }
    if (r < 0.62) {
      final a = Ammo.values[rnd.nextInt(Ammo.values.length)];
      final amount = switch (a) {
        Ammo.light => 24,
        Ammo.medium => 40,
        Ammo.shells => 10,
        Ammo.heavy => 6,
        Ammo.rockets => 2,
      };
      return Pickup(PickupKind.ammo, p, ammo: a, amount: amount);
    }
    if (r < 0.75) return Pickup(PickupKind.medkit, p);
    if (r < 0.87) return Pickup(PickupKind.shield, p);
    if (r < 0.94) return Pickup(PickupKind.jetpack, p);
    return Pickup(PickupKind.speed, p);
  }

  // ---------------------------------------------------------- geometry

  static bool _circleRect(Offset c, double r, Rect rect) {
    final x = c.dx.clamp(rect.left, rect.right);
    final y = c.dy.clamp(rect.top, rect.bottom);
    return (Offset(x, y) - c).distanceSquared < r * r;
  }

  /// Is a circle here stuck in something solid?
  bool blocked(Offset p, double r) {
    for (final b in blocks) {
      if (_circleRect(p, r, b.rect)) return true;
    }
    for (final b in blobs) {
      if (b.solid > 0 && (b.center - p).distance < b.solid + r) return true;
    }
    return false;
  }

  /// Pushes a circle out of anything solid.
  Offset _pushOut(Offset p, double r) {
    var q = p;
    for (final b in blocks) {
      if (!_circleRect(q, r, b.rect.inflate(0))) continue;
      final cx = q.dx.clamp(b.rect.left, b.rect.right);
      final cy = q.dy.clamp(b.rect.top, b.rect.bottom);
      final d = q - Offset(cx, cy);
      if (d.distance > 0.001) {
        q = Offset(cx, cy) + d / d.distance * r;
      } else {
        // Centre is inside: go out the nearest side.
        final left = q.dx - b.rect.left, right = b.rect.right - q.dx;
        final top = q.dy - b.rect.top, bottom = b.rect.bottom - q.dy;
        final m = [left, right, top, bottom].reduce(math.min);
        if (m == left) {
          q = Offset(b.rect.left - r, q.dy);
        } else if (m == right) {
          q = Offset(b.rect.right + r, q.dy);
        } else if (m == top) {
          q = Offset(q.dx, b.rect.top - r);
        } else {
          q = Offset(q.dx, b.rect.bottom + r);
        }
      }
    }
    for (final b in blobs) {
      if (b.solid <= 0) continue;
      final d = q - b.center;
      final min = b.solid + r;
      if (d.distance < min) {
        q = b.center +
            (d.distance > 0.001 ? d / d.distance : const Offset(1, 0)) * min;
      }
    }
    return q;
  }

  /// How far along a line (0..1) until it hits something solid, or null.
  double? _segmentHit(Offset a, Offset b) {
    double? best;
    final d = b - a;
    for (final blk in blocks) {
      final t = _segRect(a, d, blk.rect);
      if (t != null && (best == null || t < best)) best = t;
    }
    for (final blob in blobs) {
      if (blob.solid <= 0) continue;
      final t = _segCircle(a, d, blob.center, blob.solid);
      if (t != null && (best == null || t < best)) best = t;
    }
    return best;
  }

  static double? _segRect(Offset a, Offset d, Rect r) {
    var t0 = 0.0, t1 = 1.0;
    for (final (p, q) in [
      (-d.dx, a.dx - r.left),
      (d.dx, r.right - a.dx),
      (-d.dy, a.dy - r.top),
      (d.dy, r.bottom - a.dy),
    ]) {
      if (p == 0) {
        if (q < 0) return null;
      } else {
        final t = q / p;
        if (p < 0) {
          if (t > t1) return null;
          if (t > t0) t0 = t;
        } else {
          if (t < t0) return null;
          if (t < t1) t1 = t;
        }
      }
    }
    return t0;
  }

  static double? _segCircle(Offset a, Offset d, Offset c, double r) {
    final f = a - c;
    final aa = d.dx * d.dx + d.dy * d.dy;
    if (aa == 0) return null;
    final b = 2 * (f.dx * d.dx + f.dy * d.dy);
    final cc = f.dx * f.dx + f.dy * f.dy - r * r;
    final disc = b * b - 4 * aa * cc;
    if (disc < 0) return null;
    final s = math.sqrt(disc);
    final t = (-b - s) / (2 * aa);
    if (t >= 0 && t <= 1) return t;
    if (cc < 0) return 0;
    return null;
  }

  bool canSee(Offset a, Offset b) => _segmentHit(a, b) == null;

  // ------------------------------------------------------------ update

  void update(double dt, Controls c) {
    if (over) {
      _updateFx(dt);
      return;
    }
    dt = math.min(dt, 1 / 20);
    time += dt;
    _updateStorm(dt);
    if (player.alive) _updatePlayer(dt, c);
    for (final f in fighters) {
      if (f.alive && f.brain != null) _updateBot(f, dt);
    }
    for (final f in fighters) {
      if (!f.alive) continue;
      _move(f, dt);
      _tickTimers(f, dt);
      if (!onLand(f.pos, -10) && !f.flying) f.pos = _toShore(f.pos);
      if ((f.pos - stormCenter).distance > stormRadius) {
        _damage(f, stormDamage * dt, null, null);
      }
    }
    _updateBullets(dt);
    _updateRockets(dt);
    _updatePickups(dt);
    _updateFx(dt);
    _checkEnd();
  }

  Offset _toShore(Offset p) {
    final limit = coastRadius(p.direction, island) - 30;
    if (p.distance <= limit) return p;
    return Offset.fromDirection(p.direction, limit);
  }

  void _tickTimers(Fighter f, double dt) {
    f.cooldown = math.max(0, f.cooldown - dt);
    f.hurtFlash = math.max(0, f.hurtFlash - dt);
    f.recoil = math.max(0, f.recoil - dt * 6);
    f.speedBoost = math.max(0, f.speedBoost - dt);
    if (f.reloading > 0) {
      f.reloading -= dt;
      if (f.reloading <= 0) _finishReload(f);
    }
    if (f.hasJetpack && f.altitude == 0)
      f.fuel = math.min(100, f.fuel + dt * 6);
  }

  void _updatePlayer(double dt, Controls c) {
    final f = player;
    var m = c.move;
    if (m.distance > 1) m = m / m.distance;
    final speed = 230.0 * (f.speedBoost > 0 ? 1.45 : 1) * (f.flying ? 1.25 : 1);
    f.vel = m * speed;
    f.aim = c.aim;

    // Jetpack.
    if (f.hasJetpack && c.jet && f.fuel > 0) {
      f.altitude = math.min(1, f.altitude + dt * 2.5);
      f.fuel = math.max(0, f.fuel - dt * 18);
      if (rnd.nextDouble() < 0.5) {
        fx.add(Fx(
            FxKind.smoke, f.pos + Offset(rnd.nextDouble() * 10 - 5, 10), 0.6,
            size: 8, vel: Offset(rnd.nextDouble() * 20 - 10, 30)));
      }
    } else {
      f.altitude =
          math.max(0, f.altitude - dt * (onLand(f.pos, -10) ? 1.6 : 0.4));
    }

    if (c.swapTo != null &&
        f.slots[c.swapTo!] != null &&
        c.swapTo != f.current) {
      f.current = c.swapTo!;
      f.reloading = 0;
    }
    if (c.nextWeapon) {
      for (var i = 1; i <= 5; i++) {
        final s = (f.current + i) % 5;
        if (f.slots[s] != null) {
          f.current = s;
          f.reloading = 0;
          break;
        }
      }
    }
    if (c.reload) _startReload(f);
    if (c.fire) _tryFire(f);

    nearPickup = null;
    for (final p in pickups) {
      if ((p.pos - f.pos).distance < 42 && p.kind == PickupKind.weapon) {
        nearPickup = p;
        break;
      }
    }
    if (c.pickup && nearPickup != null) {
      _takeWeapon(f, nearPickup!, swap: true);
    }
    c.swapTo = null;
    c.nextWeapon = false;
    c.reload = false;
    c.pickup = false;
  }

  void _move(Fighter f, double dt) {
    final before = f.pos;
    var p = f.pos + f.vel * dt;
    if (!f.flying) p = _pushOut(p, Fighter.radius);
    // Keep inside the world.
    if (p.distance > island * 1.3)
      p = Offset.fromDirection(p.direction, island * 1.3);
    f.pos = p;
    final moved = (f.pos - before).distance;
    f.walk += moved * 0.06;
  }

  // ------------------------------------------------------------ guns

  void _startReload(Fighter f) {
    final g = f.gun;
    if (g == null || f.reloading > 0) return;
    if (g.mag >= g.spec.mag || f.ammo[g.spec.ammo]! <= 0) return;
    f.reloading = g.spec.reload;
    if (f.isPlayer) events.add(GameEvent(EventKind.reload));
  }

  void _finishReload(Fighter f) {
    final g = f.gun;
    f.reloading = 0;
    if (g == null) return;
    final need = g.spec.mag - g.mag;
    final take = math.min(need, f.ammo[g.spec.ammo]!);
    g.mag += take;
    f.ammo[g.spec.ammo] = f.ammo[g.spec.ammo]! - take;
  }

  Offset muzzle(Fighter f) {
    final g = f.gun;
    final len = (g?.spec.length ?? 16) + 14;
    return f.pos +
        Offset.fromDirection(f.aim, len) +
        Offset.fromDirection(f.aim + math.pi / 2, 6);
  }

  bool _tryFire(Fighter f) {
    final g = f.gun;
    if (g == null || f.cooldown > 0 || f.reloading > 0) return false;
    if (g.mag <= 0) {
      if (f.ammo[g.spec.ammo]! > 0) {
        _startReload(f);
      } else if (f.isPlayer) {
        f.cooldown = 0.3;
        events.add(GameEvent(EventKind.empty));
      }
      return false;
    }
    final s = g.spec;
    g.mag--;
    f.cooldown = 1 / s.fireRate;
    f.recoil = 1;
    final from = muzzle(f);
    // Don't shoot through a wall you're pressed against.
    if (_segmentHit(f.pos, from) != null) {
      fx.add(Fx(FxKind.spark,
          f.pos + Offset.fromDirection(f.aim, Fighter.radius + 4), 0.2));
    } else if (g.type == WeaponType.rpg) {
      rockets.add(Rocket(
          from, Offset.fromDirection(f.aim + _wobble(s.spread), s.speed), f));
    } else {
      for (var i = 0; i < s.pellets; i++) {
        final a = f.aim + _wobble(s.spread) * (f.vel.distance > 10 ? 1.3 : 1);
        final dmg = s.damage * (0.9 + rnd.nextDouble() * 0.2);
        bullets.add(Bullet(
            from,
            Offset.fromDirection(a, s.speed * (0.92 + rnd.nextDouble() * 0.16)),
            f,
            g.type,
            dmg,
            s.range)
          ..start = from);
      }
    }
    fx.add(Fx(FxKind.flash, from, 0.06,
        angle: f.aim, size: g.type == WeaponType.sniper ? 22 : 14));
    events.add(GameEvent(EventKind.shot,
        weapon: g.type, distance: (from - watching.pos).distance));
    if (g.mag == 0 && f.ammo[s.ammo]! > 0) _startReload(f);
    return true;
  }

  double _wobble(double spread) => (rnd.nextDouble() - 0.5) * 2 * spread;

  void _updateBullets(double dt) {
    for (final b in [...bullets]) {
      final step = b.vel * dt;
      final next = b.pos + step;
      // Walls first, then people.
      final wall = _segmentHit(b.pos, next);
      double hitT = wall ?? 2;
      Fighter? victim;
      for (final f in fighters) {
        if (!f.alive || f == b.owner) continue;
        if (f.team == b.owner.team && f != b.owner) continue;
        final t = _segCircle(b.pos, step, f.pos, Fighter.radius + 2);
        if (t != null && t < hitT) {
          hitT = t;
          victim = f;
        }
      }
      if (hitT <= 1) {
        final at = b.pos + step * hitT;
        bullets.remove(b);
        if (victim != null) {
          final dist = (at - b.start).distance;
          // Shotguns and pistols get weaker far away.
          final falloff = b.type == WeaponType.shotgun
              ? (1.25 - dist / 300).clamp(0.3, 1.0)
              : b.type == WeaponType.pistol
                  ? (1.15 - dist / 900).clamp(0.6, 1.0)
                  : 1.0;
          _damage(victim, b.damage * falloff, b.owner, b.type);
          for (var i = 0; i < 4; i++) {
            fx.add(Fx(FxKind.spark, at, 0.25,
                vel: Offset.fromDirection(
                    b.vel.direction + math.pi + _wobble(0.9),
                    160 + rnd.nextDouble() * 120),
                size: 3));
          }
        } else {
          fx.add(Fx(FxKind.dust, at, 0.45,
              size: 7,
              vel: Offset.fromDirection(b.vel.direction + math.pi, 30)));
          fx.add(Fx(FxKind.spark, at, 0.15, size: 3));
        }
        continue;
      }
      b.pos = next;
      b.range -= step.distance;
      if (b.range <= 0) {
        bullets.remove(b);
        fx.add(Fx(onLand(b.pos) ? FxKind.dust : FxKind.splash, b.pos, 0.4,
            size: 6));
      }
    }
  }

  void _updateRockets(double dt) {
    for (final r in [...rockets]) {
      final step = r.vel * dt;
      final next = r.pos + step;
      r.life -= dt;
      var t = _segmentHit(r.pos, next);
      for (final f in fighters) {
        if (!f.alive || f == r.owner || f.team == r.owner.team) continue;
        final ft = _segCircle(r.pos, step, f.pos, Fighter.radius + 4);
        if (ft != null && (t == null || ft < t)) t = ft;
      }
      if (rnd.nextDouble() < 0.9) {
        fx.add(Fx(FxKind.smoke, r.pos, 0.9,
            size: 9 + rnd.nextDouble() * 5,
            vel: Offset(
                rnd.nextDouble() * 30 - 15, rnd.nextDouble() * 30 - 15)));
      }
      if (t != null || r.life <= 0) {
        rockets.remove(r);
        _explode(t != null ? r.pos + step * t : r.pos, r.owner);
      } else {
        r.pos = next;
      }
    }
  }

  void _explode(Offset at, Fighter owner) {
    const radius = 150.0;
    fx.add(Fx(FxKind.explosion, at, 0.7, size: radius));
    scorches
        .add(Fx(FxKind.scorch, at, 30, size: 60, angle: rnd.nextDouble() * 6));
    if (scorches.length > 30) scorches.removeAt(0);
    for (var i = 0; i < 14; i++) {
      fx.add(Fx(FxKind.smoke, at, 1.4 + rnd.nextDouble(),
          size: 20 + rnd.nextDouble() * 20,
          vel: Offset.fromDirection(
              rnd.nextDouble() * 6.3, 40 + rnd.nextDouble() * 80)));
    }
    for (var i = 0; i < 16; i++) {
      fx.add(Fx(FxKind.spark, at, 0.4,
          size: 4,
          vel: Offset.fromDirection(
              rnd.nextDouble() * 6.3, 200 + rnd.nextDouble() * 300)));
    }
    events.add(
        GameEvent(EventKind.explosion, distance: (at - watching.pos).distance));
    for (final f in fighters) {
      if (!f.alive) continue;
      if (f.team == owner.team && f != owner) continue;
      final d = (f.pos - at).distance;
      if (d > radius) continue;
      if (_segmentHit(at, f.pos) != null && d > 50) continue;
      final dmg = weapons[WeaponType.rpg]!.damage *
          (1 - d / radius * 0.7) *
          (f == owner ? 0.5 : 1);
      _damage(f, dmg, owner, WeaponType.rpg);
      f.pos = _pushOut(f.pos + Offset.fromDirection((f.pos - at).direction, 30),
          Fighter.radius);
    }
  }

  void _damage(Fighter f, double amount, Fighter? by, WeaponType? weapon) {
    if (!f.alive || amount <= 0) return;
    var left = amount;
    if (f.shield > 0) {
      final s = math.min(f.shield, left);
      f.shield -= s;
      left -= s;
    }
    f.health -= left;
    if (by != null) f.hurtFlash = 0.25;
    if (f.isPlayer && by != null) events.add(GameEvent(EventKind.playerHit));
    if (by != null && by.isPlayer && f != by)
      events.add(GameEvent(EventKind.hit, text: amount.round().toString()));
    if (by != null && f.brain != null && by != f) {
      // Bots turn to face whoever is shooting them.
      f.brain!.target ??= by;
      f.brain!.lastSeen = by.pos;
    }
    if (f.health <= 0) _eliminate(f, by, weapon);
  }

  void _eliminate(Fighter f, Fighter? by, WeaponType? weapon) {
    f.alive = false;
    f.health = 0;
    f.placed = aliveCount + 1;
    final how = weapon == null ? 'the storm' : weapons[weapon]!.name;
    final msg = by == null || by == f
        ? (weapon == null
            ? '${f.name} was caught in the storm'
            : '${f.name} blew themselves up')
        : '${by.name} knocked out ${f.name} with $how';
    feed.insert(0, KillMessage(msg, by?.isPlayer ?? false));
    if (feed.length > 5) feed.removeLast();
    if (by != null && by != f) by.kills++;
    events.add(GameEvent(EventKind.kill, text: msg));
    // Drop their stuff.
    var i = 0;
    for (final g in f.slots) {
      if (g == null) continue;
      pickups.add(Pickup(
          PickupKind.weapon, f.pos + Offset.fromDirection(i * 1.7, 30),
          weapon: g.type));
      i++;
    }
    for (final a in Ammo.values) {
      if (f.ammo[a]! > 0) {
        pickups.add(Pickup(
            PickupKind.ammo, f.pos + Offset.fromDirection(i * 1.7, 34),
            ammo: a, amount: f.ammo[a]!));
        i++;
      }
    }
    for (var k = 0; k < 10; k++) {
      fx.add(Fx(FxKind.smoke, f.pos, 0.8,
          size: 10, vel: Offset.fromDirection(rnd.nextDouble() * 6.3, 60)));
    }
  }

  // ---------------------------------------------------------- pickups

  void _updatePickups(double dt) {
    for (final p in [...pickups]) {
      p.age += dt;
      for (final f in fighters) {
        if (!f.alive || (p.pos - f.pos).distance > 34) continue;
        if (_autoTake(f, p)) break;
      }
    }
  }

  /// Picks things up by walking over them. Weapons only if there's room.
  bool _autoTake(Fighter f, Pickup p) {
    switch (p.kind) {
      case PickupKind.weapon:
        final has = f.slots.any((s) => s?.type == p.weapon);
        final room = f.slots.contains(null);
        if (f.isPlayer) {
          if (!has && !room) return false;
        } else {
          // Bots only take upgrades.
          final best = f.slots
              .whereType<Gun>()
              .map((g) => _gunScore(g.type))
              .fold(-1, math.max);
          if (!has && !room) return false;
          if (!has &&
              _gunScore(p.weapon!) < best &&
              f.slots.whereType<Gun>().length >= 2) return false;
        }
        _takeWeapon(f, p);
        return true;
      case PickupKind.ammo:
        f.ammo[p.ammo!] = f.ammo[p.ammo!]! + p.amount;
      case PickupKind.medkit:
        if (f.health >= 100) return false;
        f.health = math.min(100, f.health + 50);
      case PickupKind.shield:
        if (f.shield >= 100) return false;
        f.shield = math.min(100, f.shield + 50);
      case PickupKind.jetpack:
        if (f.hasJetpack && f.fuel >= 99) return false;
        f.hasJetpack = true;
        f.fuel = 100;
      case PickupKind.speed:
        f.speedBoost = 20;
    }
    pickups.remove(p);
    if (f.isPlayer) events.add(GameEvent(EventKind.pickup, text: p.label));
    return true;
  }

  void _takeWeapon(Fighter f, Pickup p, {bool swap = false}) {
    final g = Gun(p.weapon!);
    final has = f.slots.indexWhere((s) => s?.type == g.type);
    if (has < 0 && !f.slots.contains(null) && swap) {
      // Drop what you're holding.
      final old = f.slots[f.current]!;
      pickups.add(Pickup(PickupKind.weapon, f.pos + const Offset(0, 30),
          weapon: old.type));
    }
    f.give(g);
    if (has < 0) f.current = f.slots.indexWhere((s) => s?.type == g.type);
    // A new gun comes with a little ammo.
    f.ammo[g.spec.ammo] = f.ammo[g.spec.ammo]! + g.spec.mag;
    pickups.remove(p);
    if (f.isPlayer) events.add(GameEvent(EventKind.pickup, text: g.spec.name));
  }

  // -------------------------------------------------------------- bots

  ({double error, double reaction, double fireMul, double sight}) get _skill =>
      switch (difficulty) {
        Difficulty.easy => (
            error: 0.20,
            reaction: 0.9,
            fireMul: 0.55,
            sight: 700
          ),
        Difficulty.normal => (
            error: 0.11,
            reaction: 0.55,
            fireMul: 0.75,
            sight: 900
          ),
        Difficulty.hard => (
            error: 0.05,
            reaction: 0.3,
            fireMul: 0.95,
            sight: 1100
          ),
      };

  void _updateBot(Fighter f, double dt) {
    final b = f.brain!;
    final skill = _skill;
    b.think -= dt;
    if (b.think <= 0) {
      b.think = 0.25 + rnd.nextDouble() * 0.1;
      _botLook(f, b, skill.sight);
    }

    final g = f.gun;
    final target = b.target;
    var move = Offset.zero;
    final inStorm = (f.pos - stormCenter).distance > stormRadius - 60;

    // Use the best gun for the distance.
    if (target != null && f.reloading <= 0) {
      final d = (target.pos - f.pos).distance;
      int? pick;
      var bestScore = -1.0;
      for (var i = 0; i < 5; i++) {
        final s = f.slots[i];
        if (s == null || (s.mag == 0 && f.ammo[s.spec.ammo] == 0)) continue;
        final score = switch (s.type) {
          WeaponType.shotgun => d < 260 ? 5.0 : 0.5,
          WeaponType.rifle => 3.0,
          WeaponType.sniper => d > 500 ? 4.5 : 1.0,
          WeaponType.rpg => d > 200 && d < 900 ? 3.5 : 0.2,
          WeaponType.pistol => 1.5,
        };
        if (score > bestScore) {
          bestScore = score;
          pick = i;
        }
      }
      if (pick != null) f.current = pick;
    }

    if (target != null && target.alive && b.sawFor > 0) {
      final toT = target.pos - f.pos;
      final dist = toT.distance;
      final want = switch (g?.type) {
        WeaponType.shotgun => 140.0,
        WeaponType.sniper => 700.0,
        WeaponType.rpg => 450.0,
        WeaponType.pistol => 280.0,
        _ => 380.0,
      };
      final dir = toT / math.max(dist, 1);
      if (dist > want + 80) move += dir;
      if (dist < want - 80) move -= dir;
      b.strafeTimer -= dt;
      if (b.strafeTimer <= 0) {
        b.strafeTimer = 0.6 + rnd.nextDouble() * 1.4;
        b.strafe = rnd.nextBool() ? 1 : -1;
      }
      move += Offset(-dir.dy, dir.dx) * b.strafe * 0.8;
      if (inStorm)
        move += (stormCenter - f.pos) / (stormCenter - f.pos).distance;

      // Aim, with some wobble so they can miss.
      b.aimWobble += (rnd.nextDouble() - 0.5) * dt * 3;
      b.aimWobble = b.aimWobble.clamp(-skill.error, skill.error);
      final lead = target.vel * (dist / (g?.spec.speed ?? 2000)) * 0.6;
      f.aim = (target.pos + lead - f.pos).direction + b.aimWobble;
      b.sawFor += dt;
      if (b.sawFor > skill.reaction &&
          g != null &&
          dist < g.spec.range * 0.95) {
        if (rnd.nextDouble() < skill.fireMul || !g.spec.auto) {
          if (f.cooldown <= 0 &&
              rnd.nextDouble() < skill.fireMul * (g.spec.auto ? 1 : 0.5))
            _tryFire(f);
        }
      }
      if (g != null && g.mag == 0) _startReload(f);
    } else {
      b.sawFor = 0;
      if (g != null && g.mag < g.spec.mag * 0.5) _startReload(f);
      // Go where we last saw someone, else look for loot, else wander.
      if (b.goal == null || (b.goal! - f.pos).distance < 40) {
        b.goal = b.lastSeen;
        b.lastSeen = null;
        if (b.goal == null) {
          Pickup? best;
          var bestD = 600.0;
          for (final p in pickups) {
            final d = (p.pos - f.pos).distance;
            if (d < bestD && (p.pos - stormCenter).distance < stormRadius) {
              bestD = d;
              best = p;
            }
          }
          b.goal = best?.pos ?? _goalInStorm();
        }
      }
      if (inStorm && (b.goal! - stormCenter).distance > stormRadius * 0.8) {
        b.goal = _goalInStorm(inner: true);
      }
      final toGoal = b.goal! - f.pos;
      if (toGoal.distance > 1) move += toGoal / toGoal.distance;
      if (toGoal.distance > 2) f.aim = toGoal.direction;
    }

    // Unstick.
    b.stuckTimer += dt;
    if (b.stuckTimer > 0.8) {
      if ((f.pos - b.lastPos).distance < 25 && move.distance > 0.1) {
        b.goal = _openSpot(f.pos, 300);
        b.strafe = -b.strafe;
      }
      b.lastPos = f.pos;
      b.stuckTimer = 0;
    }
    if (move.distance > 1) move = move / move.distance;
    f.vel = move * 205 * (f.speedBoost > 0 ? 1.4 : 1);
  }

  Offset _goalInStorm({bool inner = false}) {
    final r = math.min(stormRadius, _stormTo + (stormRadius - _stormTo) * 0.3) *
        (inner ? 0.5 : 0.85);
    for (var tries = 0; tries < 30; tries++) {
      final p = stormCenter +
          Offset.fromDirection(rnd.nextDouble() * 6.3, rnd.nextDouble() * r);
      if (onLand(p, 60) && !blocked(p, Fighter.radius + 4)) return p;
    }
    return stormCenter;
  }

  void _botLook(Fighter f, BotBrain b, double sight) {
    Fighter? best;
    var bestD = sight * (f.gun?.type == WeaponType.sniper ? 1.4 : 1);
    for (final o in fighters) {
      if (!o.alive || o.team == f.team) continue;
      final d = (o.pos - f.pos).distance;
      if (d > bestD) continue;
      if (!canSee(f.pos, o.pos)) continue;
      best = o;
      bestD = d;
    }
    if (best != null) {
      if (b.target != best) b.sawFor = 0.0001;
      b.target = best;
      b.lastSeen = best.pos;
      b.goal = null;
    } else {
      if (b.target != null) b.goal = b.lastSeen;
      b.target = null;
      b.sawFor = 0;
    }
  }

  // ------------------------------------------------------------ storm

  static const _stormSteps = [1.0, 0.62, 0.38, 0.2, 0.08, 0.0];

  void _updateStorm(double dt) {
    stormTimer -= dt;
    if (stormMoving) {
      final total = mode == Mode.battleRoyale ? 30.0 : 20.0;
      final t = (1 - stormTimer / total).clamp(0.0, 1.0);
      stormRadius = _stormFrom + (_stormTo - _stormFrom) * t;
      if (stormTimer <= 0) {
        stormMoving = false;
        stormRadius = _stormTo;
        stormTimer = mode == Mode.battleRoyale ? 40 : 25;
      }
    } else if (stormTimer <= 0 && stormPhase < _stormSteps.length - 1) {
      stormPhase++;
      final full = mode == Mode.battleRoyale ? island * 1.15 : 820.0;
      _stormFrom = stormRadius;
      _stormTo = full * _stormSteps[stormPhase];
      stormMoving = true;
      stormTimer = mode == Mode.battleRoyale ? 30 : 20;
    }
  }

  // -------------------------------------------------------------- fx

  void _updateFx(double dt) {
    for (final e in [...fx]) {
      e.age += dt;
      e.pos += e.vel * dt;
      e.vel = e.vel * math.pow(0.2, dt).toDouble();
      if (e.age >= e.life) fx.remove(e);
    }
    for (final k in feed) {
      k.age += dt;
    }
  }

  // -------------------------------------------------------------- end

  void _checkEnd() {
    final teams = {
      for (final f in fighters)
        if (f.alive) f.team
    };
    if (!teams.contains(player.team)) {
      over = true;
      won = false;
      player.placed = player.placed == 0 ? teams.length + 1 : player.placed;
    } else if (teams.length == 1) {
      over = true;
      won = true;
      player.placed = 1;
    }
  }
}
