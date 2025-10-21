import 'dart:convert';
import 'package:http/http.dart' as http;

class CharacterService {
  CharacterService({required this.baseUrl, this.authToken});

  final String baseUrl;
  final String? authToken;

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    if (authToken != null && authToken!.isNotEmpty)
      'Authorization': 'Bearer $authToken',
  };

  /// 신규 캐릭터 생성
  /// payload 예: { systemId, data, derived, name?, hp?, mp? }
  Future<Map<String, dynamic>> createCharacter({
    required String roomId,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$baseUrl/character-sheets');
    final body = jsonEncode({'roomId': roomId, ...payload});

    final res = await http.post(uri, headers: _headers(), body: body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Create failed (${res.statusCode}): ${res.body}');
  }

  /// 기존 캐릭터 수정
  Future<Map<String, dynamic>> updateCharacter({
    required String characterId,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$baseUrl/character-sheets/$characterId');
    final res = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Update failed (${res.statusCode}): ${res.body}');
  }

  /// 방의 모든 캐릭터 조회
  Future<List<Map<String, dynamic>>> getCharactersByRoom(String roomId) async {
    final uri = Uri.parse('$baseUrl/character-sheets/room/$roomId');
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final raw = jsonDecode(res.body);
      if (raw is List) return raw.cast<Map<String, dynamic>>();
      if (raw is Map && raw['items'] is List) {
        return (raw['items'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    }
    throw Exception('Fetch by room failed (${res.statusCode}): ${res.body}');
  }
}
