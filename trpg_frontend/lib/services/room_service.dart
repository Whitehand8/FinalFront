// lib/services/room_service.dart
import 'package:dio/dio.dart';
import 'package:refine_trpg/models/participant.dart';
import 'package:refine_trpg/models/room.dart';
import 'ApiClient.dart';

class RoomServiceException implements Exception {
  final String message;
  final int? statusCode;
  RoomServiceException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class RoomService {
  static Future<Room> createRoom(Room room) async {
    try {
      final res = await ApiClient.instance.dio
          .post('/rooms', data: room.toCreateJson());
      return Room.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<Room> getRoom(String roomId) async {
    try {
      final res = await ApiClient.instance.dio
          .get('/rooms/${Uri.encodeComponent(roomId)}');
      return Room.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<Room> joinRoom(String roomId,
      {required String password}) async {
    try {
      final res = await ApiClient.instance.dio
          .post('/rooms/$roomId/join', data: {'password': password});
      return Room.fromJson(res.data);
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<void> leaveRoom(String roomId) async {
    try {
      await ApiClient.instance.dio
          .post('/rooms/${Uri.encodeComponent(roomId)}/leave');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<void> deleteRoom(String roomId) async {
    try {
      await ApiClient.instance.dio
          .delete('/rooms/${Uri.encodeComponent(roomId)}');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<void> transferCreator(String roomId, int newCreatorId) async {
    try {
      await ApiClient.instance.dio.patch(
        '/rooms/${Uri.encodeComponent(roomId)}/transfer-creator',
        data: {'newCreatorId': newCreatorId},
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<void> updateParticipantRole(
      String roomId, String userId, String newRole) async {
    try {
      await ApiClient.instance.dio.patch(
        '/rooms/${Uri.encodeComponent(roomId)}/participants/${Uri.encodeComponent(userId)}/role',
        data: {'role': newRole},
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static Future<List<Participant>> getParticipants(String roomId) async {
    try {
      final res = await ApiClient.instance.dio
          .get('/rooms/${Uri.encodeComponent(roomId)}/participants');
      return (res.data as List).map((e) => Participant.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  static RoomServiceException _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) {
      return RoomServiceException('인증 정보가 유효하지 않습니다.');
    } else if (e.response?.statusCode == 403) {
      return RoomServiceException('권한이 없습니다.');
    } else if (e.response?.statusCode == 404) {
      return RoomServiceException('방을 찾을 수 없습니다.', statusCode: 404);
    } else if (e.response?.statusCode == 409) {
      final msg = _extractMessage(e.response?.data) ?? '충돌 발생';
      if (msg.contains('방 참가 처리 중 다른 요청으로 인해 방이 삭제되었습니다')) {
        return RoomServiceException('방이 이미 삭제되어 참가할 수 없습니다.');
      } else if (msg.contains('이미 방에 참가한 사용자입니다') ||
          msg.contains('이미 다른 방에 참가 중입니다')) {
        return RoomServiceException('이미 다른 방에 참가 중입니다.');
      }
      return RoomServiceException(msg);
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } else if (e.type == DioExceptionType.connectionError) {
      return RoomServiceException('네트워크 연결을 확인해주세요.');
    } else {
      final msg = _extractMessage(e.response?.data) ?? '서버 오류';
      return RoomServiceException(msg, statusCode: e.response?.statusCode);
    }
  }

// message 필드를 안전하게 문자열로 추출
  static String? _extractMessage(dynamic data) {
    if (data is! Map<String, dynamic>) return null;

    final message = data['message'];
    if (message is String) {
      return message;
    } else if (message is List) {
      if (message.isEmpty) return null;
      // 첫 번째 오류 메시지 사용 (또는 join 가능)
      return message[0] is String ? message[0] as String : '유효하지 않은 오류 형식';
    }
    return null;
  }
}
