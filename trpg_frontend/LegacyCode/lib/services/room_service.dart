import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/browser_client.dart' as http_browser;
import '../models/room.dart';

class RoomServiceException implements Exception {
  final String message;
  final int? statusCode;

  RoomServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'RoomServiceException: $message (code: $statusCode)';
}

class RoomService {
  static const _baseUrl = 'http://localhost:11122';

  // 싱글톤 클라이언트
  static http.Client? _sharedClient;

  static http.Client _client() {
    if (_sharedClient != null) return _sharedClient!;

    if (kIsWeb) {
      final c = http_browser.BrowserClient()..withCredentials = true;
      _sharedClient = c;
      return c;
    } else {
      _sharedClient = http.Client();
      return _sharedClient!;
    }
  }

  static void closeClient() {
    _sharedClient?.close();
    _sharedClient = null;
  }

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withAuth) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final Token = prefs.getString('authToken');
        if (Token != null && Token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $Token';
        }
      } catch (_) {}
    }
    return headers;
  }

  static String _parseErrorMessage(String responseBody) {
    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String) {
          return message;
        }
      }
    } catch (e) {
      return responseBody;
    }
    return '요청을 처리할 수 없습니다.';
  }

  static Future<Room> createRoom(Room room) async {
    final uri = Uri.parse('$_baseUrl/rooms');
    final client = _client();
    try {
      final res = await client.post(
        uri,
        headers: await _headers(withAuth: true),
        body: jsonEncode(room.toCreateJson()),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return Room.fromJson(body); // ← Room.fromJson 내부에서 body['room'] 처리됨
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  static Future<Room> getRoomById(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    try {
      final res = await client.get(
        uri,
        headers: await _headers(withAuth: true),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return Room.fromJson(body);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  static Future<Room> joinRoom(String roomId,
      {required String password}) async {
    final uri =
        Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/join');
    final client = _client();
    try {
      final res = await client.post(
        uri,
        headers: await _headers(withAuth: true),
        body: jsonEncode({'password': password}),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return Room.fromJson(body);
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  static Future<void> leaveRoom(String roomId) async {
    final uri =
        Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}/leave');
    final client = _client();
    try {
      final res = await client.post(
        uri,
        headers: await _headers(withAuth: true),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return;
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }

  static Future<void> deleteRoom(String roomId) async {
    final uri = Uri.parse('$_baseUrl/rooms/${Uri.encodeComponent(roomId)}');
    final client = _client();
    try {
      final res = await client.delete(
        uri,
        headers: await _headers(withAuth: true),
      );

      if (res.statusCode == 204) {
        return;
      }

      final errorMessage = _parseErrorMessage(res.body);
      throw RoomServiceException(errorMessage, statusCode: res.statusCode);
    } finally {
      // client.close(); 싱글톤이므로 닫지 않음
    }
  }
}
