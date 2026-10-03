import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'art.dart';
import 'planets.dart';
import 'space_model.dart';

// ------------------------------------------------------------- the Sun

void paintSun(Canvas canvas, double time) {
  const glow = 1100.0;
  canvas.drawCircle(
      Offset.zero,
      glow,
      Paint()
        ..shader = const RadialGradient(colors: [
          Color(0x88FFB74D),
          Color(0x30FF7043),
          Color(0x00FF5722),
        ], stops: [
          0,
          0.35,
          1
        ]).createShader(Rect.fromCircle(center: Offset.zero, radius: glow)));

  // Corona rays slowly turning
  final ray = blurPaint(const Color(0x55FFE082), 12);
  for (var i = 0; i < 14; i++) {
    final a = i / 14 * math.pi * 2 + time * 0.05;
    final len = sunRadius * (1.6 + 0.3 * math.sin(time * 1.3 + i));
    final path = Path()
      ..moveTo(math.cos(a - 0.08) * sunRadius, math.sin(a - 0.08) * sunRadius)
      ..lineTo(math.cos(a) * len, math.sin(a) * len)
      ..lineTo(math.cos(a + 0.08) * sunRadius, math.sin(a + 0.08) * sunRadius)
      ..close();
    canvas.drawPath(path, ray);
  }

  canvas.drawCircle(Offset.zero, sunRadius * 1.15, blurPaint(const Color(0xAAFFC107), 30));
  final r = sunRadius + math.sin(time * 3) * 3;
  final rect = Rect.fromCircle(center: Offset.zero, radius: r);
  canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = const RadialGradient(colors: [
          Color(0xFFFFFDE7),
          Color(0xFFFFE082),
          Color(0xFFFFA000),
          Color(0xFFE65100),
        ], stops: [
          0,
          0.45,
          0.85,
          1
        ]).createShader(rect));

  // Bubbling surface
  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  final rnd = math.Random(5);
  for (var i = 0; i < 26; i++) {
    final a = rnd.nextDouble() * math.pi * 2;
    final d = rnd.nextDouble() * r * 0.9;
    final wob = math.sin(time * 1.5 + i) * 6;
    canvas.drawCircle(Offset(math.cos(a) * d + wob, math.sin(a) * d),
        8 + rnd.nextDouble() * 18, blurPaint(const Color(0x33FF6F00), 10));
  }
  canvas.restore();
}

// ----------------------------------------------------------- planets

Color? _atmosphere(String name) {
  switch (name) {
    case 'Earth':
      return const Color(0xFF64B5F6);
    case 'Venus':
      return const Color(0xFFFFE0A0);
    case 'Mars':
      return const Color(0xFFFFAB91);
    case 'Jupiter':
    case 'Saturn':
      return const Color(0xFFFFE0B2);
    case 'Uranus':
      return const Color(0xFFB2EBF2);
    case 'Neptune':
      return const Color(0xFF7986CB);
    default:
      return null;
  }
}

void _blob(Canvas canvas, Offset c, double rx, double ry, Color color, {double blur = 0}) {
  final paint = blur > 0 ? blurPaint(color, blur) : (Paint()..color = color);
  canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), paint);
}

void _craters(Canvas canvas, Offset c, double r, Color base, int seed, int count) {
  final rnd = math.Random(seed);
  for (var i = 0; i < count; i++) {
    final a = rnd.nextDouble() * math.pi * 2;
    final d = math.sqrt(rnd.nextDouble()) * r * 0.9;
    final cr = r * (0.05 + rnd.nextDouble() * 0.12);
    final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
    canvas.drawCircle(p, cr, Paint()..color = darker(base, 0.25));
    canvas.drawCircle(p + Offset(-cr * 0.2, -cr * 0.2), cr * 0.7, Paint()..color = darker(base, 0.12));
  }
}

void _bands(Canvas canvas, Offset c, double r, List<Color> colors, {double blur = 1}) {
  final n = colors.length;
  for (var i = 0; i < n; i++) {
    final top = c.dy - r + (i / n) * 2 * r;
    canvas.drawRect(Rect.fromLTRB(c.dx - r, top, c.dx + r, top + 2 * r / n + 1),
        blur > 0 ? blurPaint(colors[i], blur) : (Paint()..color = colors[i]));
  }
}

void _rings(Canvas canvas, Planet p, {required bool back}) {
  final c = p.position;
  final r = p.radius;
  final List<(double, double, Color)> rings;
  final double tilt, flat;
  if (p.name == 'Saturn') {
    tilt = -0.32;
    flat = 0.3;
    rings = const [
      (1.22, 1.45, Color(0x668C7A5C)),
      (1.48, 1.92, Color(0xEED8C59C)),
      (2.0, 2.25, Color(0xCCC2AD84)),
    ];
  } else if (p.name == 'Uranus') {
    tilt = 1.45;
    flat = 0.35;
    rings = const [
      (1.55, 1.6, Color(0x88B0BEC5)),
      (1.75, 1.8, Color(0x99CFD8DC)),
    ];
  } else {
    return;
  }
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(tilt);
  canvas.clipRect(Rect.fromLTRB(-r * 3, back ? -r * 3 : 0, r * 3, back ? 0 : r * 3));
  canvas.scale(1, flat);
  for (final ring in rings) {
    canvas.drawCircle(
        Offset.zero,
        r * (ring.$1 + ring.$2) / 2,
        Paint()
          ..color = back ? darker(ring.$3, 0.25) : ring.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * (ring.$2 - ring.$1));
  }
  canvas.restore();
}

void paintPlanet(Canvas canvas, Planet p, {required bool visited, double time = 0}) {
  final c = p.position;
  final r = p.radius;
  final toSun = -c;
  final light = toSun.distance == 0 ? const Offset(-1, 0) : toSun / toSun.distance;
  final rect = Rect.fromCircle(center: c, radius: r);

  final air = _atmosphere(p.name);
  if (air != null) {
    canvas.drawCircle(c, r * 1.1, blurPaint(air.withAlpha(110), r * 0.15 + 3));
  }

  _rings(canvas, p, back: true);

  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(light.dx * 0.45, light.dy * 0.45),
          radius: 1.1,
          colors: [lighter(p.color, 0.25), p.color, darker(p.color, 0.3)],
        ).createShader(rect));

  switch (p.name) {
    case 'Mercury':
      _craters(canvas, c, r, p.color, 1, 14);
    case 'Venus':
      for (var i = 0; i < 5; i++) {
        _blob(canvas, c + Offset(math.sin(i * 1.7) * r * 0.3, (i - 2) * r * 0.32), r * 0.9, r * 0.12,
            i.isEven ? const Color(0x55FFF3D6) : const Color(0x44B8874A),
            blur: r * 0.08);
      }
    case 'Earth':
      final land = const Color(0xFF3F7D3A);
      final desert = const Color(0xFFC2A36B);
      _blob(canvas, c + Offset(-r * 0.35, -r * 0.15), r * 0.32, r * 0.45, land);
      _blob(canvas, c + Offset(-r * 0.25, r * 0.4), r * 0.18, r * 0.3, land);
      _blob(canvas, c + Offset(r * 0.38, -r * 0.2), r * 0.3, r * 0.22, land);
      _blob(canvas, c + Offset(r * 0.42, r * 0.05), r * 0.2, r * 0.18, desert);
      _blob(canvas, c + Offset(0, -r * 0.95), r * 0.6, r * 0.18, Colors.white);
      _blob(canvas, c + Offset(0, r * 0.95), r * 0.6, r * 0.18, Colors.white);
      final spin = time * 0.05;
      for (var i = 0; i < 6; i++) {
        final y = (i - 2.5) * r * 0.32;
        final x = ((i * 0.37 + spin) % 1.0 - 0.5) * r * 2;
        _blob(canvas, c + Offset(x, y), r * 0.35, r * 0.06, const Color(0xCCFFFFFF), blur: r * 0.04);
      }
    case 'Moon':
      _blob(canvas, c + Offset(-r * 0.25, -r * 0.2), r * 0.35, r * 0.28, const Color(0x66505055),
          blur: r * 0.1);
      _blob(canvas, c + Offset(r * 0.2, r * 0.25), r * 0.25, r * 0.2, const Color(0x55505055),
          blur: r * 0.1);
      _craters(canvas, c, r, p.color, 2, 8);
    case 'Mars':
      _blob(canvas, c + Offset(r * 0.1, r * 0.05), r * 0.45, r * 0.22, const Color(0x667A2E14),
          blur: r * 0.12);
      _blob(canvas, c + Offset(-r * 0.3, -r * 0.3), r * 0.25, r * 0.15, const Color(0x557A2E14),
          blur: r * 0.1);
      _blob(canvas, c + Offset(0, -r * 0.92), r * 0.4, r * 0.16, const Color(0xEEFFFFFF),
          blur: r * 0.05);
    case 'Jupiter':
      _bands(canvas, c, r, const [
        Color(0xFF9C7550),
        Color(0xFFE9D6B4),
        Color(0xFFC08F5E),
        Color(0xFFF3E6CC),
        Color(0xFFB27A4C),
        Color(0xFFEFDDBD),
        Color(0xFFC9996A),
        Color(0xFFE8D2AD),
        Color(0xFFA27652),
      ], blur: r * 0.04);
      _blob(canvas, c + Offset(r * 0.3, r * 0.32), r * 0.22, r * 0.12, const Color(0xFFF0C7A0));
      _blob(canvas, c + Offset(r * 0.3, r * 0.32), r * 0.17, r * 0.09, const Color(0xFFBF5A36));
    case 'Saturn':
      _bands(canvas, c, r, const [
        Color(0xFFC9AE78),
        Color(0xFFE8D4A6),
        Color(0xFFD9BF8A),
        Color(0xFFF1E3BE),
        Color(0xFFDCC392),
        Color(0xFFEBD9AF),
        Color(0xFFC7AA74),
      ], blur: r * 0.05);
    case 'Uranus':
      _blob(canvas, c + Offset(0, -r * 0.4), r * 0.9, r * 0.25, const Color(0x33FFFFFF), blur: r * 0.15);
    case 'Neptune':
      _blob(canvas, c + Offset(-r * 0.1, -r * 0.35), r * 0.7, r * 0.06, const Color(0x88E8EAF6), blur: r * 0.05);
      _blob(canvas, c + Offset(r * 0.2, r * 0.3), r * 0.6, r * 0.05, const Color(0x66E8EAF6), blur: r * 0.05);
      _blob(canvas, c + Offset(-r * 0.25, r * 0.05), r * 0.2, r * 0.12, const Color(0xFF1A237E));
    case 'Pluto':
      _blob(canvas, c + Offset(-r * 0.4, -r * 0.2), r * 0.4, r * 0.3, const Color(0x668D5B3A), blur: r * 0.1);
      final heart = Path()
        ..moveTo(c.dx + r * 0.15, c.dy + r * 0.6)
        ..cubicTo(c.dx - r * 0.5, c.dy + r * 0.2, c.dx - r * 0.2, c.dy - r * 0.3, c.dx + r * 0.15, c.dy)
        ..cubicTo(c.dx + r * 0.5, c.dy - r * 0.3, c.dx + r * 0.8, c.dy + r * 0.2, c.dx + r * 0.15, c.dy + r * 0.6)
        ..close();
      canvas.drawPath(heart, Paint()..color = const Color(0xFFFFF8EE));
  }

  // Night side
  canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          c + light * (r * 0.1),
          c - light * r,
          const [Color(0x00000000), Color(0xF0000000)],
        ));
  canvas.restore();

  _rings(canvas, p, back: false);

  paintLabel(canvas, visited ? '${p.name} ✓' : p.name,
      c + Offset(0, r + (p.name == 'Saturn' ? 34 : 18)),
      size: 14, color: visited ? Colors.greenAccent : Colors.white70);
}

// ------------------------------------------------------- the solar system

class SpacePainter extends CustomPainter {
  SpacePainter(this.game);
  final SpaceGameModel game;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final full = Offset.zero & size;
    canvas.drawRect(
        full,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF0A0D1C), Color(0xFF020308)],
            radius: 1.2,
          ).createShader(full));
    final cam = game.rocketPos;
    paintMilkyWay(canvas, size, cam);
    paintStars(canvas, size, cam, time: game.time);

    final shakeAmount = game.shake * 15;
    final shake = Offset(math.sin(game.time * 80) * shakeAmount,
        math.cos(game.time * 70) * shakeAmount);

    canvas.save();
    canvas.translate(
        size.width / 2 - cam.dx + shake.dx, size.height / 2 - cam.dy + shake.dy);

    final view = size.longestSide;
    if (cam.distance < view + 1200) paintSun(canvas, game.time);
    paintLabel(canvas, 'THE SUN ☀️', const Offset(0, sunRadius + 30), size: 18);

    // Asteroid belt
    for (final a in game.asteroids) {
      if ((a.position - cam).distance > view) continue;
      final light = -a.position / a.position.distance;
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final ang = i / 8 * math.pi * 2 + game.time * a.spin * 0.6;
        final rr = a.radius * (0.72 + 0.28 * math.sin(i * 2.3 + a.spin * 5));
        final pt = a.position + Offset(math.cos(ang) * rr, math.sin(ang) * rr);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              a.position + light * a.radius,
              a.position - light * a.radius,
              const [Color(0xFFA1887F), Color(0xFF5D4037), Color(0xFF1B1210)],
              const [0, 0.5, 1],
            ));
      canvas.drawCircle(a.position + light * (a.radius * 0.2), a.radius * 0.18,
          Paint()..color = const Color(0x553E2723));
    }
    if ((cam.dx - 2575).abs() < view) {
      paintLabel(canvas, '⚠️ ASTEROID BELT ⚠️', Offset(2575, cam.dy - size.height / 2 + 140),
          size: 16, color: Colors.orangeAccent);
    }

    for (final p in planets) {
      if ((p.position - cam).distance > view + p.radius * 4) continue;
      paintPlanet(canvas, p, visited: game.visited.contains(p.name), time: game.time);
    }

    // Our rocket (blinks after a crash)
    final blink = game.invulnerable > 0 && (game.time * 14).floor().isEven;
    if (!blink) {
      canvas.save();
      canvas.translate(game.rocketPos.dx, game.rocketPos.dy);
      canvas.rotate(game.rocketAngle + math.pi / 2);
      canvas.scale(0.9);
      paintRocket(canvas, flame: game.thrusting, time: game.time, pilot: true);
      canvas.restore();
    }
    canvas.restore();

    paintTemperatureGlow(canvas, size, game.temperature, strength: 0.7);
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
