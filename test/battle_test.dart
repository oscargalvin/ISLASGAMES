import 'package:flutter_test/flutter_test.dart';
import 'package:islas_games/games/battle/battle_model.dart';

void main() {
  test('a battle royale has 8 fighters on land with pistols', () {
    final g = BattleGame(playerName: 'Oscar', seed: 1);
    expect(g.fighters.length, 8);
    for (final f in g.fighters) {
      expect(g.onLand(f.pos), isTrue);
      expect(f.gun?.type, WeaponType.pistol);
    }
    expect(g.pickups, isNotEmpty);
  });

  test('2v2 puts a bot on your team', () {
    final g = BattleGame(playerName: 'Oscar', mode: Mode.twoVsTwo, seed: 2);
    expect(g.fighters.where((f) => f.team == 0).length, 2);
    expect(g.fighters.where((f) => f.team == 1).length, 2);
  });

  test('bots fight and the game finishes', () {
    final g = BattleGame(playerName: 'Oscar', mode: Mode.oneVsOne, difficulty: Difficulty.hard, seed: 3);
    final c = Controls();
    // The player stands still; the bot should find and beat them.
    for (var i = 0; i < 60 * 240 && !g.over; i++) {
      g.update(1 / 60, c);
    }
    expect(g.over, isTrue);
    expect(g.won, isFalse, reason: '${g.feed.map((k) => k.text)} t=${g.time} hp=${g.player.health}');
  });

  test('shooting uses ammo', () {
    final g = BattleGame(playerName: 'Oscar', seed: 4);
    final c = Controls()..fire = true;
    g.update(1 / 60, c);
    expect(g.player.gun!.mag, 11);
  });
}
