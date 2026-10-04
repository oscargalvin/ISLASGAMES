import 'package:flutter_test/flutter_test.dart';

import 'package:islas_games/main.dart';

void main() {
  testWidgets('Home shows games and Tap Counter scores', (tester) async {
    await tester.pumpWidget(const IslasGamesApp());
    expect(find.text('Islas Games'), findsOneWidget);

    await tester.tap(find.text('Tap Counter'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.text('Tap!'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Perfect Puzzles lists the puzzles', (tester) async {
    await tester.pumpWidget(const IslasGamesApp());
    await tester.tap(find.text('Perfect Puzzles'));
    await tester.pumpAndSettle();
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('300 pieces'), findsOneWidget);
  });

  testWidgets('Space Adventure opens on the launch pad', (tester) async {
    await tester.pumpWidget(const IslasGamesApp());
    await tester.tap(find.text('Space Adventure'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Get your rocket ready! 🚀'), findsOneWidget);
  });
}
