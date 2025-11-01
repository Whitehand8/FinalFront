import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:trpg_frontend/models/chat.dart'; // 기존 import 경로 유지
import 'auth_service.dart';
import 'Token_manager.dart';

class ChatService with ChangeNotifier {
  // ✅ 1. String roomId를 int chatRoomId로 변경
  final int chatRoomId; 
  IO.Socket? _socket;
  bool _isDisposed = false;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  // ✅ 2. 생성자에서 int chatRoomId를 받도록 수정
  ChatService(this.chatRoomId) {
    debugPrint('[ChatService] 초기화 (ChatRoom ID: $chatRoomId)');
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
      debugPrint('[ChatService] WebSocket 연결 실패: 토큰 없음');
      return;
    }

    // ⚠️ 포트 11123, 네임스페이스 /chat
    _socket = IO.io(
      'http://localhost:11123/chat', // 백엔드 ChatGateway 포트 및 네임스페이스
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
          debugPrint('[ChatService] WebSocket 연결 성공');
          _joinRoom();
        }
      })
      ..on('joinedRoom', (_) {
        if (!_isDisposed) debugPrint('[ChatService] 방 참여 성공: $chatRoomId');
      })
      ..on('newMessage', (data) {
        if (!_isDisposed) return;
        try {
          final msg = ChatMessage.fromJson(data as Map<String, dynamic>);
          _messages.add(msg);
          notifyListeners();
        } catch (e) {
          debugPrint('[ChatService] newMessage 파싱 실패: $e');
        }
      })
      ..on('error', (data) {
        if (_isDisposed) return;
        final msg = (data as Map<String, dynamic>)['message'] as String?;
        debugPrint('[ChatService] WebSocket 오류: $msg');
      })
      ..onDisconnect((_) {
        if (!_isDisposed) debugPrint('[ChatService] WebSocket 연결 끊김');
      })
      ..onConnectError((err) {
        if (!_isDisposed) debugPrint('[ChatService] WebSocket 연결 오류: $err');
      });

    _socket!.connect();
  }

  void _joinRoom() {
    // ✅ 3. 백엔드(chat.gateway.ts)가 기대하는 숫자 ID(int) 전송
    _socket?.emit('joinRoom', {'roomId': chatRoomId});
  }

  Future<void> _fetchInitialLogs() async {
    // ✅ 4. 백엔드(chat.controller.ts)가 기대하는 숫자 ID(int)를 URL에 사용
    final uri = Uri.parse('http://localhost:11122/chat/rooms/$chatRoomId/messages');
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
              debugPrint('[ChatService] 로그 아이템 파싱 실패: $e');
            }
          }
        }
        notifyListeners();
      } else {
         debugPrint('[ChatService] 채팅 로그 로딩 실패 (Status: ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (!_isDisposed) debugPrint('[ChatService] 채팅 로그 로딩 중 네트워크 오류: $e');
    }
  }

  Future<void> sendMessage(String content) async {
    if (_isDisposed || _socket == null || !_socket!.connected) {
      debugPrint('[ChatService] 소켓이 연결되지 않아 메시지를 보낼 수 없습니다.');
      return;
    }

    final senderId = await AuthService.instance.getCurrentUserId();
    if (senderId == null) {
      debugPrint('[ChatService] 사용자 ID를 가져올 수 없습니다. 로그인이 필요합니다.');
      return;
    }

    final now = DateTime.now().toIso8601String();
    
    // ✅ 5. 백엔드(chat.gateway.ts)가 기대하는 숫자 ID(int) 전송
    final payload = {
      'roomId': chatRoomId,
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
    debugPrint('[ChatService] 해제 (ChatRoom ID: $chatRoomId)');
    _isDisposed = true;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}