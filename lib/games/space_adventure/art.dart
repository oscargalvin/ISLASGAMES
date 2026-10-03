import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared drawing helpers: stars, rocket, astronaut, labels.

Color lighter(Color c, double t) => Color.lerp(c, Colors.white, t)!;
Color darker(Color c, double t) => Color.lerp(c, Colors.black, t)!;

Paint blurPaint(Color color, double blur) => Paint()
  ..color = color
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);

// ------------------------------------------------------------------ stars

class _Star {
  const _Star(this.x, this.y, this.size, this.depth, this.color, this.phase);
  final double x, y, size, depth, phase;
  final Color color;
}

const _starColors = [
  Color(0xFFFFFFFF),
  Color(0xFFCFE0FF),
  Color(0xFFFFF0D8),
  Color(0xFFFFD9C4),
  Color(0xFFFFFFFF),
];

final List<_Star> _stars = () {
  final r = math.Random(3);
  return List.generate(
    320,
    (i) => _Star(
      r.nextDouble(),
      r.nextDouble(),
      0.4 + math.pow(r.nextDouble(), 3).toDouble() * 2.0,
      0.03 + r.nextDouble() * 0.3,
      _starColors[i % _starColors.length],
      r.nextDouble() * 6.28,
    ),
  );
}();

/// Little dusty stars that make up the Milky Way band.
final List<Offset> _dust = () {
  final r = math.Random(11);
  return List.generate(500, (_) {
    final along = r.nextDouble();
    // Roughly gaussian spread across the band.
    final across = (r.nextDouble() + r.nextDouble() + r.nextDouble() - 1.5) * 0.12;
    return Offset(along, across);
  });
}();

void paintStars(Canvas canvas, Size size, Offset camera,
    {double alpha = 1, double time = 0}) {
  if (size.isEmpty || alpha <= 0) return;
  final paint = Paint();
  for (final s in _stars) {
    final x = (s.x * size.width - camera.dx * s.depth) % size.width;
    final y = (s.y * size.height - camera.dy * s.depth) % size.height;
    final twinkle = 0.7 + 0.3 * math.sin(time * 2.2 + s.phase);
    final a = (alpha * twinkle * (90 + s.size * 80)).clamp(0.0, 255.0).toInt();
    paint.color = s.color.withAlpha(a);
    canvas.drawCircle(Offset(x, y), s.size, paint);
    if (s.size > 1.6) {
      canvas.drawCircle(Offset(x, y), s.size * 3, blurPaint(s.color.withAlpha(a ~/ 4), 3));
    }
  }
}

/// A faint, glowing band of the Milky Way across the sky.
void paintMilkyWay(Canvas canvas, Size size, Offset camera, {double alpha = 1}) {
  if (size.isEmpty || alpha <= 0) return;
  final shift = (-(camera.dx * 0.015)) % size.width;
  for (final dx in [shift - size.width, shift]) {
    canvas.save();
    canvas.translate(dx, 0);
    final a = Offset(-0.05 * size.width, size.height * 0.95);
    final b = Offset(1.05 * size.width, size.height * 0.05);
    final dir = b - a;
    final normal = Offset(-dir.dy, dir.dx) / dir.distance;
    for (var i = 0; i < 9; i++) {
      final t = i / 8;
      final c = a + dir * t;
      final glow = i.isEven ? const Color(0xFF8E9BD8) : const Color(0xFFD8C8B0);
      canvas.drawCircle(
          c, size.shortestSide * 0.16, blurPaint(glow.withAlpha((alpha * 20).toInt()), 50));
    }
    final dust = Paint()..color = Colors.white.withAlpha((alpha * 110).toInt());
    for (final p in _dust) {
      final c = a + dir * p.dx + normal * (p.dy * size.shortestSide * 2);
      canvas.drawCircle(c, 0.6, dust);
    }
    canvas.restore();
  }
  // A couple of coloured nebula clouds far away.
  final n1 = Offset(((size.width * 0.25 - camera.dx * 0.01) % (size.width * 1.4)) - size.width * 0.2,
      size.height * 0.3);
  canvas.drawCircle(n1, size.shortestSide * 0.22,
      blurPaint(const Color(0xFF7E57C2).withAlpha((alpha * 22).toInt()), 70));
  final n2 = Offset(((size.width * 0.8 - camera.dx * 0.008) % (size.width * 1.4)) - size.width * 0.2,
      size.height * 0.75);
  canvas.drawCircle(n2, size.shortestSide * 0.18,
      blurPaint(const Color(0xFF26A69A).withAlpha((alpha * 18).toInt()), 70));
}

// ------------------------------------------------------------------ text

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

/// Red edges when hot, blue edges when cold.
void paintTemperatureGlow(Canvas canvas, Size size, double temperature,
    {double strength = 1}) {
  final amount = ((temperature.abs() - 0.25) / 0.75) * strength;
  if (amount <= 0) return;
  final color = temperature > 0 ? const Color(0xFFFF3D00) : const Color(0xFF40C4FF);
  final full = Offset.zero & size;
  canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            color.withAlpha(0),
            color.withAlpha((amount.clamp(0.0, 1.0) * 150).toInt()),
          ],
          stops: const [0.6, 1],
        ).createShader(full));
}

// ----------------------------------------------------------------- rocket

/// A rocket pointing straight up, about 64 tall, centred on (0, 0).
/// The bottom of the nozzle is at y = 30.
void paintRocket(Canvas canvas,
    {bool flame = false,
    double time = 0,
    bool hatchOpen = false,
    bool pilot = false}) {
  if (flame) {
    final f = 18 + math.sin(time * 40) * 5;
    canvas.drawCircle(const Offset(0, 40), 16, blurPaint(const Color(0x88FF9800), 10));
    final outer = Path()
      ..moveTo(-9, 28)
      ..quadraticBezierTo(0, 28 + f * 2.2, 9, 28)
      ..close();
    canvas.drawPath(outer, Paint()..color = const Color(0xFFFF8F00));
    final inner = Path()
      ..moveTo(-5, 28)
      ..quadraticBezierTo(0, 28 + f * 1.3, 5, 28)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFFFF59D));
  }

  final fin = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
    ).createShader(const Rect.fromLTRB(-24, 6, 24, 30));
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
      Paint()..color = const Color(0xFF424242));

  final body = Path()
    ..moveTo(0, -34)
    ..quadraticBezierTo(16, -18, 13, 8)
    ..lineTo(12, 26)
    ..lineTo(-12, 26)
    ..lineTo(-13, 8)
    ..quadraticBezierTo(-16, -18, 0, -34)
    ..close();
  // Shaded so it looks round.
  canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFB0BEC5), Color(0xFFFFFFFF), Color(0xFFCFD8DC), Color(0xFF90A4AE)],
          stops: [0, 0.35, 0.7, 1],
        ).createShader(const Rect.fromLTRB(-14, -34, 14, 26)));

  canvas.save();
  canvas.clipPath(body);
  final band = Paint()..color = const Color(0xFF263238);
  canvas.drawRect(const Rect.fromLTRB(-16, 12, 16, 15), band);
  canvas.drawRect(const Rect.fromLTRB(-16, -14, 16, -12), band);
  canvas.restore();

  final nose = Path()
    ..moveTo(0, -34)
    ..quadraticBezierTo(9, -26, 11, -18)
    ..lineTo(-11, -18)
    ..quadraticBezierTo(-9, -26, 0, -34)
    ..close();
  canvas.drawPath(
      nose,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8E0000), Color(0xFFE53935), Color(0xFFB71C1C)],
        ).createShader(const Rect.fromLTRB(-11, -34, 11, -18)));

  canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF607D8B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);

  // Hatch around the window.
  final hatch = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-8, -13, 8, 3), const Radius.circular(3));
  if (hatchOpen) {
    canvas.drawRRect(hatch, Paint()..color = const Color(0xFF212121));
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(8, -13, 14, 3), const Radius.circular(2)),
        Paint()..color = const Color(0xFFCFD8DC));
  } else {
    canvas.drawRRect(
        hatch,
        Paint()
          ..color = const Color(0xFF78909C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
    canvas.drawCircle(const Offset(0, -5), 6, Paint()..color = const Color(0xFF37474F));
    canvas.drawCircle(
        const Offset(0, -5),
        4.8,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Color(0xFFB3E5FC), Color(0xFF0277BD)],
          ).createShader(Rect.fromCircle(center: const Offset(0, -5), radius: 4.8)));
    if (pilot) {
      canvas.drawCircle(const Offset(0, -4.5), 3, Paint()..color = Colors.white);
      canvas.drawRect(const Rect.fromLTRB(-1.6, -6, 2.2, -3.6),
          Paint()..color = const Color(0xFFFFB300));
    }
    canvas.drawCircle(const Offset(-1.8, -6.8), 1.2, Paint()..color = Colors.white70);
  }
}

// --------------------------------------------------------------- people

RRect _r(double l, double t, double w, double h, [double radius = 3]) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(radius));

/// An astronaut in a space suit, feet at (0, 0), about 62 tall.
void paintAstronaut(Canvas canvas,
    {required double walkPhase,
    required bool facingRight,
    required bool walking,
    String? carry,
    double armSwing = 0}) {
  canvas.save();
  if (!facingRight) canvas.scale(-1, 1);
  final suit = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFCFD8DC)],
    ).createShader(const Rect.fromLTWH(-12, -64, 24, 64));
  final shade = Paint()..color = const Color(0xFFB0BEC5);
  final swing = walking ? math.sin(walkPhase) * 6 : 0.0;

  canvas.drawRRect(_r(-17, -46, 10, 22), shade); // backpack
  canvas.drawRRect(_r(-8 + swing, -21, 7, 21), shade); // back leg
  canvas.drawRRect(_r(1 - swing, -21, 7, 21), suit); // front leg
  canvas.drawRRect(_r(-8 + swing, -4, 8, 4, 2), Paint()..color = const Color(0xFF546E7A));
  canvas.drawRRect(_r(1 - swing, -4, 9, 4, 2), Paint()..color = const Color(0xFF546E7A));
  canvas.drawRRect(_r(-9, -44, 19, 26, 6), suit); // body
  canvas.drawRect(const Rect.fromLTWH(-4, -38, 9, 6), Paint()..color = const Color(0xFF1565C0));
  canvas.drawRect(const Rect.fromLTWH(-4, -38, 4, 3), Paint()..color = const Color(0xFFE53935));
  _paintCarry(canvas, carry);
  canvas.save();
  canvas.translate(6, -40);
  canvas.rotate(carry != null ? -1.2 : (walking ? -swing * 0.06 : armSwing));
  canvas.drawRRect(_r(-3, 0, 6, 17), shade); // arm
  canvas.restore();
  canvas.drawCircle(const Offset(1, -53), 11.5, suit); // helmet
  canvas.drawRRect(
      _r(-1, -58, 12, 9, 4),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
        ).createShader(const Rect.fromLTWH(-1, -58, 12, 9))); // visor
  canvas.drawCircle(const Offset(7, -55), 1.6, Paint()..color = Colors.white70);
  canvas.restore();
}

/// A ground-crew person in a blue jumpsuit (before the space suit goes on).
void paintCrew(Canvas canvas,
    {required double walkPhase,
    required bool facingRight,
    required bool walking,
    String? carry,
    double armSwing = 0}) {
  canvas.save();
  if (!facingRight) canvas.scale(-1, 1);
  final suit = Paint()..color = const Color(0xFF1E63B5);
  final suitDark = Paint()..color = const Color(0xFF164C8C);
  final skin = Paint()..color = const Color(0xFFF2C9A0);
  final swing = walking ? math.sin(walkPhase) * 6 : 0.0;

  canvas.drawRRect(_r(-6 + swing, -22, 6, 22, 2), suitDark);
  canvas.drawRRect(_r(1 - swing, -22, 6, 22, 2), suit);
  final shoe = Paint()..color = const Color(0xFF212121);
  canvas.drawRRect(_r(-6 + swing, -3, 8, 3, 1), shoe);
  canvas.drawRRect(_r(1 - swing, -3, 8, 3, 1), shoe);
  canvas.drawRRect(_r(-7, -44, 15, 24, 4), suit); // body
  canvas.drawRect(const Rect.fromLTWH(1, -40, 5, 3), Paint()..color = Colors.white);
  _paintCarry(canvas, carry);
  canvas.save();
  canvas.translate(4, -41);
  canvas.rotate(carry != null ? -1.2 : (walking ? -swing * 0.06 : armSwing));
  canvas.drawRRect(_r(-2.5, 0, 5, 16, 2), suitDark);
  canvas.drawCircle(const Offset(0, 17), 2.6, skin);
  canvas.restore();
  canvas.drawRect(const Rect.fromLTWH(-1.5, -48, 4, 5), skin); // neck
  canvas.drawCircle(const Offset(1, -54), 7.5, skin); // head
  final hair = Paint()..color = const Color(0xFF5D4037);
  canvas.drawArc(Rect.fromCircle(center: const Offset(1, -55), radius: 8), math.pi, math.pi,
      true, hair);
  canvas.drawRRect(_r(-8, -58, 6, 12, 3), hair); // ponytail side
  canvas.drawCircle(const Offset(5, -54), 1.1, Paint()..color = const Color(0xFF263238));
  canvas.drawArc(Rect.fromCircle(center: const Offset(4, -51), radius: 2.2), 0.2, 2.6, false,
      Paint()
        ..color = const Color(0xFF8D4A3A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9);
  canvas.restore();
}

void _paintCarry(Canvas canvas, String? carry) {
  switch (carry) {
    case 'oxygen':
      canvas.drawRRect(_r(6, -46, 9, 24, 4), Paint()..color = const Color(0xFF2E7D32));
      canvas.drawRect(const Rect.fromLTWH(8, -49, 5, 4), Paint()..color = const Color(0xFFB0BEC5));
      canvas.drawRect(const Rect.fromLTWH(6, -38, 9, 3), Paint()..color = Colors.white70);
    case 'snacks':
      canvas.drawRect(const Rect.fromLTWH(5, -42, 16, 13), Paint()..color = const Color(0xFFB07A44));
      canvas.drawRect(const Rect.fromLTWH(5, -37, 16, 2), Paint()..color = const Color(0xFF7B5228));
      paintLabel(canvas, '🍕', const Offset(13, -36), size: 7);
    default:
      break;
  }
}
