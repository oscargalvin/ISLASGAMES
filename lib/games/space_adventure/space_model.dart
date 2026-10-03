import 'dart:math' as math;
import 'dart:ui';

import 'planets.dart';

enum Phase { setup, countdown, flight, space, surface, gameOver, win }

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

/// One part of a launch-pad job: walk to [x], then do [action] for [seconds].
/// Positions are in "rocket units" - the rocket is about 64 units tall and
/// stands at x = 0.
class JobStep {
  const JobStep(this.x, this.seconds,
      {required this.action, required this.faceRight, this.carry});
  final double x;
  final double seconds;
  final String action;
  final bool faceRight;

  /// Something the astronaut carries while walking to this step.
  final String? carry;
}

class Job {
  const Job(this.label, this.doneMessage, this.steps);
  final String label;
  final String doneMessage;
  final List<JobStep> steps;
}

/// Where things are on the launch pad (rocket units).
class Pad {
  static const truckX = -100.0;
  static const oxygenX = -60.0;
  static const snacksX = -45.0;
  static const towerX = 40.0;
  static const hutX = 86.0;
  static const startX = 20.0;
  static const liftHeight = 30.0;
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

  /// Health you lose every second just from being out in space.
  static const spaceDrain = 0.15;

  static const surfaceWidth = 2400.0;
  static const jumpSpeed = 420.0;
  static const rocketParkX = 200.0;
  static const landmarkX = 1050.0;
  static const itemXs = <double>[650, 1450, 2050];

  static const worldLeft = -700.0;
  static const worldRight = 6700.0;
  static const worldTop = -1100.0;
  static const worldBottom = 1100.0;

  static const jobs = <Job>[
    Job('⛽  Fill up the fuel tanks', 'Glug glug glug... fuel tanks full! ⛽', [
      JobStep(Pad.truckX + 24, 3.0, action: 'fuel', faceRight: false),
    ]),
    Job('💨  Load the oxygen', 'Oxygen loaded - now you can breathe in space! 💨', [
      JobStep(Pad.oxygenX, 0.7, action: 'pickup', faceRight: false),
      JobStep(-22, 1.2, action: 'load', faceRight: true, carry: 'oxygen'),
    ]),
    Job('🍕  Pack the space snacks', 'Snacks packed. Space pizza! 🍕', [
      JobStep(Pad.snacksX, 0.7, action: 'pickup', faceRight: false),
      JobStep(-22, 1.2, action: 'load', faceRight: true, carry: 'snacks'),
    ]),
    Job('👩‍🚀  Put on your space suit',
        'Space suit on. Looking good, astronaut! 👩‍🚀', [
      JobStep(Pad.hutX - 2, 2.4, action: 'suit', faceRight: true),
    ]),
    Job('🔧  Check the engines', 'Engines checked - they go VROOOM! 🔧', [
      JobStep(-26, 2.6, action: 'wrench', faceRight: true),
    ]),
    Job('🚪  Climb in and close the hatch',
        'Hatch closed. Ready for launch! 🚪', [
      JobStep(Pad.towerX, 2.4, action: 'elevator', faceRight: false),
    ]),
  ];

  Phase phase = Phase.setup;

  /// The last "world" we were in, so the right background shows behind pop-ups.
  Phase scenePhase = Phase.space;
  double time = 0;

  // ------------------------------------------------------- launch pad
  final Set<int> checklistDone = {};
  int? activeJob;
  int stepIndex = 0;
  double stepTimer = 0;
  double personX = Pad.startX;
  double personLift = 0;
  bool personWalking = false;
  bool personFacingRight = false;
  double personWalkPhase = 0;
  bool personInside = false;
  double countdown = countdownSeconds;
  double liftoff = 0;

  // -------------------------------------------------- flight to space
  double flightTime = 0;
  double flightRocketX = 0;

  // ------------------------------------------------------ staying alive
  double health = 100;
  double temperature = 0; // -1 = freezing, 0 = comfy, 1 = boiling
  String status = '';
  bool danger = false;
  String deathReason = '';
  final Set<String> visited = {};
  String _lastWarning = '';

  // ------------------------------------------------- flying around space
  Offset rocketPos = Offset.zero;
  Offset rocketVel = Offset.zero;
  double rocketAngle = 0;
  bool thrusting = false;
  double invulnerable = 0;
  double shake = 0;
  Planet? nearPlanet;
  final List<Asteroid> asteroids = [];

  // ----------------------------------------------------- pop-up message
  String message = '';
  double messageTime = 0;

  // ---------------------------------------------- walking on a planet
  Planet? surfacePlanet;
  double timeOnPlanet = 0;
  double astroX = 0;
  double astroY = 0; // height above the ground
  double astroVy = 0;
  bool facingRight = true;
  bool walking = false;
  double walkPhase = 0;
  final Set<int> collected = {};

  bool get readyToLaunch => checklistDone.length == jobs.length;
  bool get suited => checklistDone.contains(3);
  bool get hatchClosed => checklistDone.contains(jobs.length - 1);

  int get placesToVisit =>
      planets.where((p) => p.landing != LandingType.home).length;

  SurfaceInfo? get surface {
    final p = surfacePlanet;
    return p == null ? null : surfaces[p.name];
  }

  JobStep? get activeStep {
    final a = activeJob;
    if (a == null) return null;
    return jobs[a].steps[stepIndex];
  }

  /// True while the astronaut is doing a step (not walking to it).
  bool get atStep {
    final step = activeStep;
    return step != null && (personX - step.x).abs() <= 0.5;
  }

  double get stepProgress {
    final step = activeStep;
    if (step == null || !atStep) return 0;
    return (stepTimer / step.seconds).clamp(0.0, 1.0);
  }

  /// How far through a job is, 0..1 (for the little progress circles).
  double jobProgress(int i) {
    if (checklistDone.contains(i)) return 1;
    if (activeJob != i) return 0;
    return (stepIndex + stepProgress) / jobs[i].steps.length;
  }

  /// What the astronaut is holding right now, if anything.
  String? get carrying {
    final step = activeStep;
    if (step == null || step.carry == null) return null;
    if (atStep && stepProgress > 0.5) return null;
    return step.carry;
  }

  double get fuelLevel {
    if (checklistDone.contains(0)) return 1;
    if (activeJob == 0) return stepProgress;
    return 0;
  }

  bool get nearLandmark =>
      phase == Phase.surface && (astroX - landmarkX).abs() < 120;

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
    activeJob = null;
    stepIndex = 0;
    stepTimer = 0;
    personX = Pad.startX;
    personLift = 0;
    personWalking = false;
    personFacingRight = false;
    personInside = false;
    countdown = countdownSeconds;
    liftoff = 0;
    flightTime = 0;
    flightRocketX = 0;
    health = 100;
    temperature = 0;
    status = '';
    danger = false;
    deathReason = '';
    _lastWarning = '';
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
    surfacePlanet = null;
    timeOnPlanet = 0;
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

  /// Pops up a small warning, but only when things change (not every frame).
  void _warn(String key, String text) {
    if (key == _lastWarning) return;
    _lastWarning = key;
    if (key.isNotEmpty) _say(text, 3);
  }

  void _hurt(double amount, String reason) {
    if (phase == Phase.gameOver || phase == Phase.win) return;
    health -= amount;
    if (health <= 0 && deathReason.isEmpty) deathReason = reason;
  }

  // ---------------------------------------------------------------- input

  void tickChecklist(int i) {
    if (phase != Phase.setup || checklistDone.contains(i)) return;
    if (activeJob != null) {
      _say('Wait a moment - your astronaut is still busy!', 2);
      return;
    }
    if (i == jobs.length - 1 && checklistDone.length < jobs.length - 1) {
      _say('Finish all the other jobs before you climb in!', 2.5);
      return;
    }
    activeJob = i;
    stepIndex = 0;
    stepTimer = 0;
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
    if (p.landing == LandingType.home) {
      health = 100;
      _say('Home sweet home! 🌍 You are all fixed up - full health again!', 4);
      return;
    }
    final info = surfaces[p.name];
    if (info == null) return;
    visited.add(p.name);
    phase = Phase.surface;
    surfacePlanet = p;
    timeOnPlanet = 0;
    astroX = rocketParkX + 120;
    astroY = 0;
    astroVy = 0;
    facingRight = true;
    walking = false;
    collected.clear();
    _lastWarning = '';
    final first = feelMessages(info).first;
    _say(
        'You climbed out onto ${p.title}! 👩‍🚀 ${info.feel == Feel.fine ? 'Use the arrow keys to explore.' : first}',
        4);
  }

  void takeOff() {
    final p = surfacePlanet;
    if (phase != Phase.surface || p == null) return;
    phase = Phase.space;
    final diff = rocketPos - p.position;
    final n = diff.distance == 0 ? const Offset(1, 0) : diff / diff.distance;
    rocketPos = p.position + n * (p.radius + 95);
    rocketVel = n * 280;
    rocketAngle = math.atan2(n.dy, n.dx);
    nearPlanet = null;
    _lastWarning = '';
    _say('Blast off! 🚀 Off to explore more of space!', 3);
  }

  // --------------------------------------------------------------- update

  void update(double dt, Controls c) {
    time += dt;
    if (messageTime > 0) messageTime -= dt;
    if (shake > 0) shake = math.max(0.0, shake - dt);
    if (invulnerable > 0) invulnerable -= dt;

    switch (phase) {
      case Phase.setup:
        _updateSetup(dt);
      case Phase.countdown:
        _updateCountdown(dt);
      case Phase.flight:
        _updateFlight(dt, c);
      case Phase.space:
        _updateSpace(dt, c);
      case Phase.surface:
        _updateSurface(dt, c);
      default:
        break;
    }

    if (phase == Phase.space || phase == Phase.surface) scenePhase = phase;

    if (health <= 0 && (phase == Phase.space || phase == Phase.surface)) {
      health = 0;
      phase = Phase.gameOver;
    }
  }

  void _updateSetup(double dt) {
    final a = activeJob;
    if (a == null) {
      personWalking = false;
      return;
    }
    final step = jobs[a].steps[stepIndex];
    final dx = step.x - personX;
    if (dx.abs() > 0.5) {
      personX += dx.sign * math.min(dx.abs(), 45 * dt);
      personWalking = true;
      personFacingRight = dx > 0;
      personWalkPhase += dt * 10;
      return;
    }
    personX = step.x;
    personWalking = false;
    personFacingRight = step.faceRight;
    stepTimer += dt;
    if (step.action == 'elevator') {
      personLift = (stepTimer / step.seconds).clamp(0.0, 1.0) * Pad.liftHeight;
    }
    if (stepTimer >= step.seconds) {
      stepIndex++;
      stepTimer = 0;
      if (stepIndex >= jobs[a].steps.length) {
        checklistDone.add(a);
        activeJob = null;
        stepIndex = 0;
        if (a == jobs.length - 1) personInside = true;
        _say(jobs[a].doneMessage, 2.5);
      }
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

    // Space always wears you down a tiny bit.
    _hurt(spaceDrain * dt, 'You were out in space for too long! 🚀');

    // Hot near the Sun, cold far away.
    final d = rocketPos.distance;
    final hot = ((1000 - d) / 800).clamp(0.0, 1.0);
    final cold = ((d - 2600) / 4000).clamp(0.0, 1.0);
    temperature = hot - cold;

    var s = 'Flying through space... 🚀';
    var warnKey = '';
    var bad = false;
    if (hot > 0.1) {
      _hurt(hot * hot * 25 * dt,
          'You flew too close to the Sun and got too hot! 🔥');
      bad = true;
      if (hot > 0.55) {
        s = "You're getting REALLY hot! 🔥 Fly away from the Sun!";
        warnKey = 'hot2';
      } else {
        s = "It's getting a bit hot... 🥵";
        warnKey = 'hot1';
      }
    }
    if (cold > 0.25) {
      _hurt((cold - 0.25) * 4 * dt, 'You froze in the far, far cold of space! 🥶');
      bad = true;
      if (cold > 0.6) {
        s = "Brrr! You're getting really cold! 🥶";
        warnKey = 'cold2';
      } else {
        s = "It's getting a bit cold... 🥶";
        warnKey = 'cold1';
      }
    }

    final jupiter = planetNamed('Jupiter');
    if ((rocketPos - jupiter.position).distance < 450) {
      _hurt(3 * dt, "Jupiter's radiation made you too sick! 🤢");
      s = "Jupiter's radiation is making you feel a bit sick! 🤢";
      warnKey = 'rad';
      bad = true;
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
    _warn(warnKey, s);

    nearPlanet = null;
    for (final planet in planets) {
      if ((rocketPos - planet.position).distance < planet.radius + 55) {
        nearPlanet = planet;
        break;
      }
    }

    if (visited.length >= placesToVisit && health > 0) phase = Phase.win;
  }

  void _updateSurface(double dt, Controls c) {
    final info = surface;
    if (info == null) return;
    timeOnPlanet += dt;

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

    // The longer you stay, the faster your health goes down.
    final rate = info.drain * (1 + timeOnPlanet / 12);
    _hurt(rate * dt, info.deathReason);

    final messages = feelMessages(info);
    final int level;
    if (info.feel == Feel.fine) {
      level = timeOnPlanet < 40 ? 0 : 2;
    } else {
      level = timeOnPlanet < 6
          ? 0
          : timeOnPlanet < 14
              ? 1
              : 2;
    }
    status = messages[level];
    danger = info.feel != Feel.fine || level > 0;
    temperature = info.temperature;
    if (level > 0) _warn('surface$level', status);
  }
}
