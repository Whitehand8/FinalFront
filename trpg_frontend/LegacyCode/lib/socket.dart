// lib/socket.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final IO.Socket socket = IO.io(
    'http://localhost:11122', // 실제 백엔드 주소로 수정
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableAutoConnect()
        .setAuth(
          {
            'userId': 'test8888', // TODO: 실제 유저 ID로 바꾸기
            'nickname': 'test8888', // TODO: 실제 닉네임으로 바꾸기
          },
        )
        .build(),
  );
}
