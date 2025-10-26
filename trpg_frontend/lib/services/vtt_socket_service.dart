// lib/services/vtt_socket_service.dart
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:refine_trpg/models/token.dart';
import 'package:refine_trpg/models/vtt_scene.dart';
import 'package:refine_trpg/services/token_manager.dart'; // [수정됨] 인증 토큰 관리를 위해 필수

class VttSocketService with ChangeNotifier {
  // [수정됨] 백엔드 포트는 11122가 아닐 수 있음. ApiClient.dart의 baseUrl을 따르는 것이 좋음.
  // 여기서는 임시로 localhost:11122 사용
  static const String _baseUrl = 'http://localhost:11122'; 
  final String roomId;
  IO.Socket? _socket;

  VttScene? _scene; // 현재 맵(씬)
  VttScene? get scene => _scene;

  // [수정됨] Token ID는 int가 아니라 String(UUID)입니다.
  final Map<String, Token> _tokens = {};
  Map<String, Token> get tokens => _tokens;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  VttSocketService(this.roomId);

  /// 소켓 연결 및 맵(씬) 참여
  /// [수정됨] 맵에 참여하려면 mapId가 필수로 필요합니다.
  Future<void> connectAndJoin(String mapId) async {
    // 이미 연결되었다면 중복 실행 방지
    if (_socket != null && _socket!.connected) {
      // 맵만 변경하는 경우 (이미 소켓은 연결됨)
      _socket!.emit('joinMap', {'mapId': mapId});
      return;
    }
    
    // [수정됨] TokenManager에서 JWT Access Token 가져오기
    final token = await TokenManager.instance.getAccessToken();
    if (token == null) {
      debugPrint('[VttSocket] 인증 토큰이 없어 연결할 수 없습니다.');
      return;
    }

    _socket = IO.io(
      '$_baseUrl/vtt', // [API] 'vtt' 네임스페이스
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'roomId': roomId}) // 방 입장을 위한 쿼리
          .disableAutoConnect()
          .setAuth({'token': token}) // [수정됨] WsJwtGuard 인증을 위한 토큰 전달
          .build(),
    );

    // --- 소켓 이벤트 리스너 설정 ---

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('[VttSocket] VTT 소켓 연결 성공 (ID: ${_socket!.id})');
      // [수정됨] 연결 성공 시 'joinMap' 이벤트를 mapId와 함께 전송
      _socket!.emit('joinMap', {'mapId': mapId});
      notifyListeners();
    });

    // [수정됨] 백엔드 vtt.gateway.ts의 'joinMap'에 대한 응답 이벤트
    _socket!.on('joinedMap', (data) {
      debugPrint('[VttSocket] 맵 참여 완료 및 초기 상태 수신');
      if (data['map'] != null) {
        // [중요] VttScene.fromJson이 백엔드 VttMapDto와 호환되어야 함
        _scene = VttScene.fromJson(data['map']);
      }
      if (data['tokens'] != null) {
        _tokens.clear();
        for (var tokenData in (data['tokens'] as List)) {
          final token = Token.fromJson(tokenData as Map<String, dynamic>);
          // [수정됨] String ID를 키로 사용
          _tokens[token.id] = token; 
        }
      }
      notifyListeners();
    });

    // [수정됨] 백엔드 vtt.gateway.ts의 'updateMap'에 대한 브로드캐스트 이벤트
    _socket!.on('mapUpdated', (data) {
      _scene = VttScene.fromJson(data);
      notifyListeners();
    });

    // [수정됨] 백엔드 token.service.ts의 'TOKEN_CREATED' 이벤트
    _socket!.on('token.created', (data) {
      final token = Token.fromJson(data);
      _tokens[token.id] = token;
      notifyListeners();
    });

    // [수정됨] 백엔드 token.service.ts의 'TOKEN_UPDATED' 이벤트
    // (VttService.updateToken() API 호출 시 브로드캐스트됨)
    _socket!.on('token.updated', (data) {
      final token = Token.fromJson(data);
      _tokens[token.id] = token;
      notifyListeners();
    });

    // [수정됨] 백엔드 token.service.ts의 'TOKEN_DELETED' 이벤트
    _socket!.on('token.deleted', (data) {
      // [수정됨] 백엔드는 { id: string } 형태의 객체를 보냄
      final id = data['id'] as String?;
      if (id != null) {
        _tokens.remove(id);
        notifyListeners();
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('[VttSocket] VTT 소켓 연결 끊김');
      notifyListeners();
    });

    _socket!.onError((data) => debugPrint('[VttSocket] VTT 소켓 오류: $data'));

    _socket!.connect();
  }

  // --- 소켓 이벤트 송신 (Emitter) ---

  /// 맵(씬) 정보 업데이트 (GM 전용)
  /// [수정됨] 이벤트 이름: 'updateScene' -> 'updateMap'
  void updateMap(Map<String, dynamic> updateData) {
     // updateData는 백엔드의 UpdateMapMessageDto와 일치해야 함
     // 예: { 'mapId': _scene!.id, 'data': { 'name': 'New Name' } }
    _socket?.emit('updateMap', updateData);
  }

  /// [수정됨] 토큰 생성(createToken) 및 이동(moveToken)은
  /// 이 소켓 파일이 아니라 VttService (REST API)를 통해 호출해야 합니다.
  /// (호출 성공 시 'token.created'/'token.updated' 이벤트가 수신됨)

  /// 토큰 삭제 (GM 또는 소유자)
  /// [수정됨] 이벤트 이름: 'deleteToken'. ID 타입을 String으로 변경.
  void deleteToken(String tokenId) {
    // [수정됨] 백엔드 vtt.gateway.ts는 { id: string } DTO를 기대함
    _socket?.emit('deleteToken', {'id': tokenId});
  }

  @override
  void dispose() {
    debugPrint('[VttSocket] VttSocketService 해제. 소켓 연결 종료.');
    _socket?.dispose();
    super.dispose();
  }
}