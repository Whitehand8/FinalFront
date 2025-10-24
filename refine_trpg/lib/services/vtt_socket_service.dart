import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
// 수정된 모델 파일을 임포트
import 'package:refine_trpg/models/token.dart';
import 'package:refine_trpg/models/vtt_map.dart'; // VttScene 대신 VttMap 임포트
import 'auth_service.dart'; // Import AuthService to get the token

// --- 여기부터 ---
// vtt_map.dart 파일에 정의된 Enum과 헬퍼 함수를 여기에 복사
// (이 파일에서 _gridTypeFromString 함수를 사용하기 위함)

/// 백엔드의 GridType enum (common/enums/grid-type.enum.ts)
enum GridType {
  SQUARE,
  HEX_H, // Hexagonal (Horizontal)
  HEX_V, // Hexagonal (Vertical)
}

/// GridType enum <-> String 변환
GridType _gridTypeFromString(String? type) {
  switch (type) {
    case 'SQUARE':
      return GridType.SQUARE;
    case 'HEX_H':
      return GridType.HEX_H;
    case 'HEX_V':
      return GridType.HEX_V;
    default:
      debugPrint('Warning: Unknown GridType "$type", defaulting to SQUARE.');
      return GridType.SQUARE;
  }
}
// --- 여기까지 추가 ---

class VttSocketService with ChangeNotifier {
  // 백엔드 WebSocket 게이트웨이 포트 (vtt.gateway.ts)
  static const String _baseUrl = 'http://localhost:11123';
  final String roomId; // UUID (String)
  IO.Socket? _socket;

  // --- 상태 변수 ---
  bool _isConnected = false; // 소켓 연결 상태
  bool get isConnected => _isConnected;

  bool _isRoomJoined = false; // VTT 'room' 참여 상태
  bool get isRoomJoined => _isRoomJoined;

  VttMap? _vttMap; // 현재 입장한 맵 정보 (VttScene -> VttMap)
  VttMap? get vttMap => _vttMap;

  // Key: Token ID (String), Value: Token 객체 (Marker -> Token)
  final Map<String, Token> _tokens = {};
  Map<String, Token> get tokens => Map.unmodifiable(_tokens);

  String? _error; // 오류 메시지
  String? get error => _error;

  VttSocketService(this.roomId);

  // --- 1. 연결 및 방 참여 ---
  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      debugPrint('VTT 소켓이 이미 연결되었습니다.');
      return;
    }

    final token = await AuthService.getToken();
    if (token == null) {
      debugPrint('VTT 소켓: 인증 토큰이 없어 연결할 수 없습니다.');
      _setError('인증 토큰 없음');
      return;
    }

    debugPrint('VTT 소켓 연결 시도 중... (Namespace: /vtt)');

    try {
      _socket = IO.io(
        '$_baseUrl/vtt', // VTT namespace
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token}) // 백엔드 WsAuthMiddleware
            .setReconnectionAttempts(3)
            .setReconnectionDelay(1000)
            .build(),
      );

      // --- 기본 소켓 이벤트 리스너 ---
      _socket!.onConnect((_) {
        debugPrint('VTT 소켓 연결 성공. ID: ${_socket?.id}');
        _isConnected = true;
        _setError(null); // 오류 초기화
        notifyListeners();
        // 연결 성공 시 자동으로 'joinRoom' 이벤트 호출
        _socket!.emit('joinRoom', {'roomId': roomId});
      });

      _socket!.onDisconnect((reason) {
        debugPrint('VTT 소켓 연결 끊김. 이유: $reason');
        _isConnected = false;
        _isRoomJoined = false;
        _clearMapState(); // 맵 상태 초기화
        _setError('연결 끊김');
        notifyListeners();
      });

      _socket!.onConnectError((data) {
        debugPrint('VTT 소켓 연결 오류: $data');
        _isConnected = false;
        _setError('연결 실패');
        notifyListeners();
      });

      _socket!.onError((data) {
        debugPrint('VTT 소켓 오류 발생: $data');
        String errorMessage = '알 수 없는 소켓 오류';
        if (data is Map<String, dynamic> && data.containsKey('message')) {
          errorMessage = data['message'];
        } else if (data is String) {
          errorMessage = data;
        }
        _setError(errorMessage);
        notifyListeners();
      });

      // --- VTT 커스텀 이벤트 리스너 ---
      _socket!.on('joinedRoom', _handleJoinedRoom);
      _socket!.on('leftRoom', _handleLeftRoom);
      _socket!.on('joinedMap', _handleJoinedMap);
      _socket!.on('leftMap', _handleLeftMap);
      _socket!.on('mapCreated', _handleMapCreated);
      _socket!.on('mapUpdated', _handleMapUpdated);
      _socket!.on('mapDeleted', _handleMapDeleted);
      _socket!.on('token:created', _handleTokenCreated);
      _socket!.on('token:updated', _handleTokenUpdated);
      _socket!.on('token:deleted', _handleTokenDeleted);

      // 소켓 연결 시작
      _socket!.connect();
    } catch (e) {
      debugPrint('VTT 소켓 생성/연결 중 예외 발생: $e');
      _setError('소켓 초기화 실패');
      notifyListeners();
    }
  }

  // --- 2. 맵 참여/이탈 (UI에서 호출) ---

  void joinMap(String mapId) {
    if (!_isRoomJoined || _socket == null) {
      debugPrint('VTT: 방에 먼저 참여해야 맵에 입장할 수 있습니다.');
      _setError('방 참여 필요');
      notifyListeners();
      return;
    }
    debugPrint('VTT: 맵 참여 요청: $mapId');
    _socket!.emit('joinMap', {'mapId': mapId});
  }

  void leaveMap(String mapId) {
    if (_socket == null) return;
    debugPrint('VTT: 맵 이탈 요청: $mapId');
    _socket!.emit('leaveMap', {'mapId': mapId});
  }

  // --- 3. 이벤트 핸들러 (Socket.IO) ---

  void _handleJoinedRoom(dynamic data) {
    debugPrint('VTT: 방 참여 성공: $data');
    _isRoomJoined = true;
    notifyListeners();
  }

  void _handleLeftRoom(dynamic data) {
    debugPrint('VTT: 방 이탈: $data');
    _isRoomJoined = false;
    _clearMapState();
    notifyListeners();
  }

  void _handleJoinedMap(dynamic data) {
    if (data is! Map<String, dynamic>) {
      debugPrint('VTT joinedMap: 잘못된 데이터 형식 수신');
      return;
    }
    debugPrint('VTT joinedMap 수신: $data');
    try {
      if (data['map'] != null) {
        _vttMap = VttMap.fromJson(data['map'] as Map<String, dynamic>);
      } else {
        _vttMap = null;
      }
      
      _tokens.clear();
      if (data['tokens'] != null && data['tokens'] is List) {
        for (var tokenData in (data['tokens'] as List)) {
          if (tokenData is Map<String, dynamic>) {
            final token = Token.fromJson(tokenData);
            _tokens[token.id] = token; 
          } else {
            debugPrint('VTT joinedMap: 잘못된 토큰 데이터 형식 수신: $tokenData');
          }
        }
      }
      notifyListeners(); 
    } catch (e) {
      debugPrint('VTT joinedMap 처리 중 오류: $e');
      _clearMapState();
      _setError('맵 데이터 처리 실패');
      notifyListeners();
    }
  }

  void _handleLeftMap(dynamic data) {
    debugPrint('VTT 맵 이탈 완료: $data');
    _clearMapState();
    notifyListeners();
  }

  void _handleMapCreated(dynamic data) {
    debugPrint('VTT: 새 맵 생성됨. 맵 목록 새로고침 필요. $data');
    notifyListeners(); 
  }

  void _handleMapUpdated(dynamic data) {
    if (data is! Map<String, dynamic>) {
      debugPrint('VTT mapUpdated: 잘못된 데이터 형식 수신');
      return;
    }
    debugPrint('VTT mapUpdated 수신: $data');
    try {
      if (_vttMap != null && data['mapId'] == _vttMap!.id) {
         // *** 여기가 수정된 부분 ***
         _vttMap = _vttMap!.copyWith(
           name: data['name'] ?? _vttMap!.name,
           imageUrl: data['imageUrl'] ?? _vttMap!.imageUrl,
           // data['gridType']을 String?으로 캐스팅
           gridType: data['gridType'] != null ? gridTypeFromString(data['gridType'] as String?) : _vttMap!.gridType,
           gridSize: (data['gridSize'] as num?)?.toInt() ?? _vttMap!.gridSize,
           showGrid: data['showGrid'] as bool? ?? _vttMap!.showGrid,
         );
         notifyListeners();
      }
    } catch (e) {
      debugPrint('VTT mapUpdated 처리 중 오류: $e');
    }
  }

  void _handleMapDeleted(dynamic data) {
    debugPrint('VTT: 맵 삭제됨. 맵 목록 새로고침 필요. $data');
    if (_vttMap != null && data['id'] == _vttMap!.id) {
      _clearMapState();
    }
    notifyListeners();
  }

  void _handleTokenCreated(dynamic data) {
    if (data is! Map<String, dynamic>) {
      debugPrint('VTT token:created: 잘못된 데이터 형식 수신');
      return;
    }
    debugPrint('VTT token:created 수신: $data');
    try {
      final token = Token.fromJson(data);
      if (_vttMap != null && token.mapId == _vttMap!.id) {
         _tokens[token.id] = token; 
         notifyListeners();
      }
    } catch (e) {
      debugPrint('VTT token:created 처리 중 오류: $e');
    }
  }

  void _handleTokenUpdated(dynamic data) {
    if (data is! Map<String, dynamic>) {
      debugPrint('VTT token:updated: 잘못된 데이터 형식 수신');
      return;
    }
    debugPrint('VTT token:updated 수신: $data');
    try {
      final token = Token.fromJson(data);
      if (_tokens.containsKey(token.id)) {
        _tokens[token.id] = token; 
        notifyListeners();
      }
    } catch (e) {
      debugPrint('VTT token:updated 처리 중 오류: $e');
    }
  }

  void _handleTokenDeleted(dynamic data) {
    if (data is! Map<String, dynamic> || data['id'] == null) {
      debugPrint('VTT token:deleted: 잘못된 데이터 형식 수신');
      return;
    }
    debugPrint('VTT token:deleted 수신: $data');
    try {
      final tokenId = data['id'].toString(); 
      if (_tokens.remove(tokenId) != null) { 
        notifyListeners();
      }
    } catch (e) {
      debugPrint('VTT token:deleted 처리 중 오류: $e');
    }
  }

  // --- 4. 액션 (Emit Events - UI에서 호출) ---

  void moveToken(String tokenId, double x, double y) {
    if (!_isConnected || _socket == null) {
      debugPrint('VTT: 소켓이 연결되지 않아 토큰을 이동할 수 없습니다.');
      return;
    }
    if (_vttMap == null) {
       debugPrint('VTT: 맵에 입장해있지 않아 토큰을 이동할 수 없습니다.');
       return;
    }
    
    _socket!.emit('moveToken', {
      'tokenId': tokenId,
      'x': x,
      'y': y,
    });
    
    if (_tokens.containsKey(tokenId)) {
      _tokens[tokenId]!.x = x;
      _tokens[tokenId]!.y = y;
      notifyListeners();
    }
  }

  void updateMapSettings(String mapId, Map<String, dynamic> updates) {
     if (!_isConnected || _socket == null) {
        debugPrint('VTT: 소켓이 연결되지 않아 맵 설정을 변경할 수 없습니다.');
        return;
    }
     _socket!.emit('updateMap', {
       'mapId': mapId,
       'updates': updates, 
     });
  }


  // --- 5. 정리 ---
  void _setError(String? message) {
    if (_error != message) {
      _error = message;
      notifyListeners(); 
    }
  }

  void _clearMapState() {
    _vttMap = null;
    _tokens.clear();
  }

  @override
  void dispose() {
    debugPrint('VTT 소켓 서비스 정리 중... (Room: $roomId)');
    _socket?.dispose(); 
    _socket = null;
    _isConnected = false;
    _isRoomJoined = false;
    _clearMapState();
    super.dispose();
  }
}