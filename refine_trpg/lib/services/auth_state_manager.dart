// services/auth_state_manager.dart
import 'package:flutter/material.dart';
import 'auth_service.dart';

class AuthStateManager extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;

  // 로그인 상태 설정
  void setLoggedIn(bool value) {
    if (_isLoggedIn != value) {
      _isLoggedIn = value;
      notifyListeners();
    }
  }

  // 로그인
  void login() {
    setLoggedIn(true);
  }

  // 로그아웃
  void logout() {
    setLoggedIn(false);
  }

  // 로그인 상태 확인
  Future<void> checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();
    _isLoggedIn = await AuthService.isTokenValid();
    _isLoading = false;
    notifyListeners();
  }
}
