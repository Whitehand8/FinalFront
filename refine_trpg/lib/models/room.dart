// lib/models/room.dart
import 'package:flutter/foundation.dart'; // For debugPrint

/// 방 참가자의 요약 정보 (백엔드 RoomParticipantDto 와 유사)
class RoomParticipantSummary {
  /// 참가자 ID (RoomParticipant 엔티티의 PK)
  final int id;
  // User 정보는 Participant 모델에서 가져오거나 별도 조회가 필요할 수 있음
  // final int userId; // 필요시 User ID 추가
  final String name; // 사용자 이름 (User 엔티티에서 옴)
  final String nickname; // 사용자 닉네임 (User 엔티티에서 옴)
  final String role; // 참가자 역할 (예: "GM", "PLAYER")

  RoomParticipantSummary({
    required this.id,
    required this.name,
    required this.nickname,
    required this.role,
  });

  /// JSON 데이터를 RoomParticipantSummary 객체로 변환
  factory RoomParticipantSummary.fromJson(Map<String, dynamic> json) {
    // 헬퍼 함수: 안전하게 int 파싱
    int _parseInt(dynamic value, {int fallback = 0}) {
      if (value == null) return fallback;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? fallback;
      if (value is double) return value.toInt();
      return fallback;
    }

    return RoomParticipantSummary(
      // Participant ID
      id: _parseInt(json['id']), // 백엔드 RoomParticipantDto의 'id' 필드
      // 백엔드 RoomParticipantDto는 user 객체를 포함할 수 있음
      name: json['name'] as String? ?? 'Unknown Name', // 예: json['user']?['name']
      nickname: json['nickname'] as String? ?? 'Unknown Nickname', // 예: json['user']?['nickname']
      role: json['role'] as String? ?? 'PLAYER',
    );
  }
}

/// 사용자 요약 정보 (백엔드 User 엔티티 기반)
class UserSummary {
  /// 사용자 ID (User 엔티티의 PK)
  final int id; // <<< --- [수정됨] String -> int
  final String name;
  final String nickname;

  UserSummary({required this.id, required this.name, required this.nickname});

  /// JSON 데이터를 UserSummary 객체로 변환
  factory UserSummary.fromJson(Map<String, dynamic> json) {
    int parsedId = 0; // 기본값 또는 오류 처리
    if (json['id'] != null) {
      if (json['id'] is int) {
        parsedId = json['id'];
      } else if (json['id'] is String) {
        parsedId = int.tryParse(json['id']) ?? 0;
      } else if (json['id'] is double) {
        parsedId = (json['id'] as double).toInt();
      } else {
        debugPrint("Warning: Unexpected type for UserSummary ID: ${json['id'].runtimeType}");
      }
    }

    return UserSummary(
      id: parsedId, // <<< --- [수정됨] 안전하게 파싱된 int 값 사용
      name: json['name'] as String? ?? 'Unknown Name',
      nickname: json['nickname'] as String? ?? 'Unknown Nickname',
    );
  }
}

/// 방 정보를 표현하는 모델 클래스 (백엔드 RoomResponseDto 기반)
class Room {
  /// 방의 고유 ID (UUID)
  final String? id;
  final String name;
  final bool hasPassword; // <<< --- [수정됨] 비밀번호 존재 여부 (password 필드 제거)
  final int maxParticipants;
  final int currentParticipants;

  /// 참가자 목록 (요약 정보)
  final List<RoomParticipantSummary> participants;

  /// 방 생성자 정보 (요약 정보)
  final UserSummary? creator;

  /// TRPG 시스템 ID (예: "coc7e")
  final String systemId; // <<< --- [수정됨] system -> systemId 로 명칭 변경 고려 (백엔드 CreateRoomDto는 'system')

  // 백엔드 응답에 포함된 추가 필드 (선택적)
  final DateTime? createdAt;
  final DateTime? updatedAt;


  Room({
    this.id,
    required this.name,
    required this.hasPassword, // <<< --- [수정됨]
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.participants = const [],
    this.creator,
    required this.systemId,
    this.createdAt,
    this.updatedAt,
  });

  /// 방 생성 요청 시 사용하는 JSON 형식으로 변환 (백엔드 CreateRoomDto)
  Map<String, dynamic> toCreateJson({String? password}) { // <<< --- [추가됨] 비밀번호 전달 인자
    final json = {
      'name': name,
      'maxParticipants': maxParticipants,
      // 백엔드 CreateRoomDto 는 'system' 필드를 기대함
      'system': systemId, // <<< --- [수정됨] systemId -> system
    };

    // 비밀번호가 있는 경우에만 필드에 추가
    if (password != null && password.isNotEmpty) {
      json['password'] = password;
    }

    return json;
  }

  /// 서버에서 받은 JSON 데이터를 Room 객체로 변환 (백엔드 RoomResponseDto)
  factory Room.fromJson(Map<String, dynamic> json) {
    // 서버 응답이 { message: "...", room: { ... } } 형식일 수 있음
    final data = json['room'] is Map<String, dynamic>
        ? json['room'] as Map<String, dynamic>
        : json;

    UserSummary? creator;
    // 백엔드 RoomResponseDto 는 creator 객체를 포함
    if (data['creator'] != null && data['creator'] is Map<String, dynamic>) {
      creator = UserSummary.fromJson(data['creator']);
    }

    // 백엔드 RoomResponseDto 는 participants 배열을 포함
    final participants = (data['participants'] as List<dynamic>?)
            ?.map((e) {
                try {
                   return RoomParticipantSummary.fromJson(e as Map<String, dynamic>);
                } catch (err) {
                   debugPrint("Error parsing participant: $e, Error: $err");
                   return null; // 파싱 실패 시 null 반환
                }
            })
            .whereType<RoomParticipantSummary>() // null 제거
            .toList() ??
        [];

    // 헬퍼 함수: 안전하게 DateTime 파싱
    DateTime? _parseDate(dynamic value) {
       if (value is String) {
         try {
           return DateTime.parse(value);
         } catch (_) {} // 파싱 실패 시 null 반환
       }
       return null;
    }

    return Room(
      id: data['id']?.toString(), // Room ID는 UUID (String)
      name: data['name'] as String? ?? 'Unnamed Room',
      // 백엔드 RoomResponseDto 는 hasPassword 필드를 포함
      hasPassword: data['hasPassword'] as bool? ?? false, // <<< --- [수정됨]
      maxParticipants: data['maxParticipants'] as int? ?? 0,
      // 백엔드는 participants 배열 길이를 보내주지 않으므로, participants 목록으로 계산
      currentParticipants: participants.length, // <<<--- [수정됨] 직접 계산
      participants: participants,
      creator: creator,
      // 백엔드 RoomResponseDto 는 system 필드를 포함
      systemId: data['system'] as String? ?? 'unknown', // <<< --- [수정됨]
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  // --- 유틸리티 Getter ---

  bool get isFull => currentParticipants >= maxParticipants;

  // 복사본 생성 with 수정
  Room copyWith({
    String? id,
    String? name,
    bool? hasPassword,
    int? maxParticipants,
    int? currentParticipants,
    List<RoomParticipantSummary>? participants,
    UserSummary? creator, // UserSummary 타입으로 변경
    String? systemId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    // currentParticipants는 계산되므로 직접 받지 않음
    final effectiveParticipants = participants ?? this.participants;

    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      hasPassword: hasPassword ?? this.hasPassword,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: effectiveParticipants.length, // 계산된 값 사용
      participants: effectiveParticipants,
      creator: creator ?? this.creator,
      systemId: systemId ?? this.systemId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}