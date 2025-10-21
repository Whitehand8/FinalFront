// services/auth_service.dart
import 'dart:convert'; // Corrected this line
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';

class AuthService {
  // =======================================================================
  // ✨ API Endpoint Constants
  // =======================================================================
  static const _baseUrl = 'http://localhost:11122';

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
  // 회원가입, 회원탈퇴, 중복 확인, 정보 수정 등 사용자 계정과 직접 관련된 API
  // =======================================================================

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

    print('[AuthService] signup 호출 URL: $uri');
    print('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('[AuthService] Response Code: ${response.statusCode}');
      print('[AuthService] Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': '회원가입이 완료되었습니다.'};
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } on SocketException {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      print('[AuthService] 예외 발생: $e');
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
    print('[AuthService] deleteAccount 호출 URL: $uri');

    try {
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('[AuthService] Response Code: ${response.statusCode}');
      print('[AuthService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        await clearToken();
        return {
          'success': true,
          'message': responseBody['message'] ?? '성공적으로 계정을 삭제했습니다.'
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '잘못된 신원 정보입니다.'};
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': '사용자를 찾을 수 없습니다.'};
      } else if (response.statusCode == 500) {
        return {'success': false, 'message': '서버 오류로 계정 삭제에 실패했습니다.'};
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      print('[AuthService] 회원탈퇴 중 예외 발생: $e');
      return {'success': false, 'message': '회원탈퇴 중 오류가 발생했습니다.'};
    }
  }

  /// 이메일 중복 확인 API 호출
  static Future<Map<String, dynamic>> checkEmailAvailability(
      {required String email}) async {
    final uri = Uri.parse(_checkEmailUrl);
    final body = {'email': email};

    print('[AuthService] checkEmailAvailability 호출 URL: $uri');
    print('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('[AuthService] Response Code: ${response.statusCode}');
      print('[AuthService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['exists'] == true) {
          return {'success': false, 'message': '이미 사용 중인 이메일입니다.'};
        } else {
          return {'success': true, 'message': '사용 가능한 이메일입니다.'};
        }
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      print('[AuthService] 이메일 확인 중 예외 발생: $e');
      return {'success': false, 'message': '이메일 확인 중 오류가 발생했습니다.'};
    }
  }

  /// 닉네임 중복 확인 API 호출
  static Future<Map<String, dynamic>> checkNicknameAvailability(
      {required String nickname}) async {
    final uri = Uri.parse(_checkNicknameUrl);
    final body = {'nickname': nickname};

    print('[AuthService] checkNicknameAvailability 호출 URL: $uri');
    print('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      print('[AuthService] Response Code: ${response.statusCode}');
      print('[AuthService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['exists'] == true) {
          return {'success': false, 'message': '이미 사용 중인 닉네임입니다.'};
        } else {
          return {'success': true, 'message': '사용 가능한 닉네임입니다.'};
        }
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      print('[AuthService] 닉네임 확인 중 예외 발생: $e');
      return {'success': false, 'message': '닉네임 확인 중 오류가 발생했습니다.'};
    }
  }

  /// 닉네임 변경 API 호출
  static Future<Map<String, dynamic>> updateNickname(
      {required String nickname}) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': '로그인이 필요합니다.'};
    }

    final uri = Uri.parse(_updateNicknameUrl);
    final body = {'nickname': nickname};

    print('[AuthService] updateNickname 호출 URL: $uri');
    print('[AuthService] 보낼 Body: $body');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('[AuthService] Response Code: ${response.statusCode}');
      print('[AuthService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? '닉네임이 성공적으로 변경되었습니다.'
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '인증 정보가 유효하지 않습니다.'};
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': '사용자를 찾을 수 없습니다.'};
      } else if (response.statusCode == 409) {
        return {'success': false, 'message': '이미 사용 중인 닉네임입니다.'};
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      print('[AuthService] 닉네임 변경 중 예외 발생: $e');
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
    final body = {
      'currentPassword': currentPassword,
      'password': newPassword,
    };

    print('[AuthService] updatePassword 호출 URL: $uri');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      print('[AuthService] Response Code: ${response.statusCode}');
      print('[AuthService] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? '비밀번호가 성공적으로 변경되었습니다.'
        };
      } else if (response.statusCode == 401) {
        final errorMessage = _parseErrorMessage(response.body);
        return {
          'success': false,
          'message': errorMessage.contains('password')
              ? '현재 비밀번호가 일치하지 않습니다.'
              : '인증 정보가 유효하지 않습니다.'
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': '사용자를 찾을 수 없습니다.'};
      } else {
        final errorMessage = _parseErrorMessage(response.body);
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode
        };
      }
    } on SocketException {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      print('[AuthService] 비밀번호 변경 중 예외 발생: $e');
      return {'success': false, 'message': '비밀번호 변경 중 오류가 발생했습니다.'};
    }
  }

  // =======================================================================
  // 🔑 /auth API Methods
  // 로그인 등 인증(Authentication)과 직접 관련된 API
  // =======================================================================

  /// 로그인 API 호출
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(_loginUrl);

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        final token = body['access_token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);

        print('[AuthService] 토큰 저장 완료: $token');
        return {'success': true, 'message': '로그인 성공', 'token': token};
      } else {
        print('[AuthService] 로그인 실패: ${res.statusCode} ${res.body}');
        final errorMessage = _parseErrorMessage(res.body);
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': res.statusCode,
        };
      }
    } on SocketException {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } on TimeoutException {
      return {'success': false, 'message': '서버 응답 시간이 초과되었습니다.'};
    } catch (e) {
      print('[AuthService] 로그인 예외 발생: $e');
      return {'success': false, 'message': '로그인 중 오류가 발생했습니다.'};
    }
  }

  // =======================================================================
  // 🛠️ Token & Helper Utilities
  // 토큰 관리, JWT 파싱, 에러 메시지 처리 등 보조 기능을 하는 유틸리티 메소드
  // =======================================================================

  /// SharedPreferences에서 토큰 가져오기
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  /// SharedPreferences에서 토큰 제거 (로그아웃 및 회원탈퇴 시 사용)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
  }

  /// 토큰 유효성 검사 (단순 존재 여부)
  static Future<bool> isTokenValid() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// JWT 토큰의 payload 파싱
  static Map<String, dynamic> parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('invalid token');
    }

    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('invalid payload');
    }

    return payloadMap;
  }

  /// 서버 에러 응답에서 에러 메시지 추출
  static String _parseErrorMessage(String responseBody) {
    try {
      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ??
            decoded['error'] ??
            decoded['detail'] ??
            '요청을 처리할 수 없습니다.';
        if (message is String) {
          return message;
        }
      }
    } catch (e) {
      return responseBody.isNotEmpty ? responseBody : '요청을 처리할 수 없습니다.';
    }
    return '요청을 처리할 수 없습니다.';
  }

  /// Base64 디코딩 헬퍼
  static String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');

    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }

    return utf8.decode(base64Url.decode(output));
  }
}
