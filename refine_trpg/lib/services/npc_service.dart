// lib/services/npc_service.dart
import 'dart:convert';
import 'dart:async'; // For TimeoutException
import 'dart:io'; // For SocketException
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:refine_trpg/models/npc.dart'; // Ensure npc.dart uses int? id
import 'auth_service.dart';

// RoomServiceException 과 유사한 에러 클래스 (별도 파일로 분리 가능)
class NpcServiceException implements Exception {
  final String message;
  final int? statusCode;
  NpcServiceException(this.message, {this.statusCode});
  @override
  String toString() => 'NpcService Error [$statusCode]: $message';
}


class NpcService {
  static const String _baseUrl = 'http://localhost:11122'; // Backend HTTP port

  // --- Helper Methods (RoomService와 유사) ---

  static http.Client _client() => http.Client();

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await AuthService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        debugPrint("[NpcService] Warning: Authorization token is missing.");
      }
    }
    return headers;
  }

  static Future<http.Response> _requestWithTimeout(Future<http.Response> request) {
    return request.timeout(const Duration(seconds: 15)); // Timeout 15초
  }

  // UTF-8 디코딩 및 JSON 파싱, 에러 메시지 추출 강화
  static dynamic _handleResponse(http.Response res, String operationName) {
     debugPrint('[NpcService.$operationName] Response Status: ${res.statusCode}');
     // debugPrint('[NpcService.$operationName] Response Body: ${utf8.decode(res.bodyBytes, allowMalformed: true)}');

     if (res.statusCode >= 200 && res.statusCode < 300) {
        if (res.statusCode == 204 || res.bodyBytes.isEmpty) {
           return null; // No content
        }
        try {
           return jsonDecode(utf8.decode(res.bodyBytes));
        } catch (e) {
           debugPrint('[NpcService.$operationName] Error decoding success response: $e');
           throw NpcServiceException('Failed to process server response.', statusCode: res.statusCode);
        }
     } else {
        String errorMessage = 'Unknown error occurred.';
        try {
           final decoded = jsonDecode(utf8.decode(res.bodyBytes));
           if (decoded is Map<String, dynamic>) {
             errorMessage = decoded['message']?.toString() ??
                            decoded['error']?.toString() ??
                            errorMessage;
           } else if (decoded is String && decoded.isNotEmpty) {
             errorMessage = decoded;
           }
        } catch (e) {
           debugPrint("[NpcService.$operationName] Error decoding error response: $e");
           final bodyString = utf8.decode(res.bodyBytes, allowMalformed: true);
           errorMessage = bodyString.isNotEmpty ? bodyString : (res.reasonPhrase ?? 'Request failed.');
        }
        debugPrint('[NpcService.$operationName] Error: $errorMessage');
        throw NpcServiceException(errorMessage, statusCode: res.statusCode);
     }
  }

  // --- NPC API Methods ---

  /// 방 안의 모든 NPC 가져오기 (GET /npcs?roomId=...)
  Future<List<Npc>> getNpcsInRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/npcs').replace(queryParameters: {'roomId': roomId});
    final client = _client();
    const operation = 'getNpcsInRoom';
    debugPrint('[$operation] Request URL: $uri');

    try {
      final res = await _requestWithTimeout(client.get(uri, headers: await _headers()));
      final List<dynamic> body = _handleResponse(res, operation);
      // Npc.fromJson이 int? id를 처리하도록 수정되었는지 확인
      return body.map((json) => Npc.fromJson(json as Map<String, dynamic>)).toList();
    } on SocketException {
      throw NpcServiceException('Network connection failed.');
    } on TimeoutException {
      throw NpcServiceException('Request timed out.');
    } on NpcServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw NpcServiceException('An unexpected error occurred while fetching NPCs.');
    } finally {
      client.close();
    }
  }

  /// NPC 생성하기 (POST /npcs/room/:roomId)
  Future<Npc> createNpc(Npc npcToCreate) async {
    // roomId는 npcToCreate 객체 안에 포함되어 있어야 함 (String UUID)
    final uri = Uri.parse('$_baseUrl/npcs/room/${Uri.encodeComponent(npcToCreate.roomId)}');
    final client = _client();
    // Npc 모델의 toCreateJson() 사용
    final body = jsonEncode(npcToCreate.toCreateJson());
    const operation = 'createNpc';
    debugPrint('[$operation] Request URL: $uri');
    debugPrint('[$operation] Request Body: $body');

    try {
      final res = await _requestWithTimeout(client.post(uri, headers: await _headers(), body: body));
      // Backend returns NpcResponseDto
      final responseBody = _handleResponse(res, operation);
      return Npc.fromJson(responseBody);
    } on SocketException {
      throw NpcServiceException('Network connection failed.');
    } on TimeoutException {
      throw NpcServiceException('Request timed out.');
    } on NpcServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw NpcServiceException('An unexpected error occurred while creating the NPC.');
    } finally {
      client.close();
    }
  }

  /// NPC 수정하기 (PATCH /npcs/:npcId)
  /// [수정됨] npcId 타입을 int로 변경
  Future<Npc> updateNpc(int npcId, Map<String, dynamic> updateData) async {
    // URL 경로에는 npcId를 문자열로 변환하여 사용
    final uri = Uri.parse('$_baseUrl/npcs/${npcId.toString()}');
    final client = _client();
    // updateData는 UpdateNpcDto 구조와 일치해야 함 (부분 업데이트 가능)
    final body = jsonEncode(updateData);
    const operation = 'updateNpc';
    debugPrint('[$operation] Request URL: $uri');
    debugPrint('[$operation] Request Body: $body');

    try {
      final res = await _requestWithTimeout(client.patch(uri, headers: await _headers(), body: body));
      // Backend returns NpcResponseDto
      final responseBody = _handleResponse(res, operation);
      return Npc.fromJson(responseBody);
    } on SocketException {
      throw NpcServiceException('Network connection failed.');
    } on TimeoutException {
      throw NpcServiceException('Request timed out.');
    } on NpcServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw NpcServiceException('An unexpected error occurred while updating the NPC.');
    } finally {
      client.close();
    }
  }

  /// NPC 삭제하기 (DELETE /npcs/:npcId)
  /// [수정됨] npcId 타입을 int로 변경
  Future<void> deleteNpc(int npcId) async {
    // URL 경로에는 npcId를 문자열로 변환하여 사용
    final uri = Uri.parse('$_baseUrl/npcs/${npcId.toString()}');
    final client = _client();
    const operation = 'deleteNpc';
    debugPrint('[$operation] Request URL: $uri');

    try {
      final res = await _requestWithTimeout(client.delete(uri, headers: await _headers()));
      // Backend returns 200 OK with DeleteNpcResponseDto
      _handleResponse(res, operation); // Check for success status
      return; // Return void on success
    } on SocketException {
      throw NpcServiceException('Network connection failed.');
    } on TimeoutException {
      throw NpcServiceException('Request timed out.');
    } on NpcServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw NpcServiceException('An unexpected error occurred while deleting the NPC.');
    } finally {
      client.close();
    }
  }
}