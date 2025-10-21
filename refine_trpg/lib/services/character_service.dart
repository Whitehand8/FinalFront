import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/character.dart';
import 'auth_service.dart';

class CharacterService {
  static const String _baseUrl = 'http://localhost:11122';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Character>> getCharactersInRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/character-sheets/room/$roomId');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(res.body);
      return data.map((json) => Character.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load characters');
    }
  }

  Future<Character> createCharacter({
    required String roomId,
    required String systemId,
    required Map<String, dynamic> data,
    required Map<String, dynamic> derived,
  }) async {
    final uri = Uri.parse('$_baseUrl/character-sheets');
    final body = jsonEncode({
      'roomId': roomId,
      'systemId': systemId,
      'data': data,
      'derived': derived,
    });

    final res = await http.post(uri, headers: await _headers(), body: body);
    if (res.statusCode == 201) {
      return Character.fromJson(json.decode(res.body));
    } else {
      throw Exception('Failed to create character');
    }
  }

  Future<Character> updateCharacter({
    required String characterId,
    required Map<String, dynamic> data,
    required Map<String, dynamic> derived,
  }) async {
    final uri = Uri.parse('$_baseUrl/character-sheets/$characterId');
    final body = jsonEncode({'data': data, 'derived': derived});
    final res = await http.patch(uri, headers: await _headers(), body: body);
    if (res.statusCode == 200) {
      return Character.fromJson(json.decode(res.body));
    } else {
      throw Exception('Failed to update character');
    }
  }
}
