// lib/services/user_service.dart
import 'package:dio/dio.dart';
import 'ApiClient.dart';

class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();

  UserService._();

  Future<bool> isEmailAvailable(String email) async {
    final res = await ApiClient.instance.dio
        .post('/users/check-email', data: {'email': email});
    return !(res.data['exists'] as bool);
  }

  Future<bool> isNicknameAvailable(String nickname) async {
    final res = await ApiClient.instance.dio
        .post('/users/check-nickname', data: {'nickname': nickname});
    return !(res.data['exists'] as bool);
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String nickname,
    required String email,
    required String password,
  }) async {
    try {
      final res = await ApiClient.instance.dio.post('/users', data: {
        'name': name,
        'nickname': nickname,
        'email': email,
        'password': password,
      });
      return {'success': true, 'message': res.data['message'] ?? '회원가입 성공'};
    } on DioException catch (e) {
      final msg = _parseErrorMessage(e.response?.data);
      return {'success': false, 'message': msg};
    }
  }

  Future<Map<String, dynamic>> updatePassword({
    required String currentPassword, // ← 파라미터는 유지하되, 전송하지 않음
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.instance.dio.patch('/users/password', data: {
        'password': newPassword, // ← currentPassword 제거
      });
      return {'success': true, 'message': res.data['message'] ?? '비밀번호 변경 성공'};
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return {'success': false, 'message': '인증 정보가 유효하지 않습니다.'};
      }
      return _handleError(e);
    }
  }

  /// 닉네임을 변경합니다.
  Future<Map<String, dynamic>> updateNickname(String nickname) async {
    try {
      final res = await ApiClient.instance.dio.patch('/users/nickname', data: {
        'nickname': nickname,
      });
      return {
        'success': true,
        'message': res.data['message'] ?? '닉네임 변경 성공',
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return {'success': false, 'message': '로그인이 필요합니다.'};
      } else if (e.response?.statusCode == 409) {
        return {'success': false, 'message': '이미 사용 중인 닉네임입니다.'};
      } else if (e.response?.statusCode == 400) {
        return {'success': false, 'message': '닉네임은 2자 이상이어야 합니다.'};
      }
      return _handleError(e);
    }
  }

  Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final res = await ApiClient.instance.dio.delete('/users');
      return {
        'success': true,
        'message': res.data['message'] ?? '계정이 삭제되었습니다.'
      };
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  String _parseErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String) {
        return message;
      } else if (message is List) {
        return message.join(', ');
      }
    }
    return '서버 오류';
  }

  Map<String, dynamic> _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError) {
      return {'success': false, 'message': '네트워크 연결을 확인해주세요.'};
    } else if (e.response?.statusCode == 409) {
      return {'success': false, 'message': '이미 사용 중입니다.'};
    } else if (e.response?.statusCode == 401) {
      return {'success': false, 'message': '인증 정보가 유효하지 않습니다.'};
    }
    return {'success': false, 'message': _parseErrorMessage(e.response?.data)};
  }
}
