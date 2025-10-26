// lib/services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'token_manager.dart'; // 인증 정보를 가져오기 위해

class SocketService {
  static IO.Socket? _socket;
  static final String _serverUrl = 'http://localhost:11123';

  static IO.Socket get socket {
    if (_socket == null || !_socket!.connected) {
      throw Exception("소켓이 연결되지 않았습니다. connect()를 먼저 호출하세요.");
    }
    return _socket!;
  }

  static bool get isConnected => _socket?.connected == true;

  static Future<void> connect() async {
    if (isConnected) return;

    final Token = await TokenManager.instance.getAccessToken();
    if (Token == null) {
      throw Exception("인증 토큰이 없습니다. 로그인이 필요합니다.");
    }

    final uri = '$_serverUrl?Token=$Token';

    _socket = IO.io(
      uri,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          // .enableForceNew() // 필요 시
          .build(),
    );

    _socket!
      ..onConnect((_) => print('소켓 연결 성공: ${_socket!.id}'))
      ..onDisconnect((_) => print('소켓 연결 끊김'))
      ..onConnectError((data) => print('소켓 연결 오류: $data'))
      ..onError((data) => print('소켓 오류: $data'));

    _socket!.connect();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
