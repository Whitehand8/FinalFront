// lib/models/room.dart
import 'participant.dart';

class Room {
  final String? id; // TRPG Room UUID
  final String name;
  final String? password;
  final int maxParticipants;
  final int currentParticipants;
  final List<Participant> participants;
  final int? creatorId;
  final String system;
  final int? chatRoomId; // ✅ 1. 채팅방 ID (숫자) 필드 추가

  Room({
    this.id,
    required this.name,
    this.password,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.participants = const [],
    this.creatorId,
    required this.system,
    this.chatRoomId, // ✅ 2. 생성자에 추가
  });

  Map<String, dynamic> toCreateJson() {
    final json = <String, dynamic>{
      'name': name,
      'maxParticipants': maxParticipants,
      'system': system,
    };

    // 로컬 변수에 할당 → promotion 가능
    final pwd = password;
    if (pwd != null && pwd.isNotEmpty) {
      json['password'] = pwd;
    }

    return json;
  }

  factory Room.fromJson(Map<String, dynamic> json) {
    // 백엔드 응답이 { message: '...', room: {...} } 형태일 수 있으므로 data 키 확인
    final data = json['room'] is Map<String, dynamic> ? json['room'] : json;

    final participants = (data['participants'] as List<dynamic>?)
            ?.map((e) => Participant.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Room(
      id: data['id']?.toString(), // TRPG Room UUID
      name: data['name'] as String? ?? 'no_name',
      password: data['password'] as String?,
      maxParticipants: data['maxParticipants'] as int? ?? 0,
      currentParticipants: data['currentParticipants'] as int? ?? 0,
      participants: participants,
      creatorId: data['creatorId'] as int?,
      system: data['system'] as String? ?? 'coc7e',
      chatRoomId: data['chatRoomId'] as int?, // ✅ 3. JSON에서 chatRoomId 파싱
    );
  }

  bool get isValid =>
      name.isNotEmpty &&
      maxParticipants > 0 &&
      maxParticipants >= currentParticipants;

  bool get canJoin => currentParticipants < maxParticipants;

  Room copyWith({
    String? id,
    String? name,
    String? password,
    int? maxParticipants,
    int? currentParticipants,
    List<Participant>? participants,
    int? creatorId,
    String? system,
    int? chatRoomId, // ✅ 4. copyWith에 추가
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      participants: participants ?? this.participants,
      creatorId: creatorId ?? this.creatorId,
      system: system ?? this.system,
      chatRoomId: chatRoomId ?? this.chatRoomId, // ✅ 5. copyWith에 추가
    );
  }
}