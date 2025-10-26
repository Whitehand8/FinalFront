// lib/services/npc_service.dart
import 'package:dio/dio.dart'; // Dio import
import 'package:flutter/foundation.dart';
import 'package:refine_trpg/models/npc.dart';
import 'ApiClient.dart'; // ApiClient import

// NpcServiceException 정의 (기존과 동일하거나 ApiClient의 에러 처리 활용)
class NpcServiceException implements Exception {
  final String message;
  final int? statusCode;
  NpcServiceException(this.message, {this.statusCode});

  factory NpcServiceException.fromDioException(DioException e) {
    // ApiClient의 에러 파싱 로직을 활용하거나 유사하게 구현
    String message = '알 수 없는 오류가 발생했습니다.';
    if (e.response?.data is Map<String, dynamic>) {
       message = (e.response!.data as Map<String, dynamic>)['message'] ?? message;
    } else if (e.response?.data is String && (e.response!.data as String).isNotEmpty) {
       message = e.response!.data;
    } else if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.sendTimeout || e.type == DioExceptionType.receiveTimeout) {
       message = '네트워크 연결을 확인해주세요.';
    } else if (e.type == DioExceptionType.cancel) {
        message = '요청이 취소되었습니다.';
    }
    return NpcServiceException(message, statusCode: e.response?.statusCode);
  }

  @override
  String toString() => 'NpcService Error [$statusCode]: $message';
}


/// NPC 관련 REST API 서비스 (싱글톤)
class NpcService {
  // --- ✨ 싱글톤 패턴 구현 ---
  static NpcService? _instance;
  static NpcService get instance => _instance ??= NpcService._();
  NpcService._(); // Private constructor
  // --- ✨ ---

  /// 방 안의 모든 NPC 가져오기
  /// [API] GET /npcs?roomId=:roomId
  Future<List<Npc>> getNpcsInRoom(String roomId) async {
    const operation = 'getNpcsInRoom';
    try {
      final res = await ApiClient.instance.dio.get(
        '/npcs',
        queryParameters: {'roomId': roomId},
      );
      final List<dynamic> data = res.data as List<dynamic>;
      return data.map((item) => Npc.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('[NpcService.$operation] Error: ${e.message}');
      throw NpcServiceException.fromDioException(e);
    } catch (e) {
       debugPrint('[NpcService.$operation] Unexpected Error: $e');
       throw NpcServiceException('NPC 목록 로딩 중 예상치 못한 오류 발생.');
    }
  }

  /// NPC 단건 조회
  /// [API] GET /npcs/:npcId
  Future<Npc> getNpc(int npcId) async {
     const operation = 'getNpc';
     try {
       final res = await ApiClient.instance.dio.get('/npcs/${npcId.toString()}');
       return Npc.fromJson(res.data as Map<String, dynamic>);
     } on DioException catch (e) {
       debugPrint('[NpcService.$operation] Error: ${e.message}');
       throw NpcServiceException.fromDioException(e);
     } catch (e) {
       debugPrint('[NpcService.$operation] Unexpected Error: $e');
       throw NpcServiceException('NPC 정보 로딩 중 예상치 못한 오류 발생.');
     }
  }


  /// NPC 생성하기
  /// [API] POST /npcs/room/:roomId
  Future<Npc> createNpc(Npc npcToCreate) async {
    const operation = 'createNpc';
    try {
      // npcToCreate.toCreateJson()이 백엔드 CreateNpcDto와 맞는지 확인 필요
      final res = await ApiClient.instance.dio.post(
        '/npcs/room/${npcToCreate.roomId}', // roomId는 URL 파라미터로
        data: npcToCreate.toCreateJson(), // 나머지 데이터는 body로
      );
      return Npc.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[NpcService.$operation] Error: ${e.message}');
      throw NpcServiceException.fromDioException(e);
    } catch (e) {
       debugPrint('[NpcService.$operation] Unexpected Error: $e');
       throw NpcServiceException('NPC 생성 중 예상치 못한 오류 발생.');
    }
  }

  /// NPC 수정하기
  /// [API] PATCH /npcs/:npcId
  Future<Npc> updateNpc(int npcId, Map<String, dynamic> updateData) async {
     const operation = 'updateNpc';
    try {
      // updateData는 백엔드 UpdateNpcDto와 일치해야 함
      final res = await ApiClient.instance.dio.patch(
        '/npcs/${npcId.toString()}',
        data: updateData,
      );
      return Npc.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[NpcService.$operation] Error: ${e.message}');
      throw NpcServiceException.fromDioException(e);
    } catch (e) {
       debugPrint('[NpcService.$operation] Unexpected Error: $e');
       throw NpcServiceException('NPC 수정 중 예상치 못한 오류 발생.');
    }
  }

  /// NPC 삭제하기
  /// [API] DELETE /npcs/:npcId
  Future<void> deleteNpc(int npcId) async {
     const operation = 'deleteNpc';
    try {
      // 백엔드는 성공 시 200 OK와 메시지를 반환함 (ApiClient는 2xx 응답을 성공으로 처리)
      await ApiClient.instance.dio.delete('/npcs/${npcId.toString()}');
      return;
    } on DioException catch (e) {
      debugPrint('[NpcService.$operation] Error: ${e.message}');
      throw NpcServiceException.fromDioException(e);
    } catch (e) {
       debugPrint('[NpcService.$operation] Unexpected Error: $e');
       throw NpcServiceException('NPC 삭제 중 예상치 못한 오류 발생.');
    }
  }

  /// NPC 이미지 업로드용 Presigned URL 받기
  /// [API] POST /npcs/room/:roomId/presigned-url
  Future<Map<String, dynamic>> getPresignedUrlForNpcImage({
    required String roomId,
    required String fileName,
    required String contentType,
  }) async {
     const operation = 'getPresignedUrlForNpcImage';
    try {
      final res = await ApiClient.instance.dio.post(
        '/npcs/room/$roomId/presigned-url',
        data: {
          'fileName': fileName,
          'contentType': contentType,
        },
      );
      // 백엔드 PresignedUrlResponseDto 반환 ( { presignedUrl, publicUrl, key } )
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('[NpcService.$operation] Error: ${e.message}');
      throw NpcServiceException.fromDioException(e);
    } catch (e) {
       debugPrint('[NpcService.$operation] Unexpected Error: $e');
       throw NpcServiceException('Presigned URL 요청 중 예상치 못한 오류 발생.');
    }
  }
}