// models/chat.dart
// 단일 ChatMessage 모델: 백엔드 MessageResponseDto(WS/REST)와 기존 로컬 포맷을 모두 파싱
// - 서버 DTO: { id, senderId, content, sentAt }
// - 레거시/로컬: { nickname/sender, message/content, timestamp }
class ChatMessage {
  final int? id;        // 서버 메시지 PK (선택)
  final int? senderId;  // 서버 사용자 ID (선택)
  final String sender;  // 표시용 닉네임/이름
  final String content;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    this.senderId,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawSentAt = json['sentAt'] ?? json['timestamp'];
    DateTime ts;
    if (rawSentAt is String) {
      ts = DateTime.tryParse(rawSentAt) ?? DateTime.now();
    } else if (rawSentAt is DateTime) {
      ts = rawSentAt;
    } else {
      ts = DateTime.now();
    }

    int? parseInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }

    final displayNameRaw = (json['nickname'] ?? json['sender'])?.toString();
    final displayName = (displayNameRaw != null && displayNameRaw.isNotEmpty)
        ? displayNameRaw
        : (json['senderId'] != null ? '#${json['senderId']}' : 'Unknown');

    return ChatMessage(
      id: parseInt(json['id']),
      senderId: parseInt(json['senderId']),
      sender: displayName,
      content: (json['content'] ?? json['message'] ?? '').toString(),
      timestamp: ts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (senderId != null) 'senderId': senderId,
      'sender': sender,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
