// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'auth_service.dart'; // 인증 정보를 가져오기 위해

class SocketService {
  static IO.Socket? _socket;
  static final String _serverUrl = 'http://localhost:11122'; // 실제 백엔드 주소

  static IO.Socket get socket {
    if (_socket == null) {
      throw Exception("소켓이 초기화되지 않았습니다. connect()를 먼저 호출하세요.");
    }
    return _socket!;
  }

  static Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      return;
    }

    final token = await AuthService.getToken();
    if (token == null) {
      // 토큰이 없으면 연결 시도조차 하지 않음
      print("인증 토큰이 없어 소켓에 연결할 수 없습니다.");
      return;
    }

    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token}) // JWT 토큰을 auth 맵에 전달
          .build(),
    );

    _socket!.onConnect((_) {
      print('소켓 연결 성공: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('소켓 연결 끊김');
    });

    _socket!.onConnectError((data) {
      print('소켓 연결 오류: $data');
    });

    _socket!.onError((data) {
      print('소켓 오류: $data');
    });

    _socket!.connect();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
