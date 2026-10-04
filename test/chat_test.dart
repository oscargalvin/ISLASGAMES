import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islas_games/games/chat/chat_game.dart';
import 'package:islas_games/games/chat/chat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('friends reply to what you say', () {
    final rnd = math.Random(3);
    final cat = characters.first;
    expect(replyFor(cat, 'hello! tell me a joke', rnd), contains('?'));
    expect(replyFor(cat, 'bye!', rnd).isNotEmpty, isTrue);
    expect(replyFor(cat, '😂😂', rnd).contains(RegExp('[a-zA-Z]')), isFalse);
  });

  test('chats save and load', () {
    final chat = Chat(id: 'g', members: ['whiskers', 'nova'], groupName: 'Gang')
      ..messages
          .add(ChatMessage(from: 'me', text: 'Hi 👋', time: DateTime(2026)));
    final back = Chat.fromJson(
        jsonDecode(jsonEncode(chat.toJson())) as Map<String, dynamic>);
    expect(back.isGroup, isTrue);
    expect(back.messages.single.text, 'Hi 👋');
    final friend = Contact.custom('me_1', 'Granny', '👵');
    expect(Contact.fromJson(friend.toJson()).name, 'Granny');
  });

  testWidgets('send a message and get a reply', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: ChatGame()));
    await tester.pumpAndSettle();
    expect(find.text('The Cool Gang'), findsOneWidget);
    await tester.tap(find.text('Whiskers'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('typing...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('typing...'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('make a group chat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: ChatGame()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.group_add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Best Friends');
    await tester.tap(find.text('Captain Nova'));
    await tester.tap(find.text('Flamingo Flo'));
    await tester.pump();
    await tester.tap(find.text('Make group'));
    await tester.pumpAndSettle();
    expect(find.text('You made the group "Best Friends" 🎉'), findsOneWidget);
  });
}
