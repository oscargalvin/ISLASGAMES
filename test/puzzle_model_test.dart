import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:islas_games/games/perfect_puzzles/puzzle_model.dart';

void main() {
  test('levels go 4, 10, 20, 50, 100, 300 and only the first is a tutorial', () {
    expect(puzzleLevels.map((l) => l.pieceCount), [4, 10, 20, 50, 100, 300]);
    expect(puzzleLevels.where((l) => l.tutorial), [puzzleLevels.first]);
  });

  test('neighbouring pieces have matching bumps and holes', () {
    final m = PuzzleModel(puzzleLevels[2]);
    for (var p = 0; p < m.level.pieceCount; p++) {
      if (m.colOf(p) < m.cols - 1) expect(m.right(p), -m.left(p + 1));
      if (m.rowOf(p) < m.rows - 1) expect(m.bottom(p), -m.top(p + m.cols));
    }
    expect(m.top(0), 0);
    expect(m.left(0), 0);
  });

  test('a piece only goes on the board in its own spot', () {
    final m = PuzzleModel(puzzleLevels[1]); // 5 x 2
    const board = Size(500, 200);
    // Piece 6 is row 1, column 1: its cell is 100..200 x 100..200.
    expect(m.tryPlace(6, const Offset(420, 50), board), isFalse);
    expect(m.placed, isEmpty);
    expect(m.tryPlace(6, const Offset(150, 150), board), isTrue);
    expect(m.placed, {6});
    expect(m.tray, isNot(contains(6)));
  });

  test('placing every piece finishes the puzzle', () {
    final m = PuzzleModel(puzzleLevels.first);
    const board = Size(200, 150);
    for (var p = 0; p < 4; p++) {
      m.tryPlace(p, m.cellRect(p, board).center, board);
    }
    expect(m.complete, isTrue);
  });
}
