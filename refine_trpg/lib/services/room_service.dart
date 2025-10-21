import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../models/participant.dart';
import 'auth_service.dart'; // AuthService 임포트
import 'dart:io';
import 'dart:async';

class RoomServiceException implements Exception {
  final String message;
  final int? statusCode;

  RoomServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RoomService {
  static const String _baseUrl =
      'http://localhost:11122'; // AuthService와 baseUrl 통일
  static http.Client _client() => http.Client();

  static Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await AuthService.getToken(); // AuthService에서 토큰 가져오기
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<dynamic> _requestWithTimeout(Future<dynamic> request) {
    return request.timeout(const Duration(seconds: 10));
  }

  static String _parseErrorMessage(String responseBody) {
    try {
      final Map<String, dynamic> json = jsonDecode(responseBody);
      return json['error'] ?? json['message'] ?? '알 수 없는 오류 발생';
    } catch (e) {
      return '오류 응답을 처리하는 중 오류 발생: ${e.toString()}';
    }
  }

  // 방 생성 - Room 객체를 인자로 받도록 수정
  static Future<Room> createRoom(Room room) async {
    final uri = Uri.parse('$_baseUrl/rooms');
    final client = _client();
    final requestBody = room.toCreateJson(); // 요청 본문 미리 생성

    // --- 디버깅 로그 추가 ---
    print('--- [RoomService.createRoom] API 요청 시작 ---');
    print('요청 URL: $uri');
    print('요청 Body: ${jsonEncode(requestBody)}');
    // --- 디버깅 로그 추가 끝 ---

    try {
      final res = await _requestWithTimeout(
        client.post(
          uri,
          headers: await _headers(withAuth: true),
          body: jsonEncode(requestBody), // 미리 생성한 본문 사용
        ),
      );

      // --- 디버깅 로그 추가 ---
      print('응답 Status Code: ${res.statusCode}');
      print('응답 Body: ${res.body}');
      print('--- [RoomService.createRoom] API 요청 종료 ---');
      // --- 디버깅 로그 추가 끝 ---

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        return Room.fromJson(body);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('방 생성 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      // client.close();
    }
  }

  // 방 목록 조회
  static Future<List<Room>> getRooms() async {
    final uri = Uri.parse('$_baseUrl/rooms');
    final client = _client();
    try {
      final res = await _requestWithTimeout(
        client.get(uri, headers: await _headers(withAuth: true)),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final List<dynamic> body = jsonDecode(res.body);
        return body
            .map((e) => Room.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('방 목록 조회 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  // 방 정보 조회
  static Future<Room> getRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    try {
      final res = await _requestWithTimeout(
        client.get(uri, headers: await _headers(withAuth: true)),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        return Room.fromJson(body);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('방 정보 조회 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  // 방 입장
  static Future<Room> joinRoom(String roomId, {String? password}) async {
    final uri = Uri.parse('$_baseUrl/rooms/$roomId/join');
    final client = _client();

    try {
      final res = await _requestWithTimeout(
        client.post(
          uri,
          headers: await _headers(withAuth: true),
          body: jsonEncode({'password': password}),
        ),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        return Room.fromJson(body);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('방 입장 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  // 방에서 퇴장
  static Future<void> leaveRoom(String roomId) async {
    final uri = Uri.parse(
      '$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/leave',
    );
    final client = _client();
    try {
      final res = await _requestWithTimeout(
        client.post(uri, headers: await _headers(withAuth: true)),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('방 퇴장 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  // 방 삭제
  static Future<void> deleteRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    try {
      final res = await _requestWithTimeout(
        client.delete(uri, headers: await _headers(withAuth: true)),
      );

      // 204 No Content는 성공적으로 삭제됨을 의미
      if (res.statusCode == 204) {
        return;
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('방 삭제 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  // 방 정보 업데이트
  static Future<Room> updateRoom(
    String roomId,
    Map<String, dynamic> updates,
  ) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    try {
      final res = await _requestWithTimeout(
        client.patch(
          uri,
          headers: await _headers(withAuth: true),
          body: jsonEncode(updates),
        ),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return Room.fromJson(body);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('방 정보 업데이트 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      // client.close();
    }
  }

  // 👇👇👇 추가된 메서드 👇👇👇
  // 특정 방의 참여자 목록 조회
  static Future<List<Participant>> getParticipants(String roomId) async {
    final intId = int.tryParse(roomId);
    final _path = intId != null
        ? '$_baseUrl/rooms/$intId/participants'
        : '$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/participants';
    final uri = Uri.parse('$_path?ts=${DateTime.now().millisecondsSinceEpoch}');
    final client = _client();
    try {
      final res = await _requestWithTimeout(
        client.get(uri, headers: await _headers(withAuth: true)),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final List<dynamic> body = jsonDecode(res.body);
        return body
            .map((e) => Participant.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      throw RoomServiceException('참여자 목록 조회 중 오류가 발생했습니다: ${e.toString()}');
    }
  }
  // 👆👆👆 추가된 메서드 👆👆👆

  // 앱 종료 시 리소스 정리
  static void dispose() {
    // closeClient(); // http.Client는 각 요청마다 생성되므로, 닫을 필요 없음
  }
}
