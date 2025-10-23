// lib/models/npc.dart
import 'package:refine_trpg/models/enums/npc_type.dart';

class Npc {
  final String? id; // <-- 생성 시점에는 null이므로 Nullable로 변경
  final String name;
  final String description;
  final String? imageUrl;
  final NpcType type;
  final Map<String, dynamic> data;
  final String roomId;

  Npc({
    this.id,
    required this.name,
    this.description = '',
    this.imageUrl,
    required this.type,
    this.data = const {}, // <-- 생성 시 기본값을 줌
    required this.roomId,
  });

  /// 서버 응답(JSON)을 Npc 객체로 변환 (Read)
  factory Npc.fromJson(Map<String, dynamic> json) {
    return Npc(
      id: json['id'],
      name: json['name'] ?? '이름 없음',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'],
      type: npcTypeFromString(json['type'] ?? 'basic'),
      data: json['data'] as Map<String, dynamic>? ?? {},
      roomId: json['roomId'],
    );
  }

  /// Npc 객체를 생성 요청용 JSON으로 변환 (Create)
  ///의 toCreateJson() 패턴을 따름
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'description': description,
      'type': npcTypeToString(type),
      'roomId': roomId,
      // 'data'는 백엔드에서 기본값이 설정되므로 여기서는 제외 (필요시 추가)
    };
  }
}