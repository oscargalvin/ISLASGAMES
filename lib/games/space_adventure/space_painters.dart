import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'planets.dart';
import 'space_model.dart';

// ------------------------------------------------------------------ helpers

class _Star {
  const _Star(this.x, this.y, this.size, this.depth);
  final double x, y, size, depth;
}

final List<_Star> _stars = () {
  final r = math.Random(3);
  return List.generate(
    260,
    (_) => _Star(r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble() * 1.6,
        0.05 + r.nextDouble() * 0.35),
  );
}();

void paintStars(Canvas canvas, Size size, Offset camera, {double alpha = 1}) {
  if (size.isEmpty || alpha <= 0) return;
  final paint = Paint();
  for (final s in _stars) {
    final x = (s.x * size.width - camera.dx * s.depth) % size.width;
    final y = (s.y * size.height - camera.dy * s.depth) % size.height;
    paint.color = Colors.white
        .withAlpha((alpha * (120 + s.depth * 380)).clamp(0.0, 255.0).toInt());
    canvas.drawCircle(Offset(x, y), s.size, paint);
  }
}

void paintLabel(Canvas canvas, String text, Offset center,
    {double size = 14, Color color = Colors.white}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

/// A rocket pointing straight up, about 64 tall, centred on (0, 0).
/// The bottom of the nozzle is at y = 30.
void paintRocket(Canvas canvas, {bool flame = false, double time = 0}) {
  if (flame) {
    final f = 18 + math.sin(time * 40) * 5;
    final outer = Path()
      ..moveTo(-9, 28)
      ..quadraticBezierTo(0, 28 + f * 2.2, 9, 28)
      ..close();
    canvas.drawPath(outer, Paint()..color = const Color(0xFFFF9800));
    final inner = Path()
      ..moveTo(-5, 28)
      ..quadraticBezierTo(0, 28 + f * 1.3, 5, 28)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFEB3B));
  }

  final fin = Paint()..color = const Color(0xFFD32F2F);
  canvas.drawPath(
      Path()
        ..moveTo(-12, 6)
        ..lineTo(-24, 30)
        ..lineTo(-12, 25)
        ..close(),
      fin);
  canvas.drawPath(
      Path()
        ..moveTo(12, 6)
        ..lineTo(24, 30)
        ..lineTo(12, 25)
        ..close(),
      fin);

  canvas.drawRect(const Rect.fromLTRB(-8, 25, 8, 30),
      Paint()..color = const Color(0xFF616161));

  final body = Path()
    ..moveTo(0, -34)
    ..quadraticBezierTo(16, -18, 13, 8)
    ..lineTo(12, 26)
    ..lineTo(-12, 26)
    ..lineTo(-13, 8)
    ..quadraticBezierTo(-16, -18, 0, -34)
    ..close();
  canvas.drawPath(body, Paint()..color = const Color(0xFFECEFF1));

  final nose = Path()
    ..moveTo(0, -34)
    ..quadraticBezierTo(9, -26, 11, -18)
    ..lineTo(-11, -18)
    ..quadraticBezierTo(-9, -26, 0, -34)
    ..close();
  canvas.drawPath(nose, Paint()..color = const Color(0xFFD32F2F));

  canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF78909C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

  canvas.drawCircle(
      const Offset(0, -5), 6.5, Paint()..color = const Color(0xFF455A64));
  canvas.drawCircle(
      const Offset(0, -5), 5, Paint()..color = const Color(0xFF4FC3F7));
  canvas.drawCircle(
      const Offset(-1.8, -6.8), 1.6, Paint()..color = Colors.white70);
}

/// An astronaut standing with their feet at (0, 0), about 62 tall.
void paintAstronaut(Canvas canvas,
    {required double walkPhase,
    required bool facingRight,
    required bool walking}) {
  canvas.save();
  if (!facingRight) canvas.scale(-1, 1);
  final suit = Paint()..color = Colors.white;
  final shade = Paint()..color = const Color(0xFFB0BEC5);
  final swing = walking ? math.sin(walkPhase) * 6 : 0.0;

  RRect r(double l, double t, double w, double h) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), const Radius.circular(3));

  canvas.drawRRect(r(-17, -46, 10, 22), shade); // backpack
  canvas.drawRRect(r(-8 + swing, -21, 7, 21), shade); // back leg
  canvas.drawRRect(r(1 - swing, -21, 7, 21), suit); // front leg
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-9, -44, 19, 26), const Radius.circular(6)),
      suit);
  canvas.drawRRect(r(3 - swing * 0.6, -41, 6, 17), shade); // arm
  canvas.drawRect(const Rect.fromLTWH(-4, -36, 9, 5),
      Paint()..color = const Color(0xFFE91E63)); // badge
  canvas.drawCircle(const Offset(1, -53), 11.5, suit); // helmet
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(-1, -58, 12, 9), const Radius.circular(4)),
      Paint()..color = const Color(0xFFFFB300)); // visor
  canvas.drawCircle(
      const Offset(7, -55), 1.6, Paint()..color = Colors.white70);
  canvas.restore();
}

Color _lighter(Color c, double t) => Color.lerp(c, Colors.white, t)!;
Color _darker(Color c, double t) => Color.lerp(c, Colors.black, t)!;

void paintPlanet(Canvas canvas, Planet p, {required bool visited}) {
  final c = p.position;
  final r = p.radius;
  final rect = Rect.fromCircle(center: c, radius: r);

  // A soft glow so small planets are easy to spot.
  canvas.drawCircle(
      c, r * 1.8, Paint()..color = p.color.withAlpha(visited ? 25 : 45));

  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.4),
        colors: [_lighter(p.color, 0.4), p.color, _darker(p.color, 0.55)],
        stops: const [0, 0.5, 1],
      ).createShader(rect),
  );

  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  if (p.banded) {
    final band = Paint()..color = _darker(p.color, 0.25).withAlpha(140);
    for (var i = -3; i <= 3; i++) {
      canvas.drawRect(
          Rect.fromLTWH(c.dx - r, c.dy + i * r * 0.28 - r * 0.05, r * 2, r * 0.1),
          band);
    }
  }
  if (p.name == 'Jupiter') {
    canvas.drawOval(
        Rect.fromCenter(
            center: c + Offset(r * 0.3, r * 0.3), width: r * 0.45, height: r * 0.25),
        Paint()..color = const Color(0xFFB5452B));
  }
  if (p.name == 'Earth') {
    final land = Paint()..color = const Color(0xFF43A047);
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.2), r * 0.45, land);
    canvas.drawCircle(c + Offset(r * 0.45, r * 0.35), r * 0.35, land);
  }
  if (p.name == 'Moon' || p.name == 'Mercury' || p.name == 'Pluto') {
    final crater = Paint()..color = _darker(p.color, 0.2);
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.2), r * 0.22, crater);
    canvas.drawCircle(c + Offset(r * 0.35, r * 0.3), r * 0.16, crater);
  }
  if (p.name == 'Pluto') {
    canvas.drawCircle(c + Offset(r * 0.1, r * 0.25), r * 0.35,
        Paint()..color = const Color(0xFFFFF8E1));
  }
  canvas.restore();

  final ring = p.ringColor;
  if (ring != null) {
    canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 3.6, height: r * 0.9),
        Paint()
          ..color = ring
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18);
  }

  paintLabel(canvas, visited ? '${p.name} ✓' : p.name,
      c + Offset(0, r + (ring != null ? 28 : 18)),
      size: 15, color: visited ? Colors.greenAccent : Colors.white);
}

// --------------------------------------------------------- launch pad scene

class LaunchPadPainter extends CustomPainter {
  LaunchPadPainter(this.game, {required this.rocketX, required this.groundY});
  final SpaceGameModel game;

  /// Where the rocket stands, as fractions of the screen size.
  final double rocketX, groundY;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
        full,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E88E5), Color(0xFFBBDEFB)],
          ).createShader(full));

    // Clouds
    final cloud = Paint()..color = Colors.white.withAlpha(200);
    for (var i = 0; i < 5; i++) {
      final x = ((i * 0.23 + game.time * 0.01) % 1.2 - 0.1) * size.width;
      final y = size.height * (0.08 + (i % 3) * 0.09);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 120, height: 34), cloud);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x + 30, y - 12), width: 70, height: 34), cloud);
    }

    final gy = size.height * groundY;
    canvas.drawRect(Rect.fromLTRB(0, gy, size.width, size.height),
        Paint()..color = const Color(0xFF66BB6A));
    canvas.drawRect(Rect.fromLTRB(0, gy, size.width, gy + 6),
        Paint()..color = const Color(0xFF43A047));

    final s = (size.height * 0.0055).clamp(1.6, 3.4);
    final rx = size.width * rocketX;

    // Launch tower
    final towerPaint = Paint()
      ..color = const Color(0xFF546E7A)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final tl = rx + 34 * s, tr = rx + 46 * s, tt = gy - 78 * s;
    canvas.drawRect(Rect.fromLTRB(tl, tt, tr, gy), towerPaint);
    for (var y = tt; y < gy - 1; y += 8 * s) {
      canvas.drawLine(Offset(tl, y), Offset(tr, y + 8 * s), towerPaint);
    }
    if (game.liftoff <= 0) {
      canvas.drawLine(Offset(tl, gy - 50 * s), Offset(rx + 12 * s, gy - 50 * s),
          towerPaint..strokeWidth = 4);
    }

    // Pad
    canvas.drawRect(Rect.fromLTRB(rx - 40 * s, gy - 8 * s, rx + 40 * s, gy),
        Paint()..color = const Color(0xFF424242));

    // Smoke
    final launching = game.phase == Phase.countdown && game.countdown < 1.5;
    if (launching) {
      final k = (1.5 - game.countdown) + game.liftoff * 1.5;
      final smoke = Paint()..color = Colors.white.withAlpha(210);
      for (var i = 0; i < 9; i++) {
        final dx = (i - 4) * 14 * s * (0.6 + k * 0.4);
        canvas.drawCircle(
            Offset(rx + dx, gy - 6 * s - (i % 3) * 4 * s), (6 + k * 7 + (i % 3) * 3) * s, smoke);
      }
    }

    // Rocket
    final lift = game.liftoff * game.liftoff * 260;
    final shaking = game.phase == Phase.countdown && game.countdown < 2.5;
    final shakeX = shaking ? math.sin(game.time * 60) * 1.5 * s : 0.0;
    canvas.save();
    canvas.translate(rx + shakeX, gy - 8 * s - 30 * s - lift);
    canvas.scale(s);
    paintRocket(canvas,
        flame: game.phase == Phase.countdown && game.countdown < 1.2,
        time: game.time);
    canvas.restore();

    // "Ready" gauge
    final done = game.checklistDone.length / SpaceGameModel.checklist.length;
    final gx = rx - 60 * s;
    final gaugeRect = Rect.fromLTRB(gx - 6 * s, gy - 62 * s, gx + 6 * s, gy - 10 * s);
    canvas.drawRRect(RRect.fromRectAndRadius(gaugeRect, Radius.circular(4 * s)),
        Paint()..color = Colors.black26);
    final fill = Rect.fromLTRB(gaugeRect.left, gaugeRect.bottom - gaugeRect.height * done,
        gaugeRect.right, gaugeRect.bottom);
    canvas.drawRRect(RRect.fromRectAndRadius(fill, Radius.circular(4 * s)),
        Paint()..color = done >= 1 ? Colors.greenAccent : Colors.orangeAccent);
    canvas.drawRRect(
        RRect.fromRectAndRadius(gaugeRect, Radius.circular(4 * s)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    paintLabel(canvas, 'READY', Offset(gx, gaugeRect.top - 10 * s), size: 5 * s);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ----------------------------------------------------- flying up to space

class FlightPainter extends CustomPainter {
  FlightPainter(this.game);
  final SpaceGameModel game;

  @override
  void paint(Canvas canvas, Size size) {
    final t = game.flightTime;
    final full = Offset.zero & size;
    final dark = (t / 14).clamp(0.0, 1.0);
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF64B5F6), const Color(0xFF02030A), dark)!,
            Color.lerp(const Color(0xFFBBDEFB), const Color(0xFF0B1030), dark)!,
          ],
        ).createShader(full),
    );

    paintStars(canvas, size, Offset(game.flightRocketX * 80, -t * 1600),
        alpha: dark);

    // Clouds rushing past at the start
    if (t < 9) {
      final cloud = Paint()..color = Colors.white.withAlpha(((1 - t / 9) * 230).toInt());
      for (var i = 0; i < 7; i++) {
        final x = ((i * 0.37) % 1.0) * size.width;
        final y = -200 + i * 120 + t * 420;
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 160, height: 46), cloud);
      }
    }

    // Earth getting smaller below us
    if (t > 4) {
      final k = ((t - 4) / 32).clamp(0.0, 1.0);
      final r = size.width * 1.5 + (size.width * 0.12 - size.width * 1.5) * k;
      final visible = 60 + (r * 1.6 - 60) * k;
      final center = Offset(size.width / 2, size.height + r - visible);
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawCircle(center, r * 1.03,
          Paint()..color = const Color(0xFF81D4FA).withAlpha(60));
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.5),
              colors: [Color(0xFF64B5F6), Color(0xFF1565C0)],
            ).createShader(rect));
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      final land = Paint()..color = const Color(0xFF43A047);
      canvas.drawCircle(center + Offset(-r * 0.35, -r * 0.6), r * 0.4, land);
      canvas.drawCircle(center + Offset(r * 0.4, -r * 0.75), r * 0.25, land);
      canvas.restore();
    }

    // Space station flying by
    if (t > 18 && t < 30) {
      final k = (t - 18) / 12;
      final c = Offset(size.width * (1.1 - k * 1.3), size.height * 0.25);
      final panel = Paint()..color = const Color(0xFF1A237E);
      canvas.drawRect(Rect.fromCenter(center: c, width: 30, height: 12),
          Paint()..color = Colors.grey.shade300);
      canvas.drawRect(Rect.fromCenter(center: c + const Offset(-38, 0), width: 40, height: 22), panel);
      canvas.drawRect(Rect.fromCenter(center: c + const Offset(38, 0), width: 40, height: 22), panel);
      canvas.drawLine(c + const Offset(-60, 0), c + const Offset(60, 0),
          Paint()..color = Colors.grey..strokeWidth = 2);
    }

    final s = (size.height * 0.004).clamp(1.4, 2.6);
    canvas.save();
    canvas.translate(size.width / 2 + game.flightRocketX * size.width * 0.3,
        size.height * 0.55 + math.sin(game.time * 3) * 6);
    canvas.scale(s);
    paintRocket(canvas, flame: true, time: game.time);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ------------------------------------------------------- the solar system

class SpacePainter extends CustomPainter {
  SpacePainter(this.game);
  final SpaceGameModel game;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(full, Paint()..color = const Color(0xFF05060F));
    final cam = game.rocketPos;
    paintStars(canvas, size, cam);

    final shakeAmount = game.shake * 15;
    final shake = Offset(math.sin(game.time * 80) * shakeAmount,
        math.cos(game.time * 70) * shakeAmount);

    canvas.save();
    canvas.translate(
        size.width / 2 - cam.dx + shake.dx, size.height / 2 - cam.dy + shake.dy);

    // The Sun
    const sunGlow = 1100.0;
    canvas.drawCircle(
        Offset.zero,
        sunGlow,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0x88FF9800),
            Color(0x33FF5722),
            Color(0x00FF5722),
          ], stops: [
            0,
            0.4,
            1
          ]).createShader(Rect.fromCircle(center: Offset.zero, radius: sunGlow)));
    final sunR = sunRadius + math.sin(game.time * 3) * 4;
    canvas.drawCircle(
        Offset.zero,
        sunR,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0xFFFFF59D),
            Color(0xFFFFC107),
            Color(0xFFFF6F00),
          ]).createShader(Rect.fromCircle(center: Offset.zero, radius: sunR)));
    paintLabel(canvas, 'THE SUN ☀️', const Offset(0, sunRadius + 26), size: 18);

    // Asteroid belt
    final view = size.longestSide;
    final rock = Paint()..color = const Color(0xFF8D6E63);
    final rockEdge = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final a in game.asteroids) {
      if ((a.position - cam).distance > view) continue;
      final path = Path();
      for (var i = 0; i < 7; i++) {
        final ang = i / 7 * math.pi * 2 + game.time * a.spin;
        final rr = a.radius * (0.75 + 0.25 * math.sin(i * 2.3 + a.spin * 5));
        final pt = a.position + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(path, rock);
      canvas.drawPath(path, rockEdge);
    }
    if ((cam.dx - 2575).abs() < view) {
      paintLabel(canvas, '⚠️ ASTEROID BELT ⚠️', Offset(2575, cam.dy - size.height / 2 + 120),
          size: 16, color: Colors.orangeAccent);
    }

    for (final p in planets) {
      if ((p.position - cam).distance > view + p.radius * 4) continue;
      paintPlanet(canvas, p, visited: game.visited.contains(p.name));
    }

    // Our rocket (blinks after a crash)
    final blink = game.invulnerable > 0 && (game.time * 14).floor().isEven;
    if (!blink) {
      canvas.save();
      canvas.translate(game.rocketPos.dx, game.rocketPos.dy);
      canvas.rotate(game.rocketAngle + math.pi / 2);
      canvas.scale(0.9);
      paintRocket(canvas, flame: game.thrusting, time: game.time);
      canvas.restore();
    }
    canvas.restore();

    _temperatureGlow(canvas, size, game.temperature);
    _minimap(canvas, size);
  }

  void _minimap(Canvas canvas, Size size) {
    const minX = -300.0, maxX = 6500.0;
    const left = 24.0;
    final right = size.width - 24.0;
    final y = size.height - 18.0;
    double mx(double x) => left + (x - minX) / (maxX - minX) * (right - left);

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(left - 12, y - 14, right + 12, y + 12), const Radius.circular(10)),
        Paint()..color = Colors.black54);
    canvas.drawLine(Offset(left, y), Offset(right, y),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 2);
    canvas.drawCircle(Offset(mx(0), y), 7, Paint()..color = sunColor);
    for (final p in planets) {
      canvas.drawCircle(
          Offset(mx(p.position.dx), y),
          (p.radius / 12).clamp(2.5, 6.0),
          Paint()
            ..color = game.visited.contains(p.name) || p.name == 'Earth'
                ? p.color
                : p.color.withAlpha(110));
    }
    final rx = mx(game.rocketPos.dx.clamp(minX, maxX));
    canvas.drawPath(
        Path()
          ..moveTo(rx, y - 4)
          ..lineTo(rx - 6, y - 14)
          ..lineTo(rx + 6, y - 14)
          ..close(),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Red edges when hot, blue edges when cold.
void _temperatureGlow(Canvas canvas, Size size, double temperature) {
  final strength = (temperature.abs() - 0.25) / 0.75;
  if (strength <= 0) return;
  final color = temperature > 0 ? const Color(0xFFFF3D00) : const Color(0xFF40C4FF);
  final full = Offset.zero & size;
  canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            color.withAlpha(0),
            color.withAlpha((strength.clamp(0.0, 1.0) * 170).toInt()),
          ],
          stops: const [0.55, 1],
        ).createShader(full));
}

// ---------------------------------------------------- walking on a planet

double surfaceGround(double worldX, Size size) =>
    size.height * 0.78 + math.sin(worldX / 170) * 14 + math.sin(worldX / 47) * 5;

class SurfacePainter extends CustomPainter {
  SurfacePainter(this.game);
  final SpaceGameModel game;

  @override
  void paint(Canvas canvas, Size size) {
    final info = game.surface;
    if (info == null || size.isEmpty) return;
    final full = Offset.zero & size;
    final maxCam = math.max(0.0, SpaceGameModel.surfaceWidth - size.width);
    final cam = (game.astroX - size.width / 2).clamp(0.0, maxCam);

    canvas.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [info.skyTop, info.skyBottom],
          ).createShader(full));

    if (info.showStars) {
      paintStars(canvas, Size(size.width, size.height * 0.7), Offset(cam * 0.5, 0));
    }
    if (info.showEarth) {
      final c = Offset(size.width * 0.8 - cam * 0.03, size.height * 0.2);
      canvas.drawCircle(c, 34, Paint()..color = const Color(0xFF1E88E5));
      canvas.drawCircle(c + const Offset(-10, -8), 13, Paint()..color = const Color(0xFF43A047));
      canvas.drawCircle(c + const Offset(12, 10), 9, Paint()..color = const Color(0xFF43A047));
      paintLabel(canvas, 'Earth', c + const Offset(0, 48), size: 13);
    }
    if (game.surfacePlanet?.name == 'Pluto') {
      final c = Offset(size.width * 0.15, size.height * 0.15);
      canvas.drawCircle(c, 5, Paint()..color = const Color(0xFFFFF59D));
      paintLabel(canvas, 'The Sun is just a tiny dot from here!', c + const Offset(0, 22),
          size: 12, color: Colors.white70);
    }

    // Far-away hills
    final hills = Path()..moveTo(0, size.height);
    for (var sx = 0.0; sx <= size.width + 10; sx += 10) {
      final wx = sx + cam * 0.35;
      hills.lineTo(sx, size.height * 0.66 + math.sin(wx / 260) * 28 + math.sin(wx / 90) * 8);
    }
    hills
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(hills, Paint()..color = Color.lerp(info.ground, info.skyBottom, 0.5)!);

    // Ground
    final ground = Path()..moveTo(0, size.height);
    for (var sx = 0.0; sx <= size.width + 8; sx += 8) {
      ground.lineTo(sx, surfaceGround(cam + sx, size));
    }
    ground
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(ground, Paint()..color = info.ground);

    final crater = Paint()..color = _darker(info.ground, 0.22);
    for (var i = 0; i < 44; i++) {
      final wx = i * 57.0 + (i * 131 % 47);
      final sx = wx - cam;
      if (sx < -60 || sx > size.width + 60) continue;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(sx, surfaceGround(wx, size) + 14 + (i % 3) * 12),
              width: 26.0 + (i % 4) * 12,
              height: 7.0 + (i % 3) * 2),
          crater);
    }

    _landmark(canvas, size, info, SpaceGameModel.landmarkX - cam,
        surfaceGround(SpaceGameModel.landmarkX, size));

    // Parked rocket
    canvas.save();
    canvas.translate(SpaceGameModel.rocketParkX - cam,
        surfaceGround(SpaceGameModel.rocketParkX, size) - 30 * 2.2);
    canvas.scale(2.2);
    paintRocket(canvas);
    canvas.restore();

    // Things to collect
    for (var i = 0; i < SpaceGameModel.itemXs.length; i++) {
      if (game.collected.contains(i)) continue;
      final wx = SpaceGameModel.itemXs[i];
      final c = Offset(
          wx - cam,
          surfaceGround(wx, size) -
              SpaceGameModel.itemHeight(i, info) -
              18 +
              math.sin(game.time * 3 + i) * 5);
      canvas.drawCircle(c, 20, Paint()..color = info.itemColor.withAlpha(70));
      final gem = Path()
        ..moveTo(c.dx, c.dy - 11)
        ..lineTo(c.dx + 9, c.dy)
        ..lineTo(c.dx, c.dy + 11)
        ..lineTo(c.dx - 9, c.dy)
        ..close();
      canvas.drawPath(gem, Paint()..color = info.itemColor);
      canvas.drawPath(
          gem,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // Astronaut
    canvas.save();
    canvas.translate(game.astroX - cam, surfaceGround(game.astroX, size) - game.astroY);
    canvas.scale(1.3);
    paintAstronaut(canvas,
        walkPhase: game.walkPhase,
        facingRight: game.facingRight,
        walking: game.walking && game.astroY <= 0);
    canvas.restore();

    _temperatureGlow(canvas, size, info.temperature);
  }

  void _landmark(Canvas canvas, Size size, SurfaceInfo info, double x, double gy) {
    if (x < -150 || x > size.width + 150) return;
    switch (info.landmark) {
      case 'flag':
        canvas.drawLine(Offset(x, gy), Offset(x, gy - 90),
            Paint()
              ..color = Colors.grey.shade300
              ..strokeWidth = 3);
        for (var i = 0; i < 5; i++) {
          canvas.drawRect(Rect.fromLTWH(x + 2, gy - 90 + i * 6, 46, 6),
              Paint()..color = i.isEven ? const Color(0xFFE53935) : Colors.white);
        }
        canvas.drawRect(Rect.fromLTWH(x + 2, gy - 90, 18, 18),
            Paint()..color = const Color(0xFF283593));
      case 'rover':
        final body = Paint()..color = const Color(0xFFCFD8DC);
        final dark = Paint()..color = const Color(0xFF37474F);
        canvas.drawRect(Rect.fromLTWH(x - 40, gy - 46, 80, 24), body);
        canvas.drawRect(Rect.fromLTWH(x - 50, gy - 52, 100, 6), Paint()..color = const Color(0xFF1A237E));
        canvas.drawLine(Offset(x + 25, gy - 52), Offset(x + 25, gy - 80),
            Paint()
              ..color = const Color(0xFFCFD8DC)
              ..strokeWidth = 4);
        canvas.drawRect(Rect.fromLTWH(x + 17, gy - 92, 18, 12), body);
        canvas.drawCircle(Offset(x + 30, gy - 86), 3, dark);
        for (final wx in [-30.0, 0.0, 30.0]) {
          canvas.drawCircle(Offset(x + wx, gy - 12), 11, dark);
          canvas.drawCircle(Offset(x + wx, gy - 12), 4, body);
        }
      case 'heart':
        canvas.save();
        canvas.translate(x, gy + 10);
        canvas.scale(1, 0.35);
        final heart = Path()
          ..moveTo(0, 60)
          ..cubicTo(-110, -10, -60, -90, 0, -40)
          ..cubicTo(60, -90, 110, -10, 0, 60)
          ..close();
        canvas.drawPath(heart, Paint()..color = const Color(0xFFFFFDF7));
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
