// lib/models/npc.dart
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:refine_trpg/models/enums/npc_type.dart'; // NpcType enum 임포트

class Npc {
  /// NPC 고유 ID (PK)
  final int? id; // <<< --- [수정됨] String? -> int?
  final String name;
  final String description;
  final String? imageUrl;
  final NpcType type;

  /// name, description, imageUrl 외 추가 데이터 (백엔드 data 필드 전체)
  final Map<String, dynamic> data;

  /// NPC가 속한 방 ID (UUID)
  final String roomId;

  /// NPC 공개 여부
  final bool isPublic;

  Npc({
    this.id,
    required this.name,
    this.description = '',
    this.imageUrl,
    required this.type,
    this.data = const {},
    required this.roomId,
    this.isPublic = false,
  });

  /// 서버 응답(JSON)을 Npc 객체로 변환 (백엔드 NpcResponseDto)
  factory Npc.fromJson(Map<String, dynamic> json) {
    // 헬퍼 함수: 안전하게 int? 파싱
    int? _parseIntOptional(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
         final parsed = int.tryParse(value);
         if (parsed == null) {
            debugPrint("Warning: Failed to parse NPC ID String '$value' to int?.");
         }
         return parsed;
      }
      if (value is double) {
         debugPrint("Warning: Parsing double $value to int? for NPC ID.");
         return value.toInt();
      }
      debugPrint("Warning: Unexpected type for NPC ID parsing: ${value.runtimeType}.");
      return null;
    }

    // 백엔드는 name, description, imageUrl 등을 'data' 객체 안에 포함
    final Map<String, dynamic> dataMap = json['data'] as Map<String, dynamic>? ?? {};

    return Npc(
      id: _parseIntOptional(json['id']), // <<< --- [수정됨] int? 파싱
      roomId: json['roomId'] as String? ?? '', // NpcEntity에는 roomId가 있음
      type: npcTypeFromString(json['type'] as String?), // Enum 파싱 (별도 함수 필요)
      isPublic: json['isPublic'] as bool? ?? false,
      data: dataMap, // 원본 data 맵 저장

      // data 객체 내부에서 주요 필드 추출 (편의를 위해 유지)
      name: dataMap['name'] as String? ?? 'Unnamed NPC', // 이름 기본값
      description: dataMap['description'] as String? ?? '',
      imageUrl: dataMap['imageUrl'] as String?,
    );
  }

  /// Npc 객체를 생성 요청용 JSON으로 변환 (백엔드 CreateNpcDto)
  Map<String, dynamic> toCreateJson() {
    // 백엔드 CreateNpcDto는 { data: object, isPublic: boolean, type: NpcType, trpgType: TrpgSystem } 필요
    // trpgType은 room에서 가져오거나 별도로 받아야 함. 여기서는 생략.
    return {
      'type': npcTypeToString(type), // Enum -> String 변환 (별도 함수 필요)
      'isPublic': isPublic,
      'data': {
        'name': name,
        'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        ...data, // 다른 data 필드 포함
      },
      // roomId는 URL 파라미터로 전송되므로 body에 없음
      // trpgType: 'system_id_here' // <<<--- 필요시 TRPG 시스템 ID 추가
    };
  }

  /// Npc 객체를 수정 요청용 JSON으로 변환 (백엔드 UpdateNpcDto)
  Map<String, dynamic> toUpdateJson() {
     // UpdateNpcDto는 부분 업데이트를 허용
     // { data?: object, isPublic?: boolean, type?: NpcType }
     return {
       'type': npcTypeToString(type),
       'isPublic': isPublic,
       'data': {
         'name': name,
         'description': description,
         if (imageUrl != null) 'imageUrl': imageUrl,
         ...data,
       },
     };
  }

  // 객체 복사를 위한 copyWith (선택적)
  Npc copyWith({
    int? id,
    String? name,
    String? description,
    String? imageUrl,
    NpcType? type,
    Map<String, dynamic>? data,
    String? roomId,
    bool? isPublic,
  }) {
    // copyWith 호출 시 data 필드가 제공되면 name, description, imageUrl은 data 내부 값으로 덮어쓸지 결정 필요
    // 여기서는 name, description, imageUrl을 우선 적용하고 나머지를 data에 병합
    final effectiveData = data ?? this.data;
    if (name != null) effectiveData['name'] = name;
    if (description != null) effectiveData['description'] = description;
    if (imageUrl != null) effectiveData['imageUrl'] = imageUrl;


    return Npc(
      id: id ?? this.id,
      name: name ?? this.name, // 최상위 name 유지
      description: description ?? this.description, // 최상위 description 유지
      imageUrl: imageUrl ?? this.imageUrl, // 최상위 imageUrl 유지
      type: type ?? this.type,
      data: effectiveData, // 병합된 data 사용
      roomId: roomId ?? this.roomId,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}

// --- NpcType Enum 관련 헬퍼 함수 (npc_type.dart 파일에 정의되어 있어야 함) ---
/* // 예시: lib/models/enums/npc_type.dart
enum NpcType { NPC, MONSTER }

NpcType npcTypeFromString(String? type) {
  switch (type?.toUpperCase()) {
    case 'NPC': return NpcType.NPC;
    case 'MONSTER': return NpcType.MONSTER;
    default:
      debugPrint('Warning: Unknown NpcType "$type", defaulting to NPC.');
      return NpcType.NPC;
  }
}

String npcTypeToString(NpcType type) {
  return type.toString().split('.').last; // NpcType.NPC -> "NPC"
}
*/