import 'package:flutter_test/flutter_test.dart';

import 'package:islas_games/main.dart';

void main() {
  testWidgets('Perfect Puzzles lists the puzzles', (tester) async {
    await tester.pumpWidget(const IslasGamesApp());
    expect(find.text('Space Adventure'), findsNothing);
    expect(find.text('Tap Counter'), findsNothing);
    await tester.tap(find.text('Perfect Puzzles'));
    await tester.pumpAndSettle();
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('300 pieces'), findsOneWidget);
  });
}
