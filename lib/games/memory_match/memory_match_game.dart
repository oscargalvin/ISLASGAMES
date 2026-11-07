import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

const _faces = ['🍓', '🍌', '🍉', '🍇', '🍍', '🥝', '🍒', '🍑', '🍋', '🍎'];

/// Memory Match: flip two cards at a time and find all the fruit pairs.
class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  final _ding = AudioPlayer();
  final _rnd = math.Random();
  int _pairs = 6;
  late List<String> _cards;
  final Set<int> _matched = {};
  final List<int> _open = [];
  int _tries = 0;
  Timer? _flipBack;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _flipBack?.cancel();
    _ding.dispose().catchError((_) {});
    super.dispose();
  }

  void _deal() {
    _flipBack?.cancel();
    final faces = [..._faces]..shuffle(_rnd);
    setState(() {
      _cards = [...faces.take(_pairs), ...faces.take(_pairs)]..shuffle(_rnd);
      _matched.clear();
      _open.clear();
      _tries = 0;
    });
  }

  void _tap(int i) {
    if (_matched.contains(i) || _open.contains(i) || _open.length == 2) return;
    setState(() => _open.add(i));
    if (_open.length < 2) return;
    _tries++;
    final [a, b] = _open;
    if (_cards[a] == _cards[b]) {
      _ding
          .stop()
          .then((_) => _ding.play(AssetSource('audio/ding.wav')))
          .catchError((_) {});
      setState(() {
        _matched.addAll(_open);
        _open.clear();
      });
    } else {
      _flipBack = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(_open.clear);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _matched.length == _cards.length;
    final cols = _pairs <= 6 ? 3 : 4;
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Match')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 6, label: Text('Easy')),
                ButtonSegment(value: 8, label: Text('Medium')),
                ButtonSegment(value: 10, label: Text('Hard')),
              ],
              selected: {_pairs},
              onSelectionChanged: (v) {
                _pairs = v.first;
                _deal();
              },
            ),
            const SizedBox(height: 8),
            Text(
                done
                    ? '🎉 You found them all in $_tries tries!'
                    : 'Tries: $_tries',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: GridView.count(
                    padding: const EdgeInsets.all(12),
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (var i = 0; i < _cards.length; i++) _card(i)
                    ],
                  ),
                ),
              ),
            ),
            if (done)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.icon(
                  onPressed: _deal,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Play again'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(int i) {
    final up = _open.contains(i) || _matched.contains(i);
    return GestureDetector(
      onTap: () => _tap(i),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: up ? 1 : 0),
        duration: const Duration(milliseconds: 250),
        builder: (context, t, _) {
          final showFace = t > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi * t),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(showFace ? math.pi : 0),
              child: Container(
                decoration: BoxDecoration(
                  color: showFace
                      ? (_matched.contains(i)
                          ? Colors.green.shade100
                          : Colors.white)
                      : Colors.teal,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4)
                  ],
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(showFace ? _cards[i] : '?',
                        style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: showFace ? null : Colors.white)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
