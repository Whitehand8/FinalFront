// models/character.dart
class Character {
  final int? id;
  final int participantId;
  final int ownerId;
  final String trpgType;
  final bool isPublic;
  final Map<String, dynamic> data;

  Character({
    this.id,
    required this.participantId,
    required this.ownerId,
    required this.trpgType,
    required this.isPublic,
    required this.data,
  });

  //  imageUrl 접근 편의 메서드
  String? get imageUrl => data['imageUrl'] as String?;

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'] as int?,
      participantId: json['participantId'] as int,
      ownerId: json['ownerId'] as int,
      trpgType: json['trpgType'] as String,
      isPublic: json['isPublic'] as bool,
      data: Map<String, dynamic>.from(json['data']),
    );
  }

  // ✅ toJson 추가 → API 요청 시 사용
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participantId': participantId,
      'ownerId': ownerId,
      'trpgType': trpgType,
      'isPublic': isPublic,
      'data': data,
    };
  }

  //  copyWith 추가 → 상태 변경 시 사용
  Character copyWith({
    int? id,
    int? participantId,
    int? ownerId,
    String? trpgType,
    bool? isPublic,
    Map<String, dynamic>? data,
  }) {
    return Character(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      ownerId: ownerId ?? this.ownerId,
      trpgType: trpgType ?? this.trpgType,
      isPublic: isPublic ?? this.isPublic,
      data: data ?? this.data,
    );
  }
}
