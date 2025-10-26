// services/character_service.dart
import 'package:dio/dio.dart';
import 'package:refine_trpg/models/character.dart';
import 'ApiClient.dart';
import 'room_service.dart';

class CharacterServiceException implements Exception {
  final String message;
  final int? statusCode;
  CharacterServiceException(this.message, {this.statusCode});
  @override
  String toString() => 'CharacterServiceException($statusCode): $message';
}

class CharacterService {
  final Dio _dio = ApiClient.instance.dio;

  Future<Character> createCharacter({
    required int participantId,
    required Map<String, dynamic> data,
    bool isPublic = false,
  }) async {
    try {
      final res = await _dio.post(
        '/character-sheets/$participantId',
        data: {
          'data': data,
          'isPublic': isPublic,
        },
      );
      return Character.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Character> updateCharacter({
    required int participantId,
    required Map<String, dynamic> data,
    bool? isPublic,
  }) async {
    final body = <String, dynamic>{'data': data};
    if (isPublic != null) body['isPublic'] = isPublic;

    try {
      final res =
          await _dio.patch('/character-sheets/$participantId', data: body);
      return Character.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Character> getCharacter(int participantId) async {
    try {
      final res = await _dio.get('/character-sheets/$participantId');
      return Character.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// ⚠️ 비효율적: 참여자 수만큼 API 호출 (N+1)
  /// 추후 백엔드에 `/rooms/:roomId/characters` 엔드포인트 추가 시 개선 예정
  Future<List<Character>> getCharactersInRoom(String roomId) async {
    try {
      final participants = await RoomService.getParticipants(roomId);
      final futures = participants.map((p) async {
        try {
          return await getCharacter(p.id);
        } catch (e) {
          // 캐릭터가 없는 참여자는 무시
          return null;
        }
      });
      final results = await Future.wait(futures);
      return results.whereType<Character>().toList();
    } on RoomServiceException catch (e) {
      throw CharacterServiceException('참여자 목록 조회 실패: ${e.message}',
          statusCode: e.statusCode);
    } catch (e) {
      throw CharacterServiceException('캐릭터 목록 조회 중 오류 발생: $e');
    }
  }

  /// 캐릭터 시트 이미지 업로드용 Presigned URL 발급
  Future<Map<String, String>> getPresignedUrlForCharacterSheet({
    required int participantId,
    required String fileName,
    required String contentType,
  }) async {
    try {
      final res = await _dio.post(
        '/character-sheets/$participantId/presigned-url',
        data: {
          'fileName': fileName,
          'contentType': contentType,
        },
      );
      // { "presignedUrl": "...", "publicUrl": "...", "key": "..." }
      return Map<String, String>.from(res.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  CharacterServiceException _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      return CharacterServiceException('인증이 필요합니다.');
    } else if (e.response?.statusCode == 403) {
      return CharacterServiceException('권한이 없습니다.');
    } else if (e.response?.statusCode == 404) {
      return CharacterServiceException('캐릭터 시트를 찾을 수 없습니다.');
    } else if (e.response?.statusCode == 409) {
      return CharacterServiceException('이미 캐릭터 시트가 존재합니다.');
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return CharacterServiceException('서버 응답 시간이 초과되었습니다.');
    } else if (e.type == DioExceptionType.connectionError) {
      return CharacterServiceException('네트워크 연결을 확인해주세요.');
    } else {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['message'] ?? '오류 발생')
          : '서버 오류';
      return CharacterServiceException(msg, statusCode: e.response?.statusCode);
    }
  }
}
