import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:refine_trpg/models/chat.dart';
import 'auth_service.dart';
import 'Token_manager.dart';

class ChatService with ChangeNotifier {
  final String roomId;
  IO.Socket? _socket;
  bool _isDisposed = false;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  ChatService(this.roomId) {
    _init();
  }

  Future<void> _init() async {
    await _fetchInitialLogs();
    await _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    if (_isDisposed) return;

    final Token = await TokenManager.instance.getAccessToken();
    if (Token == null) {
      debugPrint('WebSocket 연결 실패: 토큰 없음');
      return;
    }

    // ⚠️ 포트 11123, 네임스페이스 /chat
    _socket = IO.io(
      'http://localhost:11123/chat',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setExtraHeaders({
            'authorization': 'Bearer $Token', // 소문자 필수
          })
          .build(),
    );

    _socket!
      ..onConnect((_) {
        if (!_isDisposed) {
          debugPrint('WebSocket 연결 성공');
          _joinRoom();
        }
      })
      ..on('joinedRoom', (_) {
        if (!_isDisposed) debugPrint('방 참여 성공: $roomId');
      })
      ..on('newMessage', (data) {
        if (_isDisposed) return;
        try {
          final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
          _messages.add(msg);
          notifyListeners();
        } catch (e) {
          debugPrint('newMessage 파싱 실패: $e');
        }
      })
      ..on('error', (data) {
        if (_isDisposed) return;
        final msg = (data as Map<String, dynamic>)['message'] as String?;
        debugPrint('WebSocket 오류: $msg');
        // 필요 시 UI에 SnackBar 등으로 표시
      })
      ..onDisconnect((_) {
        if (!_isDisposed) debugPrint('WebSocket 연결 끊김');
      })
      ..onConnectError((err) {
        if (!_isDisposed) debugPrint('WebSocket 연결 오류: $err');
      });

    _socket!.connect();
  }

  void _joinRoom() {
    _socket?.emit('joinRoom', {'roomId': roomId});
  }

  Future<void> _fetchInitialLogs() async {
    final uri = Uri.parse('http://localhost:11122/chat/rooms/$roomId/messages');
    try {
      final Token = await TokenManager.instance.getAccessToken();
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (Token != null) 'Authorization': 'Bearer $Token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        if (_isDisposed) return;
        _messages.clear();
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            try {
              _messages.add(ChatMessage.fromJson(item));
            } catch (e) {
              debugPrint('로그 아이템 파싱 실패: $e');
            }
          }
        }
        notifyListeners();
      }
    } catch (e) {
      if (!_isDisposed) debugPrint('채팅 로그 로딩 실패: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    if (_isDisposed || _socket == null || !_socket!.connected) {
      debugPrint('소켓이 연결되지 않아 메시지를 보낼 수 없습니다.');
      return;
    }

    final senderId = await AuthService.instance.getCurrentUserId();
    if (senderId == null) {
      debugPrint('사용자 ID를 가져올 수 없습니다. 로그인이 필요합니다.');
      return;
    }

    final now = DateTime.now().toIso8601String();
    final payload = {
      'roomId': roomId,
      'messages': [
        {
          'senderId': senderId,
          'content': content,
          'sentAt': now,
        }
      ]
    };
    _socket?.emit('sendMessage', payload);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}
