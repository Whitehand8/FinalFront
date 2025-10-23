import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/marker.dart';
import '../models/vtt_scene.dart';
import 'auth_service.dart'; // Import AuthService to get the token

class VttSocketService with ChangeNotifier {
  static const String _baseUrl = 'http://localhost:11122'; // Ensure this matches your backend URL
  final String roomId;
  IO.Socket? _socket;
  bool _isConnected = false; // Track connection status

  VttScene? _scene;
  VttScene? get scene => _scene;

  final Map<int, Marker> _markers = {};
  // Use a getter that returns an unmodifiable map or a copy to prevent external modification
  Map<int, Marker> get markers => Map.unmodifiable(_markers);

  bool get isConnected => _isConnected;

  VttSocketService(this.roomId);

  // --- Connection ---
  Future<void> connect() async {
    // Prevent multiple connection attempts if already connected or connecting
    if (_socket != null && _socket!.connected) {
      debugPrint('VTT 소켓이 이미 연결 중이거나 연결되었습니다.');
      return;
    }

    final token = await AuthService.getToken();
    if (token == null) {
      debugPrint('VTT 소켓: 인증 토큰이 없어 연결할 수 없습니다.');
      // Optionally notify listeners about the connection failure state
      _isConnected = false;
      notifyListeners();
      return;
    }

    debugPrint('VTT 소켓 연결 시도 중... Room ID: $roomId');

    try {
      _socket = IO.io(
        '$_baseUrl/vtt', // VTT namespace
        IO.OptionBuilder()
            .setTransports(['websocket']) // Use WebSocket transport
            .setQuery({'roomId': roomId}) // Pass roomId as query parameter
            .disableAutoConnect() // Connect manually
            .setAuth({'token': token}) // Send auth token
             // Optional: Add reconnection attempts
            .setReconnectionAttempts(3)
            .setReconnectionDelay(1000) // 1 second
            .build(),
      );

      // --- Socket Event Listeners ---
      _socket!.onConnect((_) {
        debugPrint('VTT 소켓 연결 성공. ID: ${_socket?.id}');
        _isConnected = true;
        _socket!.emit('requestInitialState'); // Request initial data upon connection
        notifyListeners(); // Notify listeners about connection status change
      });

      _socket!.on('initialState', _handleInitialState);
      _socket!.on('sceneUpdated', _handleSceneUpdated);
      _socket!.on('markerCreated', _handleMarkerCreated);
      _socket!.on('markerMoved', _handleMarkerMoved);
      _socket!.on('markerDeleted', _handleMarkerDeleted);

      _socket!.onDisconnect((reason) {
        debugPrint('VTT 소켓 연결 끊김. 이유: $reason');
        _isConnected = false;
        _clearState(); // Clear data on disconnect
        notifyListeners();
      });

      _socket!.onConnectError((data) {
        debugPrint('VTT 소켓 연결 오류: $data');
        _isConnected = false;
        _clearState();
        notifyListeners();
      });

      _socket!.onError((data) {
        debugPrint('VTT 소켓 오류 발생: $data');
        // Consider more specific error handling based on 'data'
      });

      // Attempt to connect
      _socket!.connect();

    } catch (e) {
       debugPrint('VTT 소켓 생성/연결 중 예외 발생: $e');
       _isConnected = false;
       notifyListeners();
    }
  }

  // --- Event Handlers ---
  void _handleInitialState(dynamic data) {
    if (data is! Map<String, dynamic>) {
       debugPrint('VTT initialState: 잘못된 데이터 형식 수신');
       return;
    }
    debugPrint('VTT initialState 수신: $data');
    try {
      if (data['scene'] != null) {
        _scene = VttScene.fromJson(data['scene'] as Map<String, dynamic>);
      } else {
        _scene = null; // Ensure scene is nulled if not provided
      }
      _markers.clear(); // Clear existing markers before adding new ones
      if (data['markers'] != null && data['markers'] is List) {
        for (var markerData in (data['markers'] as List)) {
           if (markerData is Map<String, dynamic>) {
              final marker = Marker.fromJson(markerData);
              _markers[marker.id] = marker;
           } else {
               debugPrint('VTT initialState: 잘못된 마커 데이터 형식 수신: $markerData');
           }
        }
      }
      notifyListeners(); // Update UI
    } catch (e) {
        debugPrint('VTT initialState 처리 중 오류: $e');
        _clearState(); // Clear state on error to prevent inconsistent data
        notifyListeners();
    }
  }

 void _handleSceneUpdated(dynamic data) {
    if (data is! Map<String, dynamic>) {
       debugPrint('VTT sceneUpdated: 잘못된 데이터 형식 수신');
       return;
    }
    debugPrint('VTT sceneUpdated 수신: $data');
    try {
      _scene = VttScene.fromJson(data);
      notifyListeners();
    } catch (e) {
        debugPrint('VTT sceneUpdated 처리 중 오류: $e');
        // Decide if state should be cleared or just log the error
    }
 }

 void _handleMarkerCreated(dynamic data) {
     if (data is! Map<String, dynamic>) {
        debugPrint('VTT markerCreated: 잘못된 데이터 형식 수신');
        return;
     }
     debugPrint('VTT markerCreated 수신: $data');
     try {
       final marker = Marker.fromJson(data);
       _markers[marker.id] = marker; // Add or update the marker
       notifyListeners();
     } catch (e) {
         debugPrint('VTT markerCreated 처리 중 오류: $e');
     }
 }

 void _handleMarkerMoved(dynamic data) {
     if (data is! Map<String, dynamic>) {
        debugPrint('VTT markerMoved: 잘못된 데이터 형식 수신');
        return;
     }
     debugPrint('VTT markerMoved 수신: $data');
     try {
         // Attempt to parse the marker data
         final marker = Marker.fromJson(data);
         // Update the marker in the map only if it exists
         if (_markers.containsKey(marker.id)) {
            _markers[marker.id] = marker;
            notifyListeners();
         } else {
             // Log if trying to move a marker that doesn't exist locally
             debugPrint('VTT markerMoved: 로컬에 존재하지 않는 마커 이동 시도 (ID: ${marker.id})');
             // Optional: Request initial state again if consistency is critical
             // _socket?.emit('requestInitialState');
         }
     } catch (e) {
         debugPrint('VTT markerMoved 처리 중 오류: $e');
     }
 }


  void _handleMarkerDeleted(dynamic data) {
      if (data is! Map<String, dynamic> || data['markerId'] == null) {
          debugPrint('VTT markerDeleted: 잘못된 데이터 형식 수신');
          return;
      }
      debugPrint('VTT markerDeleted 수신: $data');
      try {
        // Ensure markerId is correctly parsed (might be int or String from backend)
        final id = int.tryParse(data['markerId'].toString());
        if (id != null) {
          if (_markers.remove(id) != null) { // Remove marker if it exists
             notifyListeners();
          } else {
             debugPrint('VTT markerDeleted: 로컬에 존재하지 않는 마커 삭제 시도 (ID: $id)');
          }
        } else {
           debugPrint('VTT markerDeleted: 유효하지 않은 markerId 수신: ${data['markerId']}');
        }
      } catch (e) {
          debugPrint('VTT markerDeleted 처리 중 오류: $e');
      }
  }


  // --- Actions (Emit Events) ---
  void updateScene(VttScene scene) {
    if (!_isConnected || _socket == null) {
        debugPrint('VTT: 소켓이 연결되지 않아 씬을 업데이트할 수 없습니다.');
        return;
    }
    _socket!.emit('updateScene', scene.toJson());
  }

  void createMarker(Marker marker) {
     if (!_isConnected || _socket == null) {
        debugPrint('VTT: 소켓이 연결되지 않아 마커를 생성할 수 없습니다.');
        return;
    }
    _socket!.emit('createMarker', marker.toJson());
  }

  void moveMarker(int markerId, double x, double y) {
     if (!_isConnected || _socket == null) {
        debugPrint('VTT: 소켓이 연결되지 않아 마커를 이동할 수 없습니다.');
        return;
     }
    _socket!.emit('moveMarker', {'markerId': markerId, 'x': x, 'y': y});
  }

  void deleteMarker(int markerId) {
     if (!_isConnected || _socket == null) {
        debugPrint('VTT: 소켓이 연결되지 않아 마커를 삭제할 수 없습니다.');
        return;
     }
    _socket!.emit('deleteMarker', {'markerId': markerId});
  }

  // --- Cleanup ---
   void _clearState() {
     _scene = null;
     _markers.clear();
     // Keep _isConnected updated by connect/disconnect handlers
   }


  @override
  void dispose() {
    debugPrint('VTT 소켓 서비스 정리 중...');
    _socket?.dispose(); // Dispose the socket connection
    _socket = null;
    _isConnected = false;
    super.dispose(); // Call ChangeNotifier's dispose
  }
}