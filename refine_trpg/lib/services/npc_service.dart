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
      'Accept': 'application/json', // Accept 헤더 추가
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 방 안의 모든 NPC 가져오기 (✅ MODIFIED: 엔드포인트 수정)
  Future<List<Npc>> getNpcsInRoom(String roomId) async {
    // [BEFORE] final uri = Uri.parse('$_baseUrl/npc/room/$roomId');
    // [AFTER]  Backend: GET /npcs?roomId=...
    final uri =
        Uri.parse('$_baseUrl/npcs').replace(queryParameters: {'roomId': roomId});

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
      // Backend: NpcResponseDto[]
      return data.map((json) => Npc.fromJson(json)).toList();
    } else {
      final body = json.decode(utf8.decode(res.bodyBytes));
      throw Exception(
          'Failed to load NPCs: ${body['message'] ?? 'Unknown error'}. Status: ${res.statusCode}');
    }
  }

  /// NPC 생성하기 (✅ MODIFIED: 엔드포인트 수정)
  /// npcToCreate 객체에 roomId가 포함되어 있어야 함
  Future<Npc> createNpc(Npc npcToCreate) async {
    // [BEFORE] final uri = Uri.parse('$_baseUrl/npc');
    // [AFTER]  Backend: POST /npcs/room/:roomId
    final uri = Uri.parse('$_baseUrl/npcs/room/${npcToCreate.roomId}');

    // 모델의 toCreateJson() 메서드 사용 (이 메서드가 Backend의 CreateNpcDto와 일치해야 함)
    final body = jsonEncode(npcToCreate.toCreateJson());

    final res = await http.post(uri, headers: await _headers(), body: body);

    if (res.statusCode == 201) {
      // Backend: NpcResponseDto
      return Npc.fromJson(json.decode(utf8.decode(res.bodyBytes)));
    } else {
      final body = json.decode(utf8.decode(res.bodyBytes));
      throw Exception(
          'Failed to create NPC: ${body['message'] ?? 'Unknown error'}. Status: ${res.statusCode}');
    }
  }

  /// NPC 수정하기 (✅ MODIFIED: 엔드포인트 수정)
  /// npcId는 String이 아닌 number(int)일 수 있으나, http 경로는 string으로 처리됨.
  /// 백엔드 npc.controller.ts는 @Param('npcId', ParseIntPipe)를 사용하므로
  /// npcId는 숫자형 문자열이어야 합니다.
  Future<Npc> updateNpc(String npcId, Map<String, dynamic> updateData) async {
    // [BEFORE] final uri = Uri.parse('$_baseUrl/npc/$npcId');
    // [AFTER]  Backend: PATCH /npcs/:npcId
    final uri = Uri.parse('$_baseUrl/npcs/$npcId');
    final body = jsonEncode(updateData);

    final res = await http.patch(uri, headers: await _headers(), body: body);

    if (res.statusCode == 200) {
      // Backend: NpcResponseDto
      return Npc.fromJson(json.decode(utf8.decode(res.bodyBytes)));
    } else {
      final body = json.decode(utf8.decode(res.bodyBytes));
      throw Exception(
          'Failed to update NPC: ${body['message'] ?? 'Unknown error'}. Status: ${res.statusCode}');
    }
  }

  /// NPC 삭제하기 (✅ MODIFIED: 엔드포인트 수정)
  Future<void> deleteNpc(String npcId) async {
    // [BEFORE] final uri = Uri.parse('$_baseUrl/npc/$npcId');
    // [AFTER]  Backend: DELETE /npcs/:npcId
    final uri = Uri.parse('$_baseUrl/npcs/$npcId');

    final res = await http.delete(uri, headers: await _headers());

    // Backend: 200 OK (DeleteNpcResponseDto) 또는 204 No Content (일반적)
    // npc.controller.ts는 200 OK와 DTO를 반환함.
    if (res.statusCode == 200) {
      return; // 성공
    } else if (res.statusCode != 204) { // 204도 성공으로 간주
      final body = json.decode(utf8.decode(res.bodyBytes));
      throw Exception(
          'Failed to delete NPC: ${body['message'] ?? 'Unknown error'}. Status: ${res.statusCode}');
    }
  }
}