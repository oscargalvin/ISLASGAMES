import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'art.dart';
import 'planets.dart';
import 'space_model.dart';

/// Height of the ground (in screen pixels) at a spot along the planet.
double surfaceGround(double worldX, Size size, SurfaceInfo info, double time) {
  final base = size.height * 0.78;
  switch (info.style) {
    case GroundStyle.cloud:
      return base + math.sin(worldX / 210 + time * 0.5) * 8 + math.sin(worldX / 70 - time) * 3;
    case GroundStyle.ice:
      return base + math.sin(worldX / 260) * 10 + math.sin(worldX / 90) * 3;
    case GroundStyle.lava:
    case GroundStyle.rock:
      return base + math.sin(worldX / 170) * 14 + math.sin(worldX / 47) * 5;
  }
}

class SurfacePainter extends CustomPainter {
  SurfacePainter(this.game);
  final SpaceGameModel game;

  @override
  void paint(Canvas canvas, Size size) {
    final info = game.surface;
    final planet = game.surfacePlanet;
    if (info == null || planet == null || size.isEmpty) return;
    final t = game.time;
    final full = Offset.zero & size;
    final maxCam = math.max(0.0, SpaceGameModel.surfaceWidth - size.width);
    final cam = (game.astroX - size.width / 2).clamp(0.0, maxCam);
    double ground(double wx) => surfaceGround(wx, size, info, t);
    final horizon = size.height * 0.6;

    // Sky
    canvas.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [info.skyTop, info.skyMid, info.skyBottom],
            stops: [0, 0.45, horizon / size.height],
          ).createShader(full));

    if (info.starAlpha > 0) {
      paintMilkyWay(canvas, Size(size.width, horizon), Offset(cam * 2, 0), alpha: info.starAlpha * 0.8);
      paintStars(canvas, Size(size.width, horizon), Offset(cam * 0.5, 0),
          alpha: info.starAlpha, time: t);
    }

    _sun(canvas, size, info, cam);
    _skyObject(canvas, size, info, cam, t);

    // Far mountains / cloud banks, fading into the haze
    final far = Color.lerp(info.mountains, info.skyBottom, 0.55)!;
    final near = Color.lerp(info.mountains, info.skyBottom, 0.2)!;
    if (info.style == GroundStyle.cloud) {
      _cloudBank(canvas, size, cam * 0.15 - t * 6, size.height * 0.6, far, 70);
      _cloudBank(canvas, size, cam * 0.4 - t * 14, size.height * 0.68, near, 55);
    } else {
      _ridge(canvas, size, cam * 0.15, size.height * 0.6, 40, 300, far, info.style == GroundStyle.ice);
      _ridge(canvas, size, cam * 0.4, size.height * 0.67, 28, 170, near, info.style == GroundStyle.ice);
    }

    // Landmarks that sit far away in the background
    if (info.landmark == 'storm') {
      _storm(canvas, size, info, cam, t, red: planet.name == 'Jupiter');
    }
    if (info.landmark == 'volcano') _volcano(canvas, size, cam, t);

    // Haze near the horizon
    if (info.haze != const Color(0x00000000)) {
      final band = Rect.fromLTRB(0, size.height * 0.35, size.width, size.height * 0.8);
      canvas.drawRect(
          band,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [info.haze.withAlpha(0), info.haze, info.haze.withAlpha(0)],
            ).createShader(band));
    }

    _groundLayer(canvas, size, info, cam, t, ground);

    // Close-up landmarks
    final lx = SpaceGameModel.landmarkX - cam;
    final ly = ground(SpaceGameModel.landmarkX);
    switch (info.landmark) {
      case 'flag':
        _flag(canvas, lx, ly);
      case 'rover':
        _rover(canvas, lx, ly);
      case 'heart':
        _heart(canvas, lx, ly);
      case 'crater':
        _crater(canvas, lx, ly, info);
    }

    // Parked rocket (hovering over gas planets)
    final hover = info.style == GroundStyle.cloud;
    final bob = hover ? math.sin(t * 2) * 4 - 26 : 0.0;
    canvas.save();
    canvas.translate(SpaceGameModel.rocketParkX - cam,
        ground(SpaceGameModel.rocketParkX) - 30 * 2.2 + bob);
    canvas.scale(2.2);
    paintRocket(canvas, flame: hover, time: t);
    canvas.restore();

    // Things to collect
    for (var i = 0; i < SpaceGameModel.itemXs.length; i++) {
      if (game.collected.contains(i)) continue;
      final wx = SpaceGameModel.itemXs[i];
      final c = Offset(
          wx - cam,
          ground(wx) - SpaceGameModel.itemHeight(i, info) - 18 + math.sin(t * 3 + i) * 5);
      canvas.drawCircle(c, 22, blurPaint(info.itemColor.withAlpha(140), 10));
      final gem = Path()
        ..moveTo(c.dx, c.dy - 11)
        ..lineTo(c.dx + 9, c.dy - 2)
        ..lineTo(c.dx, c.dy + 11)
        ..lineTo(c.dx - 9, c.dy - 2)
        ..close();
      canvas.drawPath(
          gem,
          Paint()
            ..shader = LinearGradient(
              colors: [lighter(info.itemColor, 0.5), info.itemColor, darker(info.itemColor, 0.3)],
            ).createShader(Rect.fromCenter(center: c, width: 18, height: 22)));
      canvas.drawPath(
          gem,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }

    // Astronaut
    final feet = Offset(game.astroX - cam, ground(game.astroX) - game.astroY - (hover ? 10 : 0));
    if (!hover && game.astroY <= 0) {
      canvas.drawOval(Rect.fromCenter(center: feet + const Offset(0, 2), width: 34, height: 6),
          Paint()..color = const Color(0x44000000));
    }
    if (hover) {
      final board = Rect.fromCenter(center: feet + const Offset(0, 3), width: 46, height: 8);
      canvas.drawOval(board.inflate(4), blurPaint(const Color(0x8840C4FF), 8));
      canvas.drawOval(board, Paint()..color = const Color(0xFF455A64));
      canvas.drawOval(board.deflate(2), Paint()..color = const Color(0xFF90A4AE));
    }
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(1.3);
    paintAstronaut(canvas,
        walkPhase: game.walkPhase,
        facingRight: game.facingRight,
        walking: game.walking && game.astroY <= 0 && !hover);
    canvas.restore();

    // Gets redder or bluer the longer you stay somewhere extreme
    final stay = (game.timeOnPlanet / 14).clamp(0.3, 1.0);
    if (info.feel == Feel.hot || info.feel == Feel.cold) {
      paintTemperatureGlow(canvas, size, info.temperature, strength: stay);
    }
    if (info.style == GroundStyle.lava) {
      // Heat shimmer over everything on Venus
      canvas.drawRect(full, Paint()..color = const Color(0x22FF6D00));
    }
  }

  // ------------------------------------------------------------ the sky

  void _sun(Canvas canvas, Size size, SurfaceInfo info, double cam) {
    if (info.sunSize <= 0) {
      if (info.style == GroundStyle.lava) {
        // On Venus the Sun is just a bright smudge through the clouds.
        canvas.drawCircle(Offset(size.width * 0.3 - cam * 0.02, size.height * 0.18), 120,
            blurPaint(const Color(0x66FFF3C4), 70));
      }
      return;
    }
    final c = Offset(size.width * 0.22 - cam * 0.02, size.height * (info.sunSize > 40 ? 0.22 : 0.14));
    canvas.drawCircle(c, info.sunSize * 4 + 20, blurPaint(const Color(0x33FFF8E1), info.sunSize * 2 + 10));
    canvas.drawCircle(c, info.sunSize * 1.4 + 3, blurPaint(const Color(0x88FFF8E1), info.sunSize * 0.5 + 3));
    canvas.drawCircle(c, info.sunSize, Paint()..color = const Color(0xFFFFFDF2));
    if (info.sunSize < 8) {
      paintLabel(canvas, 'the Sun', c + const Offset(0, 16), size: 11, color: Colors.white54);
    }
  }

  void _skyObject(Canvas canvas, Size size, SurfaceInfo info, double cam, double t) {
    switch (info.skyObject) {
      case 'earth':
        final c = Offset(size.width * 0.78 - cam * 0.03, size.height * 0.2);
        const r = 34.0;
        final rect = Rect.fromCircle(center: c, radius: r);
        canvas.drawCircle(c, r * 1.15, blurPaint(const Color(0x664FC3F7), 8));
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        canvas.drawRect(rect, Paint()..color = const Color(0xFF1E5FB4));
        _oval(canvas, c + const Offset(-10, -6), 14, 18, const Color(0xFF3F7D3A));
        _oval(canvas, c + const Offset(14, 10), 10, 8, const Color(0xFFC2A36B));
        _oval(canvas, c + const Offset(4, -14), 22, 4, const Color(0xDDFFFFFF));
        _oval(canvas, c + const Offset(-6, 14), 20, 4, const Color(0xDDFFFFFF));
        canvas.drawRect(
            rect,
            Paint()
              ..shader = const LinearGradient(
                colors: [Color(0x00000000), Color(0x00000000), Color(0xDD000000)],
                stops: [0, 0.5, 1],
              ).createShader(rect));
        canvas.restore();
        paintLabel(canvas, 'Earth', c + const Offset(0, 50), size: 12, color: Colors.white60);
      case 'phobos':
        final c = Offset(size.width * 0.7 - cam * 0.03, size.height * 0.16);
        canvas.drawOval(Rect.fromCenter(center: c, width: 18, height: 12),
            Paint()..color = const Color(0xCC6D5A4E));
        paintLabel(canvas, 'Phobos (a Mars moon)', c + const Offset(0, 16), size: 11, color: Colors.white70);
      case 'charon':
        final c = Offset(size.width * 0.72 - cam * 0.03, size.height * 0.2);
        final rect = Rect.fromCircle(center: c, radius: 30);
        canvas.drawCircle(
            c,
            30,
            Paint()
              ..shader = const RadialGradient(
                center: Alignment(-0.5, -0.5),
                colors: [Color(0xFFBDBDBD), Color(0xFF757575), Color(0xFF212121)],
              ).createShader(rect));
        paintLabel(canvas, 'Charon (Pluto\'s moon)', c + const Offset(0, 44), size: 11, color: Colors.white60);
      case 'rings':
        // Saturn's rings arching across the sky
        canvas.save();
        canvas.translate(size.width * 0.5 - cam * 0.02, size.height * 0.95);
        canvas.scale(1, 0.32);
        final bands = [
          (size.width * 0.9, 34.0, const Color(0x55C2AD84)),
          (size.width * 0.82, 50.0, const Color(0x88E2CFA4)),
          (size.width * 0.7, 30.0, const Color(0x55A89470)),
        ];
        for (final b in bands) {
          canvas.drawCircle(
              Offset.zero,
              b.$1,
              Paint()
                ..color = b.$3
                ..style = PaintingStyle.stroke
                ..strokeWidth = b.$2);
        }
        canvas.restore();
      case 'tiltedRings':
        canvas.save();
        canvas.translate(size.width * 0.75 - cam * 0.02, size.height * 0.1);
        canvas.rotate(1.2);
        canvas.scale(1, 0.15);
        canvas.drawCircle(
            Offset.zero,
            size.height * 0.5,
            Paint()
              ..color = const Color(0x44E0F7FA)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10);
        canvas.restore();
    }
  }

  void _oval(Canvas canvas, Offset c, double rx, double ry, Color color) {
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), Paint()..color = color);
  }

  // ------------------------------------------------------ background shapes

  void _ridge(Canvas canvas, Size size, double offset, double baseY, double height, double wavelength,
      Color color, bool snowy) {
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 8; x += 8) {
      final wx = x + offset;
      final y = baseY -
          (math.sin(wx / wavelength) * 0.5 + 0.5) * height -
          (math.sin(wx / (wavelength * 0.37) + 1.3) * 0.5 + 0.5) * height * 0.5 -
          (math.sin(wx / (wavelength * 0.11)) * 0.5 + 0.5) * height * 0.12;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    if (snowy) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(Rect.fromLTRB(0, 0, size.width, baseY - height * 0.95),
          Paint()..color = Colors.white.withAlpha(150));
      canvas.restore();
    }
  }

  void _cloudBank(Canvas canvas, Size size, double offset, double baseY, Color color, double puff) {
    final paint = blurPaint(color, 6);
    final spacing = puff * 0.9;
    final start = -((offset % spacing) + spacing);
    var i = ((offset / spacing).floor());
    for (var x = start; x < size.width + puff; x += spacing) {
      final h = (math.sin(i * 1.7) * 0.5 + 0.5) * puff * 0.5;
      canvas.drawCircle(Offset(x, baseY - h), puff * 0.75, paint);
      i++;
    }
    canvas.drawRect(Rect.fromLTRB(0, baseY, size.width, size.height), Paint()..color = color);
  }

  void _storm(Canvas canvas, Size size, SurfaceInfo info, double cam, double t,
      {required bool red}) {
    final c = Offset(SpaceGameModel.landmarkX * 0.4 - cam * 0.4 + size.width * 0.3, size.height * 0.63);
    if (c.dx < -300 || c.dx > size.width + 300) return;
    final color = red ? const Color(0xFFB4502E) : const Color(0xFF14205E);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, 0.35);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
          Offset(math.cos(t * 0.6 + i) * 8, math.sin(t * 0.6 + i) * 8),
          150 - i * 26,
          blurPaint(Color.lerp(color, info.ground, i / 6)!.withAlpha(150), 14));
    }
    canvas.restore();
  }

  void _volcano(Canvas canvas, Size size, double cam, double t) {
    final x = SpaceGameModel.landmarkX * 0.55 - cam * 0.55 + size.width * 0.25;
    if (x < -300 || x > size.width + 300) return;
    final base = size.height * 0.72;
    final mountain = Path()
      ..moveTo(x - 240, base)
      ..lineTo(x - 40, base - 150)
      ..lineTo(x + 40, base - 150)
      ..lineTo(x + 240, base)
      ..close();
    canvas.drawPath(mountain, Paint()..color = const Color(0xFF4A2C1E));
    // Glowing lava rivers
    final lava = Paint()
      ..color = const Color(0xFFFF6D00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(
        Path()
          ..moveTo(x - 10, base - 150)
          ..quadraticBezierTo(x - 50, base - 80, x - 110, base),
        lava);
    canvas.drawPath(
        Path()
          ..moveTo(x + 15, base - 150)
          ..quadraticBezierTo(x + 40, base - 70, x + 90, base),
        lava);
    canvas.drawCircle(Offset(x, base - 155), 40 + math.sin(t * 3) * 4, blurPaint(const Color(0xAAFF6D00), 20));
    // Smoke
    for (var i = 0; i < 4; i++) {
      final k = ((t * 0.3 + i / 4) % 1.0);
      canvas.drawCircle(Offset(x + k * 40, base - 170 - k * 120), 20 + k * 40,
          blurPaint(Color.fromARGB(((1 - k) * 120).toInt(), 60, 40, 30), 14));
    }
  }

  // -------------------------------------------------------------- ground

  void _groundLayer(Canvas canvas, Size size, SurfaceInfo info, double cam, double t,
      double Function(double) ground) {
    final path = Path()..moveTo(0, size.height);
    for (var sx = 0.0; sx <= size.width + 8; sx += 8) {
      path.lineTo(sx, ground(cam + sx));
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    final rect = Rect.fromLTRB(0, size.height * 0.7, size.width, size.height);
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [info.ground, info.groundDark],
          ).createShader(rect));

    canvas.save();
    canvas.clipPath(path);
    switch (info.style) {
      case GroundStyle.rock:
      case GroundStyle.lava:
        _rocks(canvas, size, info, cam, ground);
        if (info.style == GroundStyle.lava) _lavaCracks(canvas, size, cam, t, ground);
      case GroundStyle.ice:
        _ice(canvas, size, info, cam, ground);
      case GroundStyle.cloud:
        _cloudTops(canvas, size, info, cam, t, ground);
    }
    canvas.restore();

    // Bright edge where the light catches the top of the ground
    if (info.style != GroundStyle.cloud) {
      final edge = Path();
      for (var sx = 0.0; sx <= size.width + 8; sx += 8) {
        final y = ground(cam + sx);
        if (sx == 0) {
          edge.moveTo(sx, y);
        } else {
          edge.lineTo(sx, y);
        }
      }
      canvas.drawPath(
          edge,
          Paint()
            ..color = lighter(info.ground, 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void _rocks(Canvas canvas, Size size, SurfaceInfo info, double cam,
      double Function(double) ground) {
    // Craters
    for (var i = 0; i < 44; i++) {
      final wx = i * 57.0 + (i * 131 % 47);
      final sx = wx - cam;
      if (sx < -80 || sx > size.width + 80) continue;
      final depth = 16.0 + (i % 3) * 14;
      final w = 30.0 + (i % 4) * 16;
      final c = Offset(sx, ground(wx) + depth);
      canvas.drawOval(Rect.fromCenter(center: c, width: w, height: w * 0.22),
          Paint()..color = darker(info.ground, 0.3));
      canvas.drawArc(Rect.fromCenter(center: c, width: w, height: w * 0.22), 0.2, 2.7, false,
          Paint()
            ..color = lighter(info.ground, 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    // Pebbles and boulders, with a lit top and a shadow
    final rnd = math.Random(9);
    for (var i = 0; i < 160; i++) {
      final wx = rnd.nextDouble() * SpaceGameModel.surfaceWidth;
      final dy = 6 + math.pow(rnd.nextDouble(), 2).toDouble() * size.height * 0.2;
      final r = 1.5 + math.pow(rnd.nextDouble(), 3).toDouble() * 9 + dy * 0.03;
      final sx = wx - cam;
      if (sx < -20 || sx > size.width + 20) continue;
      final c = Offset(sx, ground(wx) + dy);
      canvas.drawOval(Rect.fromCenter(center: c + Offset(r * 0.4, r * 0.3), width: r * 2.2, height: r * 1.1),
          Paint()..color = const Color(0x44000000));
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 1.4),
          Paint()..color = darker(info.ground, 0.15));
      canvas.drawOval(Rect.fromCenter(center: c - Offset(r * 0.25, r * 0.25), width: r * 1.1, height: r * 0.6),
          Paint()..color = lighter(info.ground, 0.15));
    }
  }

  void _lavaCracks(Canvas canvas, Size size, double cam, double t, double Function(double) ground) {
    final glow = 0.6 + 0.4 * math.sin(t * 2);
    final crack = Paint()
      ..color = Color.fromARGB((200 * glow).toInt(), 255, 110, 20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final rnd = math.Random(4);
    for (var i = 0; i < 28; i++) {
      final wx = rnd.nextDouble() * SpaceGameModel.surfaceWidth;
      final sx = wx - cam;
      if (sx < -80 || sx > size.width + 80) continue;
      var p = Offset(sx, ground(wx) + 20 + rnd.nextDouble() * size.height * 0.15);
      final path = Path()..moveTo(p.dx, p.dy);
      for (var j = 0; j < 4; j++) {
        p += Offset(12 + rnd.nextDouble() * 20, (rnd.nextDouble() - 0.5) * 14);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, crack);
    }
  }

  void _ice(Canvas canvas, Size size, SurfaceInfo info, double cam, double Function(double) ground) {
    final rnd = math.Random(6);
    // Smooth nitrogen-ice streaks
    for (var i = 0; i < 40; i++) {
      final wx = rnd.nextDouble() * SpaceGameModel.surfaceWidth;
      final sx = wx - cam;
      if (sx < -120 || sx > size.width + 120) continue;
      final c = Offset(sx, ground(wx) + 10 + rnd.nextDouble() * size.height * 0.18);
      canvas.drawOval(Rect.fromCenter(center: c, width: 60 + rnd.nextDouble() * 80, height: 5),
          Paint()..color = const Color(0x55FFFFFF));
    }
    // Reddish tholin patches
    for (var i = 0; i < 18; i++) {
      final wx = rnd.nextDouble() * SpaceGameModel.surfaceWidth;
      final sx = wx - cam;
      if (sx < -120 || sx > size.width + 120) continue;
      final c = Offset(sx, ground(wx) + 20 + rnd.nextDouble() * size.height * 0.15);
      canvas.drawOval(Rect.fromCenter(center: c, width: 70, height: 12),
          blurPaint(const Color(0x448D5B3A), 6));
    }
    // Ice chunks
    for (var i = 0; i < 50; i++) {
      final wx = rnd.nextDouble() * SpaceGameModel.surfaceWidth;
      final sx = wx - cam;
      if (sx < -20 || sx > size.width + 20) continue;
      final r = 2 + rnd.nextDouble() * 6;
      final c = Offset(sx, ground(wx) + 6 + rnd.nextDouble() * size.height * 0.18);
      final chunk = Path()
        ..moveTo(c.dx - r, c.dy)
        ..lineTo(c.dx - r * 0.3, c.dy - r)
        ..lineTo(c.dx + r, c.dy - r * 0.4)
        ..lineTo(c.dx + r * 0.7, c.dy)
        ..close();
      canvas.drawPath(chunk, Paint()..color = const Color(0xFFDDEBF7));
    }
  }

  void _cloudTops(Canvas canvas, Size size, SurfaceInfo info, double cam, double t,
      double Function(double) ground) {
    // Swirling stripes of cloud drifting past
    for (var i = 0; i < 7; i++) {
      final y = size.height * 0.8 + i * size.height * 0.035;
      final drift = (t * (12 + i * 5) + cam * (0.8 + i * 0.05)) % 400;
      final color = i.isEven ? lighter(info.ground, 0.15) : darker(info.ground, 0.12);
      for (var x = -drift; x < size.width + 400; x += 400) {
        canvas.drawOval(Rect.fromLTWH(x, y, 300, size.height * 0.03), blurPaint(color.withAlpha(150), 6));
      }
    }
    // Fluffy puffs along the top
    final puff = blurPaint(lighter(info.ground, 0.2), 5);
    for (var sx = -40.0; sx <= size.width + 40; sx += 34) {
      final wx = cam + sx;
      canvas.drawCircle(Offset(sx, ground(wx) + 14), 22 + math.sin(wx / 30 + t) * 4, puff);
    }
  }

  // ----------------------------------------------------- close-up landmarks

  void _flag(Canvas canvas, double x, double gy) {
    canvas.drawLine(Offset(x, gy), Offset(x, gy - 90),
        Paint()
          ..color = Colors.grey.shade300
          ..strokeWidth = 3);
    canvas.drawLine(Offset(x, gy - 90), Offset(x + 50, gy - 90),
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 2);
    for (var i = 0; i < 5; i++) {
      canvas.drawRect(Rect.fromLTWH(x + 2, gy - 88 + i * 6, 48, 6),
          Paint()..color = i.isEven ? const Color(0xFFE53935) : Colors.white);
    }
    canvas.drawRect(Rect.fromLTWH(x + 2, gy - 88, 18, 18), Paint()..color = const Color(0xFF283593));
    // Footprints
    for (var i = 0; i < 6; i++) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x - 30 - i * 22, gy + 6 + (i % 2) * 6), width: 10, height: 4),
          Paint()..color = const Color(0x55000000));
    }
  }

  void _rover(Canvas canvas, double x, double gy) {
    final body = Paint()..color = const Color(0xFFDADFE3);
    final dark = Paint()..color = const Color(0xFF37474F);
    canvas.drawRect(Rect.fromLTWH(x - 40, gy - 48, 80, 24), body);
    canvas.drawRect(Rect.fromLTWH(x - 50, gy - 54, 100, 6), Paint()..color = const Color(0xFF263238));
    canvas.drawLine(Offset(x + 25, gy - 54), Offset(x + 25, gy - 84),
        Paint()
          ..color = const Color(0xFFCFD8DC)
          ..strokeWidth = 4);
    canvas.drawRect(Rect.fromLTWH(x + 15, gy - 96, 22, 13), body);
    canvas.drawCircle(Offset(x + 31, gy - 90), 3, dark);
    canvas.drawLine(Offset(x - 40, gy - 24), Offset(x - 30, gy - 12),
        Paint()
          ..color = const Color(0xFF90A4AE)
          ..strokeWidth = 3);
    for (final wx in [-32.0, 0.0, 32.0]) {
      canvas.drawCircle(Offset(x + wx, gy - 11), 11, dark);
      canvas.drawCircle(Offset(x + wx, gy - 11), 4, body);
    }
    // Wheel tracks
    canvas.drawLine(Offset(x - 50, gy + 4), Offset(x - 200, gy + 8),
        Paint()
          ..color = const Color(0x55000000)
          ..strokeWidth = 3);
  }

  void _heart(Canvas canvas, double x, double gy) {
    canvas.save();
    canvas.translate(x, gy + 14);
    canvas.scale(1.2, 0.3);
    final heart = Path()
      ..moveTo(0, 60)
      ..cubicTo(-110, -10, -60, -90, 0, -40)
      ..cubicTo(60, -90, 110, -10, 0, 60)
      ..close();
    canvas.drawPath(heart, Paint()..color = const Color(0xFFFFFDF7));
    canvas.drawPath(
        heart,
        Paint()
          ..color = const Color(0xFFBFD7EA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    canvas.restore();
  }

  void _crater(Canvas canvas, double x, double gy, SurfaceInfo info) {
    final rect = Rect.fromCenter(center: Offset(x, gy + 18), width: 260, height: 40);
    canvas.drawOval(rect, Paint()..color = darker(info.ground, 0.35));
    canvas.drawArc(rect, math.pi, math.pi, false,
        Paint()
          ..color = lighter(info.ground, 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
