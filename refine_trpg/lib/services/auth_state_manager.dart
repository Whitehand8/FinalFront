// services/auth_state_manager.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthStateManager extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true; // 로그인 상태 확인 중 로딩 상태

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // 로그인 상태 설정 (내부 사용)
  void _setLoggedIn(bool value) {
    if (_isLoggedIn != value) {
      _isLoggedIn = value;
      notifyListeners();
    }
  }

  // 로딩 상태 설정 (내부 사용)
  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

  // 로그인 시 호출
  Future<void> login() async {
    // 실제 로그인 로직 후 토큰이 저장되었다고 가정
    _setLoggedIn(true);
  }

  // 로그아웃 시 호출
  Future<void> logout() async {
    await AuthService.clearToken(); // 토큰 제거
    _setLoggedIn(false);
  }

  // 앱 시작 시 또는 필요 시 로그인 상태 확인
  Future<void> checkLoginStatus() async {
    _setLoading(true); // 로딩 시작
    try {
      // [수정됨] isTokenValid -> hasToken 으로 변경
      final hasToken = await AuthService.hasToken();
      _setLoggedIn(hasToken); // 토큰 존재 여부로 로그인 상태 설정
    } catch (e) {
      // 오류 발생 시 로그아웃 상태로 간주 (선택적)
      debugPrint("Error checking login status: $e");
      _setLoggedIn(false);
    } finally {
      _setLoading(false); // 로딩 종료
    }
  }
}