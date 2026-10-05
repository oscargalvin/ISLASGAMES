import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'puzzle_model.dart';

/// How many puzzles are unlocked (kept while the app is open).
int _unlocked = 1;

/// Perfect Puzzles: funny cat jigsaws from 4 pieces up to 300.
class PerfectPuzzlesGame extends StatefulWidget {
  const PerfectPuzzlesGame({super.key});

  @override
  State<PerfectPuzzlesGame> createState() => _PerfectPuzzlesGameState();
}

class _PerfectPuzzlesGameState extends State<PerfectPuzzlesGame> {
  Future<void> _play(int index) async {
    var i = index;
    while (mounted && i < puzzleLevels.length) {
      final next = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => PuzzleScreen(level: puzzleLevels[i])));
      if (next == null) break;
      setState(() => _unlocked = math.max(_unlocked, i + 2));
      if (!next) break;
      i++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfect Puzzles 🧩')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < puzzleLevels.length; i++) _levelCard(i),
        ],
      ),
    );
  }

  Widget _levelCard(int i) {
    final level = puzzleLevels[i];
    final locked = i >= _unlocked;
    final done = i < _unlocked - 1;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: locked ? null : () => _play(i),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 90,
              child: locked
                  ? Container(
                      color: Colors.black12,
                      child: const Icon(Icons.lock,
                          size: 36, color: Colors.black38),
                    )
                  : Image.asset(level.image, fit: BoxFit.cover),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.tutorial ? 'Tutorial' : '${level.pieceCount} pieces',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                      locked ? 'Finish the one before to unlock' : level.title),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                done
                    ? Icons.check_circle
                    : locked
                        ? Icons.lock_outline
                        : Icons.play_circle_fill,
                color: done ? Colors.green : null,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sound effects: a happy ding, a soft oops and a yay for finishing.
class _Sounds {
  final _ding = AudioPlayer();
  final _oops = AudioPlayer();
  final _yay = AudioPlayer();

  void _play(AudioPlayer p, String file) {
    p.stop().then((_) => p.play(AssetSource('audio/$file'))).catchError((_) {});
  }

  void ding() => _play(_ding, 'ding.wav');
  void oops() => _play(_oops, 'oops.wav');
  void yay() => _play(_yay, 'yay.wav');

  void dispose() {
    for (final p in [_ding, _oops, _yay]) {
      p.dispose().catchError((_) {});
    }
  }
}

/// Playing one puzzle.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.level});

  final PuzzleLevel level;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  late final PuzzleModel model = PuzzleModel(widget.level);
  final _sounds = _Sounds();
  final _boardKey = GlobalKey();
  final _zoom = TransformationController();
  ui.Image? _image;
  int? _dragging;
  String? _message;
  Timer? _messageTimer;
  Size _boardSize = Size.zero;

  PuzzleLevel get level => widget.level;

  @override
  void initState() {
    super.initState();
    _loadImage();
    if (level.tutorial) {
      _say('Drag each piece onto the glowing spot where it goes!', seconds: 6);
    }
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(level.image);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _sounds.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _say(String text, {int seconds = 2}) {
    _messageTimer?.cancel();
    setState(() => _message = text);
    _messageTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _message = null);
    });
  }

  void _drop(int piece, Offset globalPoint) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final point = box.globalToLocal(globalPoint);
    if (model.tryPlace(piece, point, _boardSize)) {
      _sounds.ding();
      if (model.complete) {
        _messageTimer?.cancel();
        setState(() => _message = null);
        Timer(const Duration(milliseconds: 350), _sounds.yay);
      } else {
        _say(level.tutorial ? 'Ding! Great job! 🎉' : 'Ding! 🎉', seconds: 1);
      }
    } else {
      _sounds.oops();
      _say(level.tutorial
          ? 'Oops, not quite! Look for the glowing spot.'
          : "Oops, that doesn't go there!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        title: Text(level.tutorial
            ? 'Tutorial: ${level.title}'
            : '${level.title} · ${level.pieceCount} pieces'),
        actions: [
          if (!level.tutorial && image != null)
            IconButton(
              tooltip: 'Look at the picture',
              icon: const Icon(Icons.image_outlined),
              onPressed: _showPicture,
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${model.placed.length}/${level.pieceCount}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: image == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, box) {
              final portrait = box.maxHeight >= box.maxWidth;
              final trayExtent = portrait
                  ? math.min(box.maxHeight * 0.34, 260.0)
                  : math.min(box.maxWidth * 0.32, 320.0);
              final trayShown = model.complete ? 0.0 : trayExtent;
              _boardSize = _fitBoard(
                  image,
                  portrait
                      ? Size(box.maxWidth, box.maxHeight - trayShown)
                      : Size(box.maxWidth - trayShown, box.maxHeight));
              final board = _board(image);
              final tray = _tray(image, portrait);
              return Stack(
                children: [
                  if (portrait)
                    Column(children: [
                      Expanded(child: board),
                      SizedBox(height: trayShown, child: tray),
                    ])
                  else
                    Row(children: [
                      Expanded(child: board),
                      SizedBox(width: trayShown, child: tray),
                    ]),
                  if (_message != null)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: IgnorePointer(
                          child: Center(child: _bubble(_message!))),
                    ),
                  if (model.complete) _winBanner(),
                ],
              );
            }),
    );
  }

  Widget _bubble(String text) => Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(190),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
      );

  void _showPicture() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Image.asset(level.image),
        ),
      ),
    );
  }

  /// The biggest board with the picture's shape that fits in [space].
  Size _fitBoard(ui.Image image, Size space) {
    const margin = 16.0;
    final aspect = image.width / image.height;
    var w = space.width - margin * 2;
    var h = w / aspect;
    if (h > space.height - margin * 2) {
      h = space.height - margin * 2;
      w = h * aspect;
    }
    return Size(math.max(w, 1), math.max(h, 1));
  }

  Widget _board(ui.Image image) {
    final w = _boardSize.width, h = _boardSize.height;
    final big = level.pieceCount >= 50;
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _zoom,
            maxScale: big ? 6 : 2,
            child: Center(
              child: DragTarget<int>(
                onAcceptWithDetails: (d) => _drop(d.data, d.offset),
                builder: (context, _, __) => CustomPaint(
                  key: _boardKey,
                  size: Size(w, h),
                  painter: _BoardPainter(
                    image: image,
                    model: model,
                    ghost: level.tutorial,
                    glow: level.tutorial ? _dragging : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (big && !model.complete)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: IgnorePointer(
              child: Text('Pinch the board to zoom in 🔍',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _tray(ui.Image image, bool portrait) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF37474F),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: LayoutBuilder(builder: (context, box) {
        const tile = 76.0;
        final across = math.max(
            1, ((portrait ? box.maxHeight : box.maxWidth) - 12) ~/ tile);
        return GridView.builder(
          padding: const EdgeInsets.all(6),
          scrollDirection: portrait ? Axis.horizontal : Axis.vertical,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: across),
          itemCount: model.tray.length,
          itemBuilder: (context, i) =>
              _trayPiece(image, model.tray[i], portrait),
        );
      }),
    );
  }

  Widget _trayPiece(ui.Image image, int piece, bool portrait) {
    final cell =
        Size(_boardSize.width / model.cols, _boardSize.height / model.rows);
    final scale = _zoom.value.getMaxScaleOnAxis();
    final big = Size(cell.width * scale, cell.height * scale);
    final bump = PuzzleModel.bumpSize(big);
    final full = Size(big.width + bump * 2, big.height + bump * 2);
    return Draggable<int>(
      data: piece,
      // Drag the piece across towards the board; swipe the other way to scroll.
      affinity: portrait ? Axis.vertical : Axis.horizontal,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => setState(() => _dragging = piece),
      onDragEnd: (_) => setState(() => _dragging = null),
      feedback: Transform.translate(
        offset: Offset(-full.width / 2, -full.height / 2),
        child: Opacity(
          opacity: 0.9,
          child: CustomPaint(
            size: full,
            painter: _PiecePainter(
                image: image, model: model, piece: piece, lift: true),
          ),
        ),
      ),
      childWhenDragging: const SizedBox.shrink(),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          child: CustomPaint(
            size: full,
            painter: _PiecePainter(image: image, model: model, piece: piece),
          ),
        ),
      ),
    );
  }

  Widget _winBanner() {
    final last = puzzleLevels.last == level;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Center(
        child: Card(
          elevation: 12,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉 Yay! You did it! 🎉',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(
                    level.tutorial
                        ? "Now you know how! From here on, nobody shows you where pieces go."
                        : last
                            ? 'You finished every puzzle. Perfect!'
                            : 'Ready for a bigger one?',
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('All puzzles'),
                    ),
                    if (!last)
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Next puzzle 🧩'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the board: the frame, the pieces already placed and, in the
/// tutorial, a faint picture and a glowing spot for the piece being dragged.
class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.image,
    required this.model,
    required this.ghost,
    required this.glow,
  }) : placedCount = model.placed.length;

  final ui.Image image;
  final PuzzleModel model;
  final bool ghost;
  final int? glow;
  final int placedCount;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final src =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawRRect(
        RRect.fromRectAndRadius(full.inflate(6), const Radius.circular(10)),
        Paint()..color = const Color(0xFF455A64));
    canvas.drawRect(full, Paint()..color = const Color(0xFF546E7A));
    if (ghost) {
      canvas.drawImageRect(
          image, src, full, Paint()..color = const Color(0x55FFFFFF));
    }
    final cell = Size(size.width / model.cols, size.height / model.rows);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, math.min(cell.width, cell.height) * 0.02)
      ..color = const Color(0x55000000);
    for (final p in model.placed) {
      final path =
          model.piecePath(p, cell).shift(model.cellRect(p, size).topLeft);
      canvas.save();
      canvas.clipPath(path);
      canvas.drawImageRect(
          image, src, full, Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
      if (!model.complete) canvas.drawPath(path, edge);
    }
    final g = glow;
    if (g != null) {
      final path =
          model.piecePath(g, cell).shift(model.cellRect(g, size).topLeft);
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x66FFEB3B)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFFEB3B));
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.placedCount != placedCount || old.glow != glow || old.image != image;
}

/// Draws one jigsaw piece, bumps and all.
class _PiecePainter extends CustomPainter {
  _PiecePainter({
    required this.image,
    required this.model,
    required this.piece,
    this.lift = false,
  });

  final ui.Image image;
  final PuzzleModel model;
  final int piece;
  final bool lift;

  @override
  void paint(Canvas canvas, Size size) {
    // The size includes room for bumps on every side.
    // (bumps are 0.24 of the cell's short side, so the short side is 1.48x)
    final bump = 0.24 * size.shortestSide / 1.48;
    final cellFor = Size(size.width - bump * 2, size.height - bump * 2);
    final board = Size(cellFor.width * model.cols, cellFor.height * model.rows);
    final path = model.piecePath(piece, cellFor);
    canvas.translate(bump, bump);
    if (lift) canvas.drawShadow(path, Colors.black, 6, false);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-model.colOf(piece) * cellFor.width,
          -model.rowOf(piece) * cellFor.height, board.width, board.height),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, cellFor.shortestSide * 0.025)
          ..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.piece != piece || old.image != image;
}
