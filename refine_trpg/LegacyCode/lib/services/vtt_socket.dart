import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/marker.dart';

class VttSocket {
  final String base; // 예: http://localhost:4000
  IO.Socket? _socket;

  VttSocket(this.base);

  void connect({
    void Function(Marker m)? onMarkerCreated,
    void Function(Marker m)? onMarkerMoved,
    void Function(int markerId)? onMarkerDeleted,
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
    _socket!.on('markerCreated', (data) {
      if (data is Map && data['marker'] is Map) {
        onMarkerCreated?.call(
          Marker.fromJson(Map<String, dynamic>.from(data['marker'])),
        );
      }
    });
    _socket!.on('markerMoved', (data) {
      if (data is Map && data['marker'] is Map) {
        onMarkerMoved?.call(
          Marker.fromJson(Map<String, dynamic>.from(data['marker'])),
        );
      }
    });
    _socket!.on('markerDeleted', (data) {
      final id = (data is Map) ? data['markerId'] : null;
      if (id is int) onMarkerDeleted?.call(id);
    });
    _socket!.connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
