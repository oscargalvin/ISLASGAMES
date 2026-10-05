import 'dart:convert';

import 'package:http/http.dart' as http;

/// Someone in a chat.
class Person {
  const Person(
      {required this.id,
      required this.name,
      required this.avatar,
      this.me = false});

  final String id;
  final String name;
  final String avatar;
  final bool me;

  static Person fromJson(Map<String, dynamic> j) => Person(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Someone',
        avatar: j['avatar'] as String? ?? '🙂',
        me: j['me'] as bool? ?? false,
      );
}

class ChatMessage {
  ChatMessage({
    required this.seq,
    required this.from,
    required this.text,
    required this.time,
    this.sending = false,
  });

  /// Message number in its chat, counting up from 1.
  final int seq;

  /// A person's id, 'me' or 'ai' (Islas AI chat), or 'system'.
  final String from;
  final String text;
  final DateTime time;

  /// Still on its way to the server.
  bool sending;

  static ChatMessage fromJson(Map<String, dynamic> j) => ChatMessage(
        seq: (j['seq'] as num?)?.toInt() ?? 0,
        from: j['from'] as String,
        text: j['text'] as String,
        time: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
      );

  Map<String, dynamic> toJson() => {
        'seq': seq,
        'from': from,
        'text': text,
        't': time.millisecondsSinceEpoch
      };
}

/// A chat or group with real friends, kept on the server.
class Chat {
  Chat({
    required this.id,
    required this.group,
    required this.invite,
    required this.members,
    this.name,
    this.avatar,
    this.seq = 0,
    this.last,
  });

  final String id;
  final bool group;
  final String? name;
  final String? avatar;
  final String invite;
  List<Person> members;

  /// The newest message number on the server.
  int seq;
  ChatMessage? last;
  final List<ChatMessage> messages = [];

  List<Person> get others => members.where((m) => !m.me).toList();

  String get title {
    if (group) return name ?? 'Group';
    final o = others;
    return o.isEmpty ? 'New chat' : o.first.name;
  }

  String get picture {
    if (group) return avatar ?? '👥';
    final o = others;
    return o.isEmpty ? '💬' : o.first.avatar;
  }

  Person? person(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The newest message number this device has.
  int get newestHere {
    for (final m in messages.reversed) {
      if (!m.sending) return m.seq;
    }
    return 0;
  }

  void update(Chat from) {
    members = from.members;
    seq = from.seq;
    last = from.last;
  }

  static Chat fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'] as String,
        group: j['group'] as bool? ?? false,
        name: j['name'] as String?,
        avatar: j['avatar'] as String?,
        invite: j['invite'] as String,
        members: [
          for (final m in j['members'] as List)
            Person.fromJson(Map<String, dynamic>.from(m as Map))
        ],
        seq: (j['seq'] as num?)?.toInt() ?? 0,
        last: j['last'] == null
            ? null
            : ChatMessage.fromJson(Map<String, dynamic>.from(j['last'] as Map)),
      );
}

class ChatError implements Exception {
  ChatError(this.code);

  final String code;

  /// What to tell the person.
  String get friendly => switch (code) {
        'not_set_up' =>
          "Islas Chat isn't switched on yet. The chat server needs its database.",
        'ai_not_set_up' =>
          "Islas AI isn't switched on yet. It needs its AI key.",
        'ai_tired' => 'Islas AI is tired for today 😴 Try again tomorrow!',
        'no_such_invite' =>
          "That invite code doesn't work. Check it and try again.",
        'not_in_chat' => "You're not in that chat any more.",
        'need_name' => 'Type your name first.',
        'offline' => "Can't reach Islas Chat. Check your internet.",
        _ => 'Something went wrong. Try again.',
      };

  @override
  String toString() => 'ChatError($code)';
}

/// Talks to the Islas Chat server at /api/chat.
class ChatApi {
  ChatApi({http.Client? client, Uri? endpoint})
      : _client = client ?? http.Client(),
        endpoint = endpoint ?? Uri.base.resolve('/api/chat');

  final http.Client _client;
  final Uri endpoint;

  Future<Map<String, dynamic>> call(String action,
      [Map<String, dynamic> body = const {}]) async {
    final http.Response r;
    try {
      r = await _client.post(endpoint,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'action': action, ...body}));
    } catch (_) {
      throw ChatError('offline');
    }
    final Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    } catch (_) {
      // No chat server here yet.
      throw ChatError(r.statusCode == 404 ? 'not_set_up' : 'server_error');
    }
    if (r.statusCode != 200) {
      throw ChatError(j['error'] as String? ?? 'server_error');
    }
    return j;
  }
}
