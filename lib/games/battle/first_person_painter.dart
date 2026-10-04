import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'battle_model.dart';
import 'battle_painter.dart';

/// Draws the island through your soldier's eyes, like a classic shooter:
/// walls are drawn a column at a time, people and trees are flat cut-outs.
class FirstPersonPainter extends CustomPainter {
  FirstPersonPainter(this.game, this.time);

  final BattleGame game;
  final double time;

  static const _fov = 1.2;
  static const _far = 1800.0;
  static const _haze = Color(0xFFBFD3DC);

  @override
  void paint(Canvas canvas, Size size) {
    final me = game.watching;
    final eye = me.pos;
    final dir = me.aim;
    final fwd = Offset(math.cos(dir), math.sin(dir));
    final right = Offset(-fwd.dy, fwd.dx);
    final w = size.width;
    final h = size.height;
    final focal = (w / 2) / math.tan(_fov / 2);
    final eyeH = 58 + me.altitude * 220;
    final horizon = h * 0.5;

    // Sky and ground.
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, horizon),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, horizon),
              [const Color(0xFF5E93CC), const Color(0xFFCFE2EE)]));
    canvas.drawRect(
        Rect.fromLTWH(0, horizon, w, h - horizon),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, horizon), Offset(0, h), [
            const Color(0xFF8C9C6E),
            const Color(0xFF5F7C38),
            const Color(0xFF46622A)
          ], [
            0,
            0.25,
            1
          ]));
    // The sea far away.
    canvas.drawRect(Rect.fromLTWH(0, horizon - 1, w, h * 0.012),
        Paint()..color = const Color(0xFF3C7FA0));
    // Grass texture streaks rushing past as you move.
    final streak = Paint()..color = Colors.black.withValues(alpha: 0.06);
    for (var k = 1; k < 14; k++) {
      final d = 40.0 * k * k;
      final along = (eye.dx * fwd.dx + eye.dy * fwd.dy);
      final phase = ((along % 160) / 160);
      final dd = d - phase * 40 * k;
      if (dd < 20) continue;
      final y = horizon + eyeH * focal / dd;
      if (y > h) continue;
      canvas.drawRect(
          Rect.fromLTWH(0, y, w, math.max(1, 3 * focal / dd)), streak);
    }

    final items = <(double, void Function())>[];

    // Walls: buildings, containers, crates and low walls.
    final near = game.blocks
        .where((b) => (b.rect.center - eye).distance < _far + 200)
        .toList();
    final cols = math.min(320, (w / 3).round());
    final colW = w / cols;
    for (var i = 0; i < cols; i++) {
      final offset = (i + 0.5 - cols / 2) * colW;
      final a = dir + math.atan(offset / focal);
      final ray = Offset(math.cos(a), math.sin(a)) * _far;
      final cosFix = math.cos(a - dir);
      final hits = <(double, Block, double, bool)>[];
      for (final b in near) {
        final t = BattleGame.segRect(eye, ray, b.rect);
        if (t == null || t <= 0) continue;
        final p = eye + ray * t;
        final xFace = (p.dx - b.rect.left).abs() < 0.5 ||
            (p.dx - b.rect.right).abs() < 0.5;
        hits.add((t * _far, b, xFace ? p.dy : p.dx, xFace));
      }
      hits.sort((x, y) => x.$1.compareTo(y.$1));
      for (final (dist, b, u, xFace) in hits) {
        final perp = dist * cosFix;
        final x = i * colW;
        items.add((
          perp,
          () => _slice(canvas, x, colW + 1, perp, dist, b, u, xFace, horizon,
              eyeH, focal)
        ));
        if (_wallHeight(b) > eyeH) break; // Can't see past a tall wall.
      }
      // The storm wall.
      final st = _stormHit(eye, Offset(math.cos(a), math.sin(a)));
      if (st != null && st < _far) {
        final perp = st * cosFix;
        final x = i * colW;
        items.add((
          perp,
          () {
            final top = horizon + (eyeH - 420) * focal / perp;
            final bottom = horizon + eyeH * focal / perp;
            canvas.drawRect(
                Rect.fromLTRB(x, top, x + colW + 1, bottom),
                Paint()
                  ..color = const Color(0xFF7A3FD0).withValues(alpha: 0.2));
          }
        ));
      }
    }

    // Cut-outs: people, trees, rocks, loot, effects.
    void sprite(Offset p, void Function(Offset base, double scale) draw,
        [double radius = 60]) {
      final rel = p - eye;
      final depth = rel.dx * fwd.dx + rel.dy * fwd.dy;
      if (depth < 12 || depth > _far) return;
      final side = rel.dx * right.dx + rel.dy * right.dy;
      final sx = w / 2 + side * focal / depth;
      final s = focal / depth;
      if (sx + radius * s < 0 || sx - radius * s > w) return;
      items.add((depth, () => draw(Offset(sx, horizon + eyeH * s), s)));
    }

    for (final b in game.blobs) {
      if ((b.center - eye).distance > _far) continue;
      switch (b.kind) {
        case RoundKind.tree:
          sprite(
              b.center, (base, s) => _tree(canvas, base, s, b), b.radius * 1.5);
        case RoundKind.rock:
          sprite(
              b.center, (base, s) => _rock(canvas, base, s, b), b.radius * 1.5);
        case RoundKind.bush:
          sprite(
              b.center, (base, s) => _bush(canvas, base, s, b), b.radius * 1.5);
      }
    }
    for (final p in game.pickups) {
      if ((p.pos - eye).distance > 900) continue;
      sprite(p.pos, (base, s) => _pickup(canvas, base, s, p));
    }
    for (final f in game.fighters) {
      if (f == me || !f.alive) continue;
      sprite(f.pos, (base, s) => _soldier(canvas, base, s, f, horizon, eyeH));
    }
    for (final b in game.bullets) {
      if (b.owner == me) continue;
      sprite(b.pos, (base, s) {
        canvas.drawCircle(base - Offset(0, 45 * s), math.max(1.5, 3 * s),
            Paint()..color = const Color(0xFFFFF0B0));
      });
    }
    for (final r in game.rockets) {
      sprite(r.pos, (base, s) {
        canvas.drawCircle(
            base - Offset(0, 45 * s),
            math.max(3, 12 * s),
            Paint()
              ..color = const Color(0xFFFFA733)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      });
    }
    for (final e in game.fx) {
      if (e.kind != FxKind.explosion && e.kind != FxKind.smoke) continue;
      sprite(e.pos, (base, s) {
        final t = e.t;
        if (e.kind == FxKind.explosion) {
          final r = e.size * (0.35 + 0.65 * math.sqrt(t)) * s;
          final c = base - Offset(0, r * 0.6);
          canvas.drawCircle(
              c,
              r,
              Paint()
                ..shader = ui.Gradient.radial(c, r, [
                  Colors.white.withValues(alpha: 1 - t),
                  const Color(0xFFFFC233).withValues(alpha: 1 - t),
                  const Color(0xFFFF5A1A).withValues(alpha: 0),
                ], [
                  0,
                  0.35,
                  1
                ]));
        } else {
          canvas.drawCircle(
              base - Offset(0, (30 + t * 60) * s),
              e.size * (0.6 + t * 1.4) * s,
              Paint()
                ..color =
                    const Color(0xFF7A7672).withValues(alpha: 0.4 * (1 - t)));
        }
      }, 200);
    }

    items.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (_, draw) in items) {
      draw();
    }

    _hands(canvas, size, me);

    // Crosshair.
    final c = size.center(Offset.zero);
    final cross = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    final spread = 6.0 + me.recoil * 8;
    for (final d in [
      const Offset(1, 0),
      const Offset(-1, 0),
      const Offset(0, 1),
      const Offset(0, -1)
    ]) {
      canvas.drawLine(c + d * spread, c + d * (spread + 9), cross);
    }
    canvas.drawCircle(c, 1.5, cross);
  }

  double? _stormHit(Offset eye, Offset d) {
    final f = eye - game.stormCenter;
    final b = 2 * (f.dx * d.dx + f.dy * d.dy);
    final c = f.distanceSquared - game.stormRadius * game.stormRadius;
    final disc = b * b - 4 * c;
    if (disc < 0) return null;
    final s = math.sqrt(disc);
    final t1 = (-b - s) / 2;
    final t2 = (-b + s) / 2;
    if (c < 0) return t2; // Inside: the wall ahead.
    if (t1 > 0) return t1;
    return null;
  }

  static double _wallHeight(Block b) => switch (b.kind) {
        BoxKind.building => 140 + 90 * b.height,
        BoxKind.container => 78,
        BoxKind.crate => 44,
        BoxKind.wall => 40,
      };

  Color _fog(Color c, double dist) =>
      Color.lerp(c, _haze, math.pow((dist / _far).clamp(0, 1), 1.3) * 0.85)!;

  void _slice(
      Canvas canvas,
      double x,
      double width,
      double perp,
      double dist,
      Block b,
      double u,
      bool xFace,
      double horizon,
      double eyeH,
      double focal) {
    final wallH = _wallHeight(b);
    final s = focal / perp;
    double y(double worldY) => horizon + (eyeH - worldY) * s;
    final top = y(wallH);
    final bottom = y(0);
    var base = Color(b.color);
    if (b.kind == BoxKind.container)
      base = Color.lerp(base, Colors.black, 0.1)!;
    final lit = xFace ? Color.lerp(base, Colors.black, 0.22)! : base;
    final rect = Rect.fromLTRB(x, top, x + width, bottom);
    canvas.drawRect(rect, Paint()..color = _fog(lit, dist));

    switch (b.kind) {
      case BoxKind.building:
        // Windows on each floor.
        final band = u % 70;
        if (band > 18 && band < 46) {
          final glass = _fog(const Color(0xFF39495A), dist);
          for (var floor = 0.0; floor + 70 < wallH; floor += 80) {
            canvas.drawRect(
                Rect.fromLTRB(x, y(floor + 62), x + width, y(floor + 30)),
                Paint()..color = glass);
          }
        }
        // Roof edge.
        canvas.drawRect(Rect.fromLTRB(x, top, x + width, y(wallH - 6)),
            Paint()..color = _fog(Color.lerp(lit, Colors.white, 0.2)!, dist));
      case BoxKind.container:
        if (u % 12 < 4) {
          canvas.drawRect(
              rect,
              Paint()
                ..color =
                    Colors.black.withValues(alpha: 0.18 * (1 - dist / _far)));
        }
      case BoxKind.crate:
        final plank = Paint()
          ..color = _fog(Color.lerp(lit, Colors.black, 0.35)!, dist);
        for (var k = 0.0; k <= wallH; k += 11) {
          canvas.drawRect(
              Rect.fromLTRB(x, y(k) - math.max(0.5, s), x + width, y(k)),
              plank);
        }
      case BoxKind.wall:
        if (u % 30 < 2) {
          canvas.drawRect(
              rect, Paint()..color = Colors.black.withValues(alpha: 0.15));
        }
    }
    // Darker near the ground (ambient shadow).
    canvas.drawRect(Rect.fromLTRB(x, y(14), x + width, bottom),
        Paint()..color = Colors.black.withValues(alpha: 0.12));
  }

  void _tree(Canvas canvas, Offset base, double s, Blob b) {
    final trunkW = math.max(1.5, b.radius * 0.28 * s);
    canvas.drawRect(
        Rect.fromLTRB(base.dx - trunkW / 2, base.dy - 150 * s,
            base.dx + trunkW / 2, base.dy),
        Paint()..color = const Color(0xFF5A4030));
    final pine = b.variant == 0;
    if (pine) {
      for (var k = 0; k < 4; k++) {
        final lowY = base.dy - (60 + k * 45) * s;
        final half = b.radius * (1.1 - k * 0.22) * s;
        canvas.drawPath(
            Path()
              ..moveTo(base.dx - half, lowY)
              ..lineTo(base.dx, lowY - 75 * s)
              ..lineTo(base.dx + half, lowY)
              ..close(),
            Paint()
              ..color = Color.lerp(
                  const Color(0xFF1F3A22), const Color(0xFF3F6E3B), k / 3)!);
      }
    } else {
      final rnd = math.Random(b.variant * 97 + b.center.dy.round());
      for (var k = 0; k < 6; k++) {
        final p = base -
            Offset((rnd.nextDouble() - 0.5) * b.radius * s,
                (150 + rnd.nextDouble() * 70) * s);
        final r = b.radius * (0.55 + rnd.nextDouble() * 0.3) * s;
        canvas.drawCircle(
            p,
            r,
            Paint()
              ..shader = ui.Gradient.radial(
                  p - Offset(r * 0.3, r * 0.4), r * 1.3, [
                const Color(0xFF7A9A3E),
                const Color(0xFF4A6F2A),
                const Color(0xFF2E4A1E)
              ], [
                0,
                0.55,
                1
              ]));
      }
    }
  }

  void _rock(Canvas canvas, Offset base, double s, Blob b) {
    final r = b.radius * s;
    final rect = Rect.fromLTRB(
        base.dx - r, base.dy - r * 1.4, base.dx + r, base.dy + r * 0.1);
    canvas.drawOval(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
              rect.center - Offset(r * 0.3, r * 0.4), r * 1.4, [
            const Color(0xFFB4B0A8),
            const Color(0xFF77736C),
            const Color(0xFF55524C)
          ], [
            0,
            0.6,
            1
          ]));
  }

  void _bush(Canvas canvas, Offset base, double s, Blob b) {
    final r = b.radius * s;
    for (final o in [
      Offset(-r * 0.5, -r * 0.6),
      Offset(r * 0.5, -r * 0.7),
      Offset(0, -r * 1.1)
    ]) {
      canvas.drawCircle(
          base + o, r * 0.75, Paint()..color = const Color(0xFF4E7430));
    }
  }

  void _pickup(Canvas canvas, Offset base, double s, Pickup p) {
    final rarity = p.kind == PickupKind.weapon ? weapons[p.weapon]!.rarity : 1;
    final glow = rarityColor(rarity);
    canvas.drawOval(
        Rect.fromCenter(center: base, width: 50 * s, height: 14 * s),
        Paint()..color = glow.withValues(alpha: 0.5));
    canvas.drawRect(
        Rect.fromLTRB(
            base.dx - 1.5 * s, base.dy - 70 * s, base.dx + 1.5 * s, base.dy),
        Paint()..color = glow.withValues(alpha: 0.35));
    canvas.save();
    canvas.translate(base.dx, base.dy - (22 + math.sin(p.age * 3) * 4) * s);
    canvas.scale(s * 1.4);
    drawItem(canvas, p);
    canvas.restore();
  }

  void _soldier(Canvas canvas, Offset base, double s, Fighter f, double horizon,
      double eyeH) {
    final lift = f.altitude * 220 * s;
    final b = base - Offset(0, lift);
    if (lift > 0) {
      canvas.drawOval(
          Rect.fromCenter(center: base, width: 30 * s, height: 8 * s),
          Paint()..color = Colors.black.withValues(alpha: 0.3));
    }
    final uniform = teamColors[f.team % teamColors.length];
    final dark = Color.lerp(uniform, Colors.black, 0.4)!;
    final step = f.alive ? math.sin(f.walk) * 4 * s : 0.0;
    // Legs.
    final pants = Paint()..color = dark;
    canvas.drawRect(
        Rect.fromLTRB(b.dx - 10 * s, b.dy - 34 * s + step, b.dx - 2 * s, b.dy),
        pants);
    canvas.drawRect(
        Rect.fromLTRB(b.dx + 2 * s, b.dy - 34 * s - step, b.dx + 10 * s, b.dy),
        pants);
    canvas.drawRect(
        Rect.fromLTRB(b.dx - 11 * s, b.dy - 5 * s, b.dx - 1 * s, b.dy),
        Paint()..color = const Color(0xFF2B2520));
    canvas.drawRect(
        Rect.fromLTRB(b.dx + 1 * s, b.dy - 5 * s, b.dx + 11 * s, b.dy),
        Paint()..color = const Color(0xFF2B2520));
    // Body with vest.
    final torso = Rect.fromLTRB(
        b.dx - 13 * s, b.dy - 62 * s, b.dx + 13 * s, b.dy - 32 * s);
    canvas.drawRRect(
        RRect.fromRectAndRadius(torso, Radius.circular(4 * s)),
        Paint()
          ..shader = ui.Gradient.linear(torso.topLeft, torso.bottomRight,
              [Color.lerp(uniform, Colors.white, 0.15)!, uniform, dark]));
    canvas.drawRect(
        Rect.fromLTRB(b.dx - 9 * s, b.dy - 58 * s, b.dx + 9 * s, b.dy - 38 * s),
        Paint()
          ..color =
              Color.lerp(dark, Colors.black, 0.2)!.withValues(alpha: 0.6));
    // Arms and gun pointing towards you.
    final sleeve = Paint()..color = Color.lerp(uniform, Colors.black, 0.15)!;
    canvas.drawRect(
        Rect.fromLTRB(
            b.dx - 17 * s, b.dy - 60 * s, b.dx - 11 * s, b.dy - 40 * s),
        sleeve);
    canvas.drawRect(
        Rect.fromLTRB(
            b.dx + 11 * s, b.dy - 60 * s, b.dx + 17 * s, b.dy - 40 * s),
        sleeve);
    canvas.drawRect(
        Rect.fromLTRB(b.dx - 6 * s, b.dy - 50 * s, b.dx + 6 * s, b.dy - 43 * s),
        Paint()..color = const Color(0xFF26282A));
    // Head and helmet.
    canvas.drawCircle(
        b - Offset(0, 70 * s), 8 * s, Paint()..color = const Color(0xFFC89F7E));
    canvas.drawArc(
        Rect.fromCircle(center: b - Offset(0, 72 * s), radius: 9.5 * s),
        math.pi,
        math.pi,
        true,
        Paint()..color = Color.lerp(uniform, Colors.black, 0.3)!);
    canvas.drawRect(
        Rect.fromLTRB(b.dx - 6 * s, b.dy - 73 * s, b.dx + 6 * s, b.dy - 69 * s),
        Paint()..color = const Color(0xFF1E1E1E));
    if (f.hurtFlash > 0) {
      canvas.drawRect(
          Rect.fromLTRB(b.dx - 17 * s, b.dy - 80 * s, b.dx + 17 * s, b.dy),
          Paint()..color = Colors.white.withValues(alpha: f.hurtFlash * 1.5));
    }
    // Health bar.
    if (f.health < 100 || f.shield > 0 || f.team == game.player.team) {
      final ally = f.team == game.player.team;
      final bw = math.max(24.0, 40 * s);
      final bar = Rect.fromCenter(
          center: b - Offset(0, 90 * s), width: bw, height: math.max(3, 5 * s));
      canvas.drawRect(bar.inflate(1), Paint()..color = Colors.black54);
      canvas.drawRect(
          Rect.fromLTWH(bar.left, bar.top, bw * f.health / 100, bar.height),
          Paint()
            ..color = ally ? const Color(0xFF66BB6A) : const Color(0xFFE53935));
    }
  }

  void _hands(Canvas canvas, Size size, Fighter me) {
    final g = me.gun;
    if (g == null || !me.alive) return;
    final bob = math.sin(me.walk) * 6;
    final kick = me.recoil * 22;
    final s = size.height / (g.type == WeaponType.pistol ? 100 : 115);
    canvas.save();
    canvas.translate(size.width * 0.62 + bob, size.height * 0.8 + kick);
    canvas.rotate(-math.pi / 2 - 0.18);
    canvas.scale(s);
    // Sleeves and gloves.
    final uniform = teamColors[me.team % teamColors.length];
    canvas.drawRect(const Rect.fromLTWH(-30, 2, 34, 12),
        Paint()..color = Color.lerp(uniform, Colors.black, 0.1)!);
    canvas.drawRect(const Rect.fromLTWH(-30, -14, 34, 10),
        Paint()..color = Color.lerp(uniform, Colors.black, 0.25)!);
    drawGun(canvas, g.type);
    canvas.drawCircle(
        const Offset(4, 7), 5, Paint()..color = const Color(0xFF2E2A26));
    canvas.restore();
    if (me.cooldown > 0 && me.recoil > 0.7) {
      final tip = Offset(size.width * 0.57, size.height * 0.45);
      canvas.drawCircle(
          tip,
          28,
          Paint()
            ..color = const Color(0xFFFFD27A).withValues(alpha: 0.8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }
  }

  @override
  bool shouldRepaint(FirstPersonPainter oldDelegate) => true;
}
