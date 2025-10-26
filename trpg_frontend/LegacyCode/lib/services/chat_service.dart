import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat.dart';

class ChatService {
  final String baseUrl;

  ChatService({required this.baseUrl});

  Future<List<ChatMessage>> getChatMessages(String roomId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rooms/$roomId/chats/logs'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load chat messages');
    }
  }

  Future<void> sendChatMessage(
    String roomId,
    String sender,
    String message,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rooms/$roomId/chats'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'sender': sender, 'message': message}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to send chat message');
    }
  }
}
