import 'package:flutter/material.dart';

import '../services/isla_client.dart';
import '../services/location_service.dart';

typedef AreaFinder = Future<ApproxArea?> Function();

const suggestions = [
  "What's the weather today?",
  'Tell me a fun fact about space',
  'Help me write a poem about cats',
  'How do volcanoes work?',
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.client, this.findArea});

  final IslaClient? client;
  final AreaFinder? findArea;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final IslaClient _client = widget.client ?? HttpIslaClient();
  late final AreaFinder _findArea = widget.findArea ?? askForApproxArea;

  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  ApproxArea? _area;
  bool _thinking = false;
  bool _findingArea = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _shareArea() async {
    setState(() => _findingArea = true);
    ApproxArea? area;
    try {
      area = await _findArea();
    } catch (_) {
      area = null;
    }
    if (!mounted) return;
    setState(() {
      _area = area;
      _findingArea = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(area == null
          ? "I couldn't find your area. Check location is allowed in your browser."
          : 'Thanks! I know your area now (not your exact spot).'),
    ));
  }

  void _stopSharing() {
    setState(() => _area = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("OK, I've forgotten your area."),
    ));
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _thinking) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: text));
      _thinking = true;
    });
    _scrollToEnd();

    String reply;
    try {
      reply = await _client.ask(List.of(_messages), area: _area);
    } catch (e) {
      reply = e is IslaException
          ? e.message
          : "Oops, I couldn't reach Isla GPT. Check your internet and try again.";
    }
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(fromUser: false, text: reply));
      _thinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Isla GPT ✨'),
        actions: [
          if (_findingArea)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              tooltip: _area == null ? 'Share my area' : 'Stop sharing my area',
              icon: Icon(
                  _area == null ? Icons.location_off : Icons.location_on),
              onPressed: _area == null ? _shareArea : _stopSharing,
            ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.refresh),
            onPressed: _thinking ? null : () => setState(_messages.clear),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _Welcome(onPick: _send, onShareArea: _area == null ? _shareArea : null)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_thinking ? 1 : 0),
                      itemBuilder: (context, i) => i == _messages.length
                          ? const _Bubble(fromUser: false, text: 'Thinking…')
                          : _Bubble(
                              fromUser: _messages[i].fromUser,
                              text: _messages[i].text),
                    ),
            ),
            Container(
              color: scheme.surfaceContainer,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask Isla GPT anything…',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send),
                    onPressed: _thinking ? null : () => _send(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onPick, required this.onShareArea});

  final ValueChanged<String> onPick;
  final VoidCallback? onShareArea;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 56)),
            Text('Hi, I\'m Isla GPT!', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text('Ask me anything.',
                style: text.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in suggestions)
                  ActionChip(label: Text(s), onPressed: () => onPick(s)),
              ],
            ),
            if (onShareArea != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onShareArea,
                icon: const Icon(Icons.location_on),
                label: const Text('Share my area for the weather'),
              ),
              const SizedBox(height: 4),
              Text('Only your rough area, never your exact spot.',
                  style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primary : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          text,
          style: TextStyle(
              color: fromUser
                  ? scheme.onPrimary
                  : scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
