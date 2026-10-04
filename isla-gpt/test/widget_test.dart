import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isla_gpt/main.dart';
import 'package:isla_gpt/screens/chat_screen.dart';
import 'package:isla_gpt/services/isla_client.dart';

class FakeIslaClient implements IslaClient {
  List<ChatMessage>? lastConversation;
  ApproxArea? lastArea;

  @override
  Future<String> ask(List<ChatMessage> conversation, {ApproxArea? area}) async {
    lastConversation = conversation;
    lastArea = area;
    return 'It is sunny in your area today!';
  }
}

void main() {
  test('areas are rounded so the exact spot is never sent', () {
    final area = ApproxArea(51.50735, -0.12776);
    expect(area.latitude, 51.5);
    expect(area.longitude, -0.1);
  });

  testWidgets('asking a question shows Isla GPT\'s answer', (tester) async {
    final fake = FakeIslaClient();
    await tester.pumpWidget(IslaGptApp(
      chatScreen: ChatScreen(
        client: fake,
        findArea: () async => ApproxArea(51.50735, -0.12776),
      ),
    ));
    expect(find.text("Hi, I'm Isla GPT!"), findsOneWidget);

    await tester.tap(find.text('Share my area for the weather'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.location_on), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // let the snackbar go
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), "What's the weather?");
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.text("What's the weather?"), findsOneWidget);
    expect(find.text('It is sunny in your area today!'), findsOneWidget);
    expect(fake.lastConversation!.single.text, "What's the weather?");
    expect(fake.lastArea!.latitude, 51.5);
  });

  testWidgets('suggestions can be tapped to ask', (tester) async {
    final fake = FakeIslaClient();
    await tester.pumpWidget(IslaGptApp(chatScreen: ChatScreen(client: fake)));
    await tester.tap(find.text(suggestions[1]));
    await tester.pumpAndSettle();
    expect(fake.lastConversation!.single.text, suggestions[1]);
    expect(fake.lastArea, isNull);
  });
}
