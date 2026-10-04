import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:islas_games/main.dart';

void main() {
  testWidgets('Perfect Puzzles lists the puzzles', (tester) async {
    await tester.pumpWidget(const IslasGamesApp());
    expect(find.text('Space Adventure'), findsOneWidget);
    expect(find.text('Tap Counter'), findsNothing);
    await tester.tap(find.text('Perfect Puzzles'));
    await tester.pumpAndSettle();
    expect(find.text('Tutorial'), findsOneWidget);
    expect(find.text('300 pieces'), findsOneWidget);
  });

  testWidgets('archived games are hidden until the creator code is typed',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const IslasGamesApp());
    await tester.pumpAndSettle();
    expect(find.text('Walk to Australia'), findsNothing);
    expect(find.text('Archived games'), findsNothing);

    await tester.longPress(find.text('Islas Games'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Walk to Australia'), findsNothing);

    await tester.longPress(find.text('Islas Games'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'islas2026');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Walk to Australia'), findsOneWidget);
    expect(find.text('Tap Counter'), findsOneWidget);
  });
}
