import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:islas_games/games/chat/chat_game.dart';
import 'package:islas_games/games/chat/chat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A pretend Islas Chat server that works like api/chat.js.
class FakeServer {
  final users = <String, Map<String, String>>{};
  final chats = <String, Map<String, dynamic>>{};
  final invites = <String, String>{};
  var _n = 0;
  final aiAsked = <List>[];

  ChatApi api() => ChatApi(
      endpoint: Uri.parse('http://test/api/chat'),
      client: MockClient((req) async {
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        try {
          return http.Response(jsonEncode(handle(b)), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        } on ChatError catch (e) {
          return http.Response(jsonEncode({'error': e.code}), 400);
        }
      }));

  String me(Map b) {
    final t = b['token'] as String? ?? '';
    if (!users.containsKey(t)) throw ChatError('bad_token');
    return t;
  }

  Map<String, dynamic> info(String id, String me) {
    final c = chats[id]!;
    final msgs = c['msgs'] as List;
    return {
      'id': id,
      'group': c['group'],
      'name': c['name'],
      'avatar': c['avatar'],
      'invite': c['invite'],
      'members': [
        for (final m in c['members'] as Set)
          {'id': m, ...users[m]!, 'me': m == me}
      ],
      'seq': msgs.length,
      'last': msgs.isEmpty ? null : msgs.last,
    };
  }

  void post(String chat, String from, String text) {
    final msgs = chats[chat]!['msgs'] as List;
    msgs.add({
      'seq': msgs.length + 1,
      'from': from,
      'text': text,
      't': 1700000000000
    });
  }

  Map<String, dynamic> handle(Map<String, dynamic> b) {
    switch (b['action']) {
      case 'register':
        final id = 'u${_n++}';
        users[id] = {
          'name': b['name'] as String,
          'avatar': b['avatar'] as String
        };
        return {'id': id, 'token': id};
      case 'create':
        final m = me(b);
        final id = 'c${_n++}';
        final code = 'CODE${id.toUpperCase()}';
        invites[code] = id;
        chats[id] = {
          'group': b['group'] == true,
          'name': b['group'] == true ? b['name'] : null,
          'avatar': b['group'] == true ? b['avatar'] : null,
          'invite': code,
          'members': {m},
          'msgs': [],
        };
        return {'chat': info(id, m)};
      case 'join':
        final m = me(b);
        final id = invites[(b['code'] as String).toUpperCase()];
        if (id == null) throw ChatError('no_such_invite');
        if ((chats[id]!['members'] as Set).add(m)) {
          post(id, 'system', '${users[m]!['name']} joined 👋');
        }
        return {'chat': info(id, m)};
      case 'list':
        final m = me(b);
        return {
          'chats': [
            for (final e in chats.entries)
              if ((e.value['members'] as Set).contains(m)) info(e.key, m)
          ]
        };
      case 'send':
        final m = me(b);
        post(b['chatId'] as String, m, b['text'] as String);
        return {'message': (chats[b['chatId']]!['msgs'] as List).last};
      case 'messages':
        me(b);
        final msgs = chats[b['chatId']]!['msgs'] as List;
        final after = b['after'] as int;
        return {'messages': msgs.skip(after).toList(), 'seq': msgs.length};
      case 'ai':
        me(b);
        aiAsked.add(b['history'] as List);
        return {'text': 'Wow, space! 🚀 Can you see the stars?'};
    }
    throw ChatError('unknown_action');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('two friends chat through an invite code', () async {
    final server = FakeServer();
    final oscar = ChatStore(api: server.api());
    final sam = ChatStore(api: server.api());
    await oscar.signUp('Oscar', '😎');
    await sam.signUp('Sam', '🐸');

    final group = await oscar.create(group: true, name: 'Gang', avatar: '🎉');
    final samsChat = await sam.join(group.invite);
    expect(samsChat.title, 'Gang');
    expect(samsChat.members.map((m) => m.name), containsAll(['Oscar', 'Sam']));

    await oscar.send(group, "I'm in space 🚀");
    await sam.fetchMessages(samsChat);
    expect(samsChat.messages.map((m) => m.text),
        ['Sam joined 👋', "I'm in space 🚀"]);

    await sam.refresh();
    expect(sam.unread(sam.chats.single), 1);
    oscar.dispose();
    sam.dispose();
  });

  test('a one-to-one chat is named after the friend', () async {
    final server = FakeServer();
    final a = ChatStore(api: server.api());
    final b = ChatStore(api: server.api());
    await a.signUp('Oscar', '😎');
    await b.signUp('Sam', '🐸');
    final chat = await a.create();
    expect(chat.title, 'New chat');
    await b.join(chat.invite.toLowerCase());
    await a.refresh();
    expect(a.chats.single.title, 'Sam');
    expect(a.chats.single.picture, '🐸');
    a.dispose();
    b.dispose();
  });

  test('a bad invite code gives a friendly message', () async {
    final s = ChatStore(api: FakeServer().api());
    await s.signUp('Oscar', '😎');
    expect(() => s.join('NOPE'), throwsA(isA<ChatError>()));
    expect(ChatError('no_such_invite').friendly, contains("doesn't work"));
    s.dispose();
  });

  test('Islas AI gets the conversation and replies', () async {
    final server = FakeServer();
    final s = ChatStore(api: server.api());
    await s.signUp('Oscar', '😎');
    await s.askAi("Oh my god I'm in space");
    expect(s.aiMessages.last.text, contains('space'));
    expect(server.aiAsked.single.single,
        {'me': true, 'text': "Oh my god I'm in space"});
    s.dispose();
  });

  testWidgets('sign up, start a chat and send a message', (tester) async {
    final server = FakeServer();
    await tester.pumpWidget(MaterialApp(home: ChatGame(api: server.api())));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Islas Chat! 👋'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Oscar');
    await tester.ensureVisible(find.text('Start chatting'));
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(find.text('Islas AI'), findsOneWidget);

    await tester.tap(find.byTooltip('New chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat with a friend'));
    await tester.pumpAndSettle();
    expect(find.textContaining('?join=CODE'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    await tester.pump();
    expect(find.text('hello'), findsOneWidget);
    expect(
        (server.chats.values.single['msgs'] as List).single['text'], 'hello');

    // Leave the screen so the polling timer stops.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('an invite link signs you up then joins the chat',
      (tester) async {
    final server = FakeServer();
    final host = ChatStore(api: server.api());
    await tester.runAsync(() async {
      await host.signUp('Oscar', '😎');
      await host.create(group: true, name: 'Party', avatar: '🎉');
      host.dispose();
    });
    // A different person's device.
    SharedPreferences.setMockInitialValues({});
    final code = server.invites.keys.single;

    await tester.pumpWidget(
        MaterialApp(home: ChatGame(api: server.api(), joinCode: code)));
    await tester.pumpAndSettle();
    expect(find.text("You've been invited to a chat! 🎉"), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.ensureVisible(find.text('Start chatting'));
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(find.text('Party'), findsOneWidget);
    expect(find.text('Sam joined 👋'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
