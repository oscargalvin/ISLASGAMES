import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:islas_games/games/space_adventure/planets.dart';
import 'package:islas_games/games/space_adventure/space_model.dart';

void main() {
  void run(SpaceGameModel game, double seconds) {
    final c = Controls();
    for (var t = 0.0; t < seconds; t += 0.05) {
      game.update(0.05, c);
    }
  }

  SpaceGameModel inSpace() {
    final game = SpaceGameModel();
    for (var i = 0; i < SpaceGameModel.checklist.length; i++) {
      game.tickChecklist(i);
    }
    game.launch();
    run(game, 8);
    expect(game.phase, Phase.flight);
    run(game, 51);
    expect(game.phase, Phase.space);
    return game;
  }

  test('cannot launch until the rocket is ready', () {
    final game = SpaceGameModel();
    game.launch();
    expect(game.phase, Phase.setup);
  });

  test('flight clock starts at 5:00 and reaches space', () {
    final game = SpaceGameModel();
    expect(game.flightClock, '5:00');
    final space = inSpace();
    expect(space.health, greaterThan(90));
  });

  test('landing on Venus hurts and sends you back to space', () {
    final game = inSpace();
    final before = game.health;
    game.land(planetNamed('Venus'));
    expect(game.phase, Phase.ouch);
    expect(game.health, lessThan(before));
    run(game, 4);
    expect(game.phase, Phase.space);
    expect(game.visited, contains('Venus'));
  });

  test('you can walk on the Moon and fly off again', () {
    final game = inSpace();
    game.land(planetNamed('Moon'));
    expect(game.phase, Phase.surface);
    game.pressEnter();
    expect(game.phase, Phase.space);
  });

  test('flying into the Sun ends the game and ENTER restarts', () {
    final game = inSpace();
    game.rocketPos = const Offset(10, 0);
    run(game, 0.1);
    expect(game.phase, Phase.gameOver);
    game.pressEnter();
    expect(game.phase, Phase.setup);
    expect(game.health, 100);
  });
}
