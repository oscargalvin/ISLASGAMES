import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Sand Drawing: draw in the sand with your finger, then sweep it smooth.
class SandDrawingGame extends StatefulWidget {
  const SandDrawingGame({super.key});

  @override
  State<SandDrawingGame> createState() => _SandDrawingGameState();
}

class _SandDrawingGameState extends State<SandDrawingGame>
    with SingleTickerProviderStateMixin {
  final List<_Stroke> _strokes = [];
  final _sound = AudioPlayer();
  bool _soundReady = false;
  bool _soundOn = true;
  double _width = 14;
  ui.Image? _sand;
  Size _sandSize = Size.zero;
  Offset? _lastPoint;
  DateTime _lastMove = DateTime.now();

  /// Sweeps from left to right when you press Clear.
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(_strokes.clear);
        _sweep.reset();
      }
    });

  @override
  void initState() {
    super.initState();
    _sweep.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sweep.dispose();
    _sound.dispose().catchError((_) {});
    super.dispose();
  }

  Future<void> _startSound() async {
    if (!_soundOn) return;
    try {
      if (!_soundReady) {
        await _sound.setReleaseMode(ReleaseMode.loop);
        await _sound.play(AssetSource('audio/sand.wav'), volume: 0);
        _soundReady = true;
      } else {
        await _sound.resume();
      }
    } catch (_) {}
  }

  void _soundVolume(double v) {
    if (_soundReady) _sound.setVolume(_soundOn ? v : 0).catchError((_) {});
  }

  void _stopSound() {
    if (_soundReady) _sound.pause().catchError((_) {});
  }

  /// Makes the sand picture once for each screen size: warm sand with
  /// thousands of tiny light and dark grains.
  void _makeSand(Size size) {
    if (size == _sandSize || size.isEmpty) return;
    _sandSize = size;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFD9A7), Color(0xFFE2C48A), Color(0xFFD9B97A)],
        ).createShader(full),
    );
    final rnd = math.Random(7);
    // Soft ripples made by the wind.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (var y = -40.0; y < size.height + 40; y += 46) {
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width + 40; x += 40) {
        path.lineTo(x, y + math.sin(x / 90 + y / 37) * 9);
      }
      canvas.drawPath(path, ripple..color = const Color(0x1A8B6B3A));
      canvas.drawPath(path.shift(const Offset(0, 6)),
          ripple..color = const Color(0x14FFFFFF));
    }
    // Grains.
    final grains = (size.width * size.height / 18).clamp(2000, 60000).toInt();
    const colors = [
      Color(0x55A07840),
      Color(0x44FFFFFF),
      Color(0x33704F22),
      Color(0x55C9A465),
      Color(0x22000000),
    ];
    final paints = [for (final c in colors) Paint()..color = c];
    for (var i = 0; i < grains; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.5 + rnd.nextDouble() * 1.1,
        paints[rnd.nextInt(paints.length)],
      );
    }
    final picture = recorder.endRecording();
    _sand = picture.toImageSync(size.width.ceil(), size.height.ceil());
  }

  void _down(Offset p) {
    if (_sweep.isAnimating) return;
    setState(() => _strokes.add(_Stroke(_width)..points.add(p)));
    _lastPoint = p;
    _lastMove = DateTime.now();
    _startSound();
  }

  void _move(Offset p) {
    if (_sweep.isAnimating || _strokes.isEmpty) return;
    final last = _lastPoint ?? p;
    final now = DateTime.now();
    final ms = math.max(1, now.difference(_lastMove).inMilliseconds);
    final speed = (p - last).distance / ms; // pixels per millisecond
    _soundVolume((speed * 0.9).clamp(0.08, 1.0));
    _lastPoint = p;
    _lastMove = now;
    setState(() => _strokes.last.points.add(p));
  }

  void _up() {
    _lastPoint = null;
    _stopSound();
  }

  void _clear() {
    if (_strokes.isEmpty || _sweep.isAnimating) return;
    _startSound();
    _soundVolume(0.6);
    _sweep.forward().whenComplete(_stopSound);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9B97A),
      body: LayoutBuilder(builder: (context, box) {
        _makeSand(box.biggest);
        final sand = _sand;
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: (e) => _down(e.localPosition),
                onPointerMove: (e) => _move(e.localPosition),
                onPointerUp: (_) => _up(),
                onPointerCancel: (_) => _up(),
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _SandPainter(
                      sand: sand,
                      strokes: _strokes,
                      sweep: _sweep.value,
                      version:
                          _strokes.fold<int>(0, (n, s) => n + s.points.length),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: SafeArea(
                child: IconButton.filledTonal(
                  tooltip: 'Back to games',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: SafeArea(
                child: Center(child: _toolbar()),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _toolbar() {
    Widget size(double w, String label) => ChoiceChip(
          label: Text(label),
          selected: _width == w,
          onSelected: (_) => setState(() => _width = w),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(215),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          size(7, 'Thin'),
          size(14, 'Finger'),
          size(26, 'Big'),
          IconButton(
            tooltip: _soundOn ? 'Sound off' : 'Sound on',
            onPressed: () {
              setState(() => _soundOn = !_soundOn);
              if (!_soundOn) _stopSound();
            },
            icon: Icon(_soundOn ? Icons.volume_up : Icons.volume_off),
          ),
          FilledButton.icon(
            onPressed: _strokes.isEmpty ? null : _clear,
            icon: const Icon(Icons.waves),
            label: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Draws the sand and the grooves your finger made in it. Each groove has a
/// shadow on one side, a highlight on the other and a little pushed-up rim,
/// so it looks dug into the sand.
class _SandPainter extends CustomPainter {
  _SandPainter({
    required this.sand,
    required this.strokes,
    required this.sweep,
    required this.version,
  });

  final ui.Image? sand;
  final List<_Stroke> strokes;
  final double sweep;
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final image = sand;
    if (image != null) {
      canvas.drawImage(image, Offset.zero, Paint());
    } else {
      canvas.drawRect(full, Paint()..color = const Color(0xFFE2C48A));
    }
    if (strokes.isEmpty) return;

    // While clearing, only the part not yet swept is left.
    final sweepX = sweep * (size.width + 120) - 60;
    canvas.save();
    if (sweep > 0) {
      canvas.clipRect(Rect.fromLTRB(sweepX, 0, size.width, size.height));
    }

    Paint line(Color c, double w, [double blur = 0]) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null;

    final paths = [for (final s in strokes) (_smooth(s.points), s.width)];
    // Pushed-up rim of sand around the groove.
    for (final (p, w) in paths) {
      canvas.drawPath(p, line(const Color(0x30FFF4D6), w * 1.9, w * 0.35));
    }
    // Shadow side (light comes from the top left).
    for (final (p, w) in paths) {
      canvas.drawPath(p.shift(Offset(w * 0.12, w * 0.12)),
          line(const Color(0x8C6B4A1E), w, w * 0.18));
    }
    // Bottom of the groove.
    for (final (p, w) in paths) {
      canvas.drawPath(p, line(const Color(0xFFC9A464), w * 0.8, w * 0.12));
    }
    // Highlight on the far wall.
    for (final (p, w) in paths) {
      canvas.drawPath(p.shift(Offset(-w * 0.18, -w * 0.18)),
          line(const Color(0x40FFFFFF), w * 0.35, w * 0.12));
    }
    canvas.restore();

    if (sweep > 0) {
      // The smoothing wave of sand.
      final band = Rect.fromLTWH(sweepX - 60, 0, 70, size.height);
      canvas.drawRect(
        band,
        Paint()
          ..shader = const LinearGradient(colors: [
            Color(0x00FFF4D6),
            Color(0x66FFF4D6),
            Color(0x55A07840),
            Color(0x00A07840),
          ]).createShader(band),
      );
    }
  }

  /// Turns the finger's points into a smooth curve.
  static Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 1) {
      path.lineTo(pts.first.dx + 0.1, pts.first.dy);
      return path;
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(_SandPainter old) =>
      old.version != version ||
      old.sweep != sweep ||
      old.sand != sand ||
      old.strokes.length != strokes.length;
}

/// One line drawn in the sand.
class _Stroke {
  _Stroke(this.width);

  final double width;
  final List<Offset> points = [];
}
