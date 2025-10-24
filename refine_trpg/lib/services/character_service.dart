import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:refine_trpg/models/character.dart'; // 수정된 character.dart
import 'auth_service.dart';

// --- DTO 클래스 정의 ---
// DTO를 사용하면 타입 안정성이 높아집니다.

/// 백엔드의 CreateCharacterSheetDto (create-character-sheet.dto.ts)
class CreateCharacterSheetDto {
  final Map<String, dynamic> data;
  final String trpgType; // "dnd5e", "coc7e" 등

  CreateCharacterSheetDto({required this.data, required this.trpgType});

  Map<String, dynamic> toJson() => {
        'data': data,
        'trpgType': trpgType,
      };
}

/// 백엔드의 UpdateCharacterSheetDto (update-character-sheet.dto.ts)
class UpdateCharacterSheetDto {
  final Map<String, dynamic>? data;
  final bool? isPublic;

  UpdateCharacterSheetDto({this.data, this.isPublic});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (data != null) json['data'] = data;
    if (isPublic != null) json['isPublic'] = isPublic;
    return json;
  }
}

/// 백엔드의 PresignedUrlResponseDto (common/dto/presigned-url-response.dto.ts)
class PresignedUrlResponse {
  final String presignedUrl;
  final String publicUrl;

  PresignedUrlResponse({required this.presignedUrl, required this.publicUrl});

  factory PresignedUrlResponse.fromJson(Map<String, dynamic> json) {
    return PresignedUrlResponse(
      presignedUrl: json['presignedUrl'],
      publicUrl: json['publicUrl'],
    );
  }
}

// --- 서비스 클래스 ---

class CharacterService {
  static const String _baseUrl = 'http://localhost:11122';

  /// 인증 토큰을 포함한 공통 헤더
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// 공통 에러 핸들러
  static Exception _handleError(http.Response response, String operation) {
    try {
      final body = json.decode(utf8.decode(response.bodyBytes));
      final message = body['message'] ?? 'Unknown error';
      return Exception('$operation failed: $message (Status ${response.statusCode})');
    } catch (e) {
      return Exception(
          '$operation failed: ${response.reasonPhrase} (Status ${response.statusCode})');
    }
  }

  /// 캐릭터 시트 조회 (GET /character-sheets/:participantId)
  Future<Character> getCharacterSheet(int participantId) async {
    final uri = Uri.parse('$_baseUrl/character-sheets/$participantId');
    debugPrint('[CharacterService] GET $uri');

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 200) {
      final data = json.decode(utf8.decode(res.bodyBytes));
      // 백엔드는 CharacterSheetResponseDto를 반환합니다 (이미 Character 모델과 일치)
      return Character.fromJson(data);
    } else {
      throw _handleError(res, 'Failed to load character sheet');
    }
  }

  /// 캐릭터 시트 생성 (POST /character-sheets/:participantId)
  Future<Character> createCharacterSheet(
      int participantId, CreateCharacterSheetDto createDto) async {
    final uri = Uri.parse('$_baseUrl/character-sheets/$participantId');
    final body = jsonEncode(createDto.toJson());
    debugPrint('[CharacterService] POST $uri\nBody: $body');

    final res = await http.post(uri, headers: await _headers(), body: body);

    if (res.statusCode == 201) {
      final data = json.decode(utf8.decode(res.bodyBytes));
      return Character.fromJson(data);
    } else {
      // 409 (Conflict) 등
      throw _handleError(res, 'Failed to create character sheet');
    }
  }

  /// 캐릭터 시트 수정 (PATCH /character-sheets/:participantId)
  Future<Character> updateCharacterSheet(
      int participantId, UpdateCharacterSheetDto updateDto) async {
    final uri = Uri.parse('$_baseUrl/character-sheets/$participantId');
    final body = jsonEncode(updateDto.toJson());
    debugPrint('[CharacterService] PATCH $uri\nBody: $body');

    final res = await http.patch(uri, headers: await _headers(), body: body);

    if (res.statusCode == 200) {
      final data = json.decode(utf8.decode(res.bodyBytes));
      return Character.fromJson(data);
    } else {
      // 403 (Forbidden), 404 (Not Found) 등
      throw _handleError(res, 'Failed to update character sheet');
    }
  }

  /// 캐릭터 시트 이미지 업로드용 Presigned URL 발급
  /// (POST /character-sheets/:participantId/presigned-url)
  Future<PresignedUrlResponse> getPresignedUrlForCharacterSheet({
    required int participantId,
    required String fileName,
    required String contentType, // 예: "image/png", "image/jpeg"
  }) async {
    final uri =
        Uri.parse('$_baseUrl/character-sheets/$participantId/presigned-url');
    final body = jsonEncode({
      'fileName': fileName,
      'contentType': contentType,
    });
    debugPrint('[CharacterService] POST $uri\nBody: $body');

    final res = await http.post(uri, headers: await _headers(), body: body);

    if (res.statusCode == 201) {
      final data = json.decode(utf8.decode(res.bodyBytes));
      return PresignedUrlResponse.fromJson(data);
    } else {
      // 400 (Bad Request - MIME/확장자 오류), 403 (Forbidden) 등
      throw _handleError(res, 'Failed to get presigned URL');
    }
  }

  /*
  // 참고: "방의 모든 캐릭터 시트 조회" 기능은 백엔드에 현재 없습니다.
  // 만약 이 기능이 필요하다면, 백엔드 character-sheet.controller.ts에
  // @Get() @Query('roomId') ... 와 같은 API를 새로 추가해야 합니다.
  
  Future<List<Character>> getCharactersInRoom(String roomId) async {
    // 예시: 백엔드에 /character-sheets?roomId=:roomId 가 구현되었다고 가정
    final uri = Uri.parse('$_baseUrl/character-sheets').replace(
      queryParameters: {'roomId': roomId},
    );
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
      return data.map((json) => Character.fromJson(json)).toList();
    } else {
      throw _handleError(res, 'Failed to load characters for room');
    }
  }
  */
}