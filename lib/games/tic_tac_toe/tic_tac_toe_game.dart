import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The eight ways to get three in a row.
const _lines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
  [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
  [0, 4, 8], [2, 4, 6], // diagonals
];

/// Who has three in a row ('X' or 'O'), 'draw', or null if still playing.
String? ticTacToeWinner(List<String?> board) {
  for (final l in _lines) {
    final a = board[l[0]];
    if (a != null && a == board[l[1]] && a == board[l[2]]) return a;
  }
  return board.contains(null) ? null : 'draw';
}

/// The computer's move: win if it can, block you if it must, otherwise
/// take the middle, a corner, or anything left.
int ticTacToeComputerMove(List<String?> board, String me, math.Random rnd) {
  final you = me == 'X' ? 'O' : 'X';
  int? finish(String who) {
    for (final l in _lines) {
      final marks = l.map((i) => board[i]).toList();
      if (marks.where((m) => m == who).length == 2 && marks.contains(null)) {
        return l[marks.indexOf(null)];
      }
    }
    return null;
  }

  final free = [
    for (var i = 0; i < 9; i++)
      if (board[i] == null) i
  ];
  // Sometimes it makes a silly move, so kids can beat it.
  if (rnd.nextDouble() < 0.2) return free[rnd.nextInt(free.length)];
  final win = finish(me) ?? finish(you);
  if (win != null) return win;
  if (board[4] == null) return 4;
  final corners = [0, 2, 6, 8].where((i) => board[i] == null).toList();
  if (corners.isNotEmpty) return corners[rnd.nextInt(corners.length)];
  return free[rnd.nextInt(free.length)];
}

class TicTacToeGame extends StatefulWidget {
  const TicTacToeGame({super.key});

  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  final _rnd = math.Random();
  List<String?> _board = List.filled(9, null);
  String _turn = 'X';
  bool _vsComputer = true;
  int _xWins = 0, _oWins = 0, _draws = 0;
  Timer? _thinking;

  String? get _result => ticTacToeWinner(_board);

  @override
  void dispose() {
    _thinking?.cancel();
    super.dispose();
  }

  void _play(int i) {
    if (_board[i] != null || _result != null) return;
    if (_vsComputer && _turn == 'O') return;
    _place(i);
    if (_vsComputer && _result == null) {
      _thinking = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _place(ticTacToeComputerMove(_board, 'O', _rnd));
      });
    }
  }

  void _place(int i) {
    setState(() {
      _board[i] = _turn;
      _turn = _turn == 'X' ? 'O' : 'X';
      switch (_result) {
        case 'X':
          _xWins++;
        case 'O':
          _oWins++;
        case 'draw':
          _draws++;
      }
    });
  }

  void _newGame() {
    _thinking?.cancel();
    setState(() {
      _board = List.filled(9, null);
      _turn = 'X';
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final oName = _vsComputer ? 'Computer' : 'Player O';
    final String status;
    if (result == 'draw') {
      status = "It's a draw! 🤝";
    } else if (result == 'X') {
      status = _vsComputer ? 'You win! 🎉' : 'X wins! 🎉';
    } else if (result == 'O') {
      status = _vsComputer ? 'The computer wins! 🤖' : 'O wins! 🎉';
    } else {
      status = _turn == 'X'
          ? (_vsComputer ? 'Your turn (X)' : "X's turn")
          : (_vsComputer ? 'Computer is thinking...' : "O's turn");
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tic-Tac-Toe')),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) {
          final side = math
              .min(box.maxWidth - 32, box.maxHeight - 230)
              .clamp(200.0, 480.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        label: Text('vs Computer'),
                        icon: Icon(Icons.smart_toy)),
                    ButtonSegment(
                        value: false,
                        label: Text('2 Players'),
                        icon: Icon(Icons.people)),
                  ],
                  selected: {_vsComputer},
                  onSelectionChanged: (v) {
                    setState(() {
                      _vsComputer = v.first;
                      _xWins = _oWins = _draws = 0;
                    });
                    _newGame();
                  },
                ),
                const SizedBox(height: 12),
                Text('X: $_xWins   ·   $oName: $_oWins   ·   Draws: $_draws',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(status,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SizedBox(
                  width: side,
                  height: side,
                  child: GridView.count(
                    crossAxisCount: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [for (var i = 0; i < 9; i++) _cell(i, side / 3)],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _newGame,
                  icon: const Icon(Icons.refresh),
                  label: Text(result == null ? 'Start over' : 'Play again'),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _cell(int i, double size) {
    final mark = _board[i];
    final winLine = _lines.firstWhere(
      (l) => l.every((j) => _board[j] != null && _board[j] == _board[l[0]]),
      orElse: () => const [],
    );
    final winning = winLine.contains(i);
    return Material(
      color: winning
          ? Colors.amber.shade200
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _play(i),
        child: Center(
          child: AnimatedScale(
            scale: mark == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Text(
              mark ?? '',
              style: TextStyle(
                fontSize: size * 0.55,
                fontWeight: FontWeight.w900,
                color: mark == 'X' ? Colors.teal : Colors.deepOrange,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
