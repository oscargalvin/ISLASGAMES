import 'dart:convert';

import 'package:http/http.dart' as http;

/// One message in the chat.
class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;

  Map<String, String> toJson() =>
      {'role': fromUser ? 'user' : 'assistant', 'text': text};
}

/// Roughly where someone is: rounded to about 10 km, never their exact spot.
class ApproxArea {
  ApproxArea(double latitude, double longitude)
      : latitude = roundToArea(latitude),
        longitude = roundToArea(longitude);

  final double latitude;
  final double longitude;

  /// One decimal place is about 11 km, enough for a town but not a street.
  static double roundToArea(double value) => (value * 10).round() / 10;

  Map<String, double> toJson() => {'lat': latitude, 'lon': longitude};
}

/// Talks to Isla GPT's brain.
abstract class IslaClient {
  Future<String> ask(List<ChatMessage> conversation, {ApproxArea? area});
}

/// Calls the `/api/chat` function that Vercel hosts next to the app.
class HttpIslaClient implements IslaClient {
  HttpIslaClient({http.Client? httpClient, String? endpoint})
      : _http = httpClient ?? http.Client(),
        _endpoint = endpoint ?? _defaultEndpoint;

  /// Override with `--dart-define=ISLA_GPT_API=https://your-site/api/chat`
  /// when running the app somewhere other than Vercel.
  static const _defaultEndpoint =
      String.fromEnvironment('ISLA_GPT_API', defaultValue: '/api/chat');

  final http.Client _http;
  final String _endpoint;

  @override
  Future<String> ask(List<ChatMessage> conversation, {ApproxArea? area}) async {
    final response = await _http.post(
      Uri.base.resolve(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': [for (final m in conversation) m.toJson()],
        if (area != null) 'area': area.toJson(),
      }),
    );
    final body = _decode(response.body);
    if (response.statusCode != 200) {
      throw IslaException(body['error'] as String? ??
          'Isla GPT is having a little rest. Please try again soon.');
    }
    return body['reply'] as String;
  }

  Map<String, dynamic> _decode(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }
}

class IslaException implements Exception {
  IslaException(this.message);
  final String message;

  @override
  String toString() => message;
}
