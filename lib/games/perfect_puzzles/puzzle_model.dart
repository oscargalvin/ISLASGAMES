import 'dart:math' as math;
import 'dart:ui';

/// One puzzle in Perfect Puzzles.
class PuzzleLevel {
  const PuzzleLevel({
    required this.title,
    required this.cols,
    required this.rows,
    required this.image,
    this.tutorial = false,
  });

  final String title;
  final int cols;
  final int rows;
  final String image;

  /// The tutorial is the only puzzle that shows you where pieces go.
  final bool tutorial;

  int get pieceCount => cols * rows;
}

/// The puzzles, in order. Swap the pictures in assets/puzzles/ to change them.
const List<PuzzleLevel> puzzleLevels = [
  PuzzleLevel(
      title: 'Cool Cat',
      cols: 2,
      rows: 2,
      image: 'assets/puzzles/cat_1.png',
      tutorial: true),
  PuzzleLevel(
      title: 'Flamingo Floaty',
      cols: 5,
      rows: 2,
      image: 'assets/puzzles/cat_2.png'),
  PuzzleLevel(
      title: 'DJ Whiskers',
      cols: 5,
      rows: 4,
      image: 'assets/puzzles/cat_3.png'),
  PuzzleLevel(
      title: 'Pizza Party',
      cols: 10,
      rows: 5,
      image: 'assets/puzzles/cat_4.png'),
  PuzzleLevel(
      title: 'Skater Cat',
      cols: 10,
      rows: 10,
      image: 'assets/puzzles/cat_5.png'),
  PuzzleLevel(
      title: 'Beach Day',
      cols: 20,
      rows: 15,
      image: 'assets/puzzles/cat_6.png'),
];

/// The state of one puzzle: which pieces are on the board and which are
/// still in the tray, plus the bumps and holes on every piece.
class PuzzleModel {
  PuzzleModel(this.level, {int? seed}) {
    final rnd = math.Random(seed ?? level.pieceCount);
    // +1: the piece on the left/top has a bump sticking out; -1: a hole.
    _right = List.generate(level.rows,
        (_) => List.generate(level.cols, (_) => rnd.nextBool() ? 1 : -1));
    _bottom = List.generate(level.rows,
        (_) => List.generate(level.cols, (_) => rnd.nextBool() ? 1 : -1));
    tray = List.generate(level.pieceCount, (i) => i)..shuffle(rnd);
  }

  final PuzzleLevel level;
  late final List<List<int>> _right;
  late final List<List<int>> _bottom;

  /// Pieces waiting to be placed, in the order they show in the tray.
  late final List<int> tray;
  final Set<int> placed = {};

  int get cols => level.cols;
  int get rows => level.rows;
  bool get complete => placed.length == level.pieceCount;

  int rowOf(int piece) => piece ~/ cols;
  int colOf(int piece) => piece % cols;

  /// Bump (+1), hole (-1) or flat edge (0) on each side of a piece.
  int top(int p) => rowOf(p) == 0 ? 0 : -_bottom[rowOf(p) - 1][colOf(p)];
  int bottom(int p) => rowOf(p) == rows - 1 ? 0 : _bottom[rowOf(p)][colOf(p)];
  int left(int p) => colOf(p) == 0 ? 0 : -_right[rowOf(p)][colOf(p) - 1];
  int right(int p) => colOf(p) == cols - 1 ? 0 : _right[rowOf(p)][colOf(p)];

  /// The rectangle a piece fills on a board of [board] size (without bumps).
  Rect cellRect(int piece, Size board) {
    final w = board.width / cols, h = board.height / rows;
    return Rect.fromLTWH(colOf(piece) * w, rowOf(piece) * h, w, h);
  }

  /// Is [point] (where the piece was dropped, in board coordinates) close
  /// enough to where the piece really goes?
  bool fits(int piece, Offset point, Size board) {
    final cell = cellRect(piece, board);
    return cell
        .inflate(math.min(cell.width, cell.height) * 0.25)
        .contains(point);
  }

  /// Puts a piece on the board if it was dropped in the right spot.
  bool tryPlace(int piece, Offset point, Size board) {
    if (placed.contains(piece) || !fits(piece, point, board)) return false;
    placed.add(piece);
    tray.remove(piece);
    return true;
  }

  /// How far bumps stick out past a piece's cell.
  static double bumpSize(Size cell) => math.min(cell.width, cell.height) * 0.24;

  /// The jigsaw outline of a piece, with its cell's top-left at (0, 0).
  Path piecePath(int piece, Size cell) {
    final w = cell.width, h = cell.height, t = bumpSize(cell);
    final path = Path()..moveTo(0, 0);
    _edge(path, Offset.zero, Offset(w, 0), top(piece), t);
    _edge(path, Offset(w, 0), Offset(w, h), right(piece), t);
    _edge(path, Offset(w, h), Offset(0, h), bottom(piece), t);
    _edge(path, Offset(0, h), Offset.zero, left(piece), t);
    return path..close();
  }

  static void _edge(Path path, Offset a, Offset b, int side, double t) {
    if (side == 0) {
      path.lineTo(b.dx, b.dy);
      return;
    }
    final d = b - a;
    // Going clockwise, "outwards" is to the left of the direction of travel.
    final n = Offset(d.dy, -d.dx) / d.distance * (t * side);
    Offset at(double u, double v) => a + d * u + n * v;
    final p0 = at(0.36, 0);
    path.lineTo(p0.dx, p0.dy);
    final c1 = at(0.42, 0.35), c2 = at(0.26, 0.95), p1 = at(0.5, 1.0);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
    final c3 = at(0.74, 0.95), c4 = at(0.58, 0.35), p2 = at(0.64, 0);
    path.cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, p2.dx, p2.dy);
    path.lineTo(b.dx, b.dy);
  }
}
