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

  test('spots weather questions about where you are', () {
    expect(isLocalWeatherQuestion("What's the weather today?"), isTrue);
    expect(isLocalWeatherQuestion('Is it going to rain?'), isTrue);
    expect(isLocalWeatherQuestion("What's the weather in Paris?"), isFalse);
    expect(isLocalWeatherQuestion('How do volcanoes work?'), isFalse);
  });

  testWidgets('a weather question asks for the area first', (tester) async {
    final fake = FakeIslaClient();
    var asked = 0;
    await tester.pumpWidget(IslaGptApp(
      chatScreen: ChatScreen(
        client: fake,
        findArea: () async {
          asked++;
          return ApproxArea(40.71, -74.01);
        },
      ),
    ));
    await tester.tap(find.text(suggestions[0])); // "What's the weather today?"
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(fake.lastArea!.latitude, 40.7);

    // Already shared, so the next weather question doesn't ask again.
    await tester.enterText(find.byType(TextField), 'Will it rain?');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(asked, 1);
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
