// lib/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'ApiClient.dart';
import 'Token_manager.dart';
import 'package:refine_trpg/utils/jwt_utils.dart';
import 'user_service.dart';

class AuthService with ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._() {
    // ApiClient에 콜백 등록
    ApiClient.instance.setOnUnauthenticated(() {
      _updateAuthState(false);
    });
  }

  final TokenManager _TokenManager = TokenManager.instance;
  bool _isLoggedIn = false;
  bool _isLoading = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  void _updateAuthState(bool loggedIn) {
    if (_isLoggedIn != loggedIn) {
      _isLoggedIn = loggedIn;
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  Future<int?> getCurrentUserId() async {
    final Token = await _TokenManager.getAccessToken();
    if (Token == null) return null;
    final payload = parseJwtPayload(Token);
    if (payload == null) return null;
    final id = payload['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  Future<bool> _isTokenNotExpiredLocally() async {
    final Token = await _TokenManager.getAccessToken();
    if (Token == null) return false;
    final payload = parseJwtPayload(Token);
    if (payload == null) return false;

    final exp = payload['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000)
          .isAfter(DateTime.now());
    }
    return false;
  }

  Future<void> checkLoginStatus() async {
    _setLoading(true);
    final hasToken = await _TokenManager.getAccessToken() != null;
    final notExpired = await _isTokenNotExpiredLocally();
    _updateAuthState(hasToken && notExpired);
    _setLoading(false);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await ApiClient.instance.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final data = res.data;
      await _TokenManager.saveTokens(
        data['access_Token'] as String,
        data['refresh_Token'] as String,
      );
      _updateAuthState(true);
      return {'success': true, 'user': data['user']};
    } on DioException catch (e) {
      final msg = _parseErrorMessage(e.response?.data);
      return {'success': false, 'message': msg};
    }
  }

  Future<void> logout() async {
    final refreshToken = await _TokenManager.getRefreshToken();
    if (refreshToken != null) {
      try {
        await ApiClient.instance.dio
            .post('/auth/logout', data: {'refresh_Token': refreshToken});
      } on DioException catch (e) {
        if (kDebugMode) debugPrint('Logout failed: ${e.message}');
      }
    }
    await _TokenManager.clearTokens();
    _updateAuthState(false);
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final result = await UserService.instance.deleteAccount();
      if (result['success'] == true) {
        await logout(); // 토큰 삭제 + 상태 업데이트
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': '회원탈퇴 중 오류가 발생했습니다.'};
    }
  }

  String _parseErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] ?? '알 수 없는 오류';
    }
    return '서버 오류';
  }
}
