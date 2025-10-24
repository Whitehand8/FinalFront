// services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint

class AuthService {
  // =======================================================================
  // ✨ API Endpoint Constants
  // =======================================================================
  static const _baseUrl = 'http://localhost:11122'; // Backend HTTP port

  // ... (다른 엔드포인트 상수들) ...
  // -----------------------------------------------------------------------
  // 👤 /users endpoints
  // -----------------------------------------------------------------------
  static const _usersUrl = '$_baseUrl/users'; // POST: 회원가입, DELETE: 회원탈퇴
  static const _checkEmailUrl =
      '$_baseUrl/users/check-email'; // POST: 이메일 중복 확인
  static const _checkNicknameUrl =
      '$_baseUrl/users/check-nickname'; // POST: 닉네임 중복 확인
  static const _updateNicknameUrl = '$_baseUrl/users/nickname'; // PATCH: 닉네임 변경
  static const _updatePasswordUrl =
      '$_baseUrl/users/password'; // PATCH: 비밀번호 변경

  // -----------------------------------------------------------------------
  // 🔑 /auth endpoints
  // -----------------------------------------------------------------------
  static const _loginUrl = '$_baseUrl/auth/login'; // POST: 로그인


  // =======================================================================
  // 👤 /users API Methods
  // =======================================================================

  // ... (signup, deleteAccount, checkEmailAvailability, checkNicknameAvailability, updateNickname, updatePassword 메서드 - 변경 없음) ...
  /// 회원가입 API 호출
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String nickname,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(_usersUrl);
    final body = {
      'name': name,
      'nickname': nickname,
      'email': email,
      'password': password,
    };

    debugPrint('[AuthService] signup 호출 URL: $uri');
    debugPrint('[AuthService] 보낼 Body: ${jsonEncode(body)}');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15)); // Add timeout

      debugPrint('[AuthService] Signup Response Code: ${response.statusCode}');
      // debugPrint('[AuthService] Signup Response Body: ${response.body}'); // Log body only if needed

      if (response.statusCode == 201 || response.statusCode == 200) { // Allow 200 OK as well
        return {'success': true, 'message': '회원가입이 완료되었습니다.'};
      } else {
        final errorMessage = _parseErrorMessage(response.bodyBytes);
        debugPrint('[AuthService] Signup failed: $errorMessage');
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on SocketException {
      debugPrint('[AuthService] Signup failed: Network error');
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
       debugPrint('[AuthService] Signup failed: Timeout');
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      debugPrint('[AuthService] Signup failed: Exception: $e');
      return {'success': false, 'message': '회원가입 중 오류가 발생했습니다.'};
    }
  }

  /// 회원탈퇴 API 호출
  static Future<Map<String, dynamic>> deleteAccount() async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': '로그인이 필요합니다.'};
    }

    final uri = Uri.parse(_usersUrl);
    debugPrint('[AuthService] deleteAccount 호출 URL: $uri');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('[AuthService] Delete Account Response Code: ${response.statusCode}');
      // debugPrint('[AuthService] Delete Account Response Body: ${response.body}');

      // Backend returns 200 OK with message on success
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        await clearToken(); // Clear token after successful deletion
        return {
          'success': true,
          'message': responseBody['message'] ?? '성공적으로 계정을 삭제했습니다.'
        };
      } else {
        // Specific error handling based on status codes
        final errorMessage = _parseErrorMessage(response.bodyBytes);
         debugPrint('[AuthService] Delete Account failed: $errorMessage');
         String userMessage = errorMessage; // Default to backend message
         if (response.statusCode == 401) {
           userMessage = '인증 정보가 유효하지 않습니다.';
         } else if (response.statusCode == 404) {
           userMessage = '사용자를 찾을 수 없습니다.';
         } else if (response.statusCode == 500) {
           userMessage = '서버 오류로 계정 삭제에 실패했습니다.';
         }
        return {
          'success': false,
          'message': userMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
       debugPrint('[AuthService] Delete Account failed: Network error');
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
       debugPrint('[AuthService] Delete Account failed: Timeout');
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
       debugPrint('[AuthService] Delete Account failed: Exception: $e');
      return {'success': false, 'message': '회원탈퇴 중 오류가 발생했습니다.'};
    }
  }

  /// 이메일 중복 확인 API 호출
  static Future<Map<String, dynamic>> checkEmailAvailability(
      {required String email}) async {
    final uri = Uri.parse(_checkEmailUrl);
    final body = jsonEncode({'email': email});

    debugPrint('[AuthService] checkEmailAvailability 호출 URL: $uri');
    debugPrint('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthService] Check Email Response Code: ${response.statusCode}');
      // debugPrint('[AuthService] Check Email Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        // Backend returns { exists: boolean }
        if (responseBody['exists'] == true) {
          return {'success': false, 'message': '이미 사용 중인 이메일입니다.'}; // Exists means not available
        } else {
          return {'success': true, 'message': '사용 가능한 이메일입니다.'}; // Doesn't exist means available
        }
      } else {
        final errorMessage = _parseErrorMessage(response.bodyBytes);
         debugPrint('[AuthService] Check Email failed: $errorMessage');
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
       debugPrint('[AuthService] Check Email failed: Network error');
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
       debugPrint('[AuthService] Check Email failed: Timeout');
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
       debugPrint('[AuthService] Check Email failed: Exception: $e');
      return {'success': false, 'message': '이메일 확인 중 오류가 발생했습니다.'};
    }
  }

  /// 닉네임 중복 확인 API 호출
  static Future<Map<String, dynamic>> checkNicknameAvailability(
      {required String nickname}) async {
    final uri = Uri.parse(_checkNicknameUrl);
    final body = jsonEncode({'nickname': nickname});

    debugPrint('[AuthService] checkNicknameAvailability 호출 URL: $uri');
    debugPrint('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthService] Check Nickname Response Code: ${response.statusCode}');
      // debugPrint('[AuthService] Check Nickname Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        // Backend returns { exists: boolean }
        if (responseBody['exists'] == true) {
          return {'success': false, 'message': '이미 사용 중인 닉네임입니다.'}; // Exists means not available
        } else {
          return {'success': true, 'message': '사용 가능한 닉네임입니다.'}; // Doesn't exist means available
        }
      } else {
        final errorMessage = _parseErrorMessage(response.bodyBytes);
         debugPrint('[AuthService] Check Nickname failed: $errorMessage');
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
       debugPrint('[AuthService] Check Nickname failed: Network error');
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
       debugPrint('[AuthService] Check Nickname failed: Timeout');
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
       debugPrint('[AuthService] Check Nickname failed: Exception: $e');
      return {'success': false, 'message': '닉네임 확인 중 오류가 발생했습니다.'};
    }
  }

  /// 닉네임 변경 API 호출
  static Future<Map<String, dynamic>> updateNickname(
      {required String newNickname}) async { // Renamed parameter for clarity
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': '로그인이 필요합니다.'};
    }

    final uri = Uri.parse(_updateNicknameUrl);
    final body = jsonEncode({'nickname': newNickname}); // DTO expects 'nickname'

    debugPrint('[AuthService] updateNickname 호출 URL: $uri');
    debugPrint('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      debugPrint('[AuthService] Update Nickname Response Code: ${response.statusCode}');
      // debugPrint('[AuthService] Update Nickname Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        // Backend returns { message: string }
        return {
          'success': true,
          'message': responseBody['message'] ?? '닉네임이 성공적으로 변경되었습니다.'
        };
      } else {
        final errorMessage = _parseErrorMessage(response.bodyBytes);
        debugPrint('[AuthService] Update Nickname failed: $errorMessage');
         String userMessage = errorMessage;
         if (response.statusCode == 401) {
           userMessage = '인증 정보가 유효하지 않습니다.';
         } else if (response.statusCode == 404) {
           userMessage = '사용자를 찾을 수 없습니다.';
         } else if (response.statusCode == 409) {
           userMessage = '이미 사용 중인 닉네임입니다.'; // Conflict
         }
        return {
          'success': false,
          'message': userMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
       debugPrint('[AuthService] Update Nickname failed: Network error');
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
       debugPrint('[AuthService] Update Nickname failed: Timeout');
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
       debugPrint('[AuthService] Update Nickname failed: Exception: $e');
      return {'success': false, 'message': '닉네임 변경 중 오류가 발생했습니다.'};
    }
  }

  /// 비밀번호 변경 API 호출
  static Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': '로그인이 필요합니다.'};
    }

    final uri = Uri.parse(_updatePasswordUrl);
    // Backend DTO expects 'currentPassword' and 'password' (for the new one)
    final body = jsonEncode({
      'currentPassword': currentPassword,
      'password': newPassword,
    });

    debugPrint('[AuthService] updatePassword 호출 URL: $uri');
    // Don't log passwords in production: debugPrint('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      debugPrint('[AuthService] Update Password Response Code: ${response.statusCode}');
      // debugPrint('[AuthService] Update Password Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
         // Backend returns { message: string }
        return {
          'success': true,
          'message': responseBody['message'] ?? '비밀번호가 성공적으로 변경되었습니다.'
        };
      } else {
        final errorMessage = _parseErrorMessage(response.bodyBytes);
         debugPrint('[AuthService] Update Password failed: $errorMessage');
         String userMessage = errorMessage;
         // Backend returns 401 specifically for wrong currentPassword
         if (response.statusCode == 401) {
            userMessage = '현재 비밀번호가 일치하지 않거나 인증 정보가 유효하지 않습니다.';
         } else if (response.statusCode == 404) {
           userMessage = '사용자를 찾을 수 없습니다.';
         } else if (response.statusCode == 400 && errorMessage.contains('password')) {
           // Handle potential validation errors for the new password format
           userMessage = '새 비밀번호 형식이 올바르지 않습니다. $errorMessage';
         }
        return {
          'success': false,
          'message': userMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
       debugPrint('[AuthService] Update Password failed: Network error');
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
       debugPrint('[AuthService] Update Password failed: Timeout');
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
       debugPrint('[AuthService] Update Password failed: Exception: $e');
      return {'success': false, 'message': '비밀번호 변경 중 오류가 발생했습니다.'};
    }
  }


  // =======================================================================
  // 🔑 /auth API Methods
  // =======================================================================

  /// 로그인 API 호출
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(_loginUrl);
    final body = jsonEncode({'email': email, 'password': password});

    debugPrint('[AuthService] Login 호출 URL: $uri');
    // Don't log credentials in production: debugPrint('[AuthService] Login Body: $body');

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));

       debugPrint('[AuthService] Login Response Code: ${res.statusCode}');
       // debugPrint('[AuthService] Login Response Body: ${res.body}');

      if (res.statusCode == 200) { // Backend login returns 200 OK
        final responseBody = jsonDecode(utf8.decode(res.bodyBytes));
        // Backend returns { access_token: string, refresh_token: string }
        final accessToken = responseBody['access_token'];
        // TODO: Store refresh_token securely if implementing refresh logic
        // final refreshToken = responseBody['refresh_token'];

        if (accessToken == null || accessToken.isEmpty) {
           debugPrint('[AuthService] Login failed: Access token missing in response.');
           return {'success': false, 'message': '로그인 응답 처리 중 오류 발생.'};
        }

        // Store only the access token for now
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', accessToken);

        debugPrint('[AuthService] Access Token 저장 완료.');
        return {'success': true, 'message': '로그인 성공', 'token': accessToken};
      } else {
        // Handle specific login errors (401 Unauthorized)
        final errorMessage = _parseErrorMessage(res.bodyBytes);
        debugPrint('[AuthService] Login 실패: $errorMessage');
        String userMessage = '로그인 실패: $errorMessage';
        if (res.statusCode == 401) {
           userMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
        }
        return {
          'success': false,
          'message': userMessage,
          'statusCode': res.statusCode,
        };
      }
    } on SocketException {
       debugPrint('[AuthService] Login failed: Network error');
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
       debugPrint('[AuthService] Login failed: Timeout');
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
       debugPrint('[AuthService] Login failed: Exception: $e');
      return {'success': false, 'message': '로그인 중 오류가 발생했습니다.'};
    }
  }

  // =======================================================================
  // 🛠️ Token & Helper Utilities
  // =======================================================================

  /// SharedPreferences에서 토큰(Access Token) 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  /// SharedPreferences에서 토큰(Access Token) 제거
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    // TODO: Also remove refresh token if stored
    debugPrint('[AuthService] Cleared authentication token.');
  }

  /// 토큰 존재 여부 확인 (유효성 검증은 아님)
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // [수정됨] JWT 토큰 payload 파싱 (User ID를 int로 파싱 시도)
  /// JWT 토큰의 payload 파싱. User ID ('id' 클레임)를 int? 로 변환 시도.
  static Map<String, dynamic> parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      debugPrint('[AuthService] parseJwt Error: Invalid token structure.');
      throw Exception('Invalid token structure');
    }

    final payload = _decodeBase64(parts[1]);
    final Map<String, dynamic> payloadMap = json.decode(payload);

    // --- User ID 파싱 로직 추가 ---
    if (payloadMap.containsKey('id')) { // 백엔드는 'id' 클레임 사용
      final userIdValue = payloadMap['id'];
      int? userIdInt;
      if (userIdValue is int) {
        userIdInt = userIdValue;
      } else if (userIdValue is String) {
        userIdInt = int.tryParse(userIdValue);
      } else if (userIdValue is double) {
         userIdInt = userIdValue.toInt(); // Handle potential double if backend sends it unexpectedly
      }

      if (userIdInt != null) {
        // Replace original 'id' with the parsed integer version
        payloadMap['id'] = userIdInt;
        debugPrint('[AuthService] Parsed User ID from JWT: $userIdInt (int)');
      } else {
        debugPrint("[AuthService] Warning: Could not parse 'id' claim ('$userIdValue') into int.");
        // Keep the original value or handle error as needed
      }
    } else {
        debugPrint("[AuthService] Warning: JWT payload does not contain 'id' claim.");
    }
    // Standard 'sub' claim (subject) might also contain the user identifier
    if (payloadMap.containsKey('sub')) {
      // You might want similar parsing logic for 'sub' if it represents the user ID
       debugPrint("[AuthService] JWT contains 'sub' claim: ${payloadMap['sub']}");
    }
    // ----------------------------

    return payloadMap;
  }

  // [수정됨] UTF-8 및 다양한 JSON 구조 처리 강화
  /// 서버 에러 응답에서 에러 메시지 추출 (UTF-8 디코딩)
  static String _parseErrorMessage(List<int> responseBodyBytes) {
    try {
      final decodedBody = utf8.decode(responseBodyBytes, allowMalformed: true);
      final dynamic decodedJson = jsonDecode(decodedBody);

      if (decodedJson is Map<String, dynamic>) {
        // Common NestJS error structure: { message: string | string[], error: string, statusCode: number }
        final message = decodedJson['message'];
        if (message is List) {
          // Handle validation errors which often come as a list of strings
          return message.join('\n');
        } else if (message is String) {
          return message;
        }
        // Fallback to other common keys
        return decodedJson['error']?.toString() ??
               decodedJson['detail']?.toString() ??
               '요청 처리 중 서버 오류 발생';
      } else if (decodedJson is String && decodedJson.isNotEmpty) {
        // Handle plain string errors
        return decodedJson;
      }
    } catch (e) {
      // If decoding/parsing fails, return the raw string (best effort)
       debugPrint("[AuthService] Error parsing error message body: $e");
       final rawBody = utf8.decode(responseBodyBytes, allowMalformed: true);
      return rawBody.isNotEmpty ? rawBody : '서버로부터 유효하지 않은 응답 수신';
    }
    // Default message if body is empty or parsing yields nothing
    return '요청을 처리할 수 없습니다.';
  }


  /// Base64 디코딩 헬퍼 (URL-safe)
  static String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0: break;
      case 2: output += '=='; break;
      case 3: output += '='; break;
      default:
        debugPrint('[AuthService] _decodeBase64 Error: Illegal base64url string length.');
        throw Exception('Illegal base64url string!');
    }
    try {
       return utf8.decode(base64Url.decode(output));
    } catch (e) {
       debugPrint('[AuthService] _decodeBase64 Error: Decoding failed. $e');
       throw Exception('Failed to decode base64 string: $e');
    }
  }
}