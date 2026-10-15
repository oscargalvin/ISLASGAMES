import 'package:flutter/material.dart';

/// Isla GPT is for ages 11 and up, so it checks before showing the chat.
class AgeGate extends StatefulWidget {
  const AgeGate({super.key, required this.child});

  final Widget child;

  @override
  State<AgeGate> createState() => _AgeGateState();
}

enum _Answer { notYet, oldEnough, tooYoung }

class _AgeGateState extends State<AgeGate> {
  var _answer = _Answer.notYet;

  @override
  Widget build(BuildContext context) {
    if (_answer == _Answer.oldEnough) return widget.child;

    final text = Theme.of(context).textTheme;
    final tooYoung = _answer == _Answer.tooYoung;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tooYoung ? '🌱' : '✨',
                    style: const TextStyle(fontSize: 56)),
                Text('Isla GPT', style: text.headlineMedium),
                const SizedBox(height: 4),
                Text('For ages 11+', style: text.titleMedium),
                const SizedBox(height: 24),
                if (tooYoung)
                  Text(
                    "Sorry, Isla GPT is for ages 11 and up. "
                    'Come back when you\'re older, or ask a grown-up to help you.',
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  )
                else ...[
                  Text('Are you 11 or older?',
                      style: text.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () =>
                            setState(() => _answer = _Answer.oldEnough),
                        child: const Text("Yes, I'm 11+"),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _answer = _Answer.tooYoung),
                        child: const Text("No, I'm younger"),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
