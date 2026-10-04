import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islas_games/games/tic_tac_toe/tic_tac_toe_game.dart';
import 'package:islas_games/main.dart';

void main() {
  test('tic-tac-toe spots wins and draws', () {
    expect(ticTacToeWinner(['X', 'X', 'X', null, 'O', 'O', null, null, null]),
        'X');
    expect(ticTacToeWinner(['O', 'X', null, null, 'O', 'X', null, null, 'O']),
        'O');
    expect(
        ticTacToeWinner(['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', 'X']), 'draw');
    expect(ticTacToeWinner(List.filled(9, null)), isNull);
  });

  test('the computer always takes a free square', () {
    final rnd = math.Random(1);
    for (var n = 0; n < 50; n++) {
      final board = <String?>['X', 'O', 'X', null, 'O', null, 'X', null, null];
      expect(board[ticTacToeComputerMove(board, 'O', rnd)], isNull);
    }
  });

  testWidgets('home has the family games', (tester) async {
    await tester.pumpWidget(const IslasGamesApp());
    for (final name in ['Sand Drawing', 'Tic-Tac-Toe', 'Memory Match']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('tapping a square in Tic-Tac-Toe puts an X there',
      (tester) async {
    await tester.pumpWidget(const IslasGamesApp());
    await tester.tap(find.text('Tic-Tac-Toe'));
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
        .first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('X'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
