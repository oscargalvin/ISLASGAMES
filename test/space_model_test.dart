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

  void doAllJobs(SpaceGameModel game) {
    for (var i = 0; i < SpaceGameModel.jobs.length; i++) {
      game.tickChecklist(i);
      expect(game.activeJob, i);
      var guard = 0;
      while (game.activeJob != null && guard++ < 1000) {
        run(game, 0.05);
      }
      expect(game.checklistDone, contains(i));
    }
  }

  SpaceGameModel inSpace() {
    final game = SpaceGameModel();
    doAllJobs(game);
    expect(game.personInside, isTrue);
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

  test('the hatch job has to be done last', () {
    final game = SpaceGameModel();
    game.tickChecklist(SpaceGameModel.jobs.length - 1);
    expect(game.activeJob, isNull);
  });

  test('flight clock starts at 5:00 and reaches space', () {
    final game = SpaceGameModel();
    expect(game.flightClock, '5:00');
    final space = inSpace();
    expect(space.health, greaterThan(90));
  });

  test('space slowly wears your health down', () {
    final game = inSpace();
    final before = game.health;
    run(game, 10);
    expect(game.health, lessThan(before));
    expect(game.health, greaterThan(before - 5));
  });

  test('Venus can be explored but hurts more the longer you stay', () {
    final game = inSpace();
    game.land(planetNamed('Venus'));
    expect(game.phase, Phase.surface);
    final start = game.health;
    run(game, 3);
    final firstLoss = start - game.health;
    final mid = game.health;
    run(game, 3);
    final secondLoss = mid - game.health;
    expect(secondLoss, greaterThan(firstLoss));
    expect(game.status, contains('hot'));
    game.pressEnter();
    expect(game.phase, Phase.space);
    expect(game.visited, contains('Venus'));
  });

  test('every planet can be landed on', () {
    for (final p in planets) {
      if (p.landing == LandingType.home) continue;
      final game = inSpace();
      game.land(p);
      expect(game.phase, Phase.surface, reason: p.name);
      run(game, 1);
    }
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

  test('pressing E five times skips the flight, but not the launch pad', () {
    final game = SpaceGameModel();
    for (var i = 0; i < 5; i++) {
      game.pressSecretKey();
    }
    expect(game.phase, Phase.setup);

    doAllJobs(game);
    game.launch();
    run(game, 8);
    expect(game.phase, Phase.flight);
    for (var i = 0; i < 4; i++) {
      game.pressSecretKey();
    }
    expect(game.phase, Phase.flight);
    game.pressSecretKey();
    expect(game.phase, Phase.space);
  });
}
