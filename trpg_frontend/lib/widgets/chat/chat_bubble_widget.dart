// widgets/chat_bubble_widget.dart
import 'package:flutter/material.dart';

class ChatBubbleWidget extends StatelessWidget {
  final String playerName;
  final String message;
  final bool isMe; // ✅ '내가 보낸 메시지'인지 확인하는 플래그 추가

  const ChatBubbleWidget({
    super.key,
    required this.playerName,
    required this.message,
    required this.isMe, // ✅ 생성자에 isMe 파라미터 추가
  });

  @override
  Widget build(BuildContext context) {
    // --- ✅ UI 스타일을 isMe 값에 따라 동적으로 결정 ---
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMe ? Colors.blue[100] : Colors.grey[300];
    final crossAxisAlignment =
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    // (선택) 말풍선 꼬리 모양을 흉내 내기 위한 모서리 설정
    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(0), // '나'의 말풍선은 오른쪽 아래가 뾰족하게
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(0), // '상대' 말풍선은 왼쪽 위가 뾰족하게
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );
    // ------------------------------------------

    // ✅ Align 위젯으로 감싸서 정렬 적용
    return Align(
      alignment: alignment,
      child: Container(
        // ✅ 말풍선이 화면의 75%를 넘지 않도록 최대 너비 제한
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: bubbleColor, // ✅ 동적 색상 적용
          borderRadius: borderRadius, // ✅ 동적 모서리 적용
        ),
        child: Column(
          crossAxisAlignment: crossAxisAlignment, // ✅ 동적 텍스트 정렬 적용
          children: [
            Text(
              playerName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13, // 이름은 약간 작게
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              message,
              style: const TextStyle(fontSize: 15), // 메시지는 기본 크기
            ),
          ],
        ),
      ),
    );
  }
}