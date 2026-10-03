import 'dart:math' as math;
import 'dart:ui';

import 'planets.dart';

enum Phase { setup, countdown, flight, space, surface, ouch, gameOver, win }

class Asteroid {
  Asteroid(this.position, this.radius, this.spin);
  final Offset position;
  final double radius;
  final double spin;
}

/// Which directions are being held down (keyboard or on-screen buttons).
class Controls {
  bool left = false;
  bool right = false;
  bool up = false;
  bool down = false;
}

/// All the game rules live here. The screen just draws whatever this says.
class SpaceGameModel {
  SpaceGameModel() {
    _makeAsteroids();
    reset();
  }

  static const countdownSeconds = 5.0;
  static const liftoffSeconds = 2.0;

  /// The trip to space really takes 50 seconds, but the clock says 5 minutes.
  static const flightSeconds = 50.0;

  static const surfaceWidth = 2400.0;
  static const jumpSpeed = 420.0;
  static const rocketParkX = 200.0;
  static const landmarkX = 1050.0;
  static const itemXs = <double>[650, 1450, 2050];

  static const worldLeft = -700.0;
  static const worldRight = 6700.0;
  static const worldTop = -1100.0;
  static const worldBottom = 1100.0;

  static const checklist = <String>[
    '⛽  Fill up the fuel tanks',
    '💨  Load the oxygen',
    '🍕  Pack the space snacks',
    '👩‍🚀  Put on your space suit',
    '🔧  Check the engines',
    '🚪  Close the hatch',
  ];

  static const checklistMessages = <String>[
    'Glug glug glug... fuel tanks full! ⛽',
    'Oxygen loaded - now you can breathe in space! 💨',
    'Snacks packed. Space pizza! 🍕',
    'Space suit on. Looking good, astronaut! 👩‍🚀',
    'Engines checked - they go VROOOM! 🔧',
    'Hatch closed and locked. 🚪',
  ];

  Phase phase = Phase.setup;

  /// The last "world" we were in, so the right background shows behind pop-ups.
  Phase scenePhase = Phase.space;
  double time = 0;

  // Launch pad
  final Set<int> checklistDone = {};
  double countdown = countdownSeconds;
  double liftoff = 0;

  // Flight up to space
  double flightTime = 0;
  double flightRocketX = 0;

  // Staying alive
  double health = 100;
  double temperature = 0; // -1 = freezing, 0 = comfy, 1 = boiling
  String status = '';
  bool danger = false;
  String deathReason = '';
  final Set<String> visited = {};

  // Flying around space
  Offset rocketPos = Offset.zero;
  Offset rocketVel = Offset.zero;
  double rocketAngle = 0;
  bool thrusting = false;
  double invulnerable = 0;
  double shake = 0;
  Planet? nearPlanet;
  final List<Asteroid> asteroids = [];

  // Pop-up message
  String message = '';
  double messageTime = 0;

  // "Get me off of here!" planets
  Planet? ouchPlanet;
  double ouchTime = 0;
  static const ouchSeconds = 3.2;

  // Walking around on a planet
  Planet? surfacePlanet;
  double astroX = 0;
  double astroY = 0; // height above the ground
  double astroVy = 0;
  bool facingRight = true;
  bool walking = false;
  double walkPhase = 0;
  final Set<int> collected = {};

  bool get readyToLaunch => checklistDone.length == checklist.length;

  int get placesToVisit =>
      planets.where((p) => p.landing != LandingType.home).length;

  SurfaceInfo? get surface {
    final p = surfacePlanet;
    return p == null ? null : surfaces[p.name];
  }

  /// "5:00" counting down really fast.
  String get flightClock {
    final s = ((flightSeconds - flightTime) * 6).clamp(0.0, 300.0).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  String get flightFact {
    if (flightTime < 8) return 'Lift off! Zooming up through the clouds...';
    if (flightTime < 18) {
      return 'The sky is going dark - you are leaving the air behind!';
    }
    if (flightTime < 30) return 'Wave to the space station! 👋';
    if (flightTime < 42) return 'Look how tiny Earth is getting!';
    return 'Almost in space... get ready to fly!';
  }

  static double itemHeight(int i, SurfaceInfo info) {
    if (i != 1) return 20;
    final maxJump = jumpSpeed * jumpSpeed / (2 * info.gravity);
    return maxJump * 0.7;
  }

  void reset() {
    phase = Phase.setup;
    scenePhase = Phase.space;
    checklistDone.clear();
    countdown = countdownSeconds;
    liftoff = 0;
    flightTime = 0;
    flightRocketX = 0;
    health = 100;
    temperature = 0;
    status = '';
    danger = false;
    deathReason = '';
    visited.clear();
    rocketPos = Offset.zero;
    rocketVel = Offset.zero;
    rocketAngle = 0;
    thrusting = false;
    invulnerable = 0;
    shake = 0;
    nearPlanet = null;
    message = '';
    messageTime = 0;
    ouchPlanet = null;
    ouchTime = 0;
    surfacePlanet = null;
    collected.clear();
  }

  void _makeAsteroids() {
    final r = math.Random(7);
    for (var i = 0; i < 70; i++) {
      asteroids.add(Asteroid(
        Offset(2400 + r.nextDouble() * 350, -1000 + r.nextDouble() * 2000),
        10 + r.nextDouble() * 22,
        r.nextDouble() * 2 - 1,
      ));
    }
  }

  void _say(String text, double seconds) {
    message = text;
    messageTime = seconds;
  }

  void _hurt(double amount, String reason) {
    if (phase == Phase.gameOver || phase == Phase.win) return;
    health -= amount;
    if (health <= 0 && deathReason.isEmpty) deathReason = reason;
  }

  // ---------------------------------------------------------------- input

  void tickChecklist(int i) {
    if (phase != Phase.setup) return;
    if (checklistDone.add(i)) _say(checklistMessages[i], 2.5);
  }

  void launch() {
    if (phase != Phase.setup || !readyToLaunch) return;
    phase = Phase.countdown;
    countdown = countdownSeconds;
    liftoff = 0;
    messageTime = 0;
  }

  void pressEnter() {
    switch (phase) {
      case Phase.setup:
        launch();
      case Phase.space:
        final p = nearPlanet;
        if (p != null) land(p);
      case Phase.surface:
        takeOff();
      case Phase.gameOver:
      case Phase.win:
        reset();
      default:
        break;
    }
  }

  void land(Planet p) {
    if (phase != Phase.space) return;
    switch (p.landing) {
      case LandingType.home:
        health = 100;
        _say('Home sweet home! 🌍 You are all fixed up - full health again!', 4);
      case LandingType.walk:
        visited.add(p.name);
        _startSurface(p);
      case LandingType.tooHot:
      case LandingType.gas:
        visited.add(p.name);
        phase = Phase.ouch;
        ouchPlanet = p;
        ouchTime = 0;
        shake = 0.6;
        if (p.landingDamage > 0) _hurt(p.landingDamage, p.deathReason);
    }
  }

  void takeOff() {
    final p = surfacePlanet;
    if (phase != Phase.surface || p == null) return;
    _leavePlanet(p, 'Blast off! 🚀 Off to explore more of space!');
  }

  // --------------------------------------------------------------- update

  void update(double dt, Controls c) {
    time += dt;
    if (messageTime > 0) messageTime -= dt;
    if (shake > 0) shake = math.max(0.0, shake - dt);
    if (invulnerable > 0) invulnerable -= dt;

    switch (phase) {
      case Phase.countdown:
        _updateCountdown(dt);
      case Phase.flight:
        _updateFlight(dt, c);
      case Phase.space:
        _updateSpace(dt, c);
      case Phase.surface:
        _updateSurface(dt, c);
      case Phase.ouch:
        _updateOuch(dt);
      default:
        break;
    }

    if (phase == Phase.space || phase == Phase.surface) scenePhase = phase;

    if (health <= 0 &&
        (phase == Phase.space ||
            phase == Phase.surface ||
            phase == Phase.ouch)) {
      health = 0;
      phase = Phase.gameOver;
    }
  }

  void _updateCountdown(double dt) {
    if (countdown > 0) {
      countdown = math.max(0.0, countdown - dt);
      return;
    }
    liftoff += dt;
    if (liftoff >= liftoffSeconds) {
      phase = Phase.flight;
      flightTime = 0;
      flightRocketX = 0;
    }
  }

  void _updateFlight(double dt, Controls c) {
    flightTime += dt;
    var dir = 0.0;
    if (c.left) dir -= 1;
    if (c.right) dir += 1;
    flightRocketX = (flightRocketX + dir * dt * 1.5).clamp(-1.0, 1.0);
    if (flightTime >= flightSeconds) {
      phase = Phase.space;
      rocketPos = const Offset(1570, 50);
      rocketVel = const Offset(60, 0);
      rocketAngle = 0;
      _say(
          'You made it to space! 🚀 Use the arrow keys to fly. The Moon is just up ahead!',
          6);
    }
  }

  void _updateSpace(double dt, Controls c) {
    var ax = 0.0, ay = 0.0;
    if (c.left) ax -= 1;
    if (c.right) ax += 1;
    if (c.up) ay -= 1;
    if (c.down) ay += 1;
    thrusting = ax != 0 || ay != 0;

    const accel = 650.0, maxSpeed = 430.0;
    var v = rocketVel + Offset(ax, ay) * (accel * dt);
    if (!thrusting) v = v * math.pow(0.6, dt).toDouble();
    if (v.distance > maxSpeed) v = v / v.distance * maxSpeed;
    var p = rocketPos + v * dt;
    if (p.dx < worldLeft || p.dx > worldRight) {
      v = Offset(0, v.dy);
      p = Offset(p.dx.clamp(worldLeft, worldRight), p.dy);
    }
    if (p.dy < worldTop || p.dy > worldBottom) {
      v = Offset(v.dx, 0);
      p = Offset(p.dx, p.dy.clamp(worldTop, worldBottom));
    }
    rocketVel = v;
    rocketPos = p;
    if (v.distance > 20) rocketAngle = math.atan2(v.dy, v.dx);

    // Hot near the Sun, cold far away.
    final d = rocketPos.distance;
    final hot = ((1000 - d) / 800).clamp(0.0, 1.0);
    final cold = ((d - 2600) / 4000).clamp(0.0, 1.0);
    temperature = hot - cold;

    var s = 'Feeling great! 😊';
    var bad = false;
    if (hot > 0.25) {
      _hurt((hot - 0.25) * 80 * dt,
          'You got way too close to the Sun and got too hot! 🔥');
      s = hot > 0.55
          ? "You're getting REALLY HOT! 🔥 Fly away from the Sun!"
          : "You're getting hot... 🥵";
      bad = true;
    } else if (hot > 0.05) {
      s = "It's getting warm in here...";
    }
    if (cold > 0.3) {
      _hurt((cold - 0.3) * 5 * dt,
          'You froze in the far, far cold of space! 🥶');
      s = cold > 0.6 ? "Brrr! You're FREEZING! 🥶" : "You're getting cold... 🥶";
      bad = true;
    } else if (cold > 0.1) {
      s = "It's getting chilly out here...";
    }

    final jupiter = planetNamed('Jupiter');
    if ((rocketPos - jupiter.position).distance < 450) {
      _hurt(4 * dt, "Jupiter's radiation made you too sick! 🤢");
      s = "Jupiter's radiation is making you feel sick! 🤢";
      bad = true;
    }

    if (!bad && hot <= 0.05 && cold <= 0.1) {
      health = math.min(100.0, health + 2 * dt);
    }

    if (d < sunRadius + 12) {
      _hurt(1000, 'You flew right into the Sun! ☀️🔥');
    }

    if (invulnerable <= 0) {
      for (final a in asteroids) {
        final diff = rocketPos - a.position;
        if (diff.distance < a.radius + 14) {
          _hurt(15, 'Crashing into asteroids injured you too badly! 🤕');
          _say('CRASH! You hit an asteroid and got hurt! 🤕', 2.5);
          final n =
              diff.distance == 0 ? const Offset(-1, 0) : diff / diff.distance;
          rocketVel = n * 260;
          invulnerable = 1.2;
          shake = 0.4;
          break;
        }
      }
    }
    if (invulnerable > 0) {
      s = "You're injured! Watch out for asteroids! 🤕";
      bad = true;
    }

    status = s;
    danger = bad;

    nearPlanet = null;
    for (final planet in planets) {
      if ((rocketPos - planet.position).distance < planet.radius + 55) {
        nearPlanet = planet;
        break;
      }
    }

    if (visited.length >= placesToVisit && health > 0) phase = Phase.win;
  }

  void _startSurface(Planet p) {
    phase = Phase.surface;
    surfacePlanet = p;
    astroX = rocketParkX + 120;
    astroY = 0;
    astroVy = 0;
    facingRight = true;
    walking = false;
    collected.clear();
    _say(
        'You climbed out onto ${p.title}! 👩‍🚀 Use the arrow keys to explore. Press ENTER to blast off again.',
        5);
  }

  void _updateSurface(double dt, Controls c) {
    final info = surface;
    if (info == null) return;

    var dir = 0.0;
    if (c.left) dir -= 1;
    if (c.right) dir += 1;
    walking = dir != 0;
    if (walking) {
      facingRight = dir > 0;
      walkPhase += dt * 10;
    }
    astroX = (astroX + dir * 220 * dt).clamp(40.0, surfaceWidth - 40);

    if (c.up && astroY <= 0) astroVy = jumpSpeed;
    astroVy -= info.gravity * dt;
    astroY += astroVy * dt;
    if (astroY <= 0) {
      astroY = 0;
      astroVy = 0;
    }

    for (var i = 0; i < itemXs.length; i++) {
      if (collected.contains(i)) continue;
      if ((astroX - itemXs[i]).abs() < 34 &&
          (astroY - itemHeight(i, info)).abs() < 45) {
        collected.add(i);
        _say(
            collected.length == itemXs.length
                ? 'You found all ${itemXs.length} ${info.itemName}s! Amazing! ⭐'
                : 'You found a ${info.itemName}! (${collected.length}/${itemXs.length})',
            3);
      }
    }

    temperature = info.temperature;
    danger = info.coldDrain > 0;
    status = (astroX - landmarkX).abs() < 110 ? info.landmarkFact : info.status;
    if (info.coldDrain > 0) _hurt(info.coldDrain * dt, info.coldReason);
  }

  void _updateOuch(double dt) {
    ouchTime += dt;
    final p = ouchPlanet;
    if (p != null && ouchTime >= ouchSeconds && health > 0) {
      _leavePlanet(p, 'Phew! Back in space. Where to next?');
    }
  }

  void _leavePlanet(Planet p, String text) {
    phase = Phase.space;
    final diff = rocketPos - p.position;
    final n = diff.distance == 0 ? const Offset(1, 0) : diff / diff.distance;
    rocketPos = p.position + n * (p.radius + 95);
    rocketVel = n * 280;
    rocketAngle = math.atan2(n.dy, n.dx);
    nearPlanet = null;
    _say(text, 3);
  }
}
