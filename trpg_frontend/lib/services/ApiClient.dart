import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'token_manager.dart';

// 외부에서 로그아웃 시 라우팅 처리 가능하도록 콜백 주입
typedef OnUnauthenticatedCallback = void Function();

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  late final Dio _dio;
  final TokenManager _TokenManager = TokenManager.instance;
  Completer<String?>? _refreshCompleter;
  OnUnauthenticatedCallback? _onUnauthenticated;

  ApiClient._() {
    final options = BaseOptions(
      baseUrl: 'http://localhost:11122',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    );
    _dio = Dio(options);
    _dio.interceptors.add(_AuthQueuedInterceptor(this));
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (msg) => debugPrint(msg.toString()),
      ));
    }
  }

  void setOnUnauthenticated(OnUnauthenticatedCallback callback) {
    _onUnauthenticated = callback;
  }

  Dio get dio => _dio;

  Future<String?> _refreshAccessToken() async {
    // 이미 진행 중이면 기다림
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();
    try {
      final refreshToken = await _TokenManager.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final res = await _dio
          .post('/auth/refresh', data: {'refresh_Token': refreshToken});
      final newAccessToken = res.data['access_Token'] as String?;
      final newRefreshToken = res.data['refresh_Token'] as String?;

      if (newAccessToken == null || newRefreshToken == null) {
        throw Exception('Invalid refresh response');
      }

      await _TokenManager.saveTokens(newAccessToken, newRefreshToken);
      _refreshCompleter!.complete(newAccessToken);
      return newAccessToken;
    } catch (e) {
      if (kDebugMode) debugPrint('Token refresh failed: $e');
      await _TokenManager.clearTokens();
      _refreshCompleter!.complete(null);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }
}

class _AuthQueuedInterceptor extends QueuedInterceptor {
  final ApiClient _client;

  _AuthQueuedInterceptor(this._client);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final Token = await _client._TokenManager.getAccessToken();
    if (Token != null) {
      options.headers['Authorization'] = 'Bearer $Token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final newToken = await _client._refreshAccessToken();
      if (newToken != null) {
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        try {
          final retry = await _client.dio.fetch(err.requestOptions);
          return handler.resolve(retry);
        } catch (e) {
          // retry 실패 시 원래 에러 반환
          return handler.reject(err);
        }
      } else {
        await _client._TokenManager.clearTokens();
        _client._onUnauthenticated?.call();
        return handler.reject(err);
      }
    }
    handler.next(err);
  }
}
