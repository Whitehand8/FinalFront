// lib/models/character.dart

class Character {
  final int? id;
  final String uuid; // <-- 1. uuid 필드 추가
  final int participantId;
  final int ownerId;
  final String trpgType;
  final bool isPublic;
  final Map<String, dynamic> data;

  Character({
    this.id,
    required this.uuid, // <-- 2. 생성자에 추가
    required this.participantId,
    required this.ownerId,
    required this.trpgType,
    required this.isPublic,
    required this.data,
  });

  // ... (imageUrl 게터는 동일) ...

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as int?,
      uuid: json['uuid'] as String, // <-- 3. fromJson에 추가
      participantId: json['participantId'] as int,
      ownerId: json['ownerId'] as int,
      trpgType: json['trpgType'] as String,
      isPublic: json['isPublic'] as bool,
      data: Map<String, dynamic>.from(json['data']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid, // <-- 4. toJson에 추가
      'participantId': participantId,
      'ownerId': ownerId,
      'trpgType': trpgType,
      'isPublic': isPublic,
      'data': data,
    };
  }

  Character copyWith({
    int? id,
    String? uuid, // <-- 5. copyWith에 추가
    int? participantId,
    int? ownerId,
    String? trpgType,
    bool? isPublic,
    Map<String, dynamic>? data,
  }) {
    return Character(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid, // <-- 6. copyWith에 추가
      participantId: participantId ?? this.participantId,
      ownerId: ownerId ?? this.ownerId,
      trpgType: trpgType ?? this.trpgType,
      isPublic: isPublic ?? this.isPublic,
      data: data ?? this.data,
    );
  }
}