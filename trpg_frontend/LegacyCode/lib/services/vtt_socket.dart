import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/Token.dart';

class VttSocket {
  final String base; // 예: http://localhost:4000
  IO.Socket? _socket;

  VttSocket(this.base);

  void connect({
    void Function(Token m)? onTokenCreated,
    void Function(Token m)? onTokenMoved,
    void Function(int TokenId)? onTokenDeleted,
  }) {
    // namespace '/vtt'
    _socket = IO.io(
      '$base/vtt',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect() // 수동 connect
          .build(),
    );
    _socket!.onConnect((_) {});
    _socket!.on('TokenCreated', (data) {
      if (data is Map && data['Token'] is Map) {
        onTokenCreated?.call(
          Token.fromJson(Map<String, dynamic>.from(data['Token'])),
        );
      }
    });
    _socket!.on('TokenMoved', (data) {
      if (data is Map && data['Token'] is Map) {
        onTokenMoved?.call(
          Token.fromJson(Map<String, dynamic>.from(data['Token'])),
        );
      }
    });
    _socket!.on('TokenDeleted', (data) {
      final id = (data is Map) ? data['TokenId'] : null;
      if (id is int) onTokenDeleted?.call(id);
    });
    _socket!.connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
