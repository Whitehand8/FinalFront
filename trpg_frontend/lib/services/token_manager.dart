// lib/services/Token_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  TokenManager._();
  static final TokenManager _instance = TokenManager._();
  static TokenManager get instance => _instance;

  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_Token', value: access);
    await _storage.write(key: 'refresh_Token', value: refresh);
  }

  Future<String?> getAccessToken() async =>
      await _storage.read(key: 'access_Token');
  Future<String?> getRefreshToken() async =>
      await _storage.read(key: 'refresh_Token');
  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_Token');
    await _storage.delete(key: 'refresh_Token');
  }
}
