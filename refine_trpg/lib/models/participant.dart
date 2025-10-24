// lib/models/participant.dart
import 'package:flutter/foundation.dart'; // For debugPrint

/// 방 참가자 정보를 나타내는 모델 (백엔드 RoomParticipantDto 와 일치)
class Participant {
  /// 참가자 ID (RoomParticipant 엔티티의 PK)
  final int id;

  /// 사용자 ID (User 엔티티의 PK)
  final int userId; // <<< --- [수정됨] 타입 String -> int

  /// 사용자 닉네임
  final String nickname;

  /// 참가자 역할 (예: "GM", "PLAYER")
  final String role;

  Participant({
    required this.id, // <<< --- [추가됨]
    required this.userId,
    required this.nickname,
    required this.role,
  });

  /// JSON 데이터를 Participant 객체로 변환
  factory Participant.fromJson(Map<String, dynamic> json) {
    // 헬퍼 함수: 안전하게 int 파싱
    int _parseInt(dynamic value, {int fallback = 0}) {
      if (value == null) {
         debugPrint("Warning: Trying to parse null int, using fallback $fallback. Field might be missing in JSON: $json");
         return fallback;
      }
      if (value is int) return value;
      if (value is String) {
         final parsed = int.tryParse(value);
         if (parsed == null) {
            debugPrint("Warning: Failed to parse String '$value' to int, using fallback $fallback.");
            return fallback;
         }
         return parsed;
      }
      if (value is double) {
         debugPrint("Warning: Parsing double $value to int.");
         return value.toInt();
      }
      debugPrint("Warning: Unexpected type for int parsing: ${value.runtimeType}, using fallback $fallback.");
      return fallback;
    }

    // 백엔드 RoomParticipantDto는 'id' (Participant ID)와 'userId' (User ID)를 포함
    return Participant(
      id: _parseInt(json['id'], fallback: -1), // <<< --- [추가됨] Participant ID 파싱 (fallback -1은 오류 식별용)
      userId: _parseInt(json['userId'], fallback: -1), // <<< --- [수정됨] User ID 파싱 (fallback -1은 오류 식별용)
      nickname: json['nickname'] as String? ?? 'Unknown Nickname',
      role: json['role'] as String? ?? 'PLAYER', // 기본 역할 PLAYER
    );
  }

  // 객체 복사를 위한 copyWith (선택적)
  Participant copyWith({
    int? id,
    int? userId,
    String? nickname,
    String? role,
  }) {
    return Participant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      role: role ?? this.role,
    );
  }
}