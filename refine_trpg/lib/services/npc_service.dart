// lib/services/npc_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/npc.dart';
// DTO 임포트가 필요 없어짐
import 'auth_service.dart';

class NpcService {
  static const String _baseUrl = 'http://localhost:11122';

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 방 안의 모든 NPC 가져오기
  Future<List<Npc>> getNpcsInRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/npc/room/$roomId');
    final res = await http.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
      return data.map((json) => Npc.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load NPCs. Status: ${res.statusCode}');
    }
  }

  /// NPC 생성하기 (DTO 대신 Npc 객체를 받도록 수정)
  Future<Npc> createNpc(Npc npcToCreate) async {
    final uri = Uri.parse('$_baseUrl/npc');
    // 모델의 toCreateJson() 메서드 사용
    final body = jsonEncode(npcToCreate.toCreateJson());

    final res = await http.post(uri, headers: await _headers(), body: body);
    if (res.statusCode == 201) {
      return Npc.fromJson(json.decode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception('Failed to create NPC. Status: ${res.statusCode}');
    }
  }

  /// NPC 수정하기
  Future<Npc> updateNpc(String npcId, Map<String, dynamic> updateData) async {
    final uri = Uri.parse('$_baseUrl/npc/$npcId');
    final body = jsonEncode(updateData);
    final res = await http.patch(uri, headers: await _headers(), body: body);
    if (res.statusCode == 200) {
      return Npc.fromJson(json.decode(utf8.decode(res.bodyBytes)));
    } else {
      throw Exception('Failed to update NPC. Status: ${res.statusCode}');
    }
  }

  /// NPC 삭제하기
  Future<void> deleteNpc(String npcId) async {
    final uri = Uri.parse('$_baseUrl/npc/$npcId');
    final res = await http.delete(uri, headers: await _headers());
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to delete NPC. Status: ${res.statusCode}');
    }
  }
}