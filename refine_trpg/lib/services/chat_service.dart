import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/chat.dart';
import 'auth_service.dart';

class ChatService with ChangeNotifier {
  static const String _baseUrl = 'http://localhost:11122';
  static const String _wsUrl = String.fromEnvironment('CHAT_WS_URL', defaultValue: 'http://localhost:11123');
  final String roomId;
  IO.Socket? _socket;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  ChatService(this.roomId);

  void connect() async {
    // 1. 기존 로그 가져오기
    await _fetchInitialLogs();

    // 2. 웹소켓 연결
    final token = await AuthService.getToken();

    final builder = IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .disableAutoConnect();

    if (token != null) {
      // 네이티브(모바일/데스크톱)에서는 헤더가, Web에서는 쿼리가 사용됩니다.
      builder
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .setQuery({'token': token});
    }

    _socket = IO.io(_wsUrl, builder.build());

    _socket!.onConnect((_) {
      debugPrint('채팅 소켓 연결 성공');
      _socket!.emit('joinRoom', {'roomId': roomId});
    });

    _socket!.on('connect_error', (err) => debugPrint('채팅 소켓 connect_error: $err'));
    _socket!.on('error', (err) => debugPrint('채팅 소켓 error: $err'));
    _socket!.on('reconnect_attempt', (attempt) => debugPrint('채팅 소켓 재연결 시도: $attempt'));
    _socket!.on('reconnect_failed', (_) => debugPrint('채팅 소켓 재연결 실패'));

    _socket!.on('newMessage', (data) {
      _messages.add(ChatMessage.fromJson(data));
      notifyListeners();
    });

    _socket!.onDisconnect((_) => debugPrint('채팅 소켓 연결 끊김'));
    _socket!.onError((data) => debugPrint('채팅 소켓 오류: $data'));

    _socket!.on('joinedRoom', (_) => debugPrint('방 참여 완료'));
    _socket!.on('leftRoom', (_) => debugPrint('방 나가기 완료'));

    _socket!.connect();
  }

  Future<void> _fetchInitialLogs() async {
    final uri = Uri.parse('$_baseUrl/chat/rooms/${Uri.encodeComponent(roomId)}/messages');
    try {
      final token = await AuthService.getToken();
      final response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _messages.clear();
        _messages.addAll(data.map((json) => ChatMessage.fromJson(json)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('채팅 로그 로딩 실패: $e');
    }
  }

  void sendMessage(String content) {
    final text = content.trim();
    if (text.isEmpty) return;

    final payload = {
      'roomUuid': roomId,
      'messages': [
        {
          'content': text,
          'sentAt': DateTime.now().toUtc().toIso8601String(),
        }
      ]
    };

    // 원본 동작 유지: WS 전송
    _socket?.emit('sendMessage', payload);

    // 디버깅/내구성: REST로도 미러링 (Network 탭에서 확인 가능)
    _mirrorToRest(text);
  }

  Future<void> _mirrorToRest(String text) async {
    try {
      final uri = Uri.parse('$_baseUrl/chat/messages');
      final token = await AuthService.getToken();

      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'roomUuid': roomId,
          'messages': [
            {
              'content': text,
              'sentAt': DateTime.now().toUtc().toIso8601String(),
            }
          ],
        }),
      );
      // 응답은 사용하지 않음: WS의 newMessage 리스너가 UI를 갱신합니다.
    } catch (_) {
      // 네트워크 예외는 무시 (WS 전송이 이미 수행됨)
    }
  }

  /// 방에서 명시적으로 나갑니다 (필요 시 화면 전환 전에 호출)
  void leave() {
    _socket?.emit('leaveRoom', {'roomUuid': roomId});
  }

  @override
  void dispose() {
    try {
      // 방 나가기 이벤트 전송 후 리스너 정리
      _socket?.emit('leaveRoom', {'roomId': roomId});
      _socket?.off('newMessage');
      _socket?.off('joinedRoom');
      _socket?.off('leftRoom');
      _socket?.off('connect_error');
      _socket?.off('error');
      _socket?.off('reconnect_attempt');
      _socket?.off('reconnect_failed');
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {
      // ignore
    } finally {
      _socket = null;
      super.dispose();
    }
  }
}
