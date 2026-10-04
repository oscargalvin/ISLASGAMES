import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:islas_games/games/world_walk/walk_model.dart';

/// Plays the game sensibly: eat and drink when low, sleep in a hostel when
/// there's enough money left for food, rest when tired.
WalkGame playSensibly(int seed, {int maxDays = 400}) {
  final rnd = math.Random(seed);
  final g = WalkGame();
  while (g.phase != Phase.won && g.phase != Phase.lost && g.day < maxDays) {
    while (g.food < 70 && g.money >= g.mealPrice && g.buyMeal() == null) {}
    while (g.water < 70 && g.money >= g.waterPrice && g.buyWater() == null) {}
    if (!g.saidHelloToday) g.sayHello(rnd);
    if (g.energy < 25) {
      g.rest();
    } else {
      g.travel(rnd);
    }
    if (g.phase == Phase.morning) g.rest(); // waiting for a boat
    if (g.phase != Phase.evening) break;
    final budgetLeft =
        g.money - g.daysToPayday * (g.mealPrice * 2 + g.waterPrice * 2);
    final bed = g.canSleep(Sleep.campervan)
        ? Sleep.campervan
        : budgetLeft > g.hostelPrice * g.daysToPayday
            ? Sleep.hostel
            : Sleep.camp;
    g.sleep(bed, rnd);
  }
  return g;
}

void main() {
  test('the route goes from Liverpool to Sydney', () {
    expect(route.first.name, 'Liverpool');
    expect(route.last.name, 'Sydney');
    expect(totalKm, inInclusiveRange(18000, 26000));
  });

  test('you get a faster vehicle every two weeks', () {
    final g = WalkGame();
    expect(g.vehicle.name, 'Walking');
    g.day = 15;
    expect(g.vehicle.name, "Kid's bike");
    g.day = 29;
    expect(g.vehicle.name, 'Electric scooter');
  });

  test('a sensible player makes it to Sydney', () {
    for (var seed = 0; seed < 10; seed++) {
      final g = playSensibly(seed);
      expect(g.phase, Phase.won, reason: 'seed $seed: ${g.log.take(5)}');
      expect(g.day, inInclusiveRange(60, 200));
    }
  });

  test('never eating or drinking makes you poorly', () {
    final rnd = math.Random(1);
    final g = WalkGame();
    for (var d = 0; d < 30 && g.phase != Phase.lost; d++) {
      g.travel(rnd);
      if (g.phase == Phase.morning) g.rest();
      g.sleep(Sleep.camp, rnd);
    }
    expect(g.phase, Phase.lost);
  });

  test('you stop at Dover and pay for the ferry', () {
    final rnd = math.Random(2);
    final g = WalkGame()..energy = 100;
    final dover = route.indexWhere((c) => c.name == 'Dover');
    g.km = cityKm[dover] - 5;
    g.day = 100; // car: would go straight past without stopping
    g.travel(rnd);
    expect(g.here.name, 'Dover');
    expect(g.atPort, isTrue);
    g.sleep(Sleep.camp, rnd);
    final before = g.money;
    g.travel(rnd);
    expect(g.here.name, 'Calais');
    expect(g.money, lessThanOrEqualTo(before - 35 + 30));
  });

  test('a saved game loads back the same', () {
    final g = playSensibly(3, maxDays: 20);
    final copy = WalkGame.fromJson(
        jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
    expect(copy.toJson(), g.toJson());
  });
}
