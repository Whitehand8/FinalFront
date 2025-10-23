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
  // Use a single client for potential connection reuse, though http package handles this somewhat.
  // Consider using a package like 'dio' for more advanced features if needed.
  static http.Client _client() => http.Client();

  // Helper to get headers, including Authorization if available
  static Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json', // Explicitly accept JSON responses
    };

    if (withAuth) {
      final token = await AuthService.getToken(); // Fetch token from AuthService
      if (token != null) {
        headers['Authorization'] = 'Bearer $token'; // Add Bearer token
      }
    }
    return headers;
  }

  // Helper to add a timeout to requests
  static Future<dynamic> _requestWithTimeout(Future<dynamic> request) {
    // Set a reasonable timeout duration (e.g., 10 seconds)
    return request.timeout(const Duration(seconds: 10));
  }

  // Helper to parse error messages from response body
  static String _parseErrorMessage(String responseBody) {
    try {
      // Try to decode JSON and extract 'message' or 'error' field
      final Map<String, dynamic> json = jsonDecode(responseBody);
      // Prioritize specific error keys, fallback to generic message or raw body
      return json['error']?.toString()
          ?? json['message']?.toString()
          ?? '알 수 없는 오류 발생';
    } catch (e) {
      // If response is not JSON or parsing fails, return raw body or generic message
      return responseBody.isNotEmpty ? responseBody : '오류 응답 처리 실패';
    }
  }

  // --- Room CRUD and Joining/Leaving ---

  // Create a new room
  static Future<Room> createRoom(Room room) async {
    final uri = Uri.parse('$_baseUrl/rooms');
    final client = _client();
    final requestBody = room.toCreateJson(); // Get JSON body from Room model

    print('[RoomService.createRoom] Request URL: $uri');
    print('[RoomService.createRoom] Request Body: ${jsonEncode(requestBody)}');

    try {
      final res = await _requestWithTimeout(
        client.post(
          uri,
          headers: await _headers(withAuth: true), // Requires auth
          body: jsonEncode(requestBody),
        ),
      );

      print('[RoomService.createRoom] Response Status: ${res.statusCode}');
      print('[RoomService.createRoom] Response Body: ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        return Room.fromJson(body); // Parse successful response
      }

      // Handle specific known error messages from backend if possible
      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException { // Handle network errors
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException { // Handle request timeout
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException { // Re-throw specific service exceptions
      rethrow;
    } catch (e) { // Handle other unexpected errors
      print('[RoomService.createRoom] Error: $e');
      throw RoomServiceException('방 생성 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close(); // Close the client after the request
    }
  }

  // Get a list of rooms (assuming an endpoint exists, add if needed)
  static Future<List<Room>> getRooms() async {
    final uri = Uri.parse('$_baseUrl/rooms');
    final client = _client();
    print('[RoomService.getRooms] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(
        client.get(uri, headers: await _headers(withAuth: true)), // Assuming auth needed
      );
      print('[RoomService.getRooms] Response Status: ${res.statusCode}');

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
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.getRooms] Error: $e');
      throw RoomServiceException('방 목록 조회 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Get details for a specific room
  static Future<Room> getRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
     print('[RoomService.getRoom] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(
        client.get(uri, headers: await _headers(withAuth: true)), // Assuming auth needed
      );
       print('[RoomService.getRoom] Response Status: ${res.statusCode}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        return Room.fromJson(body);
      }
       if (res.statusCode == 404) {
         throw RoomServiceException('방을 찾을 수 없습니다.', statusCode: 404);
       }
      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.getRoom] Error: $e');
      throw RoomServiceException('방 정보 조회 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Join a room
  static Future<Room> joinRoom(String roomId, {String? password}) async {
    final uri = Uri.parse('$_baseUrl/rooms/$roomId/join');
    final client = _client();
    print('[RoomService.joinRoom] Request URL: $uri');

    try {
      final res = await _requestWithTimeout(
        client.post(
          uri,
          headers: await _headers(withAuth: true), // Requires auth
          // Only include password if provided
          body: jsonEncode({'password': password}),
        ),
      );
       print('[RoomService.joinRoom] Response Status: ${res.statusCode}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        return Room.fromJson(body);
      }
      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.joinRoom] Error: $e');
      throw RoomServiceException('방 입장 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Leave a room
  static Future<void> leaveRoom(String roomId) async {
    final uri = Uri.parse(
      '$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/leave',
    );
    final client = _client();
    print('[RoomService.leaveRoom] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(
        client.post(uri, headers: await _headers(withAuth: true)), // Requires auth
      );
      print('[RoomService.leaveRoom] Response Status: ${res.statusCode}');

      // Backend might return 200 OK or 204 No Content on successful leave
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return; // Success
      }
      // Handle specific 403 Forbidden error (creator cannot leave)
      if (res.statusCode == 403) {
        throw RoomServiceException('방장은 방을 나갈 수 없습니다.', statusCode: 403);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.leaveRoom] Error: $e');
      throw RoomServiceException('방 퇴장 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Delete a room (creator only)
  static Future<void> deleteRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
     print('[RoomService.deleteRoom] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(
        client.delete(uri, headers: await _headers(withAuth: true)), // Requires auth
      );
      print('[RoomService.deleteRoom] Response Status: ${res.statusCode}');

      // Expect 204 No Content for successful deletion
      if (res.statusCode == 204 || (res.statusCode >= 200 && res.statusCode < 300)) { // Allow 200 OK as well
        return; // Success
      }
       // Handle 403 Forbidden (not the creator)
      if (res.statusCode == 403) {
         throw RoomServiceException('방장만 방을 삭제할 수 있습니다.', statusCode: 403);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.deleteRoom] Error: $e');
      throw RoomServiceException('방 삭제 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Update room details (e.g., name, password)
  static Future<Room> updateRoom(
    String roomId,
    Map<String, dynamic> updates, // Map containing fields to update
  ) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    print('[RoomService.updateRoom] Request URL: $uri');
    print('[RoomService.updateRoom] Request Body: ${jsonEncode(updates)}');
    try {
      final res = await _requestWithTimeout(
        client.patch( // Use PATCH for partial updates
          uri,
          headers: await _headers(withAuth: true), // Requires auth
          body: jsonEncode(updates),
        ),
      );
       print('[RoomService.updateRoom] Response Status: ${res.statusCode}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return Room.fromJson(body); // Return updated room
      }
       if (res.statusCode == 403) {
         throw RoomServiceException('방 정보 수정 권한이 없습니다.', statusCode: 403);
       }
       if (res.statusCode == 404) {
         throw RoomServiceException('방을 찾을 수 없습니다.', statusCode: 404);
       }
      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.updateRoom] Error: $e');
      throw RoomServiceException('방 정보 업데이트 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // --- Participant Management ---

  // Get list of participants in a room
  static Future<List<Participant>> getParticipants(String roomId) async {
    final uri = Uri.parse(
      '$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/participants',
    );
    final client = _client();
     print('[RoomService.getParticipants] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(
        client.get(uri, headers: await _headers(withAuth: true)), // Assuming auth needed
      );
       print('[RoomService.getParticipants] Response Status: ${res.statusCode}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final List<dynamic> body = jsonDecode(res.body);
        return body
            .map((e) => Participant.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (res.statusCode == 404) {
        throw RoomServiceException('해당 방을 찾을 수 없습니다.', statusCode: 404);
      }
      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      print('[RoomService.getParticipants] Error: $e');
      throw RoomServiceException('참여자 목록 조회 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Transfer creator role (creator only)
  static Future<void> transferCreator(
      String roomId, String newCreatorId) async {
    final uri = Uri.parse(
      '$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/transfer-creator',
    );
    final client = _client();
    // Backend expects newCreatorId in the body
    final body = jsonEncode({'newCreatorId': newCreatorId});
    print('[RoomService.transferCreator] Request URL: $uri');
    print('[RoomService.transferCreator] Request Body: $body');

    try {
      final res = await _requestWithTimeout(
        client.patch(uri, headers: await _headers(withAuth: true), body: body), // Use PATCH
      );
       print('[RoomService.transferCreator] Response Status: ${res.statusCode}');

      // Expect 200 OK on success
      if (res.statusCode == 200) {
        return; // Success
      }
      // Handle specific errors
      if (res.statusCode == 403) {
         throw RoomServiceException('방장만 권한을 위임할 수 있습니다.', statusCode: 403);
      }
      if (res.statusCode == 404) {
         throw RoomServiceException('방 또는 대상 유저를 찾을 수 없습니다.', statusCode: 404);
      }
       if (res.statusCode == 400) { // e.g., newCreatorId is not a participant
         final errorMessage = _parseErrorMessage(res.body);
         throw RoomServiceException(errorMessage, statusCode: res.statusCode);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.transferCreator] Error: $e');
      throw RoomServiceException('방장 위임 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Update participant's role (creator only)
  static Future<void> updateParticipantRole(
    String roomId,
    String userId, // Target user ID
    String newRole, // New role (e.g., "GM", "PLAYER")
  ) async {
    final uri = Uri.parse(
      '$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/participants/${Uri.encodeComponent(userId)}/role',
    );
    final client = _client();
    final body = jsonEncode({'role': newRole});
    print('[RoomService.updateParticipantRole] Request URL: $uri');
    print('[RoomService.updateParticipantRole] Request Body: $body');

    try {
      final res = await _requestWithTimeout(
        client.patch(uri, headers: await _headers(withAuth: true), body: body), // Use PATCH
      );
       print('[RoomService.updateParticipantRole] Response Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        return; // Success
      }
       if (res.statusCode == 403) {
         throw RoomServiceException('역할 변경 권한이 없습니다.', statusCode: 403);
      }
       if (res.statusCode == 404) {
         throw RoomServiceException('방 또는 대상 유저를 찾을 수 없습니다.', statusCode: 404);
      }
       if (res.statusCode == 400) { // e.g., Invalid role
         final errorMessage = _parseErrorMessage(res.body);
         throw RoomServiceException(errorMessage, statusCode: res.statusCode);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      print('[RoomService.updateParticipantRole] Error: $e');
      throw RoomServiceException('참여자 역할 변경 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  // Remove (kick) a participant from the room (creator or self)
  // Corresponds to the backend's removeUser logic (soft delete)
  static Future<void> removeUser(
      String roomId,
      String targetUserId, // ID of the user to be removed
      // Requester ID is implicitly sent via Authorization token
      ) async {
    // Backend likely determines requester from token and checks permissions.
    // Frontend just needs to send the targetUserId.
    // Assuming a DELETE endpoint for removal, matching REST conventions.
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/participants/${Uri.encodeComponent(targetUserId)}');
    final client = _client();
    print('[RoomService.removeUser] Request URL: $uri');

    try {
      final res = await _requestWithTimeout(
        client.delete(uri, headers: await _headers(withAuth: true)), // Requires auth
      );
      print('[RoomService.removeUser] Response Status: ${res.statusCode}');

      // Expect 200 OK or 204 No Content for successful removal (soft delete)
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return; // Success
      }
       // Handle specific errors based on backend implementation
      if (res.statusCode == 403) { // Forbidden
         final errorMessage = _parseErrorMessage(res.body);
         // Check specific message if backend provides it (e.g., creator cannot remove self)
         if (errorMessage.contains('cannot remove creator')) { // Example check
            throw RoomServiceException('방장은 자신을 추방할 수 없습니다.', statusCode: 403);
         } else {
             throw RoomServiceException('참여자를 추방할 권한이 없습니다.', statusCode: 403);
         }
      }
      if (res.statusCode == 404) {
         throw RoomServiceException('방 또는 대상 유저를 찾을 수 없습니다.', statusCode: 404);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } on SocketException {
      throw RoomServiceException('네트워크 연결을 확인해주세요.');
    } on TimeoutException {
      throw RoomServiceException('서버 응답 시간이 초과되었습니다.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       print('[RoomService.removeUser] Error: $e');
      throw RoomServiceException('참여자 추방 중 오류가 발생했습니다: ${e.toString()}');
    } finally {
      client.close();
    }
  }


  // --- Utility ---

  // Close the shared client if needed (e.g., on app exit)
  // Note: Standard http.Client might not need explicit closing for simple use cases.
  // static void dispose() {
  //   _sharedClient?.close();
  //   _sharedClient = null;
  // }
}
