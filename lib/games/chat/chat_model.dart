import 'dart:math' as math;

/// Someone you can chat with. They're pretend friends who text back.
class Contact {
  const Contact({
    required this.id,
    required this.name,
    required this.avatar,
    required this.status,
    required this.color,
    this.sayings = const [],
    this.emojis = const ['😄', '👍'],
  });

  final String id;
  final String name;
  final String avatar;
  final String status;

  /// Their name colour in group chats.
  final int color;

  /// Things they like to say.
  final List<String> sayings;
  final List<String> emojis;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'status': status,
        'color': color
      };

  /// Friends you add yourself.
  static Contact custom(String id, String name, String avatar) => Contact(
        id: id,
        name: name,
        avatar: avatar,
        status: 'Hey there! I am using Islas Chat.',
        color: 0xFF00897B,
        sayings: const [
          'Haha nice one!',
          'What are you up to?',
          "That's so cool!",
          'Same here 😂',
          'Tell me more!',
          'No way!!',
        ],
      );

  static Contact fromJson(Map<String, dynamic> j) =>
      characters.firstWhere((c) => c.id == j['id'],
          orElse: () => custom(
              j['id'] as String, j['name'] as String, j['avatar'] as String));
}

const characters = <Contact>[
  Contact(
    id: 'whiskers',
    name: 'Whiskers',
    avatar: '🐱',
    status: 'Too cool for school 😎',
    color: 0xFFE65100,
    sayings: [
      'Meow! 😺',
      'I just knocked a cup off the table. Worth it.',
      'Have you got any fish? 🐟',
      'Purrrfect!',
      'I was napping. For 6 hours. Totally normal.',
      'Wearing my sunglasses indoors again 😎',
    ],
    emojis: ['😺', '🐟', '😎', '🐾'],
  ),
  Contact(
    id: 'nova',
    name: 'Captain Nova',
    avatar: '🚀',
    status: 'Somewhere near Jupiter 🪐',
    color: 0xFF3949AB,
    sayings: [
      'Greetings from space! 🌌',
      'Just waved at an alien. It waved back 👽',
      'Houston, we have a snack problem. 🍫',
      'The view of Earth is AMAZING today 🌍',
      'Blasting off in 3... 2... 1... 🚀',
    ],
    emojis: ['🚀', '🪐', '👽', '⭐'],
  ),
  Contact(
    id: 'pepperoni',
    name: 'Chef Pepperoni',
    avatar: '🍕',
    status: 'Cooking up something tasty',
    color: 0xFFC62828,
    sayings: [
      'Mamma mia! 🍕',
      'I put pineapple on a pizza. Was that a mistake? 🍍',
      'Dinner is ready! Come quick!',
      'Extra cheese makes everything better 🧀',
      'Want my secret recipe? It\'s... more cheese.',
    ],
    emojis: ['🍕', '🧀', '👨‍🍳', '😋'],
  ),
  Contact(
    id: 'flo',
    name: 'Flamingo Flo',
    avatar: '🦩',
    status: 'Floating in the pool 🏖️',
    color: 0xFFD81B60,
    sayings: [
      'Standing on one leg again 🦩',
      'Pool party at mine! 🏊',
      'Pink is my favourite colour, obviously 💖',
      'Just got a new floaty! It looks like a cat 🐱',
      'Sun cream on? ☀️',
    ],
    emojis: ['🦩', '💖', '☀️', '🏖️'],
  ),
  Contact(
    id: 'robo',
    name: 'Robo',
    avatar: '🤖',
    status: 'Beep boop. Battery 87%',
    color: 0xFF546E7A,
    sayings: [
      'BEEP BOOP. Message received. 🤖',
      'Calculating... the answer is 42.',
      'I am learning to dance. 🕺 Error: legs too wobbly.',
      'Charging my battery 🔋',
      'Does not compute! 😵',
    ],
    emojis: ['🤖', '🔋', '⚙️', '💡'],
  ),
  Contact(
    id: 'dave',
    name: 'Dino Dave',
    avatar: '🦖',
    status: 'RAWR means hello',
    color: 0xFF2E7D32,
    sayings: [
      'RAWRRR! 🦖',
      'My arms are too short to text properly lol',
      'Just stomped through a volcano 🌋',
      'Do you think I could ride a skateboard? 🛹',
      'Who ate my leaf salad?? 🥗',
    ],
    emojis: ['🦖', '🌋', '🦕', '💚'],
  ),
  Contact(
    id: 'sparkle',
    name: 'Sparkle',
    avatar: '🦄',
    status: 'Magic everywhere ✨',
    color: 0xFF8E24AA,
    sayings: [
      'Sprinkling some magic on your day ✨',
      'Rainbows are my favourite slide 🌈',
      'I made a wish for you! 💫',
      'Glitter is NOT a food group (but it should be)',
      'Yay!! 🎉',
    ],
    emojis: ['🦄', '🌈', '✨', '💜'],
  ),
];

class ChatMessage {
  ChatMessage(
      {required this.from,
      required this.text,
      required this.time,
      this.read = false});

  /// 'me' or a contact's id.
  final String from;
  final String text;
  final DateTime time;

  /// For my messages: has someone replied (blue ticks)?
  bool read;

  Map<String, dynamic> toJson() =>
      {'f': from, 't': text, 'm': time.millisecondsSinceEpoch, 'r': read};
  static ChatMessage fromJson(Map<String, dynamic> j) => ChatMessage(
        from: j['f'] as String,
        text: j['t'] as String,
        time: DateTime.fromMillisecondsSinceEpoch(j['m'] as int),
        read: j['r'] as bool? ?? false,
      );
}

class Chat {
  Chat(
      {required this.id,
      required this.members,
      this.groupName,
      this.groupAvatar = '👥'});

  final String id;
  final List<String> members;
  final String? groupName;
  final String groupAvatar;
  final List<ChatMessage> messages = [];
  int unread = 0;

  bool get isGroup => groupName != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'members': members,
        'group': groupName,
        'ga': groupAvatar,
        'unread': unread,
        'messages': [for (final m in messages) m.toJson()],
      };

  static Chat fromJson(Map<String, dynamic> j) {
    final c = Chat(
      id: j['id'] as String,
      members: [for (final m in j['members'] as List) m as String],
      groupName: j['group'] as String?,
      groupAvatar: j['ga'] as String? ?? '👥',
    )..unread = j['unread'] as int? ?? 0;
    c.messages.addAll([
      for (final m in j['messages'] as List)
        ChatMessage.fromJson(Map<String, dynamic>.from(m as Map))
    ]);
    return c;
  }
}

/// Works out what a pretend friend says back.
String replyFor(Contact who, String message, math.Random rnd,
    {bool group = false}) {
  final m = message.toLowerCase();
  String pick(List<String> options) => options[rnd.nextInt(options.length)];
  final emoji = pick(who.emojis);
  final onlyEmoji =
      message.trim().isNotEmpty && !RegExp(r'[a-zA-Z0-9]').hasMatch(message);

  if (onlyEmoji) {
    return pick(
        ['$emoji$emoji$emoji', message.trim(), '😂😂', '❤️', '$emoji!']);
  }
  if (m.contains('joke')) {
    return pick([
      'Why did the cat sit on the computer? To keep an eye on the mouse! 🐭',
      'What do you call a sleeping dinosaur? A dino-snore! 🦖💤',
      'Why did the cookie go to the doctor? It felt crummy! 🍪',
      "What's orange and sounds like a parrot? A carrot! 🥕",
    ]);
  }
  if (RegExp(r'\b(hi|hello|hey|hiya|yo|sup)\b').hasMatch(m)) {
    return pick([
      'Hi! $emoji',
      'Hello there! 👋',
      'Heyyy $emoji',
      'Oh hi! How are you?'
    ]);
  }
  if (m.contains('how are you') ||
      m.contains('how r u') ||
      m.contains('you ok')) {
    return pick([
      "I'm great thanks! What about you? $emoji",
      'Super good! 😄',
      'A bit sleepy but good!'
    ]);
  }
  if (m.contains('love') || m.contains('❤')) {
    return pick(['Aww ❤️', 'Love you too! 💖', '🥰🥰']);
  }
  if (m.contains('bye') || m.contains('night') || m.contains('see you')) {
    return pick(['Bye! 👋', 'See you later! $emoji', 'Night night 🌙']);
  }
  if (m.contains('lol') || m.contains('haha') || m.contains('😂')) {
    return pick(['😂😂😂', 'LOL', 'Hahaha stop it 🤣']);
  }
  if (m.contains('?')) {
    return pick([
      'Hmm, good question 🤔',
      'Yes! 100%',
      'Nope 😆',
      'Maybe... $emoji',
      'Ask me again tomorrow!'
    ]);
  }
  if (group && rnd.nextDouble() < 0.3) {
    return pick(['Agreed!', 'Same 😂', '👀', 'Wait what?']);
  }
  return pick([...who.sayings, 'Cool! $emoji', 'Haha 😄']);
}
