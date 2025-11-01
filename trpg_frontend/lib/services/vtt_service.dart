// lib/services/vtt_service.dart
import 'package:dio/dio.dart';
import 'package:trpg_frontend/models/token.dart'; // VTT 토큰 모델
import 'package:trpg_frontend/models/vtt_scene.dart'; // VTT 맵(씬) 모델
import 'ApiClient.dart'; // Dio 클라이언트

/// VTT (맵, 토큰) 관련 REST API 서비스
class VttService {
  static VttService? _instance;
  static VttService get instance => _instance ??= VttService._();
  VttService._();

  // =======================================================================
  // ✨ VTT 맵 (Scene) API Methods (vttmap.controller.ts 기반)
  // =======================================================================

  /// 방(Room) ID로 모든 맵(씬) 목록 가져오기
  /// [API] GET /vttmaps?roomId=:roomId
  Future<List<VttScene>> getVttMapsByRoom(String roomId) async {
    try {
      final res = await ApiClient.instance.dio.get(
        '/vttmaps',
        queryParameters: {'roomId': roomId},
      );
      
      final List<dynamic> data = res.data as List<dynamic>;
      // [중요] VttScene.fromJson이 백엔드 VttMapDto와 일치해야 함
      return data
          .map((item) => VttScene.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to get VTT maps: ${e.message}');
    }
  }

  /// 특정 맵(씬) ID로 상세 정보 가져오기
  /// [API] GET /vttmaps/:mapId
  Future<VttScene> getVttMap(String mapId) async {
    try {
      final res = await ApiClient.instance.dio.get('/vttmaps/$mapId');
      // [중요] VttScene.fromJson이 백엔드 VttMapResponseDto와 일치해야 함
      return VttScene.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to get VTT map: ${e.message}');
    }
  }

  /// 새로운 맵(씬) 생성하기
  /// [API] POST /rooms/:roomId/vttmaps
  Future<VttScene> createVttMap(String roomId, Map<String, dynamic> createData) async {
    // createData 예시: { 'name': '새 맵', 'gridType': 'SQUARE', ... }
    // 백엔드의 CreateVttMapDto와 일치해야 함
    try {
      final res = await ApiClient.instance.dio.post(
        '/rooms/$roomId/vttmaps',
        data: createData,
      );
      return VttScene.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to create VTT map: ${e.message}');
    }
  }

  /// 맵(씬) 정보 업데이트
  /// [API] PATCH /vttmaps/:mapId
  Future<VttScene> updateVttMap(String mapId, Map<String, dynamic> updateData) async {
    // updateData 예시: { 'name': '수정된 맵 이름' }
    // 백엔드의 UpdateVttMapDto와 일치해야 함
    try {
      final res = await ApiClient.instance.dio.patch(
        '/vttmaps/$mapId',
        data: updateData,
      );
      return VttScene.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to update VTT map: ${e.message}');
    }
  }

  /// 맵(씬) 삭제하기
  /// [API] DELETE /vttmaps/:mapId
  Future<void> deleteVttMap(String mapId) async {
    try {
      await ApiClient.instance.dio.delete('/vttmaps/$mapId');
      return;
    } on DioException catch (e) {
      throw Exception('Failed to delete VTT map: ${e.message}');
    }
  }

  /// VTT 맵 이미지 업로드용 Presigned URL 받기
  /// [API] POST /rooms/:roomId/vttmaps/presigned-url
  Future<Map<String, dynamic>> getPresignedUrlForVttMapImage({
    required String roomId,
    required String fileName,
    required String contentType,
  }) async {
    try {
      final res = await ApiClient.instance.dio.post(
        '/rooms/$roomId/vttmaps/presigned-url',
        data: {
          'fileName': fileName,
          'contentType': contentType,
        },
      );
      // 백엔드 PresignedUrlResponseDto 반환 ( { presignedUrl, publicUrl, key } )
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception('Failed to get presigned URL: ${e.message}');
    }
  }


  // =======================================================================
  // ✨ VTT 토큰 (Token) API Methods (token.controller.ts 기반)
  // =======================================================================

  /// 맵(씬) ID로 모든 토큰 가져오기
  /// [API] GET /tokens/maps/:mapId
  Future<List<Token>> getTokensByMap(String mapId) async {
    try {
      final res = await ApiClient.instance.dio.get('/tokens/maps/$mapId');
      
      final List<dynamic> data = res.data as List<dynamic>;
      return data
          .map((item) => Token.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Failed to get tokens: ${e.message}');
    }
  }

  /// 새 토큰 생성하기
  /// [API] POST /tokens/maps/:mapId
  Future<Token> createToken(String mapId, Map<String, dynamic> createData) async {
    // createData는 백엔드의 CreateTokenDto와 일치해야 함
    // (name, x, y, npcId, characterSheetId 등)
    // token.toJson()을 사용해도 좋음
    try {
      final res = await ApiClient.instance.dio.post(
        '/tokens/maps/$mapId',
        data: createData, 
      );
      
      return Token.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to create token: ${e.message}');
    }
  }

  /// 토큰 정보 업데이트 (이동, 이름 변경 등)
  /// [API] PATCH /tokens/:id
  Future<Token> updateToken(String id, Map<String, dynamic> updateData) async {
    // updateData 예시: { 'x': newX, 'y': newY } 또는 { 'name': 'New Name' }
    // 백엔드 UpdateTokenDto와 일치해야 함
    try {
      final res = await ApiClient.instance.dio.patch(
        '/tokens/$id',
        data: updateData,
      );
      
      return Token.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Failed to update token: ${e.message}');
    }
  }

  /// 토큰 삭제하기
  /// [API] DELETE /tokens/:id
  Future<void> deleteToken(String id) async {
    try {
      // 백엔드는 204 No Content를 반환함
      await ApiClient.instance.dio.delete('/tokens/$id');
      return;
    } on DioException catch (e) {
      throw Exception('Failed to delete token: ${e.message}');
    }
  }
}