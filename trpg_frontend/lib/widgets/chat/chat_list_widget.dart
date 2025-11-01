// lib/widgets/chat/chat_list_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trpg_frontend/models/participant.dart';
import 'package:trpg_frontend/services/chat_service.dart';
import 'package:trpg_frontend/widgets/chat/chat_bubble_widget.dart';

class ChatListWidget extends StatefulWidget {
  final List<Participant> participants;
  final int? currentUserId;

  const ChatListWidget({
    super.key,
    required this.participants,
    required this.currentUserId,
  });

  @override
  State<ChatListWidget> createState() => _ChatListWidgetState();
}

class _ChatListWidgetState extends State<ChatListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 참여자 목록에서 senderId에 해당하는 닉네임을 찾습니다.
  String _getSenderNickname(int senderId) {
    // participants 리스트에서 id가 senderId와 일치하는 Participant를 찾습니다.
    final sender = widget.participants.firstWhere(
      (p) => p.id == senderId,
      // 만약 참여자 목록에 없는 ID라면 (예: 방을 나간 유저) '알 수 없음'을 반환합니다.
      orElse: () => Participant(id: 0, nickname: '알 수 없음', name: '', role: 'PLAYER'),
    );
    return sender.nickname;
  }

  /// 메시지 목록이 변경될 때마다 스크롤을 맨 아래로 이동시킵니다.
  void _scrollToBottom(int messageCount) {
    // 위젯이 화면에 그려진 후에 스크롤 컨트롤러가 준비됩니다.
    if (_scrollController.hasClients) {
      // 다음 프레임이 렌더링된 후 스크롤을 실행하여, ListView가 업데이트될 시간을 줍니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent, // 스크롤 가능한 최대 위치
          duration: const Duration(milliseconds: 300), // 0.3초 동안 부드럽게
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer를 사용해 ChatService의 변경 사항을 구독합니다.
    return Consumer<ChatService>(
      builder: (context, chatService, child) {
        final messages = chatService.messages;

        // 메시지 목록이 변경(길이 변경)될 때마다 스크롤을 맨 아래로 이동시킵니다.
        // chatService.notifyListeners()가 호출되면 이 builder 함수가 다시 실행됩니다.
        _scrollToBottom(messages.length);

        if (messages.isEmpty) {
          // VTT 캔버스 위에 표시될 것이므로, 배경과 대비되는 색상을 사용합니다.
          return Center(
            child: Text(
              '메시지를 입력해 대화를 시작하세요.',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          );
        }

        // ListView.builder를 사용해 메시지 목록을 효율적으로 렌더링합니다.
        return ListView.builder(
          controller: _scrollController,
          // 하단 채팅바와 겹치지 않도록 아래쪽에 충분한 패딩을 줍니다.
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];

            // 1. 현재 사용자가 보낸 메시지인지 확인
            final bool isMe = message.senderId == widget.currentUserId;

            // 2. 메시지 보낸 사람의 닉네임 찾기
            final senderName = _getSenderNickname(message.senderId);

            // 3. ChatBubbleWidget을 사용해 메시지 표시
            return ChatBubbleWidget(
              playerName: senderName,
              message: message.content,
              isMe: isMe,
            );
          },
        );
      },
    );
  }
}