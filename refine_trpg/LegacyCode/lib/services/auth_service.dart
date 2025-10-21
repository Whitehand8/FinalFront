import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // /auth/signup이 아니라 /users 로 변경
 static const _baseUrl = 'http://localhost:11122'; 
  static const _signUpUrl = '$_baseUrl/users';
  static const _loginUrl = '$_baseUrl/auth/login';

  /// 회원가입 API 호출 (POST /users)
  /// - 성공 시 true, 실패 시 false 반환
  static Future<bool> signUp({
    required String name,
    required String nickname,
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(_signUpUrl);
    final body = {
      'name': name,
      'nickname': nickname,
      'email': email,
      'password': password,
    };

    print('[AuthService] signUp 호출 URL: $uri');
    print('[AuthService] 보낼 Body: $body');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    print('[AuthService] Response Code: ${response.statusCode}');
    print('[AuthService] Response Body: ${response.body}');

    // 백엔드가 생성 성공 시 기본적으로 201 Created를 반환하도록 구현되었다면:
    return response.statusCode == 201 || response.statusCode == 200;
  }

  /// 로그인 API 호출
  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(_loginUrl);
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body);
      final token = body['access_token']; // 백엔드에서 보내는 키 이름 확인!

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', token);

      print('[AuthService] 토큰 저장 완료: $token');
      return true;
    } else {
      print('[AuthService] 로그인 실패: ${res.statusCode} ${res.body}');
    }

    return false;
  }

  /// 소셜 로그인 등 필요 시 추가
}
