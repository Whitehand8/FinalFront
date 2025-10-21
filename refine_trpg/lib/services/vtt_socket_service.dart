import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/marker.dart';
import '../models/vtt_scene.dart';
import '../services/auth_service.dart';

class VttSocketService with ChangeNotifier {
  // HTTP 기본값은 그대로 두되, VTT WebSocket은 별도 환경 변수로 분리
  static const String _httpBase =
      String.fromEnvironment('BACKEND_BASE_URL', defaultValue: 'http://localhost:11122');
  static const String _wsUrl =
      String.fromEnvironment('VTT_WS_URL', defaultValue: 'http://localhost:11123/vtt');

  final String roomId;
  IO.Socket? _socket;

  VttScene? _scene;
  VttScene? get scene => _scene;

  final Map<int, Marker> _markers = {};
  Map<int, Marker> get markers => _markers;

  VttSocketService(this.roomId);

  void _joinAndSync() {
    // 방 참여 및 초기 상태 재요청 (재연결 포함 공통 루틴)
    _socket!.emit('joinRoom', {'roomId': roomId});
    _socket!.emit('requestInitialState', {'roomId': roomId});
  }

  /// 현재 씬의 gridSize를 안전하게 가져오기 (없으면 0.0)
  double get gridSize {
    final g = (scene == null) ? null : (scene as dynamic).gridSize;
    if (g is num) return g.toDouble();
    return 0.0;
  }

  /// 현재 씬의 showGrid를 안전하게 가져오기 (없으면 false)
  bool get showGrid {
    final sg = (scene == null) ? null : (scene as dynamic).showGrid;
    if (sg is bool) return sg;
    return false;
  }

  /// 소켓 연결: JWT 헤더 포함 + 초기 상태 요청
  void connect() async {
    final token = await AuthService.getToken();

    _socket = IO.io(
      _wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(0)
          .setReconnectionDelay(500)
          .enableForceNew()
          .setQuery({'roomId': roomId})
          .setExtraHeaders({
            if (token != null) 'Authorization': 'Bearer $token',
            // 백엔드에서 사용할 수 있도록 방 정보를 헤더로도 전달
            'X-TRPG-Room': roomId,
          })
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('VTT 소켓 연결 성공');
      _joinAndSync();
    });

    _socket!.on('reconnect', (_) {
      debugPrint('VTT 소켓 재연결');
      _joinAndSync();
    });

    _socket!.on('initialState', (data) {
      if (data is Map && data['scene'] != null) {
        _scene = VttScene.fromJson(data['scene']);
      }
      if (data is Map && data['markers'] != null) {
        _markers.clear();
        for (var markerData in data['markers']) {
          final marker = Marker.fromJson(markerData);
          _markers[marker.id] = marker;
        }
      }
      notifyListeners();
    });

    _socket!.on('sceneUpdated', (data) {
      _scene = VttScene.fromJson(data);
      notifyListeners();
    });

    _socket!.on('markerCreated', (data) {
      final marker = Marker.fromJson(data);
      _markers[marker.id] = marker;
      notifyListeners();
    });

    _socket!.on('markerMoved', (data) {
      final marker = Marker.fromJson(data);
      _markers[marker.id] = marker;
      notifyListeners();
    });

    _socket!.on('markerDeleted', (data) {
      final id = data is Map ? data['markerId'] : null;
      if (id != null) {
        _markers.remove(id);
        notifyListeners();
      }
    });

    _socket!.onDisconnect((_) => debugPrint('VTT 소켓 연결 끊김'));
    _socket!.onError((data) => debugPrint('VTT 소켓 오류: $data'));

    _socket!.connect();
  }

  /// 씬 메타 업데이트: gridSize / showGrid 등을 서버에 전달
  void updateSceneMeta({double? gridSize, bool? showGrid}) {
    if (_scene == null) return;
    final payload = {
      'id': (scene as dynamic).id,
      if (gridSize != null) 'gridSize': gridSize,
      if (showGrid != null) 'showGrid': showGrid,
      'roomId': roomId,
    };
    _socket?.emit('updateScene', payload);
  }

  /// gridSize 설정 (로컬 상태는 서버 브로드캐스트(sceneUpdated)로 동기화)
  void setGridSize(double size) {
    updateSceneMeta(gridSize: size);
  }

  /// showGrid 토글
  void setShowGrid(bool show) {
    updateSceneMeta(showGrid: show);
  }

  /// 마커 생성
  void createMarker(Marker marker) {
    final payload = marker.toJson()..addAll({'roomId': roomId});
    _socket?.emit('createMarker', payload);
  }

  /// 마커 이동 (그리드 스냅 고려)
  void moveMarker(int markerId, double x, double y, {bool snapToGrid = true}) {
    double nx = x, ny = y;

    if (snapToGrid) {
      final gs = gridSize;
      if (gs > 0) {
        nx = (nx / gs).roundToDouble() * gs;
        ny = (ny / gs).roundToDouble() * gs;
      }
    }

    _socket?.emit('moveMarker', {'markerId': markerId, 'x': nx, 'y': ny, 'roomId': roomId});
    // 낙관적 업데이트는 서버 이벤트에 맞춰 처리(지연/권한 문제 방지)
  }

  /// 마커 삭제
  void deleteMarker(int markerId) {
    _socket?.emit('deleteMarker', {'markerId': markerId, 'roomId': roomId});
  }

  @override
  void dispose() {
    try {
      _socket?.dispose();
    } catch (_) {}
    super.dispose();
  }
}
