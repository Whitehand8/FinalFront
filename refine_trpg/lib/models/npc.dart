// lib/models/npc.dart
import 'package:refine_trpg/models/enums/npc_type.dart';

class Npc {
  // 백엔드는 ID를 number로 사용하지만, 다른 서비스에서 String으로 사용 중이므로 호환성을 위해 String? 유지
  final String? id;
  final String name;
  final String description;
  final String? imageUrl;
  final NpcType type;
  final Map<String, dynamic> data; // name, description 외의 추가 데이터
  final String roomId;
  final bool isPublic; // ✅ MODIFIED: isPublic 필드 추가

  Npc({
    this.id,
    required this.name,
    this.description = '',
    this.imageUrl,
    required this.type,
    this.data = const {},
    required this.roomId,
    this.isPublic = false, // ✅ MODIFIED: 생성자에 추가 (기본값 false)
  });

  /// 서버 응답(JSON)을 Npc 객체로 변환 (Read)
  /// ✅ MODIFIED: 백엔드 NpcResponseDto (NpcEntity) 구조에 맞게 수정
  factory Npc.fromJson(Map<String, dynamic> json) {
    // 백엔드는 name, description, imageUrl을 'data' 객체 안에 넣어 반환합니다.
    final Map<String, dynamic> dataMap =
        json['data'] as Map<String, dynamic>? ?? {};

    return Npc(
      // 백엔드는 ID를 number로 반환하므로 .toString() 처리
      id: json['id']?.toString(),
      roomId: json['roomId'] as String? ?? '', // NpcEntity에 roomId가 있음
      type: npcTypeFromString(json['type'] as String?),
      isPublic: json['isPublic'] as bool? ?? false,
      data: dataMap, // 원본 data 맵 저장

      // data 객체 내부에서 주요 필드 추출
      name: dataMap['name'] as String? ?? '이름 없음',
      description: dataMap['description'] as String? ?? '',
      imageUrl: dataMap['imageUrl'] as String?,
    );
  }

  /// Npc 객체를 생성 요청용 JSON으로 변환 (Create)
  /// ✅ MODIFIED: 백엔드 CreateNpcDto 구조에 맞게 수정
  Map<String, dynamic> toCreateJson() {
    // 백엔드 CreateNpcDto는 { data: object, isPublic: boolean, type: NpcType } 형태를 기대합니다.
    return {
      'type': npcTypeToString(type),
      'isPublic': isPublic,
      'data': {
        'name': name,
        'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        ...data, // Npc 객체에 저장된 다른 data 필드들도 함께 전송
      },
      // roomId는 NpcService의 createNpc에서 URL 파라미터로 전송되므로 body에 포함하지 않습니다.
    };
  }
}