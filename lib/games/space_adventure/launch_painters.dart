import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art.dart';
import 'space_model.dart';

// --------------------------------------------------------- launch pad scene

class LaunchPadPainter extends CustomPainter {
  LaunchPadPainter(this.game,
      {required this.rocketX, required this.groundY, required this.roomWidth});
  final SpaceGameModel game;

  /// Where the rocket stands, as fractions of the screen size.
  final double rocketX, groundY;

  /// How much of the screen width the scene can use (the rest has the list).
  final double roomWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final full = Offset.zero & size;
    final gy = size.height * groundY;
    final s = math.min(size.height * 0.0055, size.width * roomWidth / 250).clamp(1.0, 3.4);
    final rx = size.width * rocketX;
    final horizon = gy - 26 * s;

    // Morning sky
    canvas.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF2D69B3), Color(0xFF7FB2E3), Color(0xFFF4DCBC)],
            stops: [
              0,
              (horizon / size.height).clamp(0.0, 1.0) * 0.7,
              (horizon / size.height).clamp(0.0, 1.0),
            ],
          ).createShader(full));

    // Low sun
    final sun = Offset(size.width * 0.08, horizon - size.height * 0.28);
    canvas.drawCircle(sun, 90, blurPaint(const Color(0x66FFE0B2), 60));
    canvas.drawCircle(sun, 26, blurPaint(const Color(0xFFFFF8E1), 6));

    // Soft clouds drifting by
    for (var i = 0; i < 6; i++) {
      final x = ((i * 0.21 + game.time * 0.006) % 1.3 - 0.15) * size.width;
      final y = size.height * (0.07 + (i % 3) * 0.08);
      final w = 90.0 + (i % 3) * 50;
      final cloud = blurPaint(Colors.white.withAlpha(170), 14);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.3), cloud);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x + w * 0.2, y - w * 0.1), width: w * 0.55, height: w * 0.3),
          cloud);
    }

    // Distant hills, the sea, then the scrubby ground of the launch site
    final hills = Path()..moveTo(0, horizon);
    for (var x = 0.0; x <= size.width + 10; x += 10) {
      hills.lineTo(x, horizon - 10 * s - math.sin(x / 140) * 6 * s - math.sin(x / 47) * 2 * s);
    }
    hills
      ..lineTo(size.width, horizon)
      ..close();
    canvas.drawPath(hills, Paint()..color = const Color(0xFF8DA6A0));
    canvas.drawRect(Rect.fromLTRB(0, horizon - 1, size.width, horizon + 5 * s),
        Paint()..color = const Color(0xFF4F82A8));
    final groundRect = Rect.fromLTRB(0, horizon + 5 * s, size.width, size.height);
    canvas.drawRect(
        groundRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8FA567), Color(0xFF5E7A3C)],
          ).createShader(groundRect));
    final tuft = Paint()..color = const Color(0xFF4E6A31);
    for (var i = 0; i < 70; i++) {
      final x = (i * 97.0) % size.width;
      final y = horizon + 8 * s + ((i * 53) % 100) / 100 * (size.height - horizon);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 10, height: 3), tuft);
    }

    // Concrete apron and flame trench
    canvas.drawRect(Rect.fromLTRB(rx - 132 * s, gy - 3 * s, rx + 112 * s, gy + 16 * s),
        Paint()..color = const Color(0xFFBDB8AE));
    canvas.drawRect(Rect.fromLTRB(rx - 132 * s, gy + 14 * s, rx + 112 * s, gy + 16 * s),
        Paint()..color = const Color(0xFF8D877C));
    canvas.drawRect(Rect.fromLTRB(rx - 16 * s, gy - 3 * s, rx + 16 * s, gy + 10 * s),
        Paint()..color = const Color(0xFF3E3A35));

    _tower(canvas, s, rx, gy);
    _truck(canvas, s, rx, gy);
    _oxygen(canvas, s, rx, gy);
    _snacks(canvas, s, rx, gy);
    _hut(canvas, s, rx, gy);

    // Smoke
    final launching = game.phase == Phase.countdown && game.countdown < 1.5;
    if (launching) {
      final k = (1.5 - game.countdown) + game.liftoff * 1.5;
      for (var i = 0; i < 11; i++) {
        final dx = (i - 5) * 13 * s * (0.6 + k * 0.5);
        canvas.drawCircle(
            Offset(rx + dx, gy - 4 * s - (i % 3) * 4 * s),
            (6 + k * 8 + (i % 3) * 3) * s,
            blurPaint(Colors.white.withAlpha(215), 6));
      }
    }

    // Rocket (on a pad 8 units tall)
    final padTop = gy - 8 * s;
    canvas.drawRect(Rect.fromLTRB(rx - 22 * s, padTop, rx + 22 * s, gy - 3 * s),
        Paint()..color = const Color(0xFF616161));
    final lift = game.liftoff * game.liftoff * 260;
    final shaking = game.phase == Phase.countdown && game.countdown < 2.5;
    final shakeX = shaking ? math.sin(game.time * 60) * 1.5 * s : 0.0;
    canvas.save();
    canvas.translate(rx + shakeX, padTop - 30 * s - lift);
    canvas.scale(s);
    paintRocket(canvas,
        flame: game.phase == Phase.countdown && game.countdown < 1.2,
        time: game.time,
        hatchOpen: !game.hatchClosed,
        pilot: game.personInside);
    canvas.restore();

    // Fuel hose while filling up
    if (game.activeJob == 0 && game.atStep) {
      final from = Offset(rx + (-100 + 14) * s, gy - 12 * s);
      final to = Offset(rx - 12 * s, padTop - 18 * s);
      final hose = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo((from.dx + to.dx) / 2, gy + 4 * s, to.dx, to.dy);
      canvas.drawPath(
          hose,
          Paint()
            ..color = const Color(0xFF212121)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * s);
    }

    _person(canvas, s, rx, gy);
    _gauge(canvas, s, rx, gy);
  }

  void _tower(Canvas canvas, double s, double rx, double gy) {
    final red = Paint()
      ..color = const Color(0xFFC0392B)
      ..strokeWidth = 1.2 * s
      ..style = PaintingStyle.stroke;
    final tl = rx + 34 * s, tr = rx + 46 * s, tt = gy - 84 * s;
    canvas.drawLine(Offset(tl, gy), Offset(tl, tt), red);
    canvas.drawLine(Offset(tr, gy), Offset(tr, tt), red);
    for (var y = gy; y > tt; y -= 8 * s) {
      canvas.drawLine(Offset(tl, y), Offset(tr, y - 8 * s), red);
      canvas.drawLine(Offset(tr, y), Offset(tl, y - 8 * s), red);
      canvas.drawLine(Offset(tl, y), Offset(tr, y), red);
    }
    canvas.drawLine(Offset((tl + tr) / 2, tt), Offset((tl + tr) / 2, tt - 16 * s),
        Paint()
          ..color = const Color(0xFF9E9E9E)
          ..strokeWidth = 0.8 * s);
    canvas.drawCircle(Offset((tl + tr) / 2, tt - 16 * s), 1.4 * s,
        Paint()..color = Color.lerp(Colors.red, Colors.white, (math.sin(game.time * 4) + 1) / 2)!);

    // Swing arm to the hatch
    if (game.liftoff <= 0) {
      final armY = gy - 8 * s - 35 * s;
      canvas.drawRect(Rect.fromLTRB(rx + 12 * s, armY - 2 * s, tl, armY + 2 * s),
          Paint()..color = const Color(0xFF7F8C8D));
    }

    // Elevator platform
    final lift = game.personInside ? Pad.liftHeight : game.personLift;
    final py = gy - lift * s;
    canvas.drawRect(Rect.fromLTRB(tl - 6 * s, py - 1.5 * s, tr + 2 * s, py),
        Paint()..color = const Color(0xFF455A64));
  }

  void _truck(Canvas canvas, double s, double rx, double gy) {
    final x = rx + Pad.truckX * s;
    final tank = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 24 * s, gy - 20 * s, x + 12 * s, gy - 6 * s), Radius.circular(7 * s));
    canvas.drawRRect(
        tank,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFB0BEC5)],
          ).createShader(tank.outerRect));
    paintLabel(canvas, 'FUEL', Offset(x - 6 * s, gy - 13 * s), size: 4 * s, color: const Color(0xFFD32F2F));
    final cab = Rect.fromLTRB(x + 13 * s, gy - 17 * s, x + 25 * s, gy - 5 * s);
    canvas.drawRRect(RRect.fromRectAndRadius(cab, Radius.circular(2 * s)),
        Paint()..color = const Color(0xFFE53935));
    canvas.drawRect(Rect.fromLTRB(x + 18 * s, gy - 15 * s, x + 24 * s, gy - 10 * s),
        Paint()..color = const Color(0xFF90CAF9));
    canvas.drawRect(Rect.fromLTRB(x - 26 * s, gy - 7 * s, x + 25 * s, gy - 4 * s),
        Paint()..color = const Color(0xFF37474F));
    for (final wx in [-16.0, 0.0, 19.0]) {
      canvas.drawCircle(Offset(x + wx * s, gy - 3 * s), 3.2 * s, Paint()..color = const Color(0xFF212121));
      canvas.drawCircle(Offset(x + wx * s, gy - 3 * s), 1.3 * s, Paint()..color = const Color(0xFF9E9E9E));
    }
  }

  void _oxygen(Canvas canvas, double s, double rx, double gy) {
    final taken = game.checklistDone.contains(1) ||
        (game.activeJob == 1 && (game.stepIndex >= 1 || game.stepProgress > 0.5));
    final count = taken ? 2 : 3;
    for (var i = 0; i < count; i++) {
      final x = rx + (Pad.oxygenX - 6 + i * 6) * s;
      final r = RRect.fromRectAndRadius(
          Rect.fromLTRB(x - 2.5 * s, gy - 15 * s, x + 2.5 * s, gy - 3 * s), Radius.circular(2.5 * s));
      canvas.drawRRect(
          r,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047), Color(0xFF1B5E20)],
            ).createShader(r.outerRect));
      canvas.drawRect(Rect.fromLTRB(x - 1 * s, gy - 17 * s, x + 1 * s, gy - 15 * s),
          Paint()..color = const Color(0xFFB0BEC5));
    }
    paintLabel(canvas, 'O₂', Offset(rx + Pad.oxygenX * s, gy - 21 * s), size: 4 * s);
  }

  void _snacks(Canvas canvas, double s, double rx, double gy) {
    final x = rx + Pad.snacksX * s;
    final taken = game.checklistDone.contains(2) ||
        (game.activeJob == 2 && (game.stepIndex >= 1 || game.stepProgress > 0.5));
    canvas.drawRect(Rect.fromLTRB(x - 7 * s, gy - 5 * s, x + 7 * s, gy - 3 * s),
        Paint()..color = const Color(0xFF8D6E63));
    if (!taken) {
      canvas.drawRect(Rect.fromLTRB(x - 6 * s, gy - 14 * s, x + 6 * s, gy - 5 * s),
          Paint()..color = const Color(0xFFB07A44));
      canvas.drawRect(Rect.fromLTRB(x - 6 * s, gy - 10 * s, x + 6 * s, gy - 9 * s),
          Paint()..color = const Color(0xFF7B5228));
      paintLabel(canvas, '🍕', Offset(x, gy - 9.5 * s), size: 4.5 * s);
    }
  }

  void _hut(Canvas canvas, double s, double rx, double gy) {
    final x = rx + Pad.hutX * s;
    final wall = Rect.fromLTRB(x - 11 * s, gy - 28 * s, x + 11 * s, gy - 3 * s);
    canvas.drawRect(wall, Paint()..color = const Color(0xFFECEFF1));
    canvas.drawPath(
        Path()
          ..moveTo(x - 13 * s, gy - 28 * s)
          ..lineTo(x, gy - 35 * s)
          ..lineTo(x + 13 * s, gy - 28 * s)
          ..close(),
        Paint()..color = const Color(0xFF546E7A));
    final changing = game.activeJob == 3 &&
        game.atStep &&
        game.stepProgress > 0.15 &&
        game.stepProgress < 0.85;
    canvas.drawRect(Rect.fromLTRB(x - 5 * s, gy - 18 * s, x + 5 * s, gy - 3 * s),
        Paint()..color = changing ? const Color(0xFF263238) : const Color(0xFF90A4AE));
    paintLabel(canvas, 'SUITS', Offset(x, gy - 23 * s), size: 3.6 * s, color: const Color(0xFF37474F));
    if (changing) {
      for (var i = 0; i < 5; i++) {
        final a = game.time * 3 + i * 1.25;
        paintLabel(canvas, '✨',
            Offset(x + math.cos(a) * 9 * s, gy - 14 * s + math.sin(a) * 7 * s),
            size: 3.5 * s);
      }
    }
  }

  void _person(Canvas canvas, double s, double rx, double gy) {
    if (game.personInside) return;
    final step = game.activeStep;
    final action = game.atStep ? step?.action : null;
    final p = game.stepProgress;
    if (action == 'suit' && p > 0.15 && p < 0.85) return; // inside the hut

    var arm = 0.0;
    if (action == 'fuel') arm = -1.0;
    if (action == 'load') arm = -1.3;
    if (action == 'pickup') arm = 0.5;
    if (action == 'wrench') arm = -0.6 + math.sin(game.time * 14) * 0.5;

    final pos = Offset(rx + game.personX * s, gy - 3 * s - game.personLift * s);
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(s * 0.36);
    final suitOn = game.suited || (action == 'suit' && p >= 0.85);
    if (suitOn) {
      paintAstronaut(canvas,
          walkPhase: game.personWalkPhase,
          facingRight: game.personFacingRight,
          walking: game.personWalking,
          carry: game.carrying,
          armSwing: arm);
    } else {
      paintCrew(canvas,
          walkPhase: game.personWalkPhase,
          facingRight: game.personFacingRight,
          walking: game.personWalking,
          carry: game.carrying,
          armSwing: arm);
    }
    canvas.restore();

    if (action == 'wrench' && (game.time * 8).floor().isEven) {
      final spark = pos + Offset(9 * s, -10 * s);
      for (var i = 0; i < 4; i++) {
        final a = i * 1.6 + game.time * 20;
        canvas.drawLine(spark, spark + Offset(math.cos(a) * 3 * s, math.sin(a) * 3 * s),
            Paint()
              ..color = const Color(0xFFFFEB3B)
              ..strokeWidth = 0.6 * s);
      }
    }
  }

  void _gauge(Canvas canvas, double s, double rx, double gy) {
    final gx = rx - 22 * s;
    final rect = Rect.fromLTRB(gx - 2.5 * s, gy - 70 * s, gx + 2.5 * s, gy - 46 * s);
    final level = game.fuelLevel;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(2 * s)),
        Paint()..color = Colors.black38);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(rect.left, rect.bottom - rect.height * level, rect.right, rect.bottom),
            Radius.circular(2 * s)),
        Paint()..color = level >= 1 ? Colors.greenAccent : Colors.orangeAccent);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(2 * s)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6 * s);
    paintLabel(canvas, '⛽', Offset(gx, rect.top - 4 * s), size: 4 * s);
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
    if (size.isEmpty) return;
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
            Color.lerp(const Color(0xFF3F7FCB), const Color(0xFF010208), dark)!,
            Color.lerp(const Color(0xFFCFE6F7), const Color(0xFF070B1E), dark)!,
          ],
        ).createShader(full),
    );

    final cam = Offset(game.flightRocketX * 80, -t * 1600);
    paintMilkyWay(canvas, size, Offset(game.flightRocketX * 80, 0), alpha: dark);
    paintStars(canvas, size, cam, alpha: dark, time: game.time);

    // Clouds rushing past at the start
    if (t < 9) {
      final alpha = ((1 - t / 9) * 220).toInt();
      for (var i = 0; i < 8; i++) {
        final x = ((i * 0.37) % 1.0) * size.width;
        final y = -220 + i * 110 + t * 420;
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 200, height: 56),
            blurPaint(Colors.white.withAlpha(alpha), 16));
      }
    }

    // Earth getting smaller below us
    if (t > 4) {
      final k = ((t - 4) / 32).clamp(0.0, 1.0);
      final r = size.width * 1.5 + (size.width * 0.12 - size.width * 1.5) * k;
      final visible = 60 + (r * 1.6 - 60) * k;
      final center = Offset(size.width / 2, size.height + r - visible);
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawCircle(center, r * 1.04, blurPaint(const Color(0xAA4FC3F7), r * 0.05 + 6));
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.3, -0.6),
              colors: [Color(0xFF4A90D9), Color(0xFF0D3B7A)],
            ).createShader(rect));
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      final land = Paint()..color = const Color(0xFF4E7D3A);
      canvas.drawOval(
          Rect.fromCenter(center: center + Offset(-r * 0.3, -r * 0.62), width: r * 0.7, height: r * 0.4),
          land);
      canvas.drawOval(
          Rect.fromCenter(center: center + Offset(r * 0.42, -r * 0.75), width: r * 0.4, height: r * 0.25),
          Paint()..color = const Color(0xFFB59B6A));
      final cloud = blurPaint(Colors.white.withAlpha(190), r * 0.02 + 2);
      for (var i = 0; i < 7; i++) {
        final a = -math.pi / 2 + (i - 3) * 0.28;
        canvas.drawOval(
            Rect.fromCenter(
                center: center + Offset(math.cos(a) * r * 0.82, math.sin(a) * r * 0.82),
                width: r * 0.3,
                height: r * 0.06),
            cloud);
      }
      // Night side shadow
      canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x00000000), Color(0x00000000), Color(0xAA000000)],
              stops: [0, 0.55, 1],
            ).createShader(rect));
      canvas.restore();
    }

    // Space station flying by
    if (t > 18 && t < 30) {
      final k = (t - 18) / 12;
      final c = Offset(size.width * (1.1 - k * 1.3), size.height * 0.25);
      final panel = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
        ).createShader(Rect.fromCenter(center: c, width: 140, height: 24));
      canvas.drawLine(c + const Offset(-62, 0), c + const Offset(62, 0),
          Paint()
            ..color = Colors.grey
            ..strokeWidth = 2);
      for (final dx in [-46.0, -28.0, 28.0, 46.0]) {
        canvas.drawRect(Rect.fromCenter(center: c + Offset(dx, 0), width: 14, height: 30), panel);
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 34, height: 12), const Radius.circular(4)),
          Paint()..color = Colors.grey.shade300);
    }

    final s = (size.height * 0.004).clamp(1.4, 2.6);
    canvas.save();
    canvas.translate(size.width / 2 + game.flightRocketX * size.width * 0.3,
        size.height * 0.55 + math.sin(game.time * 3) * 6);
    canvas.scale(s);
    paintRocket(canvas, flame: true, time: game.time, pilot: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
