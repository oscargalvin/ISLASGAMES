import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_model.dart';

const _green = Color(0xFF0B8F7A);
const _darkGreen = Color(0xFF075E54);
const _myBubble = Color(0xFFD7F5E9);
const _saveKey = 'islas_chat_save';

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
  '🙂',
  '😎',
  '🐶',
  '🐸',
  '🐼',
  '🦊',
  '🐯',
  '🐙',
  '👧',
  '👦',
  '👩',
  '👨'
];

/// All the chats and friends, saved on this device.
class ChatStore extends ChangeNotifier {
  final _rnd = math.Random();
  final List<Contact> contacts = [];
  final List<Chat> chats = [];

  /// Who is typing in which chat right now.
  final Map<String, String> typing = {};
  final List<Timer> _timers = [];
  bool loaded = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final saved = p.getString(_saveKey);
      if (saved != null) {
        final j = jsonDecode(saved) as Map<String, dynamic>;
        contacts.addAll([
          for (final c in j['contacts'] as List)
            Contact.fromJson(Map<String, dynamic>.from(c as Map))
        ]);
        chats.addAll([
          for (final c in j['chats'] as List)
            Chat.fromJson(Map<String, dynamic>.from(c as Map))
        ]);
      }
    } catch (_) {
      contacts.clear();
      chats.clear();
    }
    if (contacts.isEmpty) _starter();
    loaded = true;
    notifyListeners();
  }

  void _starter() {
    for (final id in ['whiskers', 'nova', 'flo']) {
      contacts.add(characters.firstWhere((c) => c.id == id));
    }
    final now = DateTime.now();
    final hi = Chat(id: 'chat_whiskers', members: ['whiskers'])
      ..messages.add(ChatMessage(
          from: 'whiskers',
          text: 'Hi! Welcome to Islas Chat 😺 Send me a message!',
          time: now))
      ..unread = 1;
    final group = Chat(
        id: 'group_cool',
        members: ['whiskers', 'nova', 'flo'],
        groupName: 'The Cool Gang',
        groupAvatar: '😎')
      ..messages.add(ChatMessage(
          from: 'nova',
          text: 'Who wants to come to space this weekend? 🚀',
          time: now))
      ..unread = 1;
    chats.addAll([hi, group]);
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _saveKey,
          jsonEncode({
            'contacts': [for (final c in contacts) c.toJson()],
            'chats': [for (final c in chats) c.toJson()],
          }));
    } catch (_) {}
  }

  Contact contact(String id) => contacts.firstWhere((c) => c.id == id,
      orElse: () => characters.firstWhere((c) => c.id == id,
          orElse: () => Contact.custom(id, 'Friend', '🙂')));

  String title(Chat chat) => chat.groupName ?? contact(chat.members.first).name;
  String avatar(Chat chat) =>
      chat.isGroup ? chat.groupAvatar : contact(chat.members.first).avatar;

  List<Chat> get sortedChats => [...chats]..sort((a, b) {
      final ta = a.messages.isEmpty ? DateTime(2000) : a.messages.last.time;
      final tb = b.messages.isEmpty ? DateTime(2000) : b.messages.last.time;
      return tb.compareTo(ta);
    });

  void addContact(Contact c) {
    if (contacts.any((x) => x.id == c.id)) return;
    contacts.add(c);
    _save();
    notifyListeners();
  }

  Chat chatWith(Contact c) {
    final existing = chats.where((x) => !x.isGroup && x.members.first == c.id);
    if (existing.isNotEmpty) return existing.first;
    final chat = Chat(id: 'chat_${c.id}', members: [c.id]);
    chats.add(chat);
    _save();
    notifyListeners();
    return chat;
  }

  Chat makeGroup(String name, String avatar, List<String> members) {
    final chat = Chat(
        id: 'group_${DateTime.now().millisecondsSinceEpoch}',
        members: members,
        groupName: name,
        groupAvatar: avatar);
    chat.messages.add(ChatMessage(
        from: 'system',
        text: 'You made the group "$name" 🎉',
        time: DateTime.now()));
    chats.add(chat);
    _save();
    notifyListeners();
    return chat;
  }

  void deleteChat(Chat chat) {
    chats.remove(chat);
    _save();
    notifyListeners();
  }

  void markRead(Chat chat) {
    if (chat.unread == 0) return;
    chat.unread = 0;
    _save();
    notifyListeners();
  }

  /// Sends my message, then pretend friends type and reply.
  void send(Chat chat, String text, {required bool viewing}) {
    final t = text.trim();
    if (t.isEmpty) return;
    chat.messages.add(ChatMessage(from: 'me', text: t, time: DateTime.now()));
    _save();
    notifyListeners();

    final repliers = chat.isGroup
        ? ([...chat.members]..shuffle(_rnd))
            .take(1 + _rnd.nextInt(math.min(2, chat.members.length)))
        : chat.members;
    var delay = 700;
    for (final id in repliers) {
      final who = contact(id);
      _later(delay, () {
        typing[chat.id] = id;
        notifyListeners();
      });
      delay += 1100 + _rnd.nextInt(1200);
      _later(delay, () {
        typing.remove(chat.id);
        for (final m in chat.messages) {
          if (m.from == 'me') m.read = true;
        }
        chat.messages.add(ChatMessage(
            from: id,
            text: replyFor(who, t, _rnd, group: chat.isGroup),
            time: DateTime.now()));
        if (!viewingChats.contains(chat.id)) chat.unread++;
        _save();
        notifyListeners();
      });
      delay += 400;
    }
  }

  /// Chats that are open on screen (so replies don't count as unread).
  final Set<String> viewingChats = {};

  void _later(int ms, VoidCallback f) =>
      _timers.add(Timer(Duration(milliseconds: ms), f));

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}

/// Islas Chat: a pretend messaging app with funny friends who text back.
class ChatGame extends StatefulWidget {
  const ChatGame({super.key});

  @override
  State<ChatGame> createState() => _ChatGameState();
}

class _ChatGameState extends State<ChatGame> {
  final store = ChatStore();

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _green),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _darkGreen,
          foregroundColor: Colors.white,
        ),
      ),
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => _ChatList(store: store),
      ),
    );
  }
}

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _Avatar extends StatelessWidget {
  const _Avatar(this.emoji, {this.size = 48});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: Color(0xFFE0F2EF), shape: BoxShape.circle),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.55)),
      );
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.store});

  final ChatStore store;

  void _open(BuildContext context, Chat chat) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Theme(
        data: Theme.of(context),
        child: _ChatScreen(store: store, chat: chat),
      ),
    ));
  }

  Future<void> _newChat(BuildContext context) async {
    final picked = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
                title: Text('New chat',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 20))),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: _green,
                  child: Icon(Icons.person_add, color: Colors.white)),
              title: const Text('Add a friend'),
              onTap: () async {
                Navigator.pop(context);
                await _addFriend(context);
              },
            ),
            for (final c in store.contacts)
              ListTile(
                leading: _Avatar(c.avatar, size: 40),
                title: Text(c.name),
                subtitle: Text(c.status),
                onTap: () => Navigator.pop(context, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null && context.mounted) {
      _open(context, store.chatWith(picked));
    }
  }

  Future<void> _addFriend(BuildContext context) async {
    final notAdded = characters
        .where((c) => !store.contacts.any((x) => x.id == c.id))
        .toList();
    final nameCtrl = TextEditingController();
    var avatar = _avatarChoices.first;
    final added = await showDialog<Contact>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add a friend'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notAdded.isNotEmpty) ...[
                    const Text('Fun friends to add:',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    for (final c in notAdded)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _Avatar(c.avatar, size: 40),
                        title: Text(c.name),
                        subtitle: Text(c.status),
                        trailing: const Icon(Icons.add_circle, color: _green),
                        onTap: () => Navigator.pop(context, c),
                      ),
                    const Divider(),
                  ],
                  const Text('Or make your own friend:',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final a in _avatarChoices)
                        ChoiceChip(
                          label: Text(a, style: const TextStyle(fontSize: 20)),
                          selected: avatar == a,
                          onSelected: (_) => setDialog(() => avatar = a),
                        ),
                    ],
                  ),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: "Friend's name"),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(
                    context,
                    Contact.custom(
                        'me_${DateTime.now().millisecondsSinceEpoch}',
                        name,
                        avatar));
              },
              child: const Text('Add my friend'),
            ),
          ],
        ),
      ),
    );
    if (added == null) return;
    store.addContact(added);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${added.name} ${added.avatar} is now your friend!')));
    }
  }

  Future<void> _newGroup(BuildContext context) async {
    final chosen = <String>{};
    final nameCtrl = TextEditingController();
    var avatar = '👥';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('New group'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, children: [
                    for (final a in [
                      '👥',
                      '🎉',
                      '😎',
                      '⚽',
                      '🎮',
                      '🍕',
                      '🌈',
                      '🔥'
                    ])
                      ChoiceChip(
                        label: Text(a, style: const TextStyle(fontSize: 20)),
                        selected: avatar == a,
                        onSelected: (_) => setDialog(() => avatar = a),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Who is in it? (pick at least 2)',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  for (final c in store.contacts)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: _Avatar(c.avatar, size: 36),
                      title: Text(c.name),
                      value: chosen.contains(c.id),
                      onChanged: (v) => setDialog(
                          () => v! ? chosen.add(c.id) : chosen.remove(c.id)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed:
                  chosen.length < 2 ? null : () => Navigator.pop(context, true),
              child: const Text('Make group'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final name =
        nameCtrl.text.trim().isEmpty ? 'My group' : nameCtrl.text.trim();
    _open(context, store.makeGroup(name, avatar, chosen.toList()));
  }

  @override
  Widget build(BuildContext context) {
    final chats = store.sortedChats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Islas Chat',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              tooltip: 'Add a friend',
              onPressed: () => _addFriend(context),
              icon: const Icon(Icons.person_add_alt_1)),
          IconButton(
              tooltip: 'New group',
              onPressed: () => _newGroup(context),
              icon: const Icon(Icons.group_add)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        tooltip: 'New chat',
        onPressed: () => _newChat(context),
        child: const Icon(Icons.chat),
      ),
      body: !store.loaded
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
              ? const Center(
                  child:
                      Text('No chats yet. Tap the green button to start one!'))
              : ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 80),
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final last =
                        chat.messages.isEmpty ? null : chat.messages.last;
                    final typer = store.typing[chat.id];
                    final String preview;
                    if (typer != null) {
                      preview = '${store.contact(typer).name} is typing...';
                    } else if (last == null) {
                      preview = 'Say hi! 👋';
                    } else if (last.from == 'me') {
                      preview = 'You: ${last.text}';
                    } else if (chat.isGroup && last.from != 'system') {
                      preview =
                          '${store.contact(last.from).name}: ${last.text}';
                    } else {
                      preview = last.text;
                    }
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: _Avatar(store.avatar(chat), size: 52),
                      title: Text(store.title(chat),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: typer != null ? _green : null,
                              fontStyle:
                                  typer != null ? FontStyle.italic : null)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (last != null)
                            Text(_time(last.time),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: chat.unread > 0
                                        ? _green
                                        : Colors.black54)),
                          const SizedBox(height: 4),
                          if (chat.unread > 0)
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: _green,
                              child: Text('${chat.unread}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white)),
                            ),
                        ],
                      ),
                      onTap: () => _open(context, chat),
                      onLongPress: () async {
                        final del = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                                'Delete the chat with ${store.title(chat)}?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('No')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (del == true) store.deleteChat(chat);
                      },
                    );
                  },
                ),
    );
  }
}

class _ChatScreen extends StatefulWidget {
  const _ChatScreen({required this.store, required this.chat});

  final ChatStore store;
  final Chat chat;

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _emojis = false;

  ChatStore get store => widget.store;
  Chat get chat => widget.chat;

  @override
  void initState() {
    super.initState();
    store.viewingChats.add(chat.id);
    store.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => store.markRead(chat));
    _text.addListener(() => setState(() {}));
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.viewingChats.remove(chat.id);
    store.removeListener(_changed);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    store.send(chat, _text.text, viewing: true);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final typer = store.typing[chat.id];
    final subtitle = typer != null
        ? (chat.isGroup
            ? '${store.contact(typer).name} is typing...'
            : 'typing...')
        : chat.isGroup
            ? ['You', for (final m in chat.members) store.contact(m).name]
                .join(', ')
            : store.contact(chat.members.first).status;
    final messages = chat.messages.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _Avatar(store.avatar(chat), size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.title(chat),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
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
                        final at = sel.isValid ? sel.start : t.length;
                        _text.value = TextEditingValue(
                          text: t.replaceRange(
                              at, sel.isValid ? sel.end : t.length, e),
                          selection:
                              TextSelection.collapsed(offset: at + e.length),
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
    return Container(
      color: const Color(0xFFF0F2F5),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
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
                        if (_emojis) {
                          _focus.unfocus();
                        } else {
                          _focus.requestFocus();
                        }
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
                        onTap: () => setState(() => _emojis = false),
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          border: InputBorder.none,
                        ),
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
              backgroundColor: _green,
              foregroundColor: Colors.white,
              tooltip: 'Send',
              onPressed: _text.text.trim().isEmpty ? null : _send,
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
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(m.text, style: const TextStyle(fontSize: 13)),
        ),
      );
    }
    final mine = m.from == 'me';
    final who = mine ? null : store.contact(m.from);
    final bigEmoji =
        !RegExp(r'[a-zA-Z0-9]').hasMatch(m.text) && m.text.runes.length <= 6;
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
              if (chat.isGroup && who != null)
                Text('${who.avatar} ${who.name}',
                    style: TextStyle(
                        color: Color(who.color),
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
                    Icon(Icons.done_all,
                        size: 16,
                        color:
                            m.read ? const Color(0xFF34B7F1) : Colors.black38),
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
