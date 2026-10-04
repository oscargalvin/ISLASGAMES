import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'battle_model.dart';

const _rarityColors = [
  Color(0xFFB0B0B0), // common
  Color(0xFF5BC236), // uncommon
  Color(0xFF3C9BE8), // rare
  Color(0xFFB15BE8), // epic
  Color(0xFFF2B233), // legendary
];

/// Uniform colours: your team is blue-grey, enemies get other camo colours.
const teamColors = [
  Color(0xFF3E6A8A),
  Color(0xFF7A6A45),
  Color(0xFF55663A),
  Color(0xFF7A4A42),
  Color(0xFF4C4E5E),
  Color(0xFF8A7552),
  Color(0xFF3F5E50),
  Color(0xFF6B5564),
];

Color rarityColor(int r) => _rarityColors[r.clamp(0, 4)];

Path coastPath(double inset, {int points = 240}) {
  final p = Path();
  for (var i = 0; i <= points; i++) {
    final a = i / points * 2 * math.pi;
    final r = coastRadius(a, BattleGame.island) - inset;
    final o = Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// The island's ground, drawn once into a picture: sea, beach, grass and roads.
class Ground {
  Ground(this.image, this.world, this.scale);
  final ui.Image image;

  /// Half the width of the square of world the image covers.
  final double world;
  final double scale;

  static Ground build(BattleGame g) {
    const scale = 0.4;
    const world = BattleGame.island * 1.3;
    final size = (world * 2 * scale).round();
    final rnd = math.Random(7);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(scale);
    c.translate(world, world);
    final all = Rect.fromCircle(center: Offset.zero, radius: world);

    // Sea, getting lighter towards the beach.
    c.drawRect(all, Paint()..color = const Color(0xFF17506E));
    c.drawPath(
        coastPath(-120),
        Paint()
          ..color = const Color(0xFF2B7B94)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60));
    c.drawPath(
        coastPath(-35),
        Paint()
          ..color = const Color(0xFF4FB0B8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));

    // Beach.
    final beach = coastPath(0);
    c.drawPath(beach, Paint()..color = const Color(0xFFD8C190));
    c.save();
    c.clipPath(beach);
    for (var i = 0; i < 2500; i++) {
      final p = Offset(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1) *
          BattleGame.island *
          1.1;
      c.drawCircle(
          p,
          2 + rnd.nextDouble() * 3,
          Paint()
            ..color = (rnd.nextBool()
                    ? const Color(0xFFC4AA78)
                    : const Color(0xFFE8D6AC))
                .withValues(alpha: 0.6));
    }
    c.restore();

    // Grass, with lots of patches so it doesn't look flat.
    final grass = coastPath(60);
    c.drawPath(
        grass,
        Paint()
          ..color = const Color(0xFF5B7A36)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    c.save();
    c.clipPath(grass);
    const greens = [
      Color(0xFF4C6A2C),
      Color(0xFF6C8B3F),
      Color(0xFF55743A),
      Color(0xFF7D8E47),
      Color(0xFF465F2B),
      Color(0xFF8A9150),
    ];
    for (var i = 0; i < 1600; i++) {
      final p = Offset(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1) *
          BattleGame.island *
          1.1;
      final r = 20 + rnd.nextDouble() * 110;
      c.drawOval(
          Rect.fromCenter(
              center: p, width: r * 2, height: r * (1.2 + rnd.nextDouble())),
          Paint()
            ..color = greens[rnd.nextInt(greens.length)].withValues(alpha: 0.35)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4));
    }
    // Dry, muddy patches.
    for (var i = 0; i < 45; i++) {
      final p = Offset(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1) *
          BattleGame.island;
      final r = 40 + rnd.nextDouble() * 90;
      c.drawOval(
          Rect.fromCenter(center: p, width: r * 2, height: r * 1.4),
          Paint()
            ..color = const Color(0xFF8B7B55).withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5));
    }
    // Grass blades.
    final blade = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9000; i++) {
      final p = Offset(rnd.nextDouble() * 2 - 1, rnd.nextDouble() * 2 - 1) *
          BattleGame.island *
          1.05;
      blade.color =
          (rnd.nextBool() ? const Color(0xFF3B5522) : const Color(0xFF93A85A))
              .withValues(alpha: 0.5);
      c.drawLine(
          p,
          p + Offset(rnd.nextDouble() * 6 - 3, -4 - rnd.nextDouble() * 6),
          blade);
    }
    // Town squares: trampled dirt and gravel.
    for (final t in g.towns) {
      c.drawCircle(
          t,
          360,
          Paint()
            ..color = const Color(0xFF9A8A6A).withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90));
      for (var i = 0; i < 600; i++) {
        final p = t +
            Offset.fromDirection(
                rnd.nextDouble() * 6.3, rnd.nextDouble() * 330);
        c.drawCircle(
            p,
            1.5 + rnd.nextDouble() * 2.5,
            Paint()
              ..color = (rnd.nextBool()
                      ? const Color(0xFF7A6C52)
                      : const Color(0xFFB8A98A))
                  .withValues(alpha: 0.7));
      }
    }
    // Dirt roads with tyre tracks.
    for (final road in g.roads) {
      final path = Path()..moveTo(road.first.dx, road.first.dy);
      for (final p in road.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 86
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF8E7A58).withValues(alpha: 0.75)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 60
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFFAD9672));
      for (final side in [-14.0, 14.0]) {
        final track = Path();
        for (var i = 0; i < road.length; i++) {
          final a = road[math.max(0, i - 1)];
          final b = road[math.min(road.length - 1, i + 1)];
          final n = Offset(-(b - a).dy, (b - a).dx) /
              math.max((b - a).distance, 1) *
              side;
          final p = road[i] + n;
          i == 0 ? track.moveTo(p.dx, p.dy) : track.lineTo(p.dx, p.dy);
        }
        c.drawPath(
            track,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7
              ..color = const Color(0xFF7D6A4C).withValues(alpha: 0.6));
      }
    }
    c.restore();
    // Wet sand line at the water's edge.
    c.drawPath(
        beach,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = const Color(0xFFB59E6E).withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    final image = rec.endRecording().toImageSync(size, size);
    return Ground(image, world, scale);
  }
}

class BattlePainter extends CustomPainter {
  BattlePainter({
    required this.game,
    required this.ground,
    required this.camera,
    required this.zoom,
    required this.time,
  });

  final BattleGame game;
  final Ground ground;
  final Offset camera;
  final double zoom;
  final double time;

  static const _sun = Offset(1, 1.3);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-camera.dx, -camera.dy);
    final view = Rect.fromCenter(
            center: camera,
            width: size.width / zoom,
            height: size.height / zoom)
        .inflate(220);

    // Sea all around, then the island picture.
    canvas.drawRect(view, Paint()..color = const Color(0xFF17506E));
    canvas.drawImageRect(
      ground.image,
      Rect.fromLTWH(
          0, 0, ground.image.width.toDouble(), ground.image.height.toDouble()),
      Rect.fromCircle(center: Offset.zero, radius: ground.world),
      Paint()..filterQuality = FilterQuality.medium,
    );
    _waves(canvas, view);

    for (final s in game.scorches) {
      if (!view.contains(s.pos)) continue;
      canvas.drawCircle(
          s.pos,
          s.size,
          Paint()
            ..color =
                const Color(0xFF1E1A16).withValues(alpha: 0.55 * (1 - s.t))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }

    for (final p in game.pickups) {
      if (view.contains(p.pos)) _pickup(canvas, p);
    }

    // Shadows first so they fall on the ground, not on roofs.
    for (final b in game.blocks) {
      if (view.overlaps(b.rect)) _blockShadow(canvas, b);
    }
    for (final b in game.blobs) {
      if (b.kind == RoundKind.rock && view.contains(b.center))
        _rockShadow(canvas, b);
    }
    for (final b in game.blobs) {
      if (b.kind == RoundKind.rock && view.contains(b.center)) _rock(canvas, b);
    }
    for (final b in game.blocks) {
      if (view.overlaps(b.rect)) _block(canvas, b);
    }

    for (final f in game.fighters) {
      if (!f.alive && view.contains(f.pos)) _knockedOut(canvas, f);
    }
    for (final f in game.fighters) {
      if (f.alive && !f.flying && view.contains(f.pos)) _soldier(canvas, f);
    }

    for (final b in game.bullets) {
      final tail = b.pos - b.vel * (b.type == WeaponType.sniper ? 0.04 : 0.018);
      canvas.drawLine(
          tail,
          b.pos,
          Paint()
            ..strokeWidth = b.type == WeaponType.sniper ? 3.5 : 2.2
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(tail, b.pos,
                [const Color(0x00FFE7A0), const Color(0xFFFFF4D0)]));
    }
    for (final r in game.rockets) {
      _rocket(canvas, r);
    }

    // Trees and bushes cover people underneath (see-through if it's you).
    final me = game.watching;
    for (final b in game.blobs) {
      if (b.kind == RoundKind.rock || !view.contains(b.center)) continue;
      final under = (me.pos - b.center).distance < b.radius;
      if (b.kind == RoundKind.tree) {
        _tree(canvas, b, under ? 0.45 : 1);
      } else {
        _bush(canvas, b, under ? 0.5 : 1);
      }
    }

    for (final f in game.fighters) {
      if (f.alive && f.flying && view.contains(f.pos)) _soldier(canvas, f);
    }

    for (final e in game.fx) {
      if (view.contains(e.pos)) _fx(canvas, e);
    }

    for (final f in game.fighters) {
      if (f.alive && !f.isPlayer && view.contains(f.pos)) _tag(canvas, f);
    }

    _storm(canvas, view);
    canvas.restore();
  }

  void _waves(Canvas canvas, Rect view) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var k = 0; k < 3; k++) {
      final phase = (time * 0.25 + k / 3) % 1;
      final path = Path();
      for (var i = 0; i <= 160; i++) {
        final a = i / 160 * 2 * math.pi;
        final r = coastRadius(a, BattleGame.island) +
            10 +
            phase * 90 +
            6 * math.sin(a * 23 + time);
        final o = Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      p.color = Colors.white.withValues(alpha: 0.22 * (1 - phase));
      canvas.drawPath(path, p);
    }
  }

  // ------------------------------------------------------------ world

  void _blockShadow(Canvas canvas, Block b) {
    final off = _sun * (b.height * 26);
    final r = b.rect;
    final path = Path()
      ..moveTo(r.right, r.top)
      ..lineTo(r.right + off.dx, r.top + off.dy)
      ..lineTo(r.right + off.dx, r.bottom + off.dy)
      ..lineTo(r.left + off.dx, r.bottom + off.dy)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.right, r.bottom)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF101810).withValues(alpha: 0.38)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  void _block(Canvas canvas, Block b) {
    final r = b.rect;
    final base = Color(b.color);
    final seed = (r.left * 7 + r.top * 13).round();
    final rnd = math.Random(seed);
    switch (b.kind) {
      case BoxKind.building:
        // Flat concrete roof with a raised edge, vents and air-con units.
        canvas.drawRect(r, Paint()..color = _shade(base, -0.25));
        final roof = r.deflate(7);
        canvas.drawRect(
            roof,
            Paint()
              ..shader = ui.Gradient.linear(roof.topLeft, roof.bottomRight,
                  [_shade(base, 0.08), _shade(base, -0.08)]));
        for (var i = 0; i < 30; i++) {
          final p = Offset(roof.left + rnd.nextDouble() * roof.width,
              roof.top + rnd.nextDouble() * roof.height);
          canvas.drawCircle(
              p,
              4 + rnd.nextDouble() * 10,
              Paint()
                ..color = (rnd.nextBool() ? Colors.black : Colors.white)
                    .withValues(alpha: 0.04));
        }
        canvas.drawRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = _shade(base, 0.2));
        for (var i = 0; i < 2 + rnd.nextInt(2); i++) {
          final u = Rect.fromLTWH(
              roof.left + 10 + rnd.nextDouble() * (roof.width - 50),
              roof.top + 10 + rnd.nextDouble() * (roof.height - 50),
              30,
              22);
          canvas.drawRect(u.shift(const Offset(4, 5)),
              Paint()..color = Colors.black.withValues(alpha: 0.25));
          canvas.drawRect(u, Paint()..color = const Color(0xFFC9CBCC));
          canvas.drawCircle(
              u.center, 8, Paint()..color = const Color(0xFF6E7273));
          canvas.drawCircle(
              u.center,
              8,
              Paint()
                ..style = PaintingStyle.stroke
                ..color = const Color(0xFF9A9E9F));
        }
        final hatch = Offset(roof.right - 22, roof.bottom - 22);
        canvas.drawRect(Rect.fromCenter(center: hatch, width: 18, height: 18),
            Paint()..color = const Color(0xFF55524E));
      case BoxKind.container:
        canvas.drawRect(r, Paint()..color = _shade(base, -0.1));
        final long = r.width > r.height;
        final ribs = Paint()
          ..strokeWidth = 2
          ..color = _shade(base, -0.3);
        final light = Paint()
          ..strokeWidth = 2
          ..color = _shade(base, 0.15);
        if (long) {
          for (var x = r.left + 6; x < r.right - 4; x += 7) {
            canvas.drawLine(
                Offset(x, r.top + 3), Offset(x, r.bottom - 3), ribs);
            canvas.drawLine(
                Offset(x + 3, r.top + 3), Offset(x + 3, r.bottom - 3), light);
          }
        } else {
          for (var y = r.top + 6; y < r.bottom - 4; y += 7) {
            canvas.drawLine(
                Offset(r.left + 3, y), Offset(r.right - 3, y), ribs);
            canvas.drawLine(
                Offset(r.left + 3, y + 3), Offset(r.right - 3, y + 3), light);
          }
        }
        canvas.drawRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = _shade(base, -0.4));
        // Rust streaks.
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(
              Offset(r.left + rnd.nextDouble() * r.width,
                  r.top + rnd.nextDouble() * r.height),
              4 + rnd.nextDouble() * 8,
              Paint()..color = const Color(0xFF6B3A1E).withValues(alpha: 0.25));
        }
      case BoxKind.crate:
        canvas.drawRect(r, Paint()..color = base);
        final plank = Paint()
          ..strokeWidth = 1.5
          ..color = _shade(base, -0.3);
        for (var y = r.top + 8.8; y < r.bottom; y += 8.8) {
          canvas.drawLine(Offset(r.left, y), Offset(r.right, y), plank);
        }
        final frame = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = _shade(base, -0.2);
        canvas.drawRect(r.deflate(2), frame);
        canvas.drawLine(r.topLeft + const Offset(3, 3),
            r.bottomRight - const Offset(3, 3), frame);
      case BoxKind.wall:
        canvas.drawRect(r, Paint()..color = base);
        final seg = Paint()
          ..strokeWidth = 1.5
          ..color = _shade(base, -0.2);
        if (r.width > r.height) {
          for (var x = r.left + 30; x < r.right; x += 30) {
            canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), seg);
          }
        } else {
          for (var y = r.top + 30; y < r.bottom; y += 30) {
            canvas.drawLine(Offset(r.left, y), Offset(r.right, y), seg);
          }
        }
        canvas.drawRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = _shade(base, 0.15));
    }
  }

  Path _rockPath(Blob b) {
    final rnd = math.Random(b.variant * 31 + b.center.dx.round());
    final n = 8 + rnd.nextInt(3);
    final path = Path();
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi;
      final r = b.radius * (0.78 + rnd.nextDouble() * 0.3);
      final p = b.center + Offset(math.cos(a) * r, math.sin(a) * r * 0.85);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _rockShadow(Canvas canvas, Blob b) {
    canvas.drawPath(
        _rockPath(b).shift(_sun * (b.radius * 0.35)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }

  void _rock(Canvas canvas, Blob b) {
    final path = _rockPath(b);
    canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
              b.center - Offset(b.radius * 0.35, b.radius * 0.4),
              b.radius * 1.4, [
            const Color(0xFFB4B0A8),
            const Color(0xFF77736C),
            const Color(0xFF55524C)
          ], [
            0,
            0.6,
            1
          ]));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF3F3C38).withValues(alpha: 0.6));
    final crack = Paint()
      ..strokeWidth = 1.5
      ..color = const Color(0xFF4A4741).withValues(alpha: 0.6);
    canvas.drawLine(b.center - Offset(b.radius * 0.3, 0),
        b.center + Offset(b.radius * 0.1, b.radius * 0.35), crack);
    // Moss.
    canvas.drawCircle(
        b.center + Offset(b.radius * 0.2, -b.radius * 0.3),
        b.radius * 0.25,
        Paint()..color = const Color(0xFF5E7A3A).withValues(alpha: 0.35));
  }

  void _tree(Canvas canvas, Blob b, double opacity) {
    final c = b.center;
    final r = b.radius;
    final rnd = math.Random(b.variant * 97 + c.dy.round());
    canvas.drawCircle(c + _sun * (r * 0.55), r * 0.95,
        Paint()..color = Colors.black.withValues(alpha: 0.28 * opacity));
    final pine = b.variant == 0;
    final dark = pine ? const Color(0xFF1F3A22) : const Color(0xFF2E4A1E);
    final mid = pine ? const Color(0xFF2F5A31) : const Color(0xFF4A6F2A);
    final light = pine ? const Color(0xFF4C7A45) : const Color(0xFF7A9A3E);
    if (pine) {
      // Pine: a star of needles in rings.
      for (var ring = 0; ring < 3; ring++) {
        final rr = r * (1 - ring * 0.28);
        final n = 9 - ring * 2;
        final path = Path();
        for (var i = 0; i < n * 2; i++) {
          final a = i / (n * 2) * 2 * math.pi + ring * 0.3;
          final d = i.isEven ? rr : rr * 0.62;
          final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
            path..close(),
            Paint()
              ..color = Color.lerp(dark, light, ring / 2.2)!
                  .withValues(alpha: opacity));
      }
    } else {
      // Leafy: lots of round clumps, shaded from the top-left.
      for (var i = 0; i < 9; i++) {
        final a = rnd.nextDouble() * 2 * math.pi;
        final d = r * 0.45 * rnd.nextDouble();
        final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
        final cr = r * (0.42 + rnd.nextDouble() * 0.2);
        canvas.drawCircle(
            p,
            cr,
            Paint()
              ..shader =
                  ui.Gradient.radial(p - Offset(cr * 0.4, cr * 0.4), cr * 1.3, [
                light.withValues(alpha: opacity),
                mid.withValues(alpha: opacity),
                dark.withValues(alpha: opacity),
              ], [
                0,
                0.55,
                1
              ]));
      }
    }
  }

  void _bush(Canvas canvas, Blob b, double opacity) {
    final rnd = math.Random(b.center.dx.round() * 3 + b.variant);
    canvas.drawCircle(b.center + const Offset(5, 7), b.radius,
        Paint()..color = Colors.black.withValues(alpha: 0.22 * opacity));
    for (var i = 0; i < 7; i++) {
      final p = b.center +
          Offset.fromDirection(
              rnd.nextDouble() * 6.3, b.radius * 0.5 * rnd.nextDouble());
      final r = b.radius * (0.45 + rnd.nextDouble() * 0.25);
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..shader =
                ui.Gradient.radial(p - Offset(r * 0.3, r * 0.3), r * 1.2, [
              const Color(0xFF6E9440).withValues(alpha: opacity),
              const Color(0xFF3C5A24).withValues(alpha: opacity),
            ]));
    }
  }

  // ------------------------------------------------------------ people

  void _soldier(Canvas canvas, Fighter f) {
    final lift = f.altitude;
    final scale = 1 + lift * 0.35;
    // Shadow on the ground (further away when flying).
    canvas.drawOval(
        Rect.fromCenter(
            center: f.pos + _sun * (4 + lift * 36),
            width: 34 * scale,
            height: 30 * scale),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35 - lift * 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + lift * 6));

    canvas.save();
    canvas.translate(f.pos.dx, f.pos.dy);
    canvas.scale(scale);
    canvas.rotate(f.aim);
    final uniform = teamColors[f.team % teamColors.length];
    final dark = _shade(uniform, -0.35);

    // Feet stepping.
    final step = math.sin(f.walk) * 7;
    final boot = Paint()..color = const Color(0xFF2B2520);
    if (!f.flying) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(step, 8), width: 13, height: 8), boot);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(-step, -8), width: 13, height: 8),
          boot);
    }

    // Jetpack on the back.
    if (f.hasJetpack) {
      for (final y in [-6.0, 6.0]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(-16, y), width: 12, height: 9),
                const Radius.circular(4)),
            Paint()..color = const Color(0xFF8A9096));
        if (f.flying) {
          canvas.drawCircle(
              Offset(-24 - math.Random().nextDouble() * 4, y),
              5,
              Paint()
                ..color = const Color(0xFFFFA733)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        }
      }
    }
    // Backpack.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: const Offset(-10, 0), width: 11, height: 20),
            const Radius.circular(4)),
        Paint()..color = _shade(uniform, -0.45));

    // Shoulders and body, lit from the top-left.
    final body = Rect.fromCenter(center: Offset.zero, width: 22, height: 32);
    canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(11)),
        Paint()
          ..shader = ui.Gradient.radial(const Offset(-4, -8), 22,
              [_shade(uniform, 0.25), uniform, dark], [0, 0.5, 1]));
    // Camo blotches.
    final camo = Paint()..color = dark.withValues(alpha: 0.45);
    canvas.drawCircle(const Offset(-3, -9), 3.5, camo);
    canvas.drawCircle(const Offset(4, 8), 4, camo);
    canvas.drawCircle(const Offset(-5, 6), 2.5, camo);

    final gun = f.gun;
    final len = gun?.spec.length ?? 16;
    // Arms holding the gun.
    final sleeve = Paint()
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..color = _shade(uniform, -0.1);
    final kick = -f.recoil * 4;
    canvas.drawLine(const Offset(2, 12), Offset(14 + kick, 6), sleeve);
    canvas.drawLine(const Offset(2, -12),
        Offset(math.min(len * 0.6, 24) + kick, 5), sleeve);
    final glove = Paint()..color = const Color(0xFF2E2A26);
    canvas.drawCircle(Offset(14 + kick, 6), 3.5, glove);
    canvas.drawCircle(Offset(math.min(len * 0.6, 24) + kick, 5), 3.5, glove);
    if (gun != null) {
      canvas.save();
      canvas.translate(8 + kick, 6);
      drawGun(canvas, gun.type);
      canvas.restore();
    }

    // Helmet.
    canvas.drawCircle(
        const Offset(1, 0),
        9.5,
        Paint()
          ..shader = ui.Gradient.radial(const Offset(-2, -4), 12, [
            _shade(uniform, 0.1),
            _shade(uniform, -0.25),
            _shade(uniform, -0.5)
          ], [
            0,
            0.6,
            1
          ]));
    canvas.drawCircle(
        const Offset(1, 0),
        9.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.black.withValues(alpha: 0.35));
    // Goggles strap.
    canvas.drawArc(
        Rect.fromCircle(center: const Offset(1, 0), radius: 7),
        -0.9,
        1.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF1E1E1E));

    if (f.hurtFlash > 0) {
      canvas.drawCircle(Offset.zero, 18,
          Paint()..color = Colors.white.withValues(alpha: f.hurtFlash * 1.6));
    }
    canvas.restore();

    // A ring under you and teammates so you can find yourself.
    if (f.team == game.player.team) {
      canvas.drawCircle(
          f.pos,
          24 * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color =
                (f.isPlayer ? const Color(0xFF4FC3F7) : const Color(0xFF81C784))
                    .withValues(alpha: 0.7));
    }
  }

  void _knockedOut(Canvas canvas, Fighter f) {
    canvas.drawCircle(
        f.pos,
        14,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  void _tag(Canvas canvas, Fighter f) {
    final ally = f.team == game.player.team;
    if (!ally && f.health >= 100 && f.shield <= 0) return;
    final top = f.pos - Offset(0, 36 + f.altitude * 12);
    final w = 40.0;
    final bar = Rect.fromCenter(center: top, width: w, height: 5);
    canvas.drawRect(bar.inflate(1), Paint()..color = Colors.black54);
    canvas.drawRect(
        Rect.fromLTWH(bar.left, bar.top, w * f.health / 100, 5),
        Paint()
          ..color = ally ? const Color(0xFF66BB6A) : const Color(0xFFE53935));
    if (f.shield > 0) {
      canvas.drawRect(
          Rect.fromLTWH(bar.left, bar.top - 4, w * f.shield / 100, 3),
          Paint()..color = const Color(0xFF42A5F5));
    }
    if (ally) {
      final tp = TextPainter(
        text: TextSpan(
            text: f.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(blurRadius: 3, color: Colors.black),
                ])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, top - Offset(tp.width / 2, 18));
    }
  }

  void _rocket(Canvas canvas, Rocket r) {
    canvas.save();
    canvas.translate(r.pos.dx, r.pos.dy);
    canvas.rotate(r.vel.direction);
    canvas.drawCircle(
        const Offset(-14, 0),
        7,
        Paint()
          ..color = const Color(0xFFFFB238)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-12, -3, 18, 6), const Radius.circular(2)),
        Paint()..color = const Color(0xFF5B6236));
    canvas.drawPath(
        Path()
          ..moveTo(6, -4)
          ..lineTo(14, 0)
          ..lineTo(6, 4)
          ..close(),
        Paint()..color = const Color(0xFF3E3E3E));
    canvas.restore();
  }

  void _pickup(Canvas canvas, Pickup p) {
    final bob = math.sin(p.age * 3 + p.pos.dx) * 3;
    final rarity = switch (p.kind) {
      PickupKind.weapon => weapons[p.weapon]!.rarity,
      PickupKind.jetpack => 3,
      PickupKind.shield => 2,
      PickupKind.speed => 3,
      PickupKind.medkit => 1,
      PickupKind.ammo => 0,
    };
    final glow = rarityColor(rarity);
    final pulse = 0.5 + 0.2 * math.sin(p.age * 4);
    canvas.drawCircle(
        p.pos,
        24,
        Paint()
          ..shader = ui.Gradient.radial(p.pos, 26,
              [glow.withValues(alpha: pulse), glow.withValues(alpha: 0)]));
    canvas.drawOval(
        Rect.fromCenter(
            center: p.pos + const Offset(3, 8), width: 30, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.save();
    canvas.translate(p.pos.dx, p.pos.dy + bob);
    drawItem(canvas, p);
    canvas.restore();
  }

  // ------------------------------------------------------------ fx

  void _fx(Canvas canvas, Fx e) {
    final t = e.t;
    switch (e.kind) {
      case FxKind.flash:
        canvas.save();
        canvas.translate(e.pos.dx, e.pos.dy);
        canvas.rotate(e.angle);
        final s = e.size * (1 - t * 0.5);
        canvas.drawPath(
            Path()
              ..moveTo(0, -s * 0.35)
              ..lineTo(s * 1.4, 0)
              ..lineTo(0, s * 0.35)
              ..lineTo(s * 0.3, 0)
              ..close(),
            Paint()..color = const Color(0xFFFFF1B0));
        canvas.drawCircle(
            Offset.zero,
            s * 0.7,
            Paint()
              ..color = const Color(0xFFFFB648).withValues(alpha: 0.8)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.restore();
      case FxKind.spark:
        final dir =
            e.vel.distance > 1 ? e.vel / e.vel.distance : const Offset(1, 0);
        canvas.drawLine(
            e.pos,
            e.pos - dir * e.size * 2,
            Paint()
              ..strokeWidth = 2
              ..color = const Color(0xFFFFD27A).withValues(alpha: 1 - t));
      case FxKind.dust:
        canvas.drawCircle(
            e.pos,
            e.size * (0.6 + t * 1.6),
            Paint()
              ..color =
                  const Color(0xFFB9A57E).withValues(alpha: 0.6 * (1 - t)));
      case FxKind.smoke:
        canvas.drawCircle(
            e.pos,
            e.size * (0.6 + t * 1.4),
            Paint()
              ..color =
                  const Color(0xFF6E6A66).withValues(alpha: 0.45 * (1 - t))
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, e.size * 0.4));
      case FxKind.splash:
        canvas.drawCircle(
            e.pos,
            e.size * (0.5 + t * 2),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: 0.7 * (1 - t)));
      case FxKind.explosion:
        final r = e.size * (0.35 + 0.65 * math.sqrt(t));
        canvas.drawCircle(
            e.pos,
            r,
            Paint()
              ..shader = ui.Gradient.radial(e.pos, r, [
                Colors.white.withValues(alpha: 1 - t),
                const Color(0xFFFFD34D).withValues(alpha: 1 - t),
                const Color(0xFFFF6A1A).withValues(alpha: 0.8 * (1 - t)),
                const Color(0xFF5A2A10).withValues(alpha: 0),
              ], [
                0,
                0.25,
                0.6,
                1
              ]));
        canvas.drawCircle(
            e.pos,
            e.size * (0.2 + t * 1.1),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.white.withValues(alpha: 0.5 * (1 - t)));
      case FxKind.scorch:
        break;
    }
  }

  void _storm(Canvas canvas, Rect view) {
    final c = game.stormCenter;
    final r = game.stormRadius;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(view.inflate(400))
      ..addOval(Rect.fromCircle(center: c, radius: r));
    canvas.drawPath(
        path, Paint()..color = const Color(0xFF6A2FB8).withValues(alpha: 0.32));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..color = const Color(0xFFB57BFF).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFE2C8FF).withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(BattlePainter oldDelegate) => true;
}

Color _shade(Color c, double amount) => amount >= 0
    ? Color.lerp(c, Colors.white, amount)!
    : Color.lerp(c, Colors.black, -amount)!;

/// Draws a gun pointing right, starting at (0, 0).
void drawGun(Canvas canvas, WeaponType type) {
  final metal = Paint()..color = const Color(0xFF26282A);
  final hi = Paint()..color = const Color(0xFF55595C);
  switch (type) {
    case WeaponType.pistol:
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, -2.5, 16, 5), const Radius.circular(1.5)),
          metal);
      canvas.drawRect(const Rect.fromLTWH(2, -2.5, 12, 1.4), hi);
    case WeaponType.rifle:
      canvas.drawRect(const Rect.fromLTWH(-6, -3, 12, 6),
          Paint()..color = const Color(0xFF3A3A34));
      canvas.drawRect(const Rect.fromLTWH(4, -3.5, 18, 7), metal);
      canvas.drawRect(const Rect.fromLTWH(22, -1.5, 12, 3), metal);
      canvas.drawRect(const Rect.fromLTWH(8, 3.5, 5, 6),
          Paint()..color = const Color(0xFF1E1E1E));
      canvas.drawRect(const Rect.fromLTWH(10, -2, 7, 4), hi);
    case WeaponType.shotgun:
      canvas.drawRect(const Rect.fromLTWH(-6, -3, 12, 6),
          Paint()..color = const Color(0xFF6B4628));
      canvas.drawRect(const Rect.fromLTWH(4, -3, 10, 6), metal);
      canvas.drawRect(const Rect.fromLTWH(14, -2.2, 16, 4.4), metal);
      canvas.drawRect(const Rect.fromLTWH(14, 1.5, 10, 3),
          Paint()..color = const Color(0xFF7A5230));
    case WeaponType.sniper:
      canvas.drawRect(const Rect.fromLTWH(-8, -3, 14, 6),
          Paint()..color = const Color(0xFF4B5132));
      canvas.drawRect(const Rect.fromLTWH(4, -3, 14, 6), metal);
      canvas.drawRect(const Rect.fromLTWH(18, -1.2, 26, 2.4), metal);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(5, -2.5, 15, 5), const Radius.circular(2.5)),
          Paint()..color = const Color(0xFF111111));
      canvas.drawCircle(
          const Offset(19, 0), 2.2, Paint()..color = const Color(0xFF6FA8DC));
    case WeaponType.rpg:
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-12, -4.5, 46, 9), const Radius.circular(3)),
          Paint()..color = const Color(0xFF59603A));
      canvas.drawRect(const Rect.fromLTWH(-12, -4.5, 46, 2.5),
          Paint()..color = const Color(0xFF7A8250));
      canvas.drawPath(
          Path()
            ..moveTo(34, -5)
            ..lineTo(44, 0)
            ..lineTo(34, 5)
            ..close(),
          Paint()..color = const Color(0xFF3F3F3F));
      canvas.drawRect(const Rect.fromLTWH(6, 4, 4, 6), metal);
  }
}

/// Draws a pickup's item, centred on (0, 0).
void drawItem(Canvas canvas, Pickup p) {
  switch (p.kind) {
    case PickupKind.weapon:
      canvas.save();
      canvas.rotate(-0.5);
      canvas.translate(-weapons[p.weapon]!.length / 2, 0);
      drawGun(canvas, p.weapon!);
      canvas.restore();
    case PickupKind.ammo:
      final colors = {
        Ammo.light: const Color(0xFF9E9E9E),
        Ammo.medium: const Color(0xFF8D6E3F),
        Ammo.shells: const Color(0xFFB23A2E),
        Ammo.heavy: const Color(0xFF3D5A80),
        Ammo.rockets: const Color(0xFF59603A),
      };
      canvas.drawRect(const Rect.fromLTWH(-10, -7, 20, 14),
          Paint()..color = const Color(0xFF4E5B31));
      canvas.drawRect(const Rect.fromLTWH(-10, -7, 20, 3),
          Paint()..color = const Color(0xFF66753F));
      canvas.drawRect(
          const Rect.fromLTWH(-4, -2, 8, 5), Paint()..color = colors[p.ammo]!);
    case PickupKind.medkit:
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-11, -8, 22, 16), const Radius.circular(3)),
          Paint()..color = Colors.white);
      final cross = Paint()..color = const Color(0xFF2E9E4F);
      canvas.drawRect(const Rect.fromLTWH(-2.5, -6, 5, 12), cross);
      canvas.drawRect(const Rect.fromLTWH(-6, -2.5, 12, 5), cross);
    case PickupKind.shield:
      canvas.drawCircle(
          const Offset(0, 2), 8, Paint()..color = const Color(0xFF3FA9F5));
      canvas.drawRect(const Rect.fromLTWH(-2.5, -10, 5, 6),
          Paint()..color = const Color(0xFF3FA9F5));
      canvas.drawCircle(
          const Offset(-3, 0), 2.5, Paint()..color = Colors.white70);
    case PickupKind.jetpack:
      for (final x in [-5.0, 5.0]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x, 0), width: 8, height: 18),
                const Radius.circular(4)),
            Paint()..color = const Color(0xFF9AA0A6));
      }
      canvas.drawRect(const Rect.fromLTWH(-9, -3, 18, 4),
          Paint()..color = const Color(0xFF424242));
    case PickupKind.speed:
      canvas.drawPath(
          Path()
            ..moveTo(3, -11)
            ..lineTo(-6, 2)
            ..lineTo(0, 2)
            ..lineTo(-3, 11)
            ..lineTo(7, -2)
            ..lineTo(1, -2)
            ..close(),
          Paint()..color = const Color(0xFFFFD54F));
  }
}

/// The little map in the corner.
class MiniMapPainter extends CustomPainter {
  MiniMapPainter(this.game);
  final BattleGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / (BattleGame.island * 2.4);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.drawCircle(Offset.zero, BattleGame.island * 1.2,
        Paint()..color = const Color(0xFF17506E));
    canvas.drawPath(
        coastPath(0, points: 90), Paint()..color = const Color(0xFFD8C190));
    canvas.drawPath(
        coastPath(60, points: 90), Paint()..color = const Color(0xFF5B7A36));
    for (final t in game.towns) {
      canvas.drawCircle(t, 120, Paint()..color = const Color(0xFF9A8A6A));
    }
    final storm = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(
          Rect.fromCircle(center: Offset.zero, radius: BattleGame.island * 1.3))
      ..addOval(
          Rect.fromCircle(center: game.stormCenter, radius: game.stormRadius));
    canvas.drawPath(storm,
        Paint()..color = const Color(0xFF6A2FB8).withValues(alpha: 0.45));
    canvas.drawCircle(
        game.stormCenter,
        game.stormRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / s
          ..color = Colors.white);
    for (final f in game.fighters) {
      if (!f.alive || f.team != game.player.team || f.isPlayer) continue;
      canvas.drawCircle(f.pos, 4 / s, Paint()..color = const Color(0xFF81C784));
    }
    final me = game.watching;
    canvas.save();
    canvas.translate(me.pos.dx, me.pos.dy);
    canvas.rotate(me.aim);
    canvas.drawPath(
        Path()
          ..moveTo(7 / s, 0)
          ..lineTo(-5 / s, -5 / s)
          ..lineTo(-3 / s, 0)
          ..lineTo(-5 / s, 5 / s)
          ..close(),
        Paint()..color = Colors.white);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(MiniMapPainter oldDelegate) => true;
}
