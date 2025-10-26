// models/room.dart
import 'participant.dart';

class Room {
  final String? id;
  final String name;
  final String? password;
  final int maxParticipants;
  final int currentParticipants;
  final List<Participant> participants;
  final int? creatorId;
  final String system;

  Room({
    this.id,
    required this.name,
    this.password,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.participants = const [],
    this.creatorId,
    required this.system,
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
    final data = json['room'] is Map<String, dynamic> ? json['room'] : json;

    final participants = (data['participants'] as List<dynamic>?)
            ?.map((e) => Participant.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Room(
      id: data['id']?.toString(),
      name: data['name'] as String? ?? 'no_name',
      password: data['password'] as String?,
      maxParticipants: data['maxParticipants'] as int? ?? 0,
      currentParticipants: data['currentParticipants'] as int? ?? 0,
      participants: participants,
      creatorId: data['creatorId'] as int?,
      system: data['system'] as String? ?? 'coc7e',
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
    List<Participant>? participants, // ✅ 타입 일치
    int? creatorId,
    String? system,
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
    );
  }
}
