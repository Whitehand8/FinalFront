class RoomParticipantSummary {
  final int id;
  final String name;
  final String nickname;
  final String role;

  RoomParticipantSummary({
    required this.id,
    required this.name,
    required this.nickname,
    required this.role,
  });

  factory RoomParticipantSummary.fromJson(Map<String, dynamic> json) {
    return RoomParticipantSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      nickname: json['nickname'] as String,
      role: json['role'] as String,
    );
  }
}

class UserSummary {
  final int id;
  final String name;
  final String nickname;

  UserSummary({
    required this.id,
    required this.name,
    required this.nickname,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
    return UserSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      nickname: json['nickname'] as String,
    );
  }
}

/// Room 모델: 서버와 주고받는 방 정보의 Dart 모델 클래스.
class Room {
  /// 방 UUID (백엔드에서 생성)
  final String? id;

  /// 방 이름
  final String name;

  /// 개인방 비밀번호 (백엔드에선 항상 필요, 해시되어 저장됨)
  final String? password;

  /// 최대 수용 인원
  final int maxParticipants;

  /// 현재 참가 인원 수 (기본 0)
  final int currentParticipants;

  /// 참가자 요약 목록
  final List<RoomParticipantSummary> participants;

  /// 방 생성자 정보 (id, name, nickname 포함) 
  final UserSummary? creator;

  Room({
    this.id,
    required this.name,
    required this.password,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.participants = const [],
    this.creator, 
  });

  /// 방 생성 요청용 JSON 변환 helper — creator, participants 등은 포함하지 않음
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'password': password ?? '',
      'maxParticipants': maxParticipants,
    };
  }

  /// 서버 응답(JSON)으로부터 Room 객체를 생성
  factory Room.fromJson(Map<String, dynamic> json) {
    // 백엔드 응답이 { message: "...", room: { ... } } 구조일 수 있음
    // room 키 안의 객체만 파싱 대상
    final data = json['room'] is Map<String, dynamic>
        ? json['room'] as Map<String, dynamic>
        : json;

    UserSummary? creator;
    if (data['creator'] != null) {
      creator = UserSummary.fromJson(data['creator'] as Map<String, dynamic>);
    }

    // participants 파싱
    final participants = (data['participants'] as List<dynamic>?)
            ?.map((e) => RoomParticipantSummary.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return Room(
      id: data['id']?.toString(),
      name: data['name'] as String? ?? 'no_name',
      password: data['password'] as String?,
      maxParticipants: data['maxParticipants'] as int? ?? 0,
      currentParticipants: data['currentParticipants'] as int? ?? 0,
      participants: participants,
      creator: creator, 
    );
  }
}