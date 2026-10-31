import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_model.dart';

const _green = Color(0xFF0B8F7A);
const _darkGreen = Color(0xFF075E54);
const _myBubble = Color(0xFFD7F5E9);
const _meKey = 'islas_chat_me';
const _aiKey = 'islas_chat_ai';
const _seenKey = 'islas_chat_seen';

const _emojiPicker = [
  '😀',
  '😂',
  '🤣',
  '😊',
  '😍',
  '🥰',
  '😎',
  '🤩',
  '😜',
  '🤪',
  '😇',
  '🤔',
  '😴',
  '😱',
  '😭',
  '😡',
  '🥳',
  '🤯',
  '🙈',
  '👻',
  '💩',
  '🤖',
  '👽',
  '🐱',
  '🐶',
  '🦄',
  '🦖',
  '🦩',
  '🐸',
  '🐵',
  '🍕',
  '🍔',
  '🍟',
  '🍩',
  '🍦',
  '🍓',
  '🍉',
  '🎉',
  '🎈',
  '🎁',
  '⚽',
  '🏀',
  '🎮',
  '🚀',
  '🌈',
  '⭐',
  '🔥',
  '💯',
  '❤️',
  '💖',
  '💜',
  '💙',
  '👍',
  '👎',
  '👏',
  '🙌',
  '👋',
  '✌️',
  '🤞',
  '💪',
];

const _avatarChoices = [
  '😎',
  '🙂',
  '🤩',
  '🐱',
  '🐶',
  '🐸',
  '🐼',
  '🦊',
  '🐯',
  '🦄',
  '🦖',
  '🐙',
  '⚽',
  '🎮',
  '🚀',
  '🌈',
];

/// My account, my chats and the Islas AI chat on this device.
class ChatStore extends ChangeNotifier {
  ChatStore({ChatApi? api}) : api = api ?? ChatApi();

  final ChatApi api;
  String? myId;
  String? token;
  String myName = '';
  String myAvatar = '😎';
  List<Chat> chats = [];
  final List<ChatMessage> aiMessages = [];
  bool aiTyping = false;
  final Map<String, int> _seen = {};
  bool loaded = false;

  /// Shown as a banner when the server can't be reached.
  String? problem;

  /// The id of the chat on screen right now.
  String? openChat;
  Timer? _timer;
  int _ticks = 0;
  bool _polling = false;
  bool _disposed = false;

  bool get signedIn => token != null;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final me = p.getString(_meKey);
      if (me != null) {
        final j = jsonDecode(me) as Map<String, dynamic>;
        myId = j['id'] as String;
        token = j['token'] as String;
        myName = j['name'] as String;
        myAvatar = j['avatar'] as String;
      }
      final ai = p.getString(_aiKey);
      if (ai != null) {
        aiMessages.addAll([
          for (final m in jsonDecode(ai) as List)
            ChatMessage.fromJson(Map<String, dynamic>.from(m as Map))
        ]);
      }
      final seen = p.getString(_seenKey);
      if (seen != null) {
        (jsonDecode(seen) as Map)
            .forEach((k, v) => _seen[k as String] = (v as num).toInt());
      }
    } catch (_) {}
    loaded = true;
    _notify();
    if (signedIn) {
      await refresh();
      _startPolling();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _saveMe() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _meKey,
          jsonEncode({
            'id': myId,
            'token': token,
            'name': myName,
            'avatar': myAvatar
          }));
    } catch (_) {}
  }

  Future<void> _saveAi() async {
    try {
      final p = await SharedPreferences.getInstance();
      final keep = aiMessages.where((m) => m.from != 'system').toList();
      await p.setString(
          _aiKey,
          jsonEncode([
            for (final m in keep.skip(math.max(0, keep.length - 200)))
              m.toJson()
          ]));
    } catch (_) {}
  }

  Future<void> _saveSeen() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_seenKey, jsonEncode(_seen));
    } catch (_) {}
  }

  void _startPolling() {
    _timer ??= Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  /// Checks for new messages: often in the open chat, less often for the list.
  Future<void> _poll() async {
    if (_polling || !signedIn) return;
    _polling = true;
    try {
      final open = chatById(openChat);
      if (open != null) await fetchMessages(open);
      if (_ticks++ % 3 == 0) await refresh();
    } finally {
      _polling = false;
    }
  }

  Chat? chatById(String? id) {
    for (final c in chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> signUp(String name, String avatar) async {
    final r = await api('register', {'name': name, 'avatar': avatar});
    myId = r['id'] as String;
    token = r['token'] as String;
    myName = name.trim();
    myAvatar = avatar;
    await _saveMe();
    _notify();
    _startPolling();
  }

  Future<void> updateProfile(String name, String avatar) async {
    await api('profile', {'token': token, 'name': name, 'avatar': avatar});
    myName = name.trim();
    myAvatar = avatar;
    await _saveMe();
    _notify();
  }

  Future<void> refresh() async {
    try {
      final r = await api('list', {'token': token});
      final fresh = [
        for (final c in r['chats'] as List)
          Chat.fromJson(Map<String, dynamic>.from(c as Map))
      ];
      chats = [
        for (final f in fresh) (chatById(f.id)?..update(f)) ?? f,
      ]..sort((a, b) => (b.last?.time ?? DateTime(2000))
          .compareTo(a.last?.time ?? DateTime(2000)));
      problem = null;
    } on ChatError catch (e) {
      problem = e.friendly;
    }
    _notify();
  }

  /// Number of new messages I haven't looked at.
  int unread(Chat c) {
    if (openChat == c.id) return 0;
    if (c.last?.from == myId) return 0;
    return math.max(0, c.seq - (_seen[c.id] ?? 0));
  }

  void markSeen(Chat c) {
    final s = math.max(c.seq, c.newestHere);
    if ((_seen[c.id] ?? 0) >= s) return;
    _seen[c.id] = s;
    _saveSeen();
  }

  void _addChat(Chat c) {
    chats.removeWhere((x) => x.id == c.id);
    chats.insert(0, c);
    _notify();
  }

  Future<Chat> create(
      {bool group = false, String? name, String? avatar}) async {
    final r = await api('create',
        {'token': token, 'group': group, 'name': name, 'avatar': avatar});
    final c = Chat.fromJson(Map<String, dynamic>.from(r['chat'] as Map));
    _addChat(c);
    return c;
  }

  Future<Chat> join(String code) async {
    final r = await api('join', {'token': token, 'code': code.trim()});
    final c = Chat.fromJson(Map<String, dynamic>.from(r['chat'] as Map));
    _seen[c.id] = math.max(_seen[c.id] ?? 0, c.seq);
    _saveSeen();
    final had = chatById(c.id);
    if (had == null) {
      _addChat(c);
      return c;
    }
    had.update(c);
    _notify();
    return had;
  }

  Future<void> leave(Chat c) async {
    await api('leave', {'token': token, 'chatId': c.id});
    chats.remove(c);
    _notify();
  }

  void _take(Chat c, ChatMessage m) {
    if (c.messages.any((x) => !x.sending && x.seq == m.seq)) return;
    if (m.from == myId) {
      // My own message coming back: swap out the "sending" copy.
      final i = c.messages.indexWhere((x) => x.sending && x.text == m.text);
      if (i >= 0) c.messages.removeAt(i);
    }
    final at = c.messages.indexWhere((x) => x.sending || x.seq > m.seq);
    at < 0 ? c.messages.add(m) : c.messages.insert(at, m);
  }

  Future<void> fetchMessages(Chat c) async {
    try {
      final r = await api(
          'messages', {'token': token, 'chatId': c.id, 'after': c.newestHere});
      for (final m in r['messages'] as List) {
        _take(c, ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)));
      }
      c.seq = math.max(c.seq, (r['seq'] as num).toInt());
      if (c.messages.isNotEmpty) {
        c.last = c.messages
            .lastWhere((m) => !m.sending, orElse: () => c.messages.last);
      }
      if (openChat == c.id) markSeen(c);
      problem = null;
    } on ChatError catch (e) {
      problem = e.friendly;
    }
    _notify();
  }

  Future<void> send(Chat c, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final pending = ChatMessage(
        seq: 0, from: myId!, text: t, time: DateTime.now(), sending: true);
    c.messages.add(pending);
    _notify();
    try {
      final r = await api('send', {'token': token, 'chatId': c.id, 'text': t});
      final m =
          ChatMessage.fromJson(Map<String, dynamic>.from(r['message'] as Map));
      _take(c, m);
      c.last = m;
      c.seq = math.max(c.seq, m.seq);
      markSeen(c);
      problem = null;
    } on ChatError catch (e) {
      c.messages.remove(pending);
      problem = e.friendly;
    }
    _notify();
  }

  /// Talk to Islas AI.
  Future<void> askAi(String text) async {
    final t = text.trim();
    if (t.isEmpty || aiTyping) return;
    aiMessages
        .add(ChatMessage(seq: 0, from: 'me', text: t, time: DateTime.now()));
    aiTyping = true;
    _notify();
    try {
      final history = [
        for (final m in aiMessages.where((m) => m.from != 'system'))
          {'me': m.from == 'me', 'text': m.text}
      ];
      final r = await api('ai', {
        'token': token,
        'history': history.sublist(math.max(0, history.length - 20)),
      });
      aiMessages.add(ChatMessage(
          seq: 0, from: 'ai', text: r['text'] as String, time: DateTime.now()));
    } on ChatError catch (e) {
      aiMessages.add(ChatMessage(
          seq: 0, from: 'system', text: e.friendly, time: DateTime.now()));
    }
    aiTyping = false;
    _saveAi();
    _notify();
  }

  void clearAi() {
    aiMessages.clear();
    _saveAi();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

String inviteLink(String code) {
  final site = Uri.base.scheme.startsWith('http')
      ? Uri.base.origin
      : 'https://islasgames.vercel.app';
  return '$site/?join=$code';
}

/// Islas Chat: message your real friends, make groups, and talk to Islas AI.
class ChatGame extends StatefulWidget {
  const ChatGame({super.key, this.joinCode, this.api});

  /// From an invite link: join this chat straight away.
  final String? joinCode;
  final ChatApi? api;

  @override
  State<ChatGame> createState() => _ChatGameState();
}

class _ChatGameState extends State<ChatGame> {
  late final store = ChatStore(api: widget.api);
  String? _joinCode;

  @override
  void initState() {
    super.initState();
    _joinCode = widget.joinCode;
    store.load().then((_) => _maybeJoin());
  }

  Future<void> _maybeJoin() async {
    final code = _joinCode;
    if (code == null || !store.signedIn || !mounted) return;
    _joinCode = null;
    try {
      final chat = await store.join(code);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            Theme(data: _theme, child: _ChatScreen(store: store, chat: chat)),
      ));
    } on ChatError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.friendly)));
      }
    }
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (!store.loaded) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!store.signedIn) {
            return _Welcome(
                store: store, inviting: _joinCode != null, onDone: _maybeJoin);
          }
          return _ChatList(store: store);
        },
      ),
    );
  }
}

final _theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _green),
  useMaterial3: true,
  appBarTheme: const AppBarTheme(
      backgroundColor: _darkGreen, foregroundColor: Colors.white),
);

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _Avatar extends StatelessWidget {
  const _Avatar(this.emoji, {this.size = 48, this.ai = false});

  final String emoji;
  final double size;
  final bool ai;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ai ? null : const Color(0xFFE0F2EF),
          gradient: ai
              ? const SweepGradient(colors: [
                  Color(0xFF7C4DFF),
                  Color(0xFF00BFA5),
                  Color(0xFFFFD740),
                  Color(0xFFFF4081),
                  Color(0xFF7C4DFF),
                ])
              : null,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
      );
}

/// Pick an emoji for yourself.
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker(
      {required this.value,
      required this.onChanged,
      this.choices = _avatarChoices});

  final String value;
  final ValueChanged<String> onChanged;
  final List<String> choices;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final a in choices)
            ChoiceChip(
              label: Text(a, style: const TextStyle(fontSize: 20)),
              selected: value == a,
              showCheckmark: false,
              onSelected: (_) => onChanged(a),
            ),
        ],
      );
}

/// First visit: choose a name and an emoji. No phone numbers.
class _Welcome extends StatefulWidget {
  const _Welcome(
      {required this.store, required this.inviting, required this.onDone});

  final ChatStore store;
  final bool inviting;
  final VoidCallback onDone;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  final _name = TextEditingController();
  String _avatar = _avatarChoices.first;
  bool _busy = false;
  String? _error;

  Future<void> _go() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Type your name first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.signUp(_name.text, _avatar);
      widget.onDone();
    } on ChatError catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Islas Chat',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: CustomPaint(
        painter: _Wallpaper(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: _Avatar(_avatar, size: 84)),
                      const SizedBox(height: 12),
                      Text(
                        widget.inviting
                            ? "You've been invited to a chat! 🎉"
                            : 'Welcome to Islas Chat! 👋',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pick a name and an emoji so your friends know it\'s you. No phone number needed.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        autofillHints: const <String>[],
                        textCapitalization: TextCapitalization.words,
                        maxLength: 30,
                        decoration: const InputDecoration(
                            labelText: 'Your name',
                            border: OutlineInputBorder()),
                        onSubmitted: (_) => _go(),
                      ),
                      _AvatarPicker(
                          value: _avatar,
                          onChanged: (a) => setState(() => _avatar = a)),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _go,
                        style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            padding: const EdgeInsets.all(16)),
                        child: Text(_busy ? 'Just a sec...' : 'Start chatting',
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the invite link and code to send to friends.
Future<void> showInvite(BuildContext context, Chat chat) {
  final link = inviteLink(chat.invite);
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
          chat.group ? 'Invite friends to ${chat.title}' : 'Invite a friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
              'Send them this link. When they open it, they join the chat.'),
          const SizedBox(height: 12),
          SelectableText(link,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: _darkGreen)),
          const SizedBox(height: 16),
          const Text('Or tell them this code:'),
          const SizedBox(height: 4),
          SelectableText(chat.invite,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 6)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Done')),
        FilledButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Link copied! Paste it to your friend.')));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy link'),
        ),
      ],
    ),
  );
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.store});

  final ChatStore store;

  Future<void> _open(BuildContext context, Chat chat) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Theme(
              data: _theme, child: _ChatScreen(store: store, chat: chat))));

  void _openAi(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Theme(data: _theme, child: _AiScreen(store: store))));

  Future<void> _run(BuildContext context, Future<Chat> Function() make,
      {bool invite = true}) async {
    try {
      final chat = await make();
      if (!context.mounted) return;
      if (invite) await showInvite(context, chat);
      if (context.mounted) await _open(context, chat);
    } on ChatError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.friendly)));
      }
    }
  }

  Future<void> _menu(BuildContext context) async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: _green,
                  child: Icon(Icons.person_add, color: Colors.white)),
              title: const Text('Chat with a friend'),
              subtitle: const Text('Get a link to send them'),
              onTap: () => Navigator.pop(context, 'chat'),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: _green,
                  child: Icon(Icons.group_add, color: Colors.white)),
              title: const Text('New group'),
              subtitle: const Text('Name it and invite lots of friends'),
              onTap: () => Navigator.pop(context, 'group'),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: _green,
                  child: Icon(Icons.login, color: Colors.white)),
              title: const Text('Join with a code'),
              subtitle: const Text('A friend gave you an invite code'),
              onTap: () => Navigator.pop(context, 'join'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (pick) {
      case 'chat':
        await _run(context, () => store.create());
      case 'group':
        await _newGroup(context);
      case 'join':
        await _joinCode(context);
    }
  }

  Future<void> _newGroup(BuildContext context) async {
    final name = TextEditingController();
    var avatar = '👥';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('New group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  autofillHints: const <String>[],
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Group name'),
                ),
                _AvatarPicker(
                  value: avatar,
                  choices: const [
                    '👥',
                    '🎉',
                    '😎',
                    '⚽',
                    '🎮',
                    '🍕',
                    '🌈',
                    '🔥',
                    '🏖️',
                    '🎂'
                  ],
                  onChanged: (a) => setDialog(() => avatar = a),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Make group')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(context,
        () => store.create(group: true, name: name.text, avatar: avatar));
  }

  Future<void> _joinCode(BuildContext context) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join with a code'),
        content: TextField(
          controller: code,
          autofocus: true,
          autofillHints: const <String>[],
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
              fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(hintText: 'ABC123'),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Join')),
        ],
      ),
    );
    if (ok != true || code.text.trim().isEmpty || !context.mounted) return;
    await _run(context, () => store.join(code.text), invite: false);
  }

  Future<void> _editMe(BuildContext context) async {
    final name = TextEditingController(text: store.myName);
    var avatar = store.myAvatar;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Me'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofillHints: const <String>[],
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Your name'),
                ),
                _AvatarPicker(
                    value: avatar,
                    onChanged: (a) => setDialog(() => avatar = a)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await store.updateProfile(name.text, avatar);
    } on ChatError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.friendly)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = store.aiMessages.isEmpty ? null : store.aiMessages.last;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Islas Chat',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Join with a code',
            onPressed: () => _joinCode(context),
            icon: const Icon(Icons.login),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _editMe(context),
              child: Tooltip(
                  message: 'Me', child: _Avatar(store.myAvatar, size: 36)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        tooltip: 'New chat',
        onPressed: () => _menu(context),
        child: const Icon(Icons.chat),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (store.problem != null) _Problem(store.problem!),
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const _Avatar('✨', size: 52, ai: true),
            title: const Text('Islas AI',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              store.aiTyping
                  ? 'typing...'
                  : ai?.text ?? 'Ask me anything! Jokes, ideas, homework help',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: ai == null
                ? null
                : Text(_time(ai.time), style: const TextStyle(fontSize: 12)),
            onTap: () => _openAi(context),
          ),
          const Divider(height: 1, indent: 80),
          for (final chat in store.chats) ...[
            _chatTile(context, chat),
            const Divider(height: 1, indent: 80),
          ],
          if (store.chats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No chats with friends yet.\nTap the green button, then send the invite link to a friend! 💬',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chatTile(BuildContext context, Chat chat) {
    final last = chat.last;
    final unread = store.unread(chat);
    final String preview;
    if (last == null) {
      preview = chat.others.isEmpty
          ? 'Send the invite link to a friend'
          : 'Say hi! 👋';
    } else if (last.from == store.myId) {
      preview = 'You: ${last.text}';
    } else if (chat.group && last.from != 'system') {
      preview = '${chat.person(last.from)?.name ?? 'Someone'}: ${last.text}';
    } else {
      preview = last.text;
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(chat.picture, size: 52),
      title:
          Text(chat.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Text(_time(last.time),
                style: TextStyle(
                    fontSize: 12, color: unread > 0 ? _green : Colors.black54)),
          const SizedBox(height: 4),
          if (unread > 0)
            CircleAvatar(
              radius: 11,
              backgroundColor: _green,
              child: Text('$unread',
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
        ],
      ),
      onTap: () => _open(context, chat),
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFFFFF3C4),
        padding: const EdgeInsets.all(12),
        child: Text('⚠️ $text'),
      );
}

/// A chat with real friends.
class _ChatScreen extends StatefulWidget {
  const _ChatScreen({required this.store, required this.chat});

  final ChatStore store;
  final Chat chat;

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  ChatStore get store => widget.store;
  Chat get chat => widget.chat;

  @override
  void initState() {
    super.initState();
    store.openChat = chat.id;
    store.fetchMessages(chat);
  }

  @override
  void dispose() {
    if (store.openChat == chat.id) store.openChat = null;
    store.markSeen(chat);
    super.dispose();
  }

  Future<void> _leave() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${chat.title}?'),
        content: const Text("You won't get messages from this chat any more."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await store.leave(chat);
      if (mounted) Navigator.of(context).pop();
    } on ChatError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.friendly)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final others = chat.others;
        final subtitle = chat.group
            ? ['You', for (final m in others) m.name].join(', ')
            : others.isEmpty
                ? 'Waiting for your friend to join'
                : 'Tap the invite button to add more friends';
        return _Conversation(
          title: chat.title,
          subtitle: subtitle,
          avatar: _Avatar(chat.picture, size: 38),
          messages: chat.messages,
          isMine: (m) => m.from == store.myId,
          sender: chat.group
              ? (m) {
                  final p = chat.person(m.from);
                  return p == null ? 'Someone' : '${p.avatar} ${p.name}';
                }
              : null,
          banner: store.problem != null
              ? _Problem(store.problem!)
              : others.isEmpty
                  ? _InviteBanner(onTap: () => showInvite(context, chat))
                  : null,
          onSend: (t) => store.send(chat, t),
          actions: [
            IconButton(
              tooltip: 'Invite friends',
              icon: const Icon(Icons.person_add_alt_1),
              onPressed: () => showInvite(context, chat),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _leave(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'leave', child: Text('Leave chat'))
              ],
            ),
          ],
        );
      },
    );
  }
}

class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFFFFF3C4),
        child: InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.link, color: _darkGreen),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Nobody else is here yet. Tap to get the invite link for your friends!')),
            ]),
          ),
        ),
      );
}

/// The chat with Islas AI.
class _AiScreen extends StatelessWidget {
  const _AiScreen({required this.store});

  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _Conversation(
        title: 'Islas AI',
        subtitle: store.aiTyping ? 'typing...' : 'Your AI helper ✨',
        avatar: const _Avatar('✨', size: 38, ai: true),
        messages: [
          if (store.aiMessages.isEmpty)
            ChatMessage(
              seq: 0,
              from: 'ai',
              text:
                  "Hi ${store.myName}! I'm Islas AI ✨ Ask me anything: jokes, stories, ideas or help with homework!",
              time: DateTime.now(),
            ),
          ...store.aiMessages,
        ],
        isMine: (m) => m.from == 'me',
        onSend: store.askAi,
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => store.clearAi(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear chat'))
            ],
          ),
        ],
      ),
    );
  }
}

/// The messages, the wallpaper and the message box.
class _Conversation extends StatefulWidget {
  const _Conversation({
    required this.title,
    required this.subtitle,
    required this.avatar,
    required this.messages,
    required this.isMine,
    required this.onSend,
    this.sender,
    this.banner,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final Widget avatar;
  final List<ChatMessage> messages;
  final bool Function(ChatMessage) isMine;

  /// Name to show above other people's messages in groups.
  final String Function(ChatMessage)? sender;
  final ValueChanged<String> onSend;
  final Widget? banner;
  final List<Widget> actions;

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _emojis = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (_text.text.trim().isEmpty) return;
    widget.onSend(_text.text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            widget.avatar,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: widget.actions,
      ),
      body: Column(
        children: [
          if (widget.banner != null) widget.banner!,
          Expanded(
            child: CustomPaint(
              painter: _Wallpaper(),
              child: ListView.builder(
                reverse: true,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, i) => _bubble(messages[i]),
              ),
            ),
          ),
          _inputBar(),
          if (_emojis)
            SizedBox(
              height: 220,
              child: GridView.count(
                crossAxisCount: 8,
                padding: const EdgeInsets.all(6),
                children: [
                  for (final e in _emojiPicker)
                    InkWell(
                      onTap: () {
                        final sel = _text.selection;
                        final t = _text.text;
                        final start = sel.isValid ? sel.start : t.length;
                        final end = sel.isValid ? sel.end : t.length;
                        _text.value = TextEditingValue(
                          text: t.replaceRange(start, end, e),
                          selection:
                              TextSelection.collapsed(offset: start + e.length),
                        );
                      },
                      child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 26))),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final canSend = _text.text.trim().isNotEmpty;
    return Container(
      color: const Color(0xFFF0F2F5),
      padding: const EdgeInsets.all(6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26)),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Emojis',
                      icon: Icon(
                          _emojis
                              ? Icons.keyboard
                              : Icons.emoji_emotions_outlined,
                          color: Colors.black54),
                      onPressed: () {
                        setState(() => _emojis = !_emojis);
                        _emojis ? _focus.unfocus() : _focus.requestFocus();
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        autofillHints: const <String>[],
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onTap: () => setState(() => _emojis = false),
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                            hintText: 'Message', border: InputBorder.none),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            FloatingActionButton.small(
              heroTag: null,
              elevation: 0,
              backgroundColor: canSend ? _green : Colors.black26,
              foregroundColor: Colors.white,
              tooltip: 'Send',
              onPressed: canSend ? _send : null,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    if (m.from == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3C4),
              borderRadius: BorderRadius.circular(10)),
          child: Text(m.text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
        ),
      );
    }
    final mine = widget.isMine(m);
    final bigEmoji =
        !RegExp(r'[a-zA-Z0-9]').hasMatch(m.text) && m.text.runes.length <= 6;
    final from = !mine && widget.sender != null ? widget.sender!(m) : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: mine ? _myBubble : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 2),
              bottomRight: Radius.circular(mine ? 2 : 14),
            ),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000), blurRadius: 2, offset: Offset(0, 1))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (from != null)
                Text(from,
                    style: TextStyle(
                        color: _nameColor(m.from),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              Text(m.text, style: TextStyle(fontSize: bigEmoji ? 34 : 16)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_time(m.time),
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black45)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(m.sending ? Icons.access_time : Icons.done,
                        size: 15, color: Colors.black38),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Each friend gets their own name colour in groups.
Color _nameColor(String id) {
  const colors = [
    Color(0xFFE65100),
    Color(0xFF3949AB),
    Color(0xFFC62828),
    Color(0xFFD81B60),
    Color(0xFF2E7D32),
    Color(0xFF8E24AA),
    Color(0xFF00838F),
    Color(0xFF6D4C41),
  ];
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) % 1000003;
  }
  return colors[h % colors.length];
}

/// A soft doodle wallpaper behind the messages.
class _Wallpaper extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFECE5DD));
    final paint = Paint()
      ..color = const Color(0x14075E54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const step = 70.0;
    var row = 0;
    for (var y = 10.0; y < size.height + step; y += step, row++) {
      for (var x = (row.isEven ? 10.0 : 45.0);
          x < size.width + step;
          x += step) {
        switch ((x ~/ step + row) % 4) {
          case 0:
            canvas.drawCircle(Offset(x, y), 9, paint);
          case 1:
            final p = Path()
              ..moveTo(x, y + 8)
              ..cubicTo(x - 14, y - 2, x - 6, y - 12, x, y - 4)
              ..cubicTo(x + 6, y - 12, x + 14, y - 2, x, y + 8);
            canvas.drawPath(p, paint);
          case 2:
            canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromCenter(
                        center: Offset(x, y), width: 22, height: 14),
                    const Radius.circular(5)),
                paint);
          default:
            final p = Path();
            for (var i = 0; i < 5; i++) {
              final a = -math.pi / 2 + i * 4 * math.pi / 5;
              final pt = Offset(x + 10 * math.cos(a), y + 10 * math.sin(a));
              i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
            }
            canvas.drawPath(p..close(), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Wallpaper oldDelegate) => false;
}
