import 'dart:convert';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:refine_trpg/models/room.dart'; // Ensure room.dart uses int IDs
import 'package:refine_trpg/models/participant.dart'; // Ensure participant.dart uses int IDs
import 'auth_service.dart';
import 'dart:io';
import 'dart:async';

class RoomServiceException implements Exception {
  final String message;
  final int? statusCode;

  RoomServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'RoomService Error [$statusCode]: $message';
}

class RoomService {
  static const String _baseUrl = 'http://localhost:11122'; // Ensure correct backend HTTP port
  // Consider using a singleton or dependency injection for http.Client
  static http.Client _client() => http.Client();

  // Helper to get headers, including Authorization if available
  static Future<Map<String, String>> _headers({bool withAuth = true}) async { // Default to true
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await AuthService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        // Handle missing token case if needed (e.g., throw error, log warning)
        debugPrint("[RoomService] Warning: Authorization token is missing.");
      }
    }
    return headers;
  }

  // Helper to add a timeout to requests
  static Future<http.Response> _requestWithTimeout(Future<http.Response> request) {
    // Consistent timeout duration
    return request.timeout(const Duration(seconds: 15));
  }

  // Helper to parse error messages from response body (UTF-8 safe)
  static String _parseErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ??
               decoded['error']?.toString() ??
               'Unknown error occurred.';
      } else if (decoded is String && decoded.isNotEmpty) {
        return decoded;
      }
    } catch (e) {
      debugPrint("[RoomService] Error decoding error response: $e");
      // Fallback to reason phrase or raw body if decoding fails
      final bodyString = utf8.decode(response.bodyBytes, allowMalformed: true);
      return bodyString.isNotEmpty ? bodyString : (response.reasonPhrase ?? 'Request failed.');
    }
    return response.reasonPhrase ?? 'Request failed.';
  }

  // Helper to handle general response logic
  static dynamic _handleResponse(http.Response res, String operationName) {
     debugPrint('[RoomService.$operationName] Response Status: ${res.statusCode}');
     // Uncomment for detailed body logging:
     // debugPrint('[RoomService.$operationName] Response Body: ${utf8.decode(res.bodyBytes, allowMalformed: true)}');

     if (res.statusCode >= 200 && res.statusCode < 300) {
        // Handle successful responses (200 OK, 201 Created, 204 No Content)
        if (res.statusCode == 204 || res.bodyBytes.isEmpty) {
           return null; // No content to parse
        }
        try {
           return jsonDecode(utf8.decode(res.bodyBytes));
        } catch (e) {
           debugPrint('[RoomService.$operationName] Error decoding success response: $e');
           throw RoomServiceException('Failed to process server response.', statusCode: res.statusCode);
        }
     } else {
        // Handle error responses
        final errorMessage = _parseErrorMessage(res);
        debugPrint('[RoomService.$operationName] Error: $errorMessage');
        throw RoomServiceException(errorMessage, statusCode: res.statusCode);
     }
  }


  // --- Room CRUD and Joining/Leaving ---

  // Create a new room
  static Future<Room> createRoom(Room roomData, {String? password}) async { // Pass password separately
    final uri = Uri.parse('$_baseUrl/rooms');
    final client = _client();
    // Use toCreateJson with password
    final requestBody = jsonEncode(roomData.toCreateJson(password: password));
    const operation = 'createRoom';
    debugPrint('[$operation] Request URL: $uri');
    debugPrint('[$operation] Request Body: $requestBody');

    try {
      final res = await _requestWithTimeout(
        client.post(
          uri,
          headers: await _headers(), // Auth needed
          body: requestBody,
        ),
      );
      final body = _handleResponse(res, operation);
      // Backend returns { message: string, room: RoomResponseDto }
      if (body != null && body['room'] is Map<String, dynamic>) {
         return Room.fromJson(body['room']); // Pass only the room object
      } else {
         throw RoomServiceException('Invalid response format after creating room.', statusCode: res.statusCode);
      }
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException { // Re-throw specific service exceptions
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while creating the room.');
    } finally {
      client.close();
    }
  }

  // Get a list of rooms (Assuming GET /rooms returns List<RoomResponseDto>)
  static Future<List<Room>> getRooms() async {
    // Note: Backend doesn't currently have a GET /rooms endpoint. This is hypothetical.
    final uri = Uri.parse('$_baseUrl/rooms'); // Adjust if endpoint exists
    final client = _client();
    const operation = 'getRooms';
    debugPrint('[$operation] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(client.get(uri, headers: await _headers())); // Auth assumed
      final List<dynamic> body = _handleResponse(res, operation);
      return body.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
       debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while fetching rooms.');
    } finally {
      client.close();
    }
  }

  // Get details for a specific room (GET /rooms/:roomId)
  static Future<Room> getRoom(String roomId) async {
    // Room ID is UUID string, no need to parse to int
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    const operation = 'getRoom';
    debugPrint('[$operation] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(client.get(uri, headers: await _headers())); // Auth needed
      final body = _handleResponse(res, operation);
      // Backend returns RoomResponseDto directly
      return Room.fromJson(body);
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException catch(e) {
       // Make 404 error more specific if possible
       if (e.statusCode == 404) {
          throw RoomServiceException('Room not found.', statusCode: 404);
       }
       rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while fetching room details.');
    } finally {
      client.close();
    }
  }

  // Join a room (POST /rooms/:roomId/join)
  static Future<Room> joinRoom(String roomId, {String? password}) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/join');
    final client = _client();
    final requestBody = jsonEncode({'password': password ?? ''}); // Send empty string if no password
    const operation = 'joinRoom';
    debugPrint('[$operation] Request URL: $uri');
    debugPrint('[$operation] Request Body: $requestBody'); // Don't log password in production

    try {
      final res = await _requestWithTimeout(
        client.post(uri, headers: await _headers(), body: requestBody), // Auth needed
      );
      final body = _handleResponse(res, operation);
       // Backend returns { message: string, room: RoomResponseDto }
      if (body != null && body['room'] is Map<String, dynamic>) {
         return Room.fromJson(body['room']);
      } else {
         throw RoomServiceException('Invalid response format after joining room.', statusCode: res.statusCode);
      }
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException {
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while joining the room.');
    } finally {
      client.close();
    }
  }

  // Leave a room (POST /rooms/:roomId/leave)
  static Future<void> leaveRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/leave');
    final client = _client();
    const operation = 'leaveRoom';
    debugPrint('[$operation] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(client.post(uri, headers: await _headers())); // Auth needed
      _handleResponse(res, operation); // Expects 204 No Content
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException catch(e) {
       // Handle specific 403 Forbidden error
       if (e.statusCode == 403) {
          throw RoomServiceException('Creator cannot leave the room.', statusCode: 403);
       }
       rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while leaving the room.');
    } finally {
      client.close();
    }
  }

  // Delete a room (creator only) (DELETE /rooms/:roomId)
  static Future<void> deleteRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    const operation = 'deleteRoom';
    debugPrint('[$operation] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(client.delete(uri, headers: await _headers())); // Auth needed
      _handleResponse(res, operation); // Expects 204 No Content
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException catch(e) {
      // Handle 403 Forbidden (not the creator)
      if (e.statusCode == 403) {
         throw RoomServiceException('Only the room creator can delete the room.', statusCode: 403);
      }
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while deleting the room.');
    } finally {
      client.close();
    }
  }

  // Update room details (PATCH /rooms/:roomId) - Backend endpoint doesn't exist yet
  // static Future<Room> updateRoom( String roomId, Map<String, dynamic> updates) async { ... }

  // --- Participant Management ---

  // Get list of participants in a room (GET /rooms/:roomId/participants)
  static Future<List<Participant>> getParticipants(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/participants');
    final client = _client();
    const operation = 'getParticipants';
    debugPrint('[$operation] Request URL: $uri');
    try {
      final res = await _requestWithTimeout(client.get(uri, headers: await _headers())); // Auth needed
      // Backend returns List<RoomParticipantDto>
      final List<dynamic> body = _handleResponse(res, operation);
      // Ensure Participant.fromJson handles the backend DTO correctly (int IDs)
      return body.map((e) => Participant.fromJson(e as Map<String, dynamic>)).toList();
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException catch(e) {
        if (e.statusCode == 404) {
           throw RoomServiceException('Room not found when fetching participants.', statusCode: 404);
        }
        rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while fetching participants.');
    } finally {
      client.close();
    }
  }

  // Transfer creator role (creator only) (PATCH /rooms/:roomId/transfer-creator)
  // [수정됨] Accepts int newCreatorUserId
  static Future<Room> transferCreator(String roomId, int newCreatorUserId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/transfer-creator');
    final client = _client();
    // Backend expects { newCreatorId: number } in the body
    final body = jsonEncode({'newCreatorId': newCreatorUserId});
    const operation = 'transferCreator';
    debugPrint('[$operation] Request URL: $uri');
    debugPrint('[$operation] Request Body: $body');

    try {
      final res = await _requestWithTimeout(
        client.patch(uri, headers: await _headers(), body: body), // Auth needed
      );
      // Backend returns { message: string, room: RoomResponseDto }
      final responseBody = _handleResponse(res, operation);
       if (responseBody != null && responseBody['room'] is Map<String, dynamic>) {
          return Room.fromJson(responseBody['room']); // Return updated room
       } else {
          throw RoomServiceException('Invalid response format after transferring creator.', statusCode: res.statusCode);
       }
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException catch(e) {
      // Handle specific errors
      if (e.statusCode == 403) {
         throw RoomServiceException('Only the room creator can transfer ownership.', statusCode: 403);
      }
      // 400 or 404 errors might contain specific messages from backend
      rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while transferring creator.');
    } finally {
      client.close();
    }
  }

  // Update participant's role (creator only) (PATCH /rooms/:roomId/participants/:userId/role)
  // [수정됨] Accepts int participantId
  static Future<Room> updateParticipantRole(
    String roomId,
    int participantId, // <<< --- Changed to int
    String newRole, // New role ("GM" or "PLAYER")
  ) async {
    // URL expects participantId (number in backend, converted to string here)
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/participants/${participantId.toString()}/role');
    final client = _client();
    // Body expects { role: string }
    final body = jsonEncode({'role': newRole.toUpperCase()}); // Ensure role is uppercase
    const operation = 'updateParticipantRole';
    debugPrint('[$operation] Request URL: $uri');
    debugPrint('[$operation] Request Body: $body');

    try {
      final res = await _requestWithTimeout(
        client.patch(uri, headers: await _headers(), body: body), // Auth needed
      );
      // Backend returns { message: string, room: RoomResponseDto }
       final responseBody = _handleResponse(res, operation);
       if (responseBody != null && responseBody['room'] is Map<String, dynamic>) {
          return Room.fromJson(responseBody['room']); // Return updated room
       } else {
          throw RoomServiceException('Invalid response format after updating role.', statusCode: res.statusCode);
       }
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException catch(e) {
       if (e.statusCode == 403) {
         throw RoomServiceException('Only the room creator can change roles.', statusCode: 403);
       }
       // 400 (Invalid role/participant) or 404 errors handled by _handleResponse
       rethrow;
    } catch (e) {
      debugPrint('[$operation] Unexpected Error: $e');
      throw RoomServiceException('An unexpected error occurred while updating participant role.');
    } finally {
      client.close();
    }
  }

  // Remove (kick) a participant - Backend endpoint MISSING
  // If DELETE /rooms/:roomId/participants/:participantId is implemented:
  /*
  static Future<void> removeParticipant(String roomId, int targetParticipantId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/participants/${targetParticipantId.toString()}');
    final client = _client();
    const operation = 'removeParticipant';
    debugPrint('[$operation] Request URL: $uri');

    try {
      final res = await _requestWithTimeout(
        client.delete(uri, headers: await _headers()), // Auth needed
      );
      _handleResponse(res, operation); // Expect 204 No Content
    } on SocketException {
      throw RoomServiceException('Network connection failed.');
    } on TimeoutException {
      throw RoomServiceException('Request timed out.');
    } on RoomServiceException catch (e) {
       if (e.statusCode == 403) {
          throw RoomServiceException('Permission denied to remove participant.', statusCode: 403);
       }
       if (e.statusCode == 404) {
          throw RoomServiceException('Room or participant not found.', statusCode: 404);
       }
       rethrow;
    } catch (e) {
       debugPrint('[$operation] Unexpected Error: $e');
       throw RoomServiceException('An unexpected error occurred while removing the participant.');
    } finally {
      client.close();
    }
  }
  */

} // End of RoomService Class