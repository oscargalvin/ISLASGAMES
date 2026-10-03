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
}
