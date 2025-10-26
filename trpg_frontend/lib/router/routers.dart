// lib/routes/routes.dart

class Routes {
  /// 로그인 화면
  static const String login = '/login';

  /// 회원가입 화면
  static const String signup = '/signup';

  /// 방 Menu (메인 대시보드)
  static const String rooms = '/rooms';

  /// 방 생성 화면
  static const String createRoom = '/rooms/create';

  /// 방 참가 화면
  static const String joinRoom = '/rooms/join';

  /// 특정 방 상세 화면 (동적)
  static const String roomDetail = '/rooms/:roomId';

  /// 앱 설정 화면
  static const String options = '/options';

  /// roomId를 받아 완전한 방 상세 경로 반환
  static String roomById(String roomId) => '/rooms/$roomId';
}
